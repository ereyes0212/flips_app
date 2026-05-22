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
          return Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: logoHeight,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              _SocialIconButton(
                icon: Icons.facebook_rounded,
                tooltip: 'Facebook',
                onTap: () => _openSocial(context, 'Facebook', 'https://www.facebook.com/diariotiempo/'),
              ),
              _SocialIconButton(
                icon: Icons.alternate_email_rounded,
                tooltip: 'X',
                onTap: () => _openSocial(context, 'X', 'https://x.com/TiempoHonduras'),
              ),
              _SocialIconButton(
                icon: Icons.camera_alt_rounded,
                tooltip: 'Instagram',
                onTap: () => _openSocial(context, 'Instagram', 'https://www.instagram.com/diariotiempo/'),
              ),
            ],
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      
                      'Diario Tiempo HN',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white.withOpacity(0.92),
                            fontWeight: FontWeight.bold,
                            fontSize: 30
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Por saber la verdad nos leen más.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            fontSize: isSmallPhone ? 28 : null,
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


void _openSocial(BuildContext context, String title, String url) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => _SocialWebScreen(title: title, url: url)),
  );
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class _SocialWebScreen extends StatefulWidget {
  const _SocialWebScreen({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_SocialWebScreen> createState() => _SocialWebScreenState();
}

class _SocialWebScreenState extends State<_SocialWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
