import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/news_models.dart';

class NewsRepository {
  const NewsRepository(this.client);

  final SupabaseClient client;

  Future<List<NewsCategory>> categories() async {
    final rows = await client
        .from('categories')
        .select('id,name,slug')
        .eq('active', true)
        .order('name');
    return rows
        .map((row) => NewsCategory.fromJson(row))
        .where((category) => !category.slug.startsWith('jobs-'))
        .toList(growable: false);
  }

  Future<List<NewsSummary>> search({
    String query = '',
    String city = '',
    String category = '',
    String country = '',
    String region = '',
    String area = '',
    String tab = 'latest',
    int page = 0,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final result = await client.rpc<dynamic>(
      'search_news_global',
      params: {
        'query': query.trim(),
        'city': city.isEmpty ? null : city,
        'category': category.isEmpty ? null : category,
        'country': country.isEmpty ? null : country,
        'region': region.isEmpty ? null : region,
        'area': area.isEmpty ? null : area,
        'sort': tab == 'trending' ? 'trending' : 'latest',
        'page': page,
        'following': tab == 'following',
        'date_from': dateFrom == null ? null : _date(dateFrom),
        'date_to': dateTo == null ? null : _date(dateTo),
      },
    );
    return (result as List? ?? const [])
        .whereType<Map>()
        .map((row) => NewsSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<NewsCategory?> categoryBySlug(String slug) async {
    if (slug.isEmpty) return null;
    final row = await client
        .from('categories')
        .select('id,name,slug')
        .eq('slug', slug)
        .eq('active', true)
        .maybeSingle();
    return row == null ? null : NewsCategory.fromJson(row);
  }

  Future<bool> isFollowing(String type, String targetId) async {
    final user = client.auth.currentUser;
    if (user == null || targetId.isEmpty) return false;
    final row = await client
        .from('follows')
        .select('id')
        .eq('user_id', user.id)
        .eq('target_type', type)
        .eq('target_id', targetId)
        .maybeSingle();
    return row != null;
  }

  Future<void> setFollowing(String type, String targetId, bool followed) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to follow news.');
    if (followed) {
      await client.from('follows').insert({
        'user_id': user.id,
        'target_type': type,
        'target_id': targetId,
      });
    } else {
      await client
          .from('follows')
          .delete()
          .eq('user_id', user.id)
          .eq('target_type', type)
          .eq('target_id', targetId);
    }
  }

  Future<NewsArticle?> article(String slug) async {
    final row = await client
        .from('public_news')
        .select('*')
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : NewsArticle.fromJson(row);
  }

  Future<List<NewsComment>> comments(String postId) async {
    final signedIn = client.auth.currentUser != null;
    final fields = signedIn
        ? 'id,user_id,body,created_at,parent_id,'
              'profiles!comments_user_id_fkey(full_name,avatar_url)'
        : 'id,user_id,body,created_at,parent_id';
    final rows = await client
        .from('comments')
        .select(fields)
        .eq('post_id', postId)
        .order('created_at');
    return rows.map((row) => NewsComment.fromJson(row)).toList(growable: false);
  }

  Future<List<CorrectionEntry>> correctionHistory(String slug) async {
    final result = await client.rpc<dynamic>(
      'correction_history',
      params: {'post_slug': slug},
    );
    return (result as List? ?? const [])
        .whereType<Map>()
        .map((row) => CorrectionEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<int> currentReaction(String postId) async {
    final user = client.auth.currentUser;
    if (user == null) return 0;
    final row = await client
        .from('reactions')
        .select('value')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();
    return (row?['value'] as num?)?.toInt() ?? 0;
  }

  Future<bool> isBookmarked(String postId) async {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final row = await client
        .from('bookmarks')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<bool> isFollowingReporter(String reporterId) async {
    return isFollowing('reporter', reporterId);
  }

  Future<void> react(String postId, int value) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to react.');
    if (value == 0) {
      await client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } else {
      await client.from('reactions').upsert({
        'post_id': postId,
        'user_id': user.id,
        'value': value,
      }, onConflict: 'post_id,user_id');
    }
  }

  Future<void> setBookmark(String postId, bool saved) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to save stories.');
    if (saved) {
      await client.from('bookmarks').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    } else {
      await client
          .from('bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    }
  }

  Future<void> setReporterFollow(String reporterId, bool followed) async {
    await setFollowing('reporter', reporterId, followed);
  }

  Future<void> addComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to comment.');
    await client.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'body': text.trim(),
      'parent_id': parentId,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  Future<void> reportStory(String postId, String reason, String note) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to report a story.');
    await client.from('news_reports').insert({
      'post_id': postId,
      'user_id': user.id,
      'reason': reason,
      'note': note.trim(),
    });
  }

  Future<void> reportComment(String commentId, String note) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to report a comment.');
    await client.from('news_reports').insert({
      'comment_id': commentId,
      'user_id': user.id,
      'reason': 'Other',
      'note': note.trim(),
    });
  }

  Future<void> recordView(String postId, String sessionKey) => client.rpc<void>(
    'record_view',
    params: {'post_id': postId, 'session_key': sessionKey},
  );

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
