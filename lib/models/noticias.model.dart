class CategoriaNoticiaModel {
  CategoriaNoticiaModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  final int id;
  final String name;
  final String slug;
  final int count;

  factory CategoriaNoticiaModel.fromJson(Map<String, dynamic> json) {
    return CategoriaNoticiaModel(
      id: json['id'] ?? 0,
      name: _cleanHtml(json['name']?.toString() ?? ''),
      slug: json['slug']?.toString() ?? '',
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
    );
  }
}

enum NoticiaContentBlockType { text, image, link, gallery, video }

class NoticiaGalleryItem {
  const NoticiaGalleryItem({required this.imageUrl, this.caption = ''});

  final String imageUrl;
  final String caption;
}

class NoticiaContentBlock {
  const NoticiaContentBlock._({
    required this.type,
    this.text = '',
    this.imageUrl = '',
    this.caption = '',
    this.linkUrl = '',
    this.videoUrl = '',
    this.galleryItems = const [],
  });

  const NoticiaContentBlock.text(String value)
    : this._(type: NoticiaContentBlockType.text, text: value);

  const NoticiaContentBlock.image({required String url, String caption = ''})
    : this._(
        type: NoticiaContentBlockType.image,
        imageUrl: url,
        caption: caption,
      );

  const NoticiaContentBlock.link({required String text, required String url})
    : this._(type: NoticiaContentBlockType.link, text: text, linkUrl: url);

  const NoticiaContentBlock.gallery(List<NoticiaGalleryItem> items)
    : this._(type: NoticiaContentBlockType.gallery, galleryItems: items);

  const NoticiaContentBlock.video(String url)
    : this._(type: NoticiaContentBlockType.video, videoUrl: url);

  final NoticiaContentBlockType type;
  final String text;
  final String imageUrl;
  final String caption;
  final String linkUrl;
  final String videoUrl;
  final List<NoticiaGalleryItem> galleryItems;

  bool get isText => type == NoticiaContentBlockType.text;
  bool get isImage => type == NoticiaContentBlockType.image;
  bool get isLink => type == NoticiaContentBlockType.link;
  bool get isGallery => type == NoticiaContentBlockType.gallery;
  bool get isVideo => type == NoticiaContentBlockType.video;
}

class NoticiaModel {
  NoticiaModel({
    required this.id,
    required this.link,
    required this.slug,
    required this.date,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.contentBlocks,
    required this.imageUrl,
    required this.imageAlt,
    required this.categories,
  });

  final int id;
  final String link;
  final String slug;
  final DateTime? date;
  final String title;
  final String excerpt;
  final String content;
  final List<NoticiaContentBlock> contentBlocks;
  final String imageUrl;
  final String imageAlt;
  final List<int> categories;

  bool get hasImage => imageUrl.isNotEmpty;

  factory NoticiaModel.fromJson(Map<String, dynamic> json) {
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    final featuredMedia = (embedded?['wp:featuredmedia'] as List<dynamic>?);
    final media =
        featuredMedia != null && featuredMedia.isNotEmpty
            ? featuredMedia.first as Map<String, dynamic>
            : null;
    final yoast = json['yoast_head_json'] as Map<String, dynamic>?;
    final ogImages = yoast?['og_image'] as List<dynamic>?;
    final ogImage =
        ogImages != null && ogImages.isNotEmpty
            ? ogImages.first as Map<String, dynamic>
            : null;
    final embeddedImage = (media?['source_url'] ?? '').toString();
    final metadataImage = (ogImage?['url'] ?? '').toString();

    final rawContent = (json['content']?['rendered'] ?? '').toString();

    return NoticiaModel(
      id: json['id'] ?? 0,
      link: json['link']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      title: _cleanHtml((json['title']?['rendered'] ?? '').toString()),
      excerpt: _cleanHtml((json['excerpt']?['rendered'] ?? '').toString()),
      content: _cleanHtml(rawContent, preserveParagraphs: true),
      contentBlocks: _parseContentBlocks(rawContent),
      imageUrl: embeddedImage.isNotEmpty ? embeddedImage : metadataImage,
      imageAlt: _cleanHtml((media?['alt_text'] ?? '').toString()),
      categories:
          (json['categories'] as List<dynamic>? ?? [])
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList(),
    );
  }

