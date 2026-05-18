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
                  const SizedBox(height: 20),
                  if (noticia.excerpt.isNotEmpty) ...[
                    Text(
                      noticia.excerpt,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.72),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Divider(height: 28),
                  Text(
                    noticia.content.isNotEmpty
                        ? noticia.content
                        : 'Esta noticia no incluye contenido disponible desde la API.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
