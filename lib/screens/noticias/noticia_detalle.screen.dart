part of 'noticias.screen.dart';

class _NoticiaDetalleScreen extends StatelessWidget {
  const _NoticiaDetalleScreen({required this.noticia, this.hideAds = false});

  final NoticiaModel noticia;
  final bool hideAds;

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
            actions: [
              IconButton(
                tooltip: 'Compartir noticia',
                onPressed: () => _compartirNoticia(context, noticia),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: _NewsImage(
                      url: noticia.imageUrl,
                      iconSize: 72,
                      borderRadius: BorderRadius.zero,
                      heroTag: _heroTagForNewsImage(noticia),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.82),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 18,
                    child: Text(
                      noticia.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
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
                  _ArticleContent(noticia: noticia, hideAds: hideAds),
                  const SizedBox(height: 28),
                  _RelatedNewsSection(noticia: noticia, hideAds: hideAds),
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
  const _ArticleContent({required this.noticia, required this.hideAds});

  final NoticiaModel noticia;
  final bool hideAds;

  @override
  Widget build(BuildContext context) {
    final blocks = _visibleBlocks();
    final adPositionMap = _adPositionMap(blocks);
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
          _ArticleBlock(block: blocks[index], hideAds: hideAds),
          if (!hideAds && adPositionMap.containsKey(index)) ...[
            const SizedBox(height: 18),
            _AnimatedArticleInlineAd(adPosition: adPositionMap[index]!),
          ],
        ],
      ],
    );
  }

  Map<int, int> _adPositionMap(List<NoticiaContentBlock> blocks) {
    final textIndexes = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (!blocks[i].isImage &&
          !blocks[i].isGallery &&
          !blocks[i].isVideo &&
          !blocks[i].isLink) {
        textIndexes.add(i);
      }
    }
    if (textIndexes.length < 4) return const {};

    final maxAds = textIndexes.length > 4 ? 4 : textIndexes.length - 1;
    final positions = <int>{};
    for (var i = 1; i <= maxAds; i++) {
      final ratio = i / (maxAds + 1);
      var textPosition = (textIndexes.length * ratio).floor();
      textPosition = textPosition.clamp(1, textIndexes.length - 1).toInt();
      positions.add(textIndexes[textPosition]);
    }
    final sorted = positions.toList()..sort();
    return {
      for (var i = 0; i < sorted.length; i++) sorted[i]: i,
    };
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

class _ArticleInlineAd extends StatefulWidget {
  const _ArticleInlineAd();

  @override
  State<_ArticleInlineAd> createState() => _ArticleInlineAdState();
}

class _AnimatedArticleInlineAd extends StatelessWidget {
  const _AnimatedArticleInlineAd({required this.adPosition});

  final int adPosition;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return const _ArticleInlineAd();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 16, end: 0),
      duration: Duration(milliseconds: 360 + (adPosition * 90)),
      curve: Curves.easeOutCubic,
      builder: (context, offsetY, child) {
        return Transform.translate(offset: Offset(0, offsetY), child: child);
      },
      child: const _ArticleInlineAd(),
    );
  }
}

class _ArticleInlineAdState extends State<_ArticleInlineAd> {
  static const String _adUnitId = '/170101793/APP/box_1';

  AdManagerBannerAd? _ad;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final ad = AdManagerBannerAd(
      adUnitId: _adUnitId,
      request: const AdManagerAdRequest(),
      sizes: const [
        AdSize(width: 300, height: 250),
        AdSize(width: 300, height: 300),
        AdSize(width: 336, height: 280),
      ],
      listener: AdManagerBannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _ready = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Error al cargar box_1 en detalle: $error');
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: 300,
        height: 250,
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}

class _ArticleBlock extends StatelessWidget {
  const _ArticleBlock({required this.block, required this.hideAds});

  final NoticiaContentBlock block;
  final bool hideAds;

  @override
  Widget build(BuildContext context) {
    if (block.isImage) return _ArticleImage(block: block);
    if (block.isGallery) return _ArticleGallery(block: block);
    if (block.isVideo) return _ArticleVideo(block: block);
    if (block.isLink) return _ArticleLink(block: block, hideAds: hideAds);

    return _ArticleTextBlock(block: block);
  }
}




class _ArticleTextBlock extends StatefulWidget {
  const _ArticleTextBlock({required this.block});

  final NoticiaContentBlock block;

