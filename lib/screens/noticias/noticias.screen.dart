import 'dart:async';
import 'dart:io';

import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/lector.provider.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/screens/notificaciones/notificaciones.screen.dart';
import 'package:flips_app/screens/onboarding/onboarding_flow.dart';
import 'package:flips_app/screens/sitio_web/sitio_web.screen.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flips_app/services/analytics.service.dart';
import 'package:flips_app/services/push_notifications.service.dart';
import 'package:flips_app/globals/widgets/ad_banner.widget.dart';
import 'package:flips_app/services/acceso_usuario.service.dart';
import 'package:flips_app/services/interstitial_ads.service.dart';
import 'package:flips_app/utils/html_texto.util.dart';
import 'package:flips_app/utils/lectura_noticia.util.dart';
import 'package:flips_app/utils/noticia_link.util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

part 'categoria_noticias.screen.dart';
part 'noticia_desde_push.screen.dart';
part 'noticia_detalle.screen.dart';
part 'widgets/category_widgets.dart';
part 'widgets/news_cards.dart';
part 'widgets/noticias_header.dart';
part 'widgets/search_bar.dart';
part 'widgets/shared_widgets.dart';

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key, this.notificationsButtonKey});

  /// Clave del botón de notificaciones del header, usada por el tour guiado
  /// para resaltarlo. La provee quien monta la pantalla.
  final GlobalKey? notificationsButtonKey;

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  static const Duration _manualRefreshCooldown = Duration(seconds: 45);

  final _controller = NoticiasController();
  final _searchController = TextEditingController();
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();
  DateTimeRange? _filtroFecha;
  DateTime? _lastManualRefreshAt;
  final _noticiasService = NoticiasService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _controller.cargarNoticias(context);
      _controller.cargarCategorias(context);
      _cargarNoticiasOffline();
    });
    _resolverAcceso();
  }

  Future<void> _cargarNoticiasOffline() async {
    final noticiasOffline = await _noticiasService.obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(noticiasOffline);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;

    setState(() => _acceso = acceso);
    if (acceso.mostrarAnuncios) InterstitialAdsService.instance.precargar();
  }

  void _abrirDetalleConInterstitial(NoticiaModel noticia) {
    void abrir() => _abrirDetalle(context, noticia, acceso: _acceso);

    if (!_acceso.mostrarAnuncios) {
      abrir();
      return;
    }

    InterstitialAdsService.instance.registrarAperturaYContinuar(abrir);
  }


  Future<void> _seleccionarFiltroFecha() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: now,
      initialDateRange: _filtroFecha,
      locale: const Locale('es'),
      helpText: 'Filtrar por fecha',
      saveText: 'Aplicar',
    );
    if (!mounted || picked == null) return;
    setState(() => _filtroFecha = picked);
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
      fechaDesde: picked.start,
      fechaHasta: picked.end,
    );
  }

  Future<void> _limpiarFiltroFecha() async {
    if (_filtroFecha == null) return;
    setState(() => _filtroFecha = null);
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
    );
  }

  Future<void> _mostrarFiltrosBusqueda() async {
    final result = await showModalBottomSheet<_NewsFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _NewsFilterSheet(
        controller: _searchController,
        filtroFecha: _filtroFecha,
        onSelectDate: _seleccionarFiltroFecha,
        onClearDate: _limpiarFiltroFecha,
      ),
    );

    if (!mounted || result == null) return;
    if (result.clearSearch) {
      _searchController.clear();
    }
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
      fechaDesde: _filtroFecha?.start,
      fechaHasta: _filtroFecha?.end,
      forceRefresh: true,
    );
  }

  Future<void> _refrescar() async {
    final provider = context.read<NoticiasProvider>();
    final now = DateTime.now();
    final lastRefresh = _lastManualRefreshAt;
    if (lastRefresh != null &&
        provider.noticias.isNotEmpty &&
        now.difference(lastRefresh) < _manualRefreshCooldown) {
      final remaining = _manualRefreshCooldown - now.difference(lastRefresh);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Espera ${remaining.inSeconds + 1}s antes de refrescar nuevamente.',
          ),
        ),
      );
      return;
    }

    _lastManualRefreshAt = now;
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
      fechaDesde: _filtroFecha?.start,
      fechaHasta: _filtroFecha?.end,
      forceRefresh: provider.usingCache || provider.errorMessage.isNotEmpty,
    );
    if (!mounted) return;
    await _controller.cargarCategorias(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoticiasProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _NoticiasAppBar(
              total: provider.noticias.length,
              usingCache: provider.usingCache,
              bellKey: widget.notificationsButtonKey,
            ),
            SliverToBoxAdapter(
              child: _NewsDiscoveryRail(
                categorias: provider.categorias,
                loadingCategorias: provider.loadingCategorias,
                hasQuery: _searchController.text.trim().isNotEmpty,
                filtroFecha: _filtroFecha,
                onOpenFilters: _mostrarFiltrosBusqueda,
                onClearDate: _limpiarFiltroFecha,
                onTapCategoria: (categoria) => _abrirCategoria(context, categoria),
              ),
            ),
            _NoticiasContentSlivers(
              provider: provider,
              onRetry: _refrescar,
              onLoadMore: () => _controller.cargarMasNoticias(
                context,
                busqueda: _searchController.text.trim(),
                fechaDesde: _filtroFecha?.start,
                fechaHasta: _filtroFecha?.end,
              ),
              onTapNoticia: _abrirDetalleConInterstitial,
              acceso: _acceso,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticiasContentSlivers extends StatelessWidget {
  const _NoticiasContentSlivers({
    required this.provider,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTapNoticia,
    required this.acceso,
  });

  final NoticiasProvider provider;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<NoticiaModel> onTapNoticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (provider.loading && provider.noticias.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.errorMessage.isNotEmpty && provider.noticias.isEmpty) {
      final isOfflineError =
          provider.errorMessage.toLowerCase().contains('sin conexión');
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: isOfflineError
              ? Icons.cloud_off_outlined
              : Icons.error_outline_rounded,
          title: isOfflineError
              ? 'Sin conexión a internet'
              : 'No pudimos cargar noticias',
          message: provider.errorMessage,
          actionLabel: 'Reintentar',
          onAction: onRetry,
        ),
      );
    }

    if (provider.noticias.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: Icons.search_off_outlined,
          title: 'Sin resultados',
          message: 'Intenta con otra palabra clave para encontrar noticias.',
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (provider.errorMessage.isNotEmpty || provider.usingCache)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _StatusBanner(
                text: provider.errorMessage.isNotEmpty
                    ? provider.errorMessage
                    : 'Mostrando noticias guardadas.',
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _PortadaCard(
              noticia: provider.noticias.first,
              acceso: acceso,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Text(
                  'Últimas noticias',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const Spacer(),
                if (provider.loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        _NoticiasList(
          noticias: provider.noticias,
          onTapNoticia: onTapNoticia,
          acceso: acceso,
        ),
        SliverToBoxAdapter(
          child: _LoadMoreButton(
            hasMore: provider.hasMore,
            loading: provider.loadingMore,
            onPressed: onLoadMore,
          ),
        ),
      ],
    );
  }
}

class _NoticiasList extends StatelessWidget {
  const _NoticiasList({
    required this.noticias,
    required this.onTapNoticia,
    required this.acceso,
  });

  final List<NoticiaModel> noticias;
  final ValueChanged<NoticiaModel> onTapNoticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final offlineIds = context.watch<NoticiasProvider>().noticiasOfflineIds;
    final children = <Widget>[];
    for (var i = 0; i < noticias.length; i++) {
      final noticia = noticias[i];
      children.add(
        _NoticiaCard(
          noticia: noticia,
          isDownloaded: offlineIds.contains(noticia.id),
          onTapOverride: () => onTapNoticia(noticia),
        ),
      );
      if (acceso.mostrarAnuncios &&
          (i + 1) % 5 == 0 &&
          i != noticias.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: _InlineNewsAdBanner(),
          ),
        );
      }
      if (i != noticias.length - 1) {
        children.add(
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.55),
          ),
        );
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}

