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
      title: (json['title']?['rendered'] ?? '').toString(),
      excerpt: (json['excerpt']?['rendered'] ?? '').toString(),
      content: (json['content']?['rendered'] ?? '').toString(),
      imageUrl: (media?['source_url'] ?? '').toString(),
      imageAlt: (media?['alt_text'] ?? '').toString(),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList(),
    );
  }
}
