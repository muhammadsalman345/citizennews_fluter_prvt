import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reporter_story.dart';

class ReporterStoriesRepository {
  const ReporterStoriesRepository(this.client);

  final SupabaseClient client;

  Future<List<ReporterStory>> ownStories() async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    final rows = await client
        .from('news_posts')
        .select(
          'id,slug,headline,summary,status,breaking,updated_at,published_at,'
          'expires_at,job_deadline,job_timezone,moderation_reason,'
          'moderation_note,categories(slug)',
        )
        .eq('reporter_id', owner)
        .order('created_at', ascending: false);
    return rows
        .map((row) => ReporterStory.fromJson(row))
        .where((story) => story.status != 'draft')
        .toList(growable: false);
  }

  Future<void> appeal({
    required String postId,
    required String message,
  }) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    await client.from('appeals').insert({
      'user_id': owner,
      'post_id': postId,
      'reason': 'copy_7a7073aebc8b',
      'message': message.trim(),
    });
  }
}
