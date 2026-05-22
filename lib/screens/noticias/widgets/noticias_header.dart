part of '../noticias.screen.dart';

class _NoticiasAppBar extends StatelessWidget {
  const _NoticiasAppBar({required this.total, required this.usingCache});

  final int total;
  final bool usingCache;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: false,
      expandedHeight: 150,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final logoHeight = screenWidth < 360 ? 34.0 : 38.0;
          return Image.asset(
            'assets/images/logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _NoticiasHeader(total: total, usingCache: usingCache),
      ),
    );
  }
}

class _NoticiasHeader extends StatelessWidget {
  const _NoticiasHeader({required this.total, required this.usingCache});

  final int total;
  final bool usingCache;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallPhone = screenWidth < 360;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ colorScheme.secondary, colorScheme.primary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 56, 16, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diario Tiempo HN',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Por decir la verdad nos leen más.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontSize: isSmallPhone ? 22 : null,
                          ),
                    ),
                  ],
                ),
              ),
              _HeaderChip(
                icon: usingCache
                    ? Icons.offline_bolt_outlined
                    : Icons.article_outlined,
                label: usingCache ? 'Caché' : '$total notas',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryAppBar extends StatelessWidget {
  const _CategoryAppBar({required this.categoria});

  final CategoriaNoticiaModel categoria;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 150,
      title: Text(categoria.name),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 62, 16, 18),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '${categoria.count} publicaciones en ${categoria.name}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
