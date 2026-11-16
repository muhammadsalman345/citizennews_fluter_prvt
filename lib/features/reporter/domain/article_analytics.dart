class ArticleAnalyticsDay {
  const ArticleAnalyticsDay({
    required this.day,
    required this.views,
    required this.verifiedViews,
  });

  final DateTime day;
  final int views;
  final int verifiedViews;

  factory ArticleAnalyticsDay.fromJson(Map<String, dynamic> json) =>
      ArticleAnalyticsDay(
        day: DateTime.parse(json['day'] as String),
        views: (json['views'] as num?)?.toInt() ?? 0,
        verifiedViews: (json['verified_views'] as num?)?.toInt() ?? 0,
      );
}

class ArticleAnalyticsData {
  const ArticleAnalyticsData({
    required this.views,
    required this.verifiedViews,
    required this.likes,
    required this.dislikes,
    required this.comments,
    required this.points,
    required this.daily,
  });

  final int views;
  final int verifiedViews;
  final int likes;
  final int dislikes;
  final int comments;
  final int points;
  final List<ArticleAnalyticsDay> daily;

  int get approvalPercent =>
      ((likes / (likes + dislikes).clamp(1, 1 << 31)) * 100).round();

  factory ArticleAnalyticsData.fromJson(Map<String, dynamic> json) =>
      ArticleAnalyticsData(
        views: (json['views'] as num?)?.toInt() ?? 0,
        verifiedViews: (json['verified_views'] as num?)?.toInt() ?? 0,
        likes: (json['likes'] as num?)?.toInt() ?? 0,
        dislikes: (json['dislikes'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        points: (json['points'] as num?)?.toInt() ?? 0,
        daily: (json['daily'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (row) => ArticleAnalyticsDay.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(growable: false),
      );
}
