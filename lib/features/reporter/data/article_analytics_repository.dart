import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/article_analytics.dart';

class ArticleAnalyticsRepository {
  const ArticleAnalyticsRepository(this.client);

  final SupabaseClient client;

  Future<ArticleAnalyticsData> load({
    required String postId,
    required int days,
  }) async {
    final result = await client.rpc<dynamic>(
      'article_analytics',
      params: {'post_id': postId, 'days': days},
    );
    return ArticleAnalyticsData.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }
}