/// Rectángulo que se intercala cada cinco noticias del listado.
class _InlineNewsAdBanner extends StatelessWidget {
  const _InlineNewsAdBanner();

  static const String _adUnitId = '/170101793/APP/box_1';

  @override
  Widget build(BuildContext context) {
    return const AdManagerBannerView(
      adUnitId: _adUnitId,
      sizes: [
        AdSize(width: 300, height: 250),
        AdSize(width: 336, height: 280),
        AdSize(width: 320, height: 480),
      ],
    );
  }
}


Future<void> _compartirNoticia(BuildContext context, NoticiaModel noticia) async {
  final link = noticia.link.trim();
  if (link.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esta noticia no tiene un enlace para compartir.')),
    );
    return;
  }

  final mensaje = '${noticia.title}\n$link';
  await SharePlus.instance.share(ShareParams(text: mensaje, subject: noticia.title));
  await AnalyticsService.logNoteShare(
    noteId: noticia.id,
    slug: noticia.slug,
    title: noticia.title,
  );
}

// La nota completa (y su guardado offline) se resuelve dentro del detalle,
// porque el listado solo trae los datos de la tarjeta.
void _abrirDetalle(
  BuildContext context,
  NoticiaModel noticia, {
  AccesoUsuario acceso = const AccesoUsuario.sinResolver(),
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      settings: analyticsRouteSettingsFromNews(noticia),
      builder: (_) => _NoticiaDetalleScreen(noticia: noticia, acceso: acceso),
    ),
  );
}

