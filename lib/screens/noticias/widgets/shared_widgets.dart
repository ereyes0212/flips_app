part of '../noticias.screen.dart';

class _NewsImage extends StatelessWidget {
  const _NewsImage({
    required this.url,
    this.size,
    this.iconSize = 36,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.heroTag,
  });

  final String url;
  final double? size;
  final double iconSize;
  final BorderRadius borderRadius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.article_outlined,
        size: iconSize,
        color: colorScheme.primary,
      ),
    );

    if (url.isEmpty) return placeholder;
    final isLocalFile = url.startsWith('/') || url.startsWith('file://');
    final localPath = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;

    final image = ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canExpand = constraints.hasBoundedWidth && constraints.hasBoundedHeight;
          return Stack(
            fit: canExpand ? StackFit.expand : StackFit.loose,
            children: [
              placeholder,
              if (isLocalFile)
                Image.file(
                  File(localPath),
                  key: ValueKey(localPath),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => placeholder,
                )
              else
                Image.network(
                  url,
                  key: ValueKey(url),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => placeholder,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                ),
            ],
          );
        },
      ),
    );

    if (heroTag == null || heroTag!.isEmpty) return image;
    return Hero(tag: heroTag!, child: image);
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date, this.color});

  final DateTime? date;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();
    final textColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_outlined, size: 14, color: textColor),
        const SizedBox(width: 6),
        Text(
          DateFormat('dd/MM/yyyy').format(date!),
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie del listado de noticias.
///
/// Con scroll infinito el pie dejó de ser un botón: mientras entra la página
/// siguiente muestra tarjetas fantasma del mismo alto que las reales, así el
/// scroll no pega un salto cuando llegan. El botón solo reaparece si la página
/// falló, para no reintentar en bucle contra un backend caído.
class _NewsListFooter extends StatelessWidget {
  const _NewsListFooter({
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onRetry,
    this.errorMessage = '',
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: _NoticiasSkeletonGroup(),
      );
    }

    if (failed && hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Column(
          children: [
            Text(
              errorMessage.isEmpty
                  ? 'No pudimos cargar más noticias.'
                  : errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Text(
          'Ya estás al día con las noticias disponibles.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    // Quedan páginas y ninguna en vuelo: el listener de scroll pide la
    // siguiente mucho antes de que el usuario llegue hasta aquí.
    return const SizedBox(height: 24);
  }
}

/// Tanda de tarjetas fantasma con la misma silueta que [_NoticiaCard].
class _NoticiasSkeletonGroup extends StatelessWidget {
  const _NoticiasSkeletonGroup({this.items = 3});

  final int items;

  @override
  Widget build(BuildContext context) {
    final divisor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withOpacity(0.55);

    return SkeletonShimmer(
      child: Column(
        children: [
          for (var i = 0; i < items; i++) ...[
            if (i > 0) Divider(height: 1, color: divisor),
            const _NoticiaCardSkeleton(),
          ],
        ],
      ),
    );
  }
}

class _NoticiaCardSkeleton extends StatelessWidget {
  const _NoticiaCardSkeleton();

  static const _linea = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            width: 92,
            height: 92,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 14, borderRadius: _linea),
                SizedBox(height: 8),
                SkeletonBox(width: 190, height: 14, borderRadius: _linea),
                SizedBox(height: 14),
                SkeletonBox(height: 10, borderRadius: _linea),
                SizedBox(height: 10),
                SkeletonBox(width: 110, height: 10, borderRadius: _linea),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Primera carga del listado: portada y tarjetas fantasma en vez de una ruleta
/// centrada, para que la pantalla ya tenga la forma que va a tener.
class _NoticiasSkeletonScreen extends StatelessWidget {
  const _NoticiasSkeletonScreen();

  @override
  Widget build(BuildContext context) {
    final divisor = Theme.of(
      context,
    ).colorScheme.outlineVariant.withOpacity(0.55);

    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            const SkeletonBox(
              height: 310,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 150, height: 16),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) Divider(height: 1, color: divisor),
              const _NoticiaCardSkeleton(),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, spreadRadius: -8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 58, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
