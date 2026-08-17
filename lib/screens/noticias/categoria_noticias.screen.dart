part of 'noticias.screen.dart';

class _CategoriaNoticiasScreen extends StatefulWidget {
  const _CategoriaNoticiasScreen({required this.categoria});

  final CategoriaNoticiaModel categoria;

  @override
  State<_CategoriaNoticiasScreen> createState() =>
      _CategoriaNoticiasScreenState();
}

class _CategoriaNoticiasScreenState extends State<_CategoriaNoticiasScreen> {
  final _service = NoticiasService();
  final List<NoticiaModel> _noticias = [];
  var _loading = true;
  var _loadingMore = false;
  var _error = '';
  var _page = 1;
  var _hasMore = true;
  AccesoUsuario _acceso = const AccesoUsuario.sinResolver();

  @override
  void initState() {
    super.initState();
    Future.microtask(_cargarNoticias);
    _resolverAcceso();
  }

  Future<void> _resolverAcceso() async {
    final acceso = await AccesoUsuarioService.instance.resolver();
    if (!mounted) return;
    setState(() => _acceso = acceso);
  }

  Future<void> _cargarNoticias({bool reset = true}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;

    setState(() {
      if (reset) {
        _loading = true;
        _error = '';
        _page = 1;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
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
      } else {
        _error = result.errorMessage;
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
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _CategoryAppBar(categoria: widget.categoria),
            if (_loading && _noticias.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
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
                child: _LoadMoreButton(
                  hasMore: _hasMore,
                  loading: _loadingMore,
                  onPressed: () => _cargarNoticias(reset: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