/// El detalle manda su propio `screen_view` (con el título de la nota), así que
/// la ruta queda marcada para que el observer global no lo repita.
RouteSettings analyticsRouteSettingsFromNews(NoticiaModel noticia) => RouteSettings(
  name: _analyticsPathFromNews(noticia),
  arguments: kRutaConAnalyticsPropio,
);

String _analyticsPathFromNews(NoticiaModel noticia) {
  final rawLink = noticia.link.trim();
  if (rawLink.isNotEmpty) {
    final uri = Uri.tryParse(rawLink);
    final path = uri?.path.trim() ?? '';
    if (path.isNotEmpty && path != '/') return path;
    if (rawLink.startsWith('/')) return rawLink;
  }

  return '/noticias/${noticia.slug}';
}

String _heroTagForNewsImage(NoticiaModel noticia) {
  if (noticia.imageUrl.isNotEmpty) return 'news-image-${noticia.id}-${noticia.imageUrl}';
  return 'news-image-${noticia.id}-${noticia.slug}';
}

/// Abre una imagen a pantalla completa con zoom.
///
/// Comparte el `heroTag` con la miniatura de origen para que la transición sea
/// continua. Ignora las URLs vacías: sin imagen no hay nada que ampliar.
void _abrirImagenCompleta(
  BuildContext context, {
  required String imageUrl,
  required String heroTag,
  String caption = '',
}) {
  if (imageUrl.isEmpty) return;

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _FullscreenImageViewer(
        imageUrl: imageUrl,
        heroTag: heroTag,
        caption: caption,
      ),
    ),
  );
}

void _abrirCategoria(BuildContext context, CategoriaNoticiaModel categoria) {
  AnalyticsService.logCategorySearch(
    categoryId: categoria.id,
    categoryName: categoria.name,
  );

  final categorySlug = categoria.slug.trim();
  final categoryPath = categorySlug.isEmpty ? '/categoria/${categoria.id}' : '/$categorySlug';

  Navigator.push(
    context,
    MaterialPageRoute(
      settings: RouteSettings(name: categoryPath),
      builder: (_) => _CategoriaNoticiasScreen(categoria: categoria),
    ),
  );
}

class NoticiaDetalleScreen extends StatelessWidget {
  const NoticiaDetalleScreen({
    super.key,
    required this.noticia,
    this.acceso = const AccesoUsuario.sinResolver(),
  });

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final noticiaParaDetalle = noticia.localImagePath.isEmpty
        ? noticia
        : noticia.copyWith(imageUrl: noticia.localImagePath);
    return _NoticiaDetalleScreen(noticia: noticiaParaDetalle, acceso: acceso);
  }
}
