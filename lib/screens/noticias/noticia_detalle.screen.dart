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

    return Text(
      block.text,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
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
