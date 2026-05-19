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

enum NoticiaContentBlockType { text, image }

class NoticiaContentBlock {
  const NoticiaContentBlock._({
    required this.type,
    this.text = '',
    this.imageUrl = '',
    this.caption = '',
  });

  const NoticiaContentBlock.text(String value)
      : this._(type: NoticiaContentBlockType.text, text: value);

  const NoticiaContentBlock.image({required String url, String caption = ''})
      : this._(
          type: NoticiaContentBlockType.image,
          imageUrl: url,
          caption: caption,
        );

  final NoticiaContentBlockType type;
  final String text;
  final String imageUrl;
  final String caption;

  bool get isText => type == NoticiaContentBlockType.text;
  bool get isImage => type == NoticiaContentBlockType.image;
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
    final media = featuredMedia != null && featuredMedia.isNotEmpty
        ? featuredMedia.first as Map<String, dynamic>
        : null;
    final yoast = json['yoast_head_json'] as Map<String, dynamic>?;
    final ogImages = yoast?['og_image'] as List<dynamic>?;
    final ogImage = ogImages != null && ogImages.isNotEmpty
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
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList(),
    );
  }

  static List<NoticiaContentBlock> _parseContentBlocks(String html) {
    if (html.trim().isEmpty) return const [];

    final blocks = <NoticiaContentBlock>[];
    final mediaRegex = RegExp(
      r'<figure\b[\s\S]*?<\/figure>|<img\b[^>]*>',
      caseSensitive: false,
    );
    var currentIndex = 0;

    void addText(String value) {
      final text = _cleanHtml(value, preserveParagraphs: true);
      if (text.isNotEmpty) blocks.add(NoticiaContentBlock.text(text));
    }

    for (final match in mediaRegex.allMatches(html)) {
      addText(html.substring(currentIndex, match.start));

      final fragment = match.group(0) ?? '';
      final src = _extractAttribute(fragment, 'src');
      final imageUrl = src.isNotEmpty
          ? src
          : _extractAttribute(fragment, 'data-src');
      if (imageUrl.isNotEmpty) {
        final captionMatch = RegExp(
          r'<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>',
          caseSensitive: false,
        ).firstMatch(fragment);
        final caption = captionMatch == null
            ? ''
            : _cleanHtml(captionMatch.group(1) ?? '');
        blocks.add(NoticiaContentBlock.image(url: imageUrl, caption: caption));
      }

      currentIndex = match.end;
    }

    addText(html.substring(currentIndex));
    return blocks;
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
