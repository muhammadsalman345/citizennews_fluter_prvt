class SeoMetadata {
  const SeoMetadata({
    required this.title,
    required this.description,
    required this.path,
    this.robots = indexRobots,
    this.type = 'website',
    this.imageUrl,
    this.imageAlt,
    this.author,
    this.publishedAt,
    this.modifiedAt,
    this.structuredData = const [],
  });

  static const indexRobots =
      'index, follow, max-image-preview:large, max-snippet:-1, '
      'max-video-preview:-1';
  static const noIndexRobots = 'noindex, nofollow, noarchive';

  final String title;
  final String description;
  final String path;
  final String robots;
  final String type;
  final String? imageUrl;
  final String? imageAlt;
  final String? author;
  final DateTime? publishedAt;
  final DateTime? modifiedAt;
  final List<Map<String, dynamic>> structuredData;

  bool get indexable => !robots.contains('noindex');
}
