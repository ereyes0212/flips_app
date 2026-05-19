import 'dart:async';

import 'package:flips_app/controllers/noticias.controller.dart';
import 'package:flips_app/models/noticias.model.dart';
import 'package:flips_app/providers/noticias.provider.dart';
import 'package:flips_app/services/noticias.service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  final _controller = NoticiasController();
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _openedNewsCount = 0;
  AdManagerInterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _controller.cargarNoticias(context);
      _controller.cargarCategorias(context);
    });
    _loadInterstitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _interstitialAd?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadInterstitial() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    AdManagerInterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdManagerAdRequest(),
      adLoadCallback: AdManagerInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          debugPrint('Error al cargar interstitial: $error');
        },
      ),
    );
  }

  void _abrirDetalleConInterstitial(NoticiaModel noticia) {
    _openedNewsCount += 1;
    final shouldShowInterstitial = _openedNewsCount % 5 == 0;
    final ad = _interstitialAd;

    if (!shouldShowInterstitial || ad == null) {
      _abrirDetalle(context, noticia);
      if (ad == null) _loadInterstitial();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        _abrirDetalle(context, noticia);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
        debugPrint('Error mostrando interstitial: $error');
        _abrirDetalle(context, noticia);
      },
    );

    ad.show();
  }

  void _buscar(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _controller.cargarNoticias(context, busqueda: value.trim());
    });
  }

  Future<void> _refrescar() async {
    await _controller.cargarNoticias(
      context,
      busqueda: _searchController.text.trim(),
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
                  onSubmitted: (value) => _controller.cargarNoticias(
                    context,
                    busqueda: value.trim(),
                  ),
                  onClear: () {
                    _searchController.clear();
                    _controller.cargarNoticias(context);
                  },
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
              onLoadMore: () => _controller.cargarMasNoticias(
                context,
                busqueda: _searchController.text.trim(),
              ),
              onTapNoticia: _abrirDetalleConInterstitial,
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
    required this.onLoadMore,
    required this.onTapNoticia,
  });

  final NoticiasProvider provider;
  final VoidCallback onLoadMore;
  final ValueChanged<NoticiaModel> onTapNoticia;

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
          title: 'No pudimos cargar las noticias',
          message: provider.errorMessage,
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
            child: _PortadaCard(noticia: provider.noticias.first),
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
  const _NoticiasList({required this.noticias, required this.onTapNoticia});

  final List<NoticiaModel> noticias;
  final ValueChanged<NoticiaModel> onTapNoticia;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < noticias.length; i++) {
      final noticia = noticias[i];
      children.add(
        _NoticiaCard(
          noticia: noticia,
          onTapOverride: () => onTapNoticia(noticia),
        ),
      );
      if ((i + 1) % 5 == 0 && i != noticias.length - 1) {
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
  static const String _adUnitId = '/170101793/APP/Interstitial';
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
}

void _abrirDetalle(BuildContext context, NoticiaModel noticia) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _NoticiaDetalleScreen(noticia: noticia)),
  );
}

void _abrirCategoria(BuildContext context, CategoriaNoticiaModel categoria) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _CategoriaNoticiasScreen(categoria: categoria),
    ),
  );
}
