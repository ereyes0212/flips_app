class NoticiaModel {
  NoticiaModel({
    required this.id,
    required this.link,
    required this.slug,
    required this.date,
    required this.title,
    required this.excerpt,
    required this.content,
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

    return NoticiaModel(
      id: json['id'] ?? 0,
      link: json['link']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      title: _cleanHtml((json['title']?['rendered'] ?? '').toString()),
      excerpt: _cleanHtml((json['excerpt']?['rendered'] ?? '').toString()),
      content: _cleanHtml(
        (json['content']?['rendered'] ?? '').toString(),
        preserveParagraphs: true,
      ),
      imageUrl: (media?['source_url'] ?? '').toString(),
      imageAlt: _cleanHtml((media?['alt_text'] ?? '').toString()),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList(),
    );
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
