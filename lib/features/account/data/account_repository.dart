import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../location/data/location_repository.dart';
import '../../news/data/news_repository.dart';
import '../../news/domain/news_models.dart';
import '../domain/account_models.dart';
import 'avatar_image_normalizer.dart';

class AccountRepository {
  AccountRepository(this.client)
    : news = NewsRepository(client),
      locations = LocationRepository(client);

  final SupabaseClient client;
  final NewsRepository news;
  final LocationRepository locations;
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random.secure();

  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in required.');
    return id;
  }

  Future<AccountDeletionRequest?> deletionRequest() async {
    final row = await client
        .from('account_deletion_requests')
        .select('status,requested_at')
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : AccountDeletionRequest.fromJson(row);
  }

  Future<void> saveProfile({
    required String fullName,
    required String bio,
    String? cityId,
  }) async {
    final cleanName = fullName.trim();
    final cleanBio = bio.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw Exception('Full name must be between 1 and 100 characters.');
    }
    if (cleanBio.length > 1000) {
      throw Exception('Bio cannot be longer than 1,000 characters.');
    }
    await client
        .from('profiles')
        .update({
          'full_name': cleanName,
          'bio': cleanBio,
          'city_id': cityId?.isEmpty == true ? null : cityId,
        })
        .eq('id', _userId)
        .select('id')
        .single();
  }

  Future<bool> chooseAndUploadAvatar(String? oldUrl) async {
    final owner = _userId;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (file == null) return false;
    final bytes = await normalizeAvatarImage(await file.readAsBytes());
    final path =
        '$owner/${DateTime.now().toUtc().microsecondsSinceEpoch}-'
        '${_random.nextInt(1 << 32)}.jpg';
    final storage = client.storage.from('public-profile-images');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        cacheControl: '3600',
        upsert: false,
      ),
    );
    var profileUpdated = false;
    try {
      final publicUrl = storage.getPublicUrl(path);
      await client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', owner)
          .select('id')
          .single();
      profileUpdated = true;
      await _removeOwnedPreviousAvatar(storage, owner, oldUrl);
      return true;
    } finally {
      if (!profileUpdated) {
        await storage.remove([path]).catchError((_) => <FileObject>[]);
      }
    }
  }

  Future<void> _removeOwnedPreviousAvatar(
    StorageFileApi storage,
    String owner,
    String? oldUrl,
  ) async {
    if (oldUrl == null || oldUrl.isEmpty) return;
    final prefix = storage.getPublicUrl('');
    if (!oldUrl.startsWith(prefix)) return;
    final previous = oldUrl
        .substring(prefix.length)
        .replaceFirst(RegExp(r'^/+'), '');
    if (!previous.startsWith('$owner/')) return;
    await storage.remove([previous]).catchError((_) => <FileObject>[]);
  }

  Future<List<NewsSummary>> savedStories() async {
    final rows = await client
        .from('bookmarks')
        .select('post_id,created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    final ids = rows
        .map((row) => row['post_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return const [];
    final stories = await client
        .from('public_news')
        .select('*')
        .inFilter('id', ids);
    final byId = {
      for (final row in stories)
        row['id'].toString(): NewsSummary.fromJson(row),
    };
    return ids.map((id) => byId[id]).whereType<NewsSummary>().toList();
  }

  Future<void> removeBookmark(String postId) async {
    await client
        .from('bookmarks')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', _userId);
  }

  Future<AccountFollowingData> following() async {
    final rows = await client
        .from('follows')
        .select('id,target_type,target_id,created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    final labels = <String, ({String label, String? username})>{};
    for (final type in const ['reporter', 'city', 'area', 'category']) {
      final ids = rows
          .where((row) => row['target_type'] == type)
          .map((row) => row['target_id'].toString())
          .toSet()
          .toList();
      if (ids.isEmpty) continue;
      final table = switch (type) {
        'reporter' => 'profiles',
        'city' => 'cities',
        'area' => 'areas',
        _ => 'categories',
      };
      final fields = type == 'reporter' ? 'id,full_name,username' : 'id,name';
      final values = await client.from(table).select(fields).inFilter('id', ids);
      for (final value in values) {
        final id = value['id'].toString();
        labels['$type:$id'] = (
          label: value[type == 'reporter' ? 'full_name' : 'name']
                  ?.toString() ??
              'Unavailable item',
          username: value['username']?.toString(),
        );
      }
    }
    final follows = rows.map((row) {
      final type = row['target_type'].toString();
      final target = row['target_id'].toString();
      final value = labels['$type:$target'];
      return AccountFollow(
        id: row['id'].toString(),
        targetType: type,
        targetId: target,
        label: value?.label ?? 'Unavailable item',
        username: value?.username,
      );
    }).toList(growable: false);
    final stories = await news.search(tab: 'following');
    return AccountFollowingData(follows: follows, stories: stories);
  }

  Future<void> unfollow(AccountFollow follow) async {
    await client
        .from('follows')
        .delete()
        .eq('user_id', _userId)
        .eq('target_type', follow.targetType)
        .eq('target_id', follow.targetId);
  }

  Future<List<AccountComment>> comments() async {
    final rows = await client
        .from('comments')
        .select('id,post_id,body,created_at,parent_id')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    final postIds = rows
        .map((row) => row['post_id'].toString())
        .toSet()
        .toList();
    final posts = postIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
              .from('public_news')
              .select('id,headline,slug')
              .inFilter('id', postIds);
    final byId = {for (final post in posts) post['id'].toString(): post};
    return rows.map((row) {
      final post = byId[row['post_id'].toString()];
      return AccountComment(
        id: row['id'].toString(),
        postId: row['post_id'].toString(),
        body: row['body']?.toString() ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        headline: post?['headline']?.toString(),
        slug: post?['slug']?.toString(),
      );
    }).toList(growable: false);
  }

  Future<AccountAppealsData> appealsAndReports() async {
    final results = await Future.wait<dynamic>([
      client
          .from('appeals')
          .select(
            'id,post_id,verification_id,reason,message,status,'
            'admin_response,created_at',
          )
          .eq('user_id', _userId)
          .order('created_at', ascending: false),
      client
          .from('news_reports')
          .select('id,reason,note,status,created_at')
          .eq('user_id', _userId)
          .order('created_at', ascending: false),
      client
          .from('identity_verifications')
          .select('id')
          .eq('user_id', _userId)
          .eq('status', 'rejected')
          .order('created_at', ascending: false)
          .limit(1),
    ]);
    final appeals = (results[0] as List)
          .whereType<Map>()
          .map((row) => AccountAppeal.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    final rejectedRows = results[2] as List;
    final rejectedId = rejectedRows.isEmpty
        ? null
        : (rejectedRows.first as Map)['id']?.toString();
    final alreadyPending = rejectedId != null &&
        appeals.any(
          (appeal) =>
              appeal.verificationId == rejectedId && appeal.status == 'pending',
        );
    return AccountAppealsData(
      appeals: appeals,
      reports: (results[1] as List)
          .whereType<Map>()
          .map((row) => AccountReport.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
      canAppealVerification: rejectedId != null && !alreadyPending,
    );
  }

  Future<void> appealVerification(String message) async {
    final clean = message.trim();
    if (clean.isEmpty || clean.length > 2000) {
      throw Exception('Appeal message must be between 1 and 2,000 characters.');
    }
    final rows = await client
        .from('identity_verifications')
        .select('id')
        .eq('user_id', _userId)
        .eq('status', 'rejected')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      throw Exception('There is no rejected verification to appeal.');
    }
    await client.from('appeals').insert({
      'user_id': _userId,
      'verification_id': rows.first['id'],
      'reason': 'Verification decision appeal',
      'message': clean,
    });
  }

  Future<void> requestDeletion(String? reason) => client.rpc<void>(
    'request_account_deletion',
    params: {'reason': reason?.trim().isEmpty == true ? null : reason?.trim()},
  );

  Future<void> cancelDeletion() =>
      client.rpc<void>('cancel_account_deletion');

  Future<void> changePassword(String password) async {
    if (password.length < 8) {
      throw Exception('Password must contain at least 8 characters.');
    }
    await client.auth.updateUser(UserAttributes(password: password));
  }
}
