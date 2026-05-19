part of 'noticias.screen.dart';

class _NoticiaDetalleScreen extends StatelessWidget {
  const _NoticiaDetalleScreen({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriasPorId = context.watch<NoticiasProvider>().categoriasPorId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            title: Text(
              noticia.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _NewsImage(
                    url: noticia.imageUrl,
                    iconSize: 72,
                    borderRadius: BorderRadius.zero,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(text: 'Noticia completa'),
                  const SizedBox(height: 14),
                  Text(
                    noticia.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateLabel(date: noticia.date),
                  const SizedBox(height: 16),
                  _CategoryPills(
                    categoryIds: noticia.categories,
                    categoriasPorId: categoriasPorId,
                    onTap: (categoria) => _abrirCategoria(context, categoria),
                  ),
                  const Divider(height: 28),
                  _ArticleContent(noticia: noticia),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleContent extends StatelessWidget {
  const _ArticleContent({required this.noticia});

  final NoticiaModel noticia;

  @override
  Widget build(BuildContext context) {
    final blocks = _visibleBlocks();
    if (blocks.isEmpty) {
      return Text(
        noticia.content.isNotEmpty
            ? noticia.content
            : 'Esta noticia no incluye contenido disponible desde la API.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: 18),
          _ArticleBlock(block: blocks[index]),
        ],
      ],
    );
  }

  List<NoticiaContentBlock> _visibleBlocks() {
    var skippedFeaturedImage = false;
    return noticia.contentBlocks.where((block) {
      if (!block.isImage) return true;
      final isFeatured = _sameImageUrl(block.imageUrl, noticia.imageUrl);
      if (isFeatured && !skippedFeaturedImage) {
        skippedFeaturedImage = true;
        return false;
      }
      return true;
    }).toList();
  }

  bool _sameImageUrl(String first, String second) {
    if (first.isEmpty || second.isEmpty) return false;
    final firstUri = Uri.tryParse(first);
    final secondUri = Uri.tryParse(second);
    if (firstUri == null || secondUri == null) return first == second;
    return firstUri.host == secondUri.host && firstUri.path == secondUri.path;
  }
}

class _ArticleBlock extends StatelessWidget {
  const _ArticleBlock({required this.block});

  final NoticiaContentBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.isImage) return _ArticleImage(block: block);
    if (block.isGallery) return _ArticleGallery(block: block);
    if (block.isVideo) return _ArticleVideo(block: block);
    if (block.isLink) return _ArticleLink(block: block);

    return Text(
      block.text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
    );
  }
}


class _ArticleVideo extends StatefulWidget {
  const _ArticleVideo({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleVideo> createState() => _ArticleVideoState();
}

class _ArticleVideoState extends State<_ArticleVideo> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.block.videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.75),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Video de la noticia',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleGallery extends StatefulWidget {
  const _ArticleGallery({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleGallery> createState() => _ArticleGalleryState();
}

class _ArticleGalleryState extends State<_ArticleGallery> {
  late final PageController _controller;
  int _currentIndex = 0;

  List<NoticiaGalleryItem> get _items => widget.block.galleryItems;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _items.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    if (_items.length == 1) {
      return _ArticleImage(
        block: NoticiaContentBlock.image(
          url: _items.first.imageUrl,
          caption: _items.first.caption,
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) {
                    setState(() => _currentIndex = value);
                  },
                  itemBuilder: (context, index) {
                    return _NewsImage(
                      url: _items[index].imageUrl,
                      borderRadius: BorderRadius.zero,
                      iconSize: 48,
                    );
                  },
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Galería ${_currentIndex + 1} de ${_items.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GalleryArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _currentIndex == 0
                            ? null
                            : () => _goTo(_currentIndex - 1),
                      ),
                      _GalleryArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _currentIndex == _items.length - 1
                            ? null
                            : () => _goTo(_currentIndex + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_items[_currentIndex].caption.isNotEmpty) ...[
                  Text(
                    _items[_currentIndex].caption,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < _items.length; index++) ...[
                        _GalleryThumb(
                          item: _items[index],
                          selected: index == _currentIndex,
                          onTap: () => _goTo(index),
                        ),
                        if (index < _items.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.black.withOpacity(onTap == null ? 0.18 : 0.48),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NoticiaGalleryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 64,
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: _NewsImage(
          url: item.imageUrl,
          borderRadius: BorderRadius.circular(9),
          iconSize: 18,
        ),
      ),
    );
  }
}

class _ArticleLink extends StatefulWidget {
  const _ArticleLink({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleLink> createState() => _ArticleLinkState();
}

class _ArticleLinkState extends State<_ArticleLink> {
  final _service = NoticiasService();
  bool _loading = false;

  Future<void> _openLinkedNoticia() async {
    if (_loading) return;

    setState(() => _loading = true);
    final noticia = await _service.obtenerNoticiaPorLink(widget.block.linkUrl);
    if (!mounted) return;

    setState(() => _loading = false);
    if (noticia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar la noticia relacionada.'),
        ),
      );
      return;
    }

    _abrirDetalle(context, noticia);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primary.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _loading ? null : _openLinkedNoticia,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.article_outlined,
                      color: colorScheme.primary,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.block.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({required this.block});

  final NoticiaContentBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: _NewsImage(
              url: block.imageUrl,
              borderRadius: BorderRadius.zero,
              iconSize: 48,
            ),
          ),
        ),
        if (block.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            block.caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