  @override
  State<_ArticleTextBlock> createState() => _ArticleTextBlockState();
}

class _ArticleTextBlockState extends State<_ArticleTextBlock> {
  final _service = NoticiasService();

  String _cleanHtml(String value, {bool preserveParagraphs = false}) {
    var text = value
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</\s*(p|div|h[1-6]|li|blockquote)\s*>',
            caseSensitive: false,
          ),
          preserveParagraphs ? '\n\n' : ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ');

    text = _decodeHtmlEntities(text);

    if (preserveParagraphs) {
      return _stripRedaccionPrefix(
        text
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .join('\n\n'),
      );
    }

    return _stripRedaccionPrefix(text.replaceAll(RegExp(r'\s+'), ' ').trim());
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _stripRedaccionPrefix(String value) {
    return value.replaceFirst(
      RegExp(r'^\s*redacci[oó]n[\s:,\-–—]+\s*', caseSensitive: false),
      '',
    );
  }

  Future<void> _openLink(String rawUrl) async {
    final normalizedUrl = rawUrl.startsWith('/')
        ? 'https://tiempo.hn$rawUrl'
        : rawUrl.startsWith('//')
        ? 'https:$rawUrl'
        : rawUrl;
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return;

    final noticia = await _service.obtenerNoticiaPorLink(normalizedUrl);
    if (!mounted) return;

    if (noticia != null) {
      _abrirDetalle(context, noticia);
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<TextSpan> _buildSpans(TextStyle style, TextStyle linkStyle) {
    final source = widget.block.sourceHtml;
    if (source.isEmpty) {
      return [TextSpan(text: widget.block.text, style: style)];
    }

    final spans = <TextSpan>[];
    final parts = source.split('\n\n');
    for (var i = 0; i < parts.length; i++) {
      final partSpans = _buildInlineSpansFromHtml(parts[i], style, linkStyle);
      spans.addAll(partSpans);
      if (i < parts.length - 1) {
        spans.add(TextSpan(text: '\n\n', style: style));
      }
    }

    return spans.isEmpty ? [TextSpan(text: widget.block.text, style: style)] : spans;
  }

  List<TextSpan> _buildInlineSpansFromHtml(
    String html,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'<[^>]+>');
    var current = 0;
    var boldDepth = 0;
    String? currentLinkUrl;

    TextStyle resolveStyle() {
      var resolved = currentLinkUrl != null ? linkStyle : baseStyle;
      if (boldDepth > 0) {
        final currentWeight = resolved.fontWeight ?? FontWeight.normal;
        resolved = resolved.copyWith(
          fontWeight: currentWeight.index < FontWeight.w700.index
              ? FontWeight.w700
              : currentWeight,
        );
      }
      return resolved;
    }

    void addText(String raw) {
      final cleaned = _cleanHtml(raw, preserveParagraphs: true);
      if (cleaned.isNotEmpty) {
        spans.add(
          TextSpan(
            text: cleaned,
            style: resolveStyle(),
            recognizer: currentLinkUrl == null
                ? null
                : (TapGestureRecognizer()
                  ..onTap = () => _openLink(currentLinkUrl!)),
          ),
        );
      }
    }

    for (final match in tagRegex.allMatches(html)) {
      addText(html.substring(current, match.start));
      final tag = match.group(0)?.toLowerCase() ?? '';

      if (tag.startsWith('<a ')) {
        final hrefMatch = RegExp(
          r'''href\s*=\s*(['"])(.*?)\1''',
          caseSensitive: false,
        ).firstMatch(match.group(0) ?? '');
        currentLinkUrl = _decodeHtmlEntities(hrefMatch?.group(2) ?? '').trim();
      } else if (tag.startsWith('</a')) {
        currentLinkUrl = null;
      } else if (tag.startsWith('<strong') || tag.startsWith('<b')) {
        boldDepth++;
      } else if (tag.startsWith('</strong') || tag.startsWith('</b')) {
        if (boldDepth > 0) boldDepth--;
      } else if (tag.startsWith('<br')) {
        addText('\n');
      }

      current = match.end;
    }

    addText(html.substring(current));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65);
    final linkStyle = baseStyle?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return RichText(text: TextSpan(children: _buildSpans(baseStyle ?? const TextStyle(), linkStyle ?? const TextStyle())));
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

class _RelatedNewsSection extends StatelessWidget {
  const _RelatedNewsSection({required this.noticia, required this.hideAds});

  final NoticiaModel noticia;
  final bool hideAds;

  @override
  Widget build(BuildContext context) {
    final allNews = context.watch<NoticiasProvider>().noticias;
    final related = allNews
        .where(
          (item) =>
              item.id != noticia.id &&
              item.categories.any((category) => noticia.categories.contains(category)),
        )
        .take(6)
        .toList();
    if (related.isEmpty) return const SizedBox.shrink();

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Te puede interesar',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = related[index];
              final card = SizedBox(
                width: 232,
                child: _RelatedNewsCard(noticia: item, hideAds: hideAds),
              );
              if (disableAnimations) return card;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 260 + (index * 90)),
                curve: Curves.easeOutCubic,
                builder: (_, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset((1 - value) * 24, 0),
                    child: child,
                  ),
                ),
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RelatedNewsCard extends StatelessWidget {
  const _RelatedNewsCard({required this.noticia, required this.hideAds});

  final NoticiaModel noticia;
  final bool hideAds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirDetalle(context, noticia, hideAds: hideAds),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _NewsImage(
                url: noticia.imageUrl,
                borderRadius: BorderRadius.zero,
                iconSize: 28,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      noticia.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _DateLabel(
                            date: noticia.date,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  const _ArticleLink({required this.block, required this.hideAds});

  final NoticiaContentBlock block;
  final bool hideAds;

  @override
  State<_ArticleLink> createState() => _ArticleLinkState();
}

class _ArticleLinkState extends State<_ArticleLink> {
  final _service = NoticiasService();
  bool _loading = false;

  String _cleanHtml(String value, {bool preserveParagraphs = false}) {
    var text = value
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</\s*(p|div|h[1-6]|li|blockquote)\s*>',
            caseSensitive: false,
          ),
          preserveParagraphs ? '\n\n' : ' ',
        )
        .replaceAll(RegExp(r'<[^>]*>'), ' ');

    text = _decodeHtmlEntities(text);

    if (preserveParagraphs) {
      return text
          .split('\n')
          .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
          .where((line) => line.isNotEmpty)
          .join('\n\n');
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  List<TextSpan> _buildLabelSpans(TextStyle baseStyle) {
    final source = widget.block.sourceHtml;
    if (source.isEmpty) return [TextSpan(text: widget.block.text, style: baseStyle)];

    final spans = <TextSpan>[];
    final tagRegex = RegExp(r'<[^>]+>');
    var current = 0;
    var boldDepth = 0;

    void addText(String raw) {
      final cleaned = _cleanHtml(raw, preserveParagraphs: true);
      if (cleaned.isEmpty) return;
      spans.add(
        TextSpan(
          text: cleaned,
          style: boldDepth > 0
              ? baseStyle.copyWith(fontWeight: FontWeight.w800)
              : baseStyle,
        ),
      );
    }

    for (final match in tagRegex.allMatches(source)) {
      addText(source.substring(current, match.start));
      final tag = (match.group(0) ?? '').toLowerCase();
      if (tag.startsWith('<strong') || tag.startsWith('<b')) boldDepth++;
      if (tag.startsWith('</strong') || tag.startsWith('</b')) {
        if (boldDepth > 0) boldDepth--;
      }
      current = match.end;
    }
    addText(source.substring(current));
    return spans.isEmpty ? [TextSpan(text: widget.block.text, style: baseStyle)] : spans;
  }

  Future<void> _openLinkedNoticia() async {
    if (_loading) return;

    setState(() => _loading = true);
    final noticia = await _service.obtenerNoticiaPorLink(widget.block.linkUrl);
    if (!mounted) return;

    setState(() => _loading = false);
    if (noticia == null) {
      final uri = Uri.tryParse(widget.block.linkUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
      return;
    }

    _abrirDetalle(context, noticia, hideAds: widget.hideAds);
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
                child: RichText(
                  text: TextSpan(
                    children: _buildLabelSpans(
                      theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ) ??
                          const TextStyle(),
                    ),
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
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: block.imageUrl.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullscreenImageViewer(
                        imageUrl: block.imageUrl,
                        heroTag: 'article-image-${block.imageUrl}',
                        caption: block.caption,
                      ),
                    ),
                  );
                },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _NewsImage(
                url: block.imageUrl,
                borderRadius: BorderRadius.zero,
                iconSize: 48,
                heroTag: block.imageUrl.isEmpty ? null : 'article-image-${block.imageUrl}',
              ),
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

class _FullscreenImageViewer extends StatelessWidget {
  const _FullscreenImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.caption,
  });

  final String imageUrl;
  final String heroTag;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
