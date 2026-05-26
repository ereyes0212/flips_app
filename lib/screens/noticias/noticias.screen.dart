import 'dart:async';
import 'dart:io';

import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flips_app/services/analytics.service.dart';
import 'package:flips_app/services/mi_perfil.service.dart';
import 'package:flips_app/utils/ad_visibility.util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

part 'categoria_noticias.screen.dart';
part 'noticia_detalle.screen.dart';
part 'widgets/category_widgets.dart';
part 'widgets/news_cards.dart';
part 'widgets/noticias_header.dart';
part 'widgets/search_bar.dart';
part 'widgets/shared_widgets.dart';

class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  static const String _interstitialAdUnitId = '/170101793/APP/Interstitial';
  static const int _interstitialFrequency = 5;
  static const int _preloadBeforeNewsCount = 2;
  static const Duration _retryLoadDelay = Duration(seconds: 8);

  final _controller = NoticiasController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _retryInterstitialTimer;
  int _openedNewsCount = 0;
  int _nextInterstitialAt = _interstitialFrequency;
  bool _pendingInterstitial = false;
  AdManagerInterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  bool _hideAds = false;
  DateTimeRange? _filtroFecha;
  final _noticiasService = NoticiasService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _controller.cargarNoticias(context);
      _controller.cargarCategorias(context);
      _cargarNoticiasOffline();
    });
    _initAdsVisibility();
  }

  Future<void> _cargarNoticiasOffline() async {
    final noticiasOffline = await _noticiasService.obtenerNoticiasOffline();
    if (!mounted) return;
    context.read<NoticiasProvider>().setNoticiasOffline(noticiasOffline);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _retryInterstitialTimer?.cancel();
    _interstitialAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAdsVisibility() async {
    final perfil = await MiPerfilService().obtenerMiPerfil();
    if (!mounted) return;
    setState(() => _hideAds = AdVisibilityUtil.shouldHideAds(perfil));
    if (_hideAds) return;
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (_hideAds) return;
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _retryInterstitialTimer?.cancel();
    _isInterstitialLoading = true;
    AdManagerInterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdManagerAdRequest(),
      adLoadCallback: AdManagerInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.setImmersiveMode(true);
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          if (kDebugMode) {
            if (error.code == 3) {
              debugPrint(
                'Interstitial sin inventario (no fill). Se reintentará en ${_retryLoadDelay.inSeconds}s.',
              );
            } else {
              debugPrint('Error al cargar interstitial: $error');
            }
          }
          _scheduleInterstitialReload();
        },
      ),
    );
  }

  void _scheduleInterstitialReload() {
    _retryInterstitialTimer?.cancel();
    _retryInterstitialTimer = Timer(_retryLoadDelay, _loadInterstitial);
  }

  void _maybePreloadInterstitial() {
    final remaining = _nextInterstitialAt - _openedNewsCount;
    if (remaining <= _preloadBeforeNewsCount) {
      _loadInterstitial();
    }
  }

  void _abrirDetalleConInterstitial(NoticiaModel noticia) {
    if (_hideAds) {
      _abrirDetalle(context, noticia, hideAds: _hideAds);
      return;
    }

    _openedNewsCount += 1;
    final reachedMilestone = _openedNewsCount >= _nextInterstitialAt;
    final shouldShowInterstitial = _pendingInterstitial || reachedMilestone;
    if (reachedMilestone) {
      _pendingInterstitial = true;
    }
    _maybePreloadInterstitial();
    final ad = _interstitialAd;
    if (kDebugMode) {
      debugPrint(
        'Noticias abiertas: $_openedNewsCount, mostrar interstitial: $shouldShowInterstitial',
      );
    }
    if (!shouldShowInterstitial || ad == null) {
      _abrirDetalle(context, noticia, hideAds: _hideAds);
      if (ad == null) _loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _pendingInterstitial = false;
        _nextInterstitialAt += _interstitialFrequency;
        _interstitialAd = null;
        _loadInterstitial();
        _abrirDetalle(context, noticia, hideAds: _hideAds);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _pendingInterstitial = true;
        _interstitialAd = null;
        _loadInterstitial();
        debugPrint('Error mostrando interstitial: $error');
        _abrirDetalle(context, noticia, hideAds: _hideAds);
      },
    );

    ad.show();
  }

  void _buscar(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final query = value.trim();
      _controller.cargarNoticias(
        context,
        busqueda: query,
        fechaDesde: _filtroFecha?.start,
        fechaHasta: _filtroFecha?.end.add(const Duration(days: 1)),
      );
      AnalyticsService.logNewsSearch(query: query);
    });
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
      fechaHasta: picked.end.add(const Duration(days: 1)),
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

  Future<void> _refrescar() async {
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
      fechaDesde: _filtroFecha?.start,
      fechaHasta: _filtroFecha?.end.add(const Duration(days: 1)),
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _NoticiasSearchBar(
                  controller: _searchController,
                  loading: provider.loading,
                  onChanged: _buscar,
                  onSubmitted: (value) {
                    final query = value.trim();
                    _controller.cargarNoticias(
                      context,
                      busqueda: query,
                      fechaDesde: _filtroFecha?.start,
                      fechaHasta: _filtroFecha?.end.add(const Duration(days: 1)),
                    );
                    AnalyticsService.logNewsSearch(query: query);
                  },
                  onClear: () {
                    _searchController.clear();
                    _controller.cargarNoticias(
                      context,
                      fechaDesde: _filtroFecha?.start,
                      fechaHasta: _filtroFecha?.end.add(const Duration(days: 1)),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _filtroFecha == null
                            ? 'Buscar por fecha'
                            : '${DateFormat('dd/MM/yyyy').format(_filtroFecha!.start)} - ${DateFormat('dd/MM/yyyy').format(_filtroFecha!.end)}',
                      ),
                      onPressed: _seleccionarFiltroFecha,
                    ),
                    if (_filtroFecha != null)
                      ActionChip(
                        avatar: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Limpiar fecha'),
                        onPressed: _limpiarFiltroFecha,
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CategoryQuickAccess(
                categorias: provider.categorias,
                loading: provider.loadingCategorias,
                onTap: (categoria) => _abrirCategoria(context, categoria),
              ),
            ),
            _NoticiasContentSlivers(
              provider: provider,
              onRetry: _refrescar,
              onLoadMore: () => _controller.cargarMasNoticias(
                context,
                busqueda: _searchController.text.trim(),
                fechaDesde: _filtroFecha?.start,
                fechaHasta: _filtroFecha?.end.add(const Duration(days: 1)),
              ),
              onTapNoticia: _abrirDetalleConInterstitial,
              hideAds: _hideAds,
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
    required this.hideAds,
  });

  final NoticiasProvider provider;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<NoticiaModel> onTapNoticia;
  final bool hideAds;

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
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Sin conexión a internet',
          message: 'Verifica tu conexión e intenta nuevamente.',
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
                text: provider.usingCache
                    ? 'Mostrando noticias guardadas mientras vuelve la conexión.'
                    : provider.errorMessage,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _PortadaCard(
              noticia: provider.noticias.first,
              hideAds: hideAds,
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
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
          hideAds: hideAds,
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
  const _NoticiasList({required this.noticias, required this.onTapNoticia, this.hideAds = false});

  final List<NoticiaModel> noticias;
  final ValueChanged<NoticiaModel> onTapNoticia;
  final bool hideAds;

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
      if (!hideAds && (i + 1) % 5 == 0 && i != noticias.length - 1) {
        children.add(
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8),
            child: _InlineNewsAdBanner(),
          ),
        );
      }
      if (i != noticias.length - 1) {
        children.add(const SizedBox(height: 14));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      sliver: SliverList(delegate: SliverChildListDelegate(children)),
    );
  }
}

