part of '../noticias.screen.dart';

// ============================================================================
// Tokens de diseño del header (única fuente de verdad)
// ============================================================================
class _HeaderTokens {
  const _HeaderTokens._();

  /// Tono profundo del degradado original de la portada.
  static const Color deep = Color(0xFF062B66);

  /// Tono sólido equivalente: punto medio entre `primary` y `deep`.
  /// Conserva la misma tonalidad del header de portada, sin degradado.
  static Color solid(BuildContext context) =>
      Color.lerp(Theme.of(context).colorScheme.primary, deep, 0.5)!;

  // Relación cromática (idéntica en ambos headers)
  static const Color onHeader = Colors.white; // texto principal
  static Color onHeaderMuted(BuildContext _) => Colors.white.withOpacity(0.78); // texto secundario
  static Color actionSurface(BuildContext _) => Colors.white.withOpacity(0.16); // botón de acción

  // Métrica compartida
  static const double toolbarHeight = 76;
  static const double leadingSize = 46; // = 34 (logo) + 6*2 (padding vertical)
  static const BorderRadius leadingRadius = BorderRadius.all(Radius.circular(14));
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(16, 6, 10, 8);
}

// ============================================================================
// Shell común: misma estructura, tipografía y ritmo para todos los headers
// ============================================================================
class _HeaderShell extends StatelessWidget {
  const _HeaderShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.action,
    this.useGradient = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? action;

  /// `true` → degradado (portada). `false` → color sólido (categoría).
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: useGradient ? null : _HeaderTokens.solid(context),
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, _HeaderTokens.deep],
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: _HeaderTokens.contentPadding,
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _HeaderTokens.onHeader,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: _HeaderTokens.onHeaderMuted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja blanca del extremo izquierdo (misma masa visual que el logo).
class _HeaderLeadingBox extends StatelessWidget {
  const _HeaderLeadingBox({required this.child, this.onTap, this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final box = Material(
      color: Colors.white,
      borderRadius: _HeaderTokens.leadingRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _HeaderTokens.leadingSize,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(child: child),
          ),
        ),
      ),
    );

    return tooltip == null ? box : Tooltip(message: tooltip!, child: box);
  }
}

/// Botón de acción del extremo derecho (blanco al 16%).
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showUnreadBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Muestra el punto de notificaciones sin leer sobre el ícono.
  final bool showUnreadBadge;

  @override
  Widget build(BuildContext context) {
    final button = IconButton.filledTonal(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: _HeaderTokens.actionSurface(context),
        foregroundColor: _HeaderTokens.onHeader,
      ),
    );

    if (!showUnreadBadge) return button;

    return AnimatedBuilder(
      animation: PushNotificationsService.instance,
      builder: (context, child) {
        final unread = PushNotificationsService.instance.unreadCount;
        if (unread == 0) return child!;

        return Badge.count(
          count: unread,
          backgroundColor: Theme.of(context).colorScheme.error,
          textColor: Theme.of(context).colorScheme.onError,
          child: child,
        );
      },
      child: button,
    );
  }
}

// ============================================================================
// Header de portada
// ============================================================================
class _NoticiasAppBar extends StatelessWidget {
  const _NoticiasAppBar({
    required this.total,
    required this.usingCache,
    this.bellKey,
  });

  final int total;
  final bool usingCache;
  final GlobalKey? bellKey;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: _HeaderTokens.toolbarHeight,
      expandedHeight: _HeaderTokens.toolbarHeight,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: _NoticiasHeader(
        total: total,
        usingCache: usingCache,
        bellKey: bellKey,
      ),
    );
  }
}

class _NoticiasHeader extends StatelessWidget {
  const _NoticiasHeader({
    required this.total,
    required this.usingCache,
    this.bellKey,
  });

  final int total;
  final bool usingCache;
  final GlobalKey? bellKey;

  @override
  Widget build(BuildContext context) {
    return _HeaderShell(
      useGradient: true, // cambia a `false` si quieres portada también sólida
      leading: _HeaderLeadingBox(
        child: Image.asset(
          'assets/images/logo.png',
          height: 34,
          fit: BoxFit.contain,
        ),
      ),
      title: 'Diario Tiempo HN',
      subtitle: usingCache ? 'Modo sin conexión' : '$total noticias disponibles',
      action: _HeaderAction(
        key: bellKey,
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notificaciones',
        showUnreadBadge: true,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
        ),
      ),
    );
  }
}

// ============================================================================
// Header de categoría: mismo diseño, color sólido
// ============================================================================
class _CategoryAppBar extends StatelessWidget {
  const _CategoryAppBar({required this.categoria});

  final CategoriaNoticiaModel categoria;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: _HeaderTokens.toolbarHeight,
      expandedHeight: _HeaderTokens.toolbarHeight,
      titleSpacing: 0,
      automaticallyImplyLeading: false, // el back va dentro del header
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: _CategoryHeader(categoria: categoria),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.categoria});

  final CategoriaNoticiaModel categoria;

  @override
  Widget build(BuildContext context) {
    final count = categoria.count;

    return _HeaderShell(
      useGradient: false, // color sólido, misma tonalidad
      leading: _HeaderLeadingBox(
        tooltip: 'Volver',
        onTap: () => Navigator.of(context).maybePop(),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: _HeaderTokens.solid(context),
        ),
      ),
      title: categoria.name,
      subtitle: count == 1 ? '1 publicación' : '$count publicaciones',
      action: _HeaderAction(
        icon: Icons.notifications_none_rounded,
        tooltip: 'Notificaciones',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
        ),
      ),
    );
  }
}