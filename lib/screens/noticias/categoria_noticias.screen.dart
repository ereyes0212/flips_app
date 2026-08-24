part of 'noticias.screen.dart';

class _CategoriaNoticiasScreen extends StatefulWidget {
  const _CategoriaNoticiasScreen({required this.categoria});

  final CategoriaNoticiaModel categoria;

  @override
  State<_CategoriaNoticiasScreen> createState() =>
      _CategoriaNoticiasScreenState();
}

class _CategoriaNoticiasScreenState extends State<_CategoriaNoticiasScreen> {
  /// Mismo umbral que el listado principal: al 80% se pide la página siguiente.
  static const double _umbralCargaAutomatica = 0.8;

  final _service = NoticiasService();
  final _scrollController = ScrollController();
  final List<NoticiaModel> _noticias = [];
  var _loading = true;
  var _loadingMore = false;
  var _loadMoreFailed = false;
  var _error = '';
  var _loadMoreError = '';
  var _page = 1;
  var _hasMore = true;
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_alHacerScroll);
    Future.microtask(_cargarNoticias);
    _resolverAcceso();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_alHacerScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;
    setState(() => _acceso = acceso);
  }

  void _alHacerScroll() {
    if (!_scrollController.hasClients) return;
    final posicion = _scrollController.position;
    final maximo = posicion.maxScrollExtent;
    if (maximo <= 0) return;
    if (posicion.pixels < maximo * _umbralCargaAutomatica) return;
    // Tras un fallo se espera al botón del pie: reintentar en cada píxel de
    // scroll solo castiga a un backend que ya respondió que no.
    if (_loadMoreFailed) return;
    _cargarNoticias(reset: false);
  }

  void _reintentarCargarMas() {
    setState(() {
      _loadMoreFailed = false;
      _loadMoreError = '';
    });
    _cargarNoticias(reset: false);
  }

  Future<void> _cargarNoticias({bool reset = true}) async {
    if (!reset && (_loading || _loadingMore || !_hasMore)) return;

    setState(() {
      if (reset) {
        _loading = true;
        _error = '';
        _page = 1;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
      _loadMoreFailed = false;
      _loadMoreError = '';
    });

    final nextPage = reset ? 1 : _page + 1;
    final result = await _service.obtenerNoticias(
      page: nextPage,
      categoria: widget.categoria.id,
    );

    if (!mounted) return;
    setState(() {
      if (result.success) {
        if (reset) {
          _noticias
            ..clear()
            ..addAll(result.items);
        } else {
          _noticias.addAll(result.items);
        }
        _page = nextPage;
        _hasMore = result.hasMore;
      } else if (reset) {
        _error = result.errorMessage;
      } else {
        // Una página que falla no borra las que ya se están leyendo.
        _loadMoreFailed = true;
        _loadMoreError = result.errorMessage;
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _cargarNoticias,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _CategoryAppBar(categoria: widget.categoria),
            if (_loading && _noticias.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: _NoticiasSkeletonGroup(items: 6),
                ),
              )
            else if (_error.isNotEmpty && _noticias.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Sin conexión a internet',
                  message: 'Verifica tu conexión e intenta nuevamente.',
                  actionLabel: 'Reintentar',
                  onAction: _cargarNoticias,
                ),
              )
            else ...[
              _NoticiasList(
                noticias: _noticias,
                onTapNoticia: (noticia) =>
                    _abrirDetalle(context, noticia, acceso: _acceso),
                acceso: _acceso,
              ),
              SliverToBoxAdapter(
                child: _NewsListFooter(
                  hasMore: _hasMore,
                  loading: _loadingMore,
                  failed: _loadMoreFailed,
                  errorMessage: _loadMoreError,
                  onRetry: _reintentarCargarMas,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
