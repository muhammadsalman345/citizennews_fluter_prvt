import '../../news/domain/news_models.dart';

class PublicReporter {
  const PublicReporter({
    required this.id,
    required this.fullName,
    required this.username,
    required this.bio,
    this.avatarUrl,
    this.cityId,
    this.cityName,
  });

  final String id;
  final String fullName;
  final String username;
  final String bio;
  final String? avatarUrl;
  final String? cityId;
  final String? cityName;

  factory PublicReporter.fromJson(
    Map<String, dynamic> json, {
    String? cityName,
  }) => PublicReporter(
    id: json['id']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? 'Citizen reporter',
    username: json['username']?.toString() ?? '',
    bio: json['bio']?.toString() ?? '',
    avatarUrl: json['avatar_url']?.toString(),
    cityId: json['city_id']?.toString(),
    cityName: cityName,
  );
}

class PublicReporterStats {
  const PublicReporterStats({
    required this.points,
    required this.published,
    required this.followers,
    required this.views,
    required this.likes,
    required this.rating,
    required this.trust,
  });

  final num points;
  final num published;
  final num followers;
  final num views;
  final num likes;
  final num rating;
  final num trust;

  factory PublicReporterStats.fromJson(Map<String, dynamic> json) =>
      PublicReporterStats(
        points: json['points'] as num? ?? 0,
        published: json['published'] as num? ?? 0,
        followers: json['followers'] as num? ?? 0,
        views: json['views'] as num? ?? 0,
        likes: json['likes'] as num? ?? 0,
        rating: json['rating'] as num? ?? 0,
        trust: json['trust_score'] as num? ?? 0,
      );

  PublicReporterStats copyWith({num? followers}) => PublicReporterStats(
    points: points,
    published: published,
    followers: followers ?? this.followers,
    views: views,
    likes: likes,
    rating: rating,
    trust: trust,
  );
}

class PublicReporterData {
  const PublicReporterData({
    required this.reporter,
    required this.stats,
    required this.stories,
    required this.followed,
  });

  final PublicReporter reporter;
  final PublicReporterStats stats;
  final List<NewsSummary> stories;
  final bool followed;

  PublicReporterData copyWith({
    bool? followed,
    PublicReporterStats? stats,
  }) => PublicReporterData(
    reporter: reporter,
    stats: stats ?? this.stats,
    stories: stories,
    followed: followed ?? this.followed,
  );
}