  static List<NoticiaContentBlock> _parseContentBlocks(String html) {
    if (html.trim().isEmpty) return const [];

    final blocks = <NoticiaContentBlock>[];
    final mediaRegex = RegExp(
      r'''(?:<style\b[\s\S]*?<\/style>\s*)?<div\b(?=[^>]*class\s*=\s*(['"])[^'"]*\btd-gallery\b[^'"]*\1)[\s\S]*?(?=<p\b|<h[1-6]\b|$)|<div\b(?=[^>]*data-mow_video\s*=)[^>]*>\s*<\/div>|<amp-iframe\b[^>]*src\s*=\s*(['"])[^'"]*mowplayer\.com/watch/[^'"]*\2[\s\S]*?<\/amp-iframe>|<iframe\b[^>]*src\s*=\s*(['"])[^'"]*mowplayer\.com/watch/[^'"]*\3[\s\S]*?<\/iframe>|<figure\b[\s\S]*?<\/figure>|<img\b[^>]*>''',
      caseSensitive: false,
    );
    var currentIndex = 0;

    void addText(String value) {
      for (final fragment in _splitTextFragments(value)) {
        final text = _cleanHtml(fragment, preserveParagraphs: true);
        if (text.isEmpty) continue;

        final link = _extractRelatedArticleLink(fragment);
        if (link.isNotEmpty) {
          blocks.add(NoticiaContentBlock.link(text: text, url: link));
          continue;
        }

        blocks.add(NoticiaContentBlock.text(text));
      }
    }

    for (final match in mediaRegex.allMatches(html)) {
      addText(html.substring(currentIndex, match.start));

      final fragment = match.group(0) ?? '';
      if (_isGalleryFragment(fragment)) {
        final items = _extractGalleryItems(fragment);
        if (items.isNotEmpty) blocks.add(NoticiaContentBlock.gallery(items));
        currentIndex = match.end;
        continue;
      }

      final videoUrl = _extractVideoUrl(fragment);
      if (videoUrl.isNotEmpty) {
        blocks.add(NoticiaContentBlock.video(videoUrl));
        currentIndex = match.end;
        continue;
      }

      final src = _extractAttribute(fragment, 'src');
      final imageUrl =
          src.isNotEmpty ? src : _extractAttribute(fragment, 'data-src');
      if (imageUrl.isNotEmpty) {
        final captionMatch = RegExp(
          r'<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>',
          caseSensitive: false,
        ).firstMatch(fragment);
        final caption =
            captionMatch == null ? '' : _cleanHtml(captionMatch.group(1) ?? '');
        blocks.add(NoticiaContentBlock.image(url: imageUrl, caption: caption));
      }

      currentIndex = match.end;
    }

    addText(html.substring(currentIndex));
    return blocks;
  }

  static String _extractVideoUrl(String html) {
    final mowId = _extractAttribute(html, 'data-mow_video');
    if (mowId.isNotEmpty) return 'https://mowplayer.com/watch/$mowId';

    final src = _extractAttribute(html, 'src');
    if (src.isEmpty) return '';
    final normalizedSrc = src.startsWith('//') ? 'https:$src' : src;
    final uri = Uri.tryParse(normalizedSrc);
    if (uri == null) return '';

    return uri.host.endsWith('mowplayer.com') ? normalizedSrc : '';
  }

  static bool _isGalleryFragment(String html) {
    return RegExp(r'\btd-gallery\b', caseSensitive: false).hasMatch(html);
  }

