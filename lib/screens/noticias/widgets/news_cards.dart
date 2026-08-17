// ignore_for_file: unused_element_parameter

part of '../noticias.screen.dart';

class _PortadaCard extends StatelessWidget {
  const _PortadaCard({required this.noticia, this.acceso = const AccesoUsuario.sinResolver()});

  final NoticiaModel noticia;
  final AccesoUsuario acceso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final cardChild = InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _abrirDetalle(context, noticia, acceso: acceso),
      child: Container(
        height: 310,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NewsImage(
              url: noticia.imageUrl,
              iconSize: 64,
              borderRadius: BorderRadius.zero,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Badge(text: 'Portada principal'),
                  const SizedBox(height: 12),
                  Text(
                    noticia.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    noticia.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DateLabel(date: noticia.date, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (disableAnimations) return cardChild;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: cardChild,
    );
  }
}

class _NoticiaCard extends StatelessWidget {
  const _NoticiaCard({
    required this.noticia,
    this.isDownloaded = false,
    this.onTapOverride,
    this.enableHero = true,
  });

  final NoticiaModel noticia;
  final bool isDownloaded;
  final VoidCallback? onTapOverride;
  final bool enableHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final cardChild = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapOverride ?? () => _abrirDetalle(context, noticia),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NewsImage(
                url: noticia.imageUrl,
                size: 92,
                heroTag: enableHero ? _heroTagForNewsImage(noticia) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noticia.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      noticia.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _DateLabel(date: noticia.date, color: colorScheme.onSurfaceVariant),
                        if (isDownloaded) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.download_done_rounded,
                            size: 15,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (disableAnimations) return cardChild;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 24, end: 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, offsetY, child) {
        return Transform.translate(offset: Offset(0, offsetY), child: child);
      },
      child: cardChild,
    );
  }
}