class _InlineNewsAdBanner extends StatefulWidget {
  const _InlineNewsAdBanner();

  @override
  State<_InlineNewsAdBanner> createState() => _InlineNewsAdBannerState();
}

class _InlineNewsAdBannerState extends State<_InlineNewsAdBanner> {
  static const String _adUnitId = '/170101793/APP/box_1';
  AdManagerBannerAd? _ad;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final ad = AdManagerBannerAd(
      adUnitId: _adUnitId,
      request: const AdManagerAdRequest(),
      sizes: const [
        AdSize(width: 300, height: 250),
        AdSize(width: 320, height: 480),
        AdSize(width: 336, height: 280),
      ],
      listener: AdManagerBannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _ready = true) : null,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Error banner inline noticias: $error');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: 300,
      height: 250,
      child: AdWidget(ad: _ad!),
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

Future<void> _abrirDetalle(BuildContext context, NoticiaModel noticia, {bool hideAds = false}) async {
  await AnalyticsService.logNoteView(
    noteId: noticia.id,
    slug: noticia.slug,
    title: noticia.title,
    categoryIds: noticia.categories,
  );
  await AnalyticsService.logNewsScreen(
    slug: noticia.slug,
    title: noticia.title,
    categoryIds: noticia.categories,
  );

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _NoticiaDetalleScreen(noticia: noticia, hideAds: hideAds)),
  );

  if (!hideAds) return;

  final provider = context.read<NoticiasProvider>();
  Future<void>(() async {
    await NoticiasService().guardarNoticiaOffline(noticia);
    final saved = await NoticiasService().obtenerNoticiasOffline();
    provider.setNoticiasOffline(saved);
  });
}

String _heroTagForNewsImage(NoticiaModel noticia) {
  if (noticia.imageUrl.isNotEmpty) return 'news-image-${noticia.id}-${noticia.imageUrl}';
  return 'news-image-${noticia.id}-${noticia.slug}';
}

void _abrirCategoria(BuildContext context, CategoriaNoticiaModel categoria) {
  AnalyticsService.logCategorySearch(
    categoryId: categoria.id,
    categoryName: categoria.name,
  );

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _CategoriaNoticiasScreen(categoria: categoria),
    ),
  );
}

class NoticiaDetalleScreen extends StatelessWidget {
  const NoticiaDetalleScreen({
    super.key,
    required this.noticia,
    this.hideAds = false,
  });

  final NoticiaModel noticia;
  final bool hideAds;

  @override
  Widget build(BuildContext context) {
    final noticiaParaDetalle =
        noticia.localImagePath.isEmpty
            ? noticia
            : NoticiaModel(
                id: noticia.id,
                link: noticia.link,
                slug: noticia.slug,
                date: noticia.date,
                title: noticia.title,
                excerpt: noticia.excerpt,
                content: noticia.content,
                contentBlocks: noticia.contentBlocks,
                imageUrl: noticia.localImagePath,
                imageAlt: noticia.imageAlt,
                localImagePath: noticia.localImagePath,
                categories: noticia.categories,
              );
    return _NoticiaDetalleScreen(noticia: noticiaParaDetalle, hideAds: hideAds);
  }
}