  static List<NoticiaGalleryItem> _extractGalleryItems(String html) {
    final items = <NoticiaGalleryItem>[];
    final seen = <String>{};
    final anchorRegex = RegExp(
      "<a\\b[^>]*class\\s*=\\s*(['\"])[^'\"]*\\bslide-gallery-image-link\\b[^'\"]*\\1[^>]*>[\\s\\S]*?<\\/a>",
      caseSensitive: false,
    );

    for (final match in anchorRegex.allMatches(html)) {
      final fragment = match.group(0) ?? '';
      final href = _extractAttribute(fragment, 'href');
      final src = _extractAttribute(fragment, 'src');
      final dataSrc = _extractAttribute(fragment, 'data-src');
      final imageUrl =
          href.isNotEmpty
              ? href
              : src.isNotEmpty
              ? src
              : dataSrc;
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;

      final dataCaption = _extractAttribute(fragment, 'data-caption');
      final caption =
          dataCaption.isNotEmpty
              ? _cleanHtml(dataCaption)
              : _extractFigureCaption(fragment);
      items.add(NoticiaGalleryItem(imageUrl: imageUrl, caption: caption));
      seen.add(imageUrl);
    }

    if (items.isNotEmpty) return items;

    final figureRegex = RegExp(
      r'<figure\b[\s\S]*?<\/figure>|<img\b[^>]*>',
      caseSensitive: false,
    );
    for (final match in figureRegex.allMatches(html)) {
      final fragment = match.group(0) ?? '';
      final src = _extractAttribute(fragment, 'src');
      final dataSrc = _extractAttribute(fragment, 'data-src');
      final imageUrl = src.isNotEmpty ? src : dataSrc;
      if (imageUrl.isEmpty || seen.contains(imageUrl)) continue;

      items.add(
        NoticiaGalleryItem(
          imageUrl: imageUrl,
          caption: _extractFigureCaption(fragment),
        ),
      );
      seen.add(imageUrl);
    }

    return items;
  }

  static String _extractFigureCaption(String html) {
    final captionMatch = RegExp(
      r'<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>',
      caseSensitive: false,
    ).firstMatch(html);
    return captionMatch == null ? '' : _cleanHtml(captionMatch.group(1) ?? '');
  }

  static List<String> _splitTextFragments(String html) {
    final fragments = <String>[];
    final blockRegex = RegExp(
      r'<(p|div|h[1-6]|li|blockquote)\b[^>]*>[\s\S]*?<\/\1>',
      caseSensitive: false,
    );
    var currentIndex = 0;

    for (final match in blockRegex.allMatches(html)) {
      if (match.start > currentIndex) {
        fragments.add(html.substring(currentIndex, match.start));
      }
      fragments.add(match.group(0) ?? '');
      currentIndex = match.end;
    }

    if (currentIndex < html.length) {
      fragments.add(html.substring(currentIndex));
    }

    return fragments.isEmpty ? [html] : fragments;
  }

  static String _extractRelatedArticleLink(String html) {
    final plainText = _cleanHtml(html).toLowerCase();
    final isRelatedArticle =
        plainText.contains('te puede interesar') ||
        plainText.contains('de igual interés') ||
        plainText.contains('de igual interes') ||
        plainText.contains('también puedes leer') ||
        plainText.contains('tambien puedes leer') ||
        plainText.contains('lea también') ||
        plainText.contains('lea tambien');
    if (!isRelatedArticle) return '';

    final anchorMatch = RegExp(
      "<a\\b[^>]*href\\s*=\\s*(['\"])(.*?)\\1[\\s\\S]*?<\\/a>",
      caseSensitive: false,
    ).firstMatch(html);
    if (anchorMatch == null) return '';

    final link = _decodeHtmlEntities(anchorMatch.group(2) ?? '').trim();
    final uri = Uri.tryParse(link);
    if (uri == null) return '';

    final host = uri.host.toLowerCase();
    return host == 'tiempo.hn' || host.endsWith('.tiempo.hn') ? link : '';
  }

  static String _extractAttribute(String html, String attribute) {
    final match = RegExp(
      "$attribute\\s*=\\s*(['\"])(.*?)\\1",
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return '';
    return _decodeHtmlEntities(match.group(2) ?? '').trim();
  }

  static String _cleanHtml(String value, {bool preserveParagraphs = false}) {
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

  static String _decodeHtmlEntities(String value) {
    var text = value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final codePoint = int.tryParse(match.group(1) ?? '');
      if (codePoint == null) return match.group(0) ?? '';
      return String.fromCharCode(codePoint);
    });

    return text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
      if (codePoint == null) return match.group(0) ?? '';
      return String.fromCharCode(codePoint);
    });
  }
}

String _cleanHtml(String value, {bool preserveParagraphs = false}) {
  var text = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|li|blockquote)\s*>', caseSensitive: false),
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
  var text = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&hellip;', '…');

  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final codePoint = int.tryParse(match.group(1) ?? '');
    if (codePoint == null) return match.group(0) ?? '';
    return String.fromCharCode(codePoint);
  });

  return text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
    if (codePoint == null) return match.group(0) ?? '';
    return String.fromCharCode(codePoint);
  });
}
