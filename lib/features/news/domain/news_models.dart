class NewsSummary {
  const NewsSummary({
    required this.id,
    required this.slug,
    required this.headline,
    required this.summary,
    required this.reporterId,
    required this.fullName,
    required this.username,
    required this.city,
    required this.category,
    required this.publishedAt,
    required this.likes,
    required this.dislikes,
    required this.comments,
    required this.views,
    required this.verified,
    required this.breaking,
    required this.status,
    this.imageUrl,
    this.avatarUrl,
    this.categoryId,
    this.categorySlug,
    this.citySlug,
    this.country,
    this.countrySlug,
    this.region,
    this.regionSlug,
    this.riskFlags = const [],
  });

  final String id;
  final String slug;
  final String headline;
  final String summary;
  final String reporterId;
  final String fullName;
  final String username;
  final String city;
  final String category;
  final String? categoryId;
  final String? categorySlug;
  final String? citySlug;
  final String? country;
  final String? countrySlug;
  final String? region;
  final String? regionSlug;
  final List<String> riskFlags;
  final String? imageUrl;
  final String? avatarUrl;
  final DateTime? publishedAt;
  final int likes;
  final int dislikes;
  final int comments;
  final int views;
  final bool verified;
  final bool breaking;
  final String status;

  bool get corrected => status == 'corrected';

  /// Public preview fields safe to persist in the short-lived feed cache.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'slug': slug,
    'headline': headline,
    'summary': summary,
    'reporter_id': reporterId,
    'full_name': fullName,
    'username': username,
    'city': city,
    'category': category,
    'category_id': categoryId,
    'category_slug': categorySlug,
    'city_slug': citySlug,
    'country': country,
    'country_slug': countrySlug,
    'region': region,
    'region_slug': regionSlug,
    'risk_flags': riskFlags,
    'public_image_url': imageUrl,
    'avatar_url': avatarUrl,
    'published_at': publishedAt?.toIso8601String(),
    'likes': likes,
    'dislikes': dislikes,
    'comments': comments,
    'views': views,
    'verified': verified,
    'breaking': breaking,
    'status': status,
  };

  factory NewsSummary.fromJson(Map<String, dynamic> json) => NewsSummary(
    id: json['id']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
    headline: json['headline']?.toString() ?? '',
    summary: json['summary']?.toString() ?? '',
    reporterId: json['reporter_id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? 'Citizen reporter',
    username: json['username']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    category: json['category']?.toString() ?? 'News',
    categoryId: json['category_id']?.toString(),
    categorySlug: json['category_slug']?.toString(),
    citySlug: json['city_slug']?.toString(),
    country: json['country']?.toString(),
    countrySlug: json['country_slug']?.toString(),
    region: json['region']?.toString(),
    regionSlug: json['region_slug']?.toString(),
    riskFlags: (json['risk_flags'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    imageUrl: json['public_image_url']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    dislikes: (json['dislikes'] as num?)?.toInt() ?? 0,
    comments: (json['comments'] as num?)?.toInt() ?? 0,
    views: (json['views'] as num?)?.toInt() ?? 0,
    verified: json['verified'] as bool? ?? false,
    breaking: json['breaking'] as bool? ?? false,
    status: json['status']?.toString() ?? '',
  );
}

class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory NewsCategory.fromJson(Map<String, dynamic> json) => NewsCategory(
    id: json['id'] as String,
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString() ?? '',
  );
}

class NewsArticle {
  const NewsArticle({
    required this.summary,
    required this.body,
    required this.images,
    required this.source,
    required this.updatedAt,
    required this.correctionNote,
  });

  final NewsSummary summary;
  final Map<String, dynamic> body;
  final List<String> images;
  final String source;
  final DateTime? updatedAt;
  final String? correctionNote;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final listed = (json['public_image_urls'] as List? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: true);
    final primary = json['public_image_url']?.toString() ?? '';
    if (listed.isEmpty && primary.isNotEmpty) listed.add(primary);
    return NewsArticle(
      summary: NewsSummary.fromJson(json),
      body: json['body'] is Map
          ? Map<String, dynamic>.from(json['body'] as Map)
          : const {'type': 'doc', 'content': []},
      images: listed,
      source: json['source']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      correctionNote: json['correction_note'] as String?,
    );
  }
}

class NewsComment {
  const NewsComment({
    required this.id,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.fullName = 'Reader',
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String body;
  final DateTime createdAt;
  final String? parentId;
  final String fullName;
  final String? avatarUrl;

  factory NewsComment.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : const <String, dynamic>{};
    return NewsComment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      parentId: json['parent_id'] as String?,
      fullName: profile['full_name']?.toString() ?? 'Reader',
      avatarUrl: profile['avatar_url']?.toString(),
    );
  }
}

class CorrectionEntry {
  const CorrectionEntry({required this.note, required this.reviewedAt});
  final String note;
  final DateTime? reviewedAt;

  factory CorrectionEntry.fromJson(Map<String, dynamic> json) =>
      CorrectionEntry(
        note: json['note']?.toString() ?? '',
        reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      );
}
