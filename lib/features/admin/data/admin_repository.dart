import 'package:supabase_flutter/supabase_flutter.dart';

import '../../reporting/data/post_image_normalizer.dart';
import '../../verification/domain/verification_models.dart';

class AdminVerificationItem {
  const AdminVerificationItem({
    required this.verification,
    required this.fullName,
    required this.username,
  });

  final IdentityVerification verification;
  final String fullName;
  final String username;
}

class AdminVerificationReview {
  const AdminVerificationReview({
    required this.context,
    required this.frontUrl,
    required this.backUrl,
    required this.selfieUrl,
  });

  final VerificationReviewContext context;
  final String frontUrl;
  final String? backUrl;
  final String selfieUrl;
}

class AdminNewsItem {
  const AdminNewsItem({
    required this.id,
    required this.reporterId,
    required this.slug,
    required this.headline,
    required this.summary,
    required this.body,
    required this.status,
    required this.source,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.deviceMetadata,
    required this.riskFlags,
    required this.breaking,
    required this.createdAt,
    required this.fullName,
    required this.username,
    required this.rating,
    required this.trustScore,
    required this.followers,
  });

  final String id;
  final String reporterId;
  final String slug;
  final String headline;
  final String summary;
  final Map<String, dynamic> body;
  final String status;
  final String source;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final Map<String, dynamic> deviceMetadata;
  final List<String> riskFlags;
  final bool breaking;
  final DateTime createdAt;
  final String fullName;
  final String username;
  final double rating;
  final double trustScore;
  final int followers;

  factory AdminNewsItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? profile,
    Map<String, dynamic>? statistics,
  }) =>
      AdminNewsItem(
        id: json['id'] as String,
        reporterId: json['reporter_id'] as String,
        slug: json['slug']?.toString() ?? '',
        headline: json['headline']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        body: json['body'] is Map
            ? Map<String, dynamic>.from(json['body'] as Map)
            : const {'type': 'doc', 'content': []},
        status: json['status']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        capturedAt: DateTime.parse(json['captured_at'] as String),
        deviceMetadata: json['device_metadata'] is Map
            ? Map<String, dynamic>.from(json['device_metadata'] as Map)
            : const {},
        riskFlags: (json['risk_flags'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        breaking: json['breaking'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        fullName: profile?['full_name']?.toString() ?? 'Unknown reporter',
        username: profile?['username']?.toString() ?? '',
        rating: (statistics?['rating'] as num?)?.toDouble() ?? 0,
        trustScore: (statistics?['trust_score'] as num?)?.toDouble() ?? 50,
        followers: (statistics?['followers'] as num?)?.toInt() ?? 0,
      );
}

class AdminNewsMedia {
  const AdminNewsMedia({
    required this.id,
    required this.path,
    required this.primary,
    required this.capturedAt,
    required this.createdAt,
    required this.signedUrl,
  });

  final String id;
  final String path;
  final bool primary;
  final DateTime capturedAt;
  final DateTime createdAt;
  final String signedUrl;
}

class AdminDuplicateCandidate {
  const AdminDuplicateCandidate({
    required this.id,
    required this.headline,
    required this.similarity,
  });

  final String id;
  final String headline;
  final double similarity;
}

class AdminNewsReview {
  const AdminNewsReview({required this.media, required this.duplicates});

  final List<AdminNewsMedia> media;
  final List<AdminDuplicateCandidate> duplicates;
}

class AdminRevisionItem {
  const AdminRevisionItem({
    required this.id,
    required this.postId,
    required this.reporterId,
    required this.headline,
    required this.summary,
    required this.body,
    required this.source,
    required this.correctionNote,
    required this.status,
    required this.createdAt,
    required this.reporterName,
    required this.username,
    required this.originalHeadline,
    required this.originalSummary,
    required this.originalBody,
    required this.originalSource,
    required this.postStatus,
    this.reason,
    this.reviewedAt,
    this.jobDeadline,
    this.jobTimezone,
  });

  final String id;
  final String postId;
  final String reporterId;
  final String headline;
  final String summary;
  final Map<String, dynamic> body;
  final String source;
  final String correctionNote;
  final String status;
  final String? reason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? jobDeadline;
  final String? jobTimezone;
  final String reporterName;
  final String username;
  final String originalHeadline;
  final String originalSummary;
  final Map<String, dynamic> originalBody;
  final String originalSource;
  final String postStatus;

  factory AdminRevisionItem.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? post,
    Map<String, dynamic>? profile,
  }) =>
      AdminRevisionItem(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        reporterId: json['reporter_id'] as String,
        headline: json['headline']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        body: json['body'] is Map
            ? Map<String, dynamic>.from(json['body'] as Map)
            : const {'type': 'doc', 'content': []},
        source: json['source']?.toString() ?? '',
        correctionNote: json['correction_note']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
        jobDeadline: json['job_deadline'] as String?,
        jobTimezone: json['job_timezone'] as String?,
        reporterName: profile?['full_name']?.toString() ?? 'Unknown reporter',
        username: profile?['username']?.toString() ?? '',
        originalHeadline: post?['headline']?.toString() ?? '',
        originalSummary: post?['summary']?.toString() ?? '',
        originalBody: post?['body'] is Map
            ? Map<String, dynamic>.from(post!['body'] as Map)
            : const {'type': 'doc', 'content': []},
        originalSource: post?['source']?.toString() ?? '',
        postStatus: post?['status']?.toString() ?? '',
      );
}

class AdminRepository {
  const AdminRepository(this.client);

  final SupabaseClient client;

  Future<List<AdminVerificationItem>> verificationQueue() async {
    final rows = await client
        .from('identity_verifications')
        .select(
          'id,user_id,document_type,front_path,back_path,selfie_path,'
          'country_id,city_id,date_of_birth,status,reason,note,created_at',
        )
        .order('created_at', ascending: false)
        .limit(200);
    final verifications = rows
        .map((row) => IdentityVerification.fromJson(row))
        .toList(growable: false);
    final userIds = verifications.map((item) => item.userId).toSet().toList();
    final profiles = userIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('profiles')
                .select('id,full_name,username')
                .inFilter('id', userIds))
            .cast<Map<String, dynamic>>();
    final byId = {for (final profile in profiles) profile['id']: profile};
    return verifications.map((verification) {
      final profile = byId[verification.userId];
      return AdminVerificationItem(
        verification: verification,
        fullName: profile?['full_name']?.toString() ?? 'Unknown user',
        username: profile?['username']?.toString() ?? '',
      );
    }).toList(growable: false);
  }

  Future<AdminVerificationReview> inspect(
    IdentityVerification verification,
  ) async {
    await client.rpc<void>(
      'audit_document_access',
      params: {'verification_id': verification.id},
    );
    final rawContext = await client.rpc<dynamic>(
      'verification_context',
      params: {'verification_id': verification.id},
    );
    final urls = await Future.wait<String?>([
      _signed('identity-documents', verification.frontPath),
      verification.backPath.isEmpty
          ? Future<String?>.value(null)
          : _signed('identity-documents', verification.backPath),
      _signed('selfies', verification.selfiePath),
    ]);
    return AdminVerificationReview(
      context: VerificationReviewContext.fromJson(
        Map<String, dynamic>.from(rawContext as Map),
      ),
      frontUrl: urls[0]!,
      backUrl: urls[1],
      selfieUrl: urls[2]!,
    );
  }

  Future<String> _signed(String bucket, String path) =>
      client.storage.from(bucket).createSignedUrl(path, 300);

  Future<List<AdminNewsItem>> newsQueue() async {
    final rows = await client
        .from('news_posts')
        .select(
          'id,reporter_id,slug,headline,summary,body,status,source,latitude,'
          'longitude,accuracy,captured_at,device_metadata,risk_flags,breaking,'
          'created_at',
        )
        .order('created_at', ascending: false)
        .limit(200);
    final reporterIds = rows
        .map((row) => row['reporter_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final profiles = reporterIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('profiles')
                .select('id,full_name,username')
                .inFilter('id', reporterIds))
            .cast<Map<String, dynamic>>();
    final statistics = reporterIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('reporter_statistics')
                .select('user_id,rating,trust_score,followers')
                .inFilter('user_id', reporterIds))
            .cast<Map<String, dynamic>>();
    final profilesById = {for (final row in profiles) row['id']: row};
    final statisticsById = {
      for (final row in statistics) row['user_id']: row,
    };
    return rows
        .map(
          (row) => AdminNewsItem.fromJson(
            row,
            profile: profilesById[row['reporter_id']],
            statistics: statisticsById[row['reporter_id']],
          ),
        )
        .where((item) => item.status != 'draft')
        .toList(growable: false);
  }

  Future<AdminNewsReview> inspectNews(String postId) async {
    final rows = await client
        .from('news_media')
        .select('id,path,primary_evidence,captured_at,created_at')
        .eq('post_id', postId)
        .order('primary_evidence', ascending: false)
        .order('created_at');
    final media = <AdminNewsMedia>[];
    for (final row in rows) {
      media.add(
        AdminNewsMedia(
          id: row['id'] as String,
          path: row['path'] as String,
          primary: row['primary_evidence'] as bool? ?? false,
          capturedAt: DateTime.parse(row['captured_at'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
          signedUrl: await _signed('evidence', row['path'] as String),
        ),
      );
    }
    final duplicateRows = await client.rpc<dynamic>(
      'duplicate_candidates',
      params: {'post_id': postId},
    );
    final duplicates = (duplicateRows as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => AdminDuplicateCandidate(
            id: row['id'] as String,
            headline: row['headline']?.toString() ?? '',
            similarity: (row['similarity'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
    return AdminNewsReview(media: media, duplicates: duplicates);
  }

  Future<List<AdminRevisionItem>> revisions() async {
    final rows = await client
        .from('news_revisions')
        .select(
          'id,post_id,reporter_id,headline,summary,body,source,'
          'correction_note,status,reason,created_at,reviewed_at,'
          'job_deadline,job_timezone',
        )
        .order('created_at', ascending: false)
        .limit(200);
    final postIds = rows
        .map((row) => row['post_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final reporterIds = rows
        .map((row) => row['reporter_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final posts = postIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('news_posts')
                .select('id,headline,summary,body,source,status')
                .inFilter('id', postIds))
            .cast<Map<String, dynamic>>();
    final profiles = reporterIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('profiles')
                .select('id,full_name,username')
                .inFilter('id', reporterIds))
            .cast<Map<String, dynamic>>();
    final postsById = {for (final row in posts) row['id']: row};
    final profilesById = {for (final row in profiles) row['id']: row};
    return rows
        .map(
          (row) => AdminRevisionItem.fromJson(
            row,
            post: postsById[row['post_id']],
            profile: profilesById[row['reporter_id']],
          ),
        )
        .toList(growable: false);
  }

  Future<void> reviewRevision({
    required String revisionId,
    required String decision,
    String? reason,
  }) =>
      client.rpc<void>(
        'review_revision',
        params: {
          'revision_id': revisionId,
          'decision': decision,
          'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        },
      );

  Future<void> moderateNews({
    required AdminNewsItem post,
    required String decision,
    String? reason,
    String? note,
  }) async {
    final publicUrls = <String>[];
    final createdPaths = <String>[];
    var completed = false;
    try {
      if (decision == 'published') {
        final media = await client
            .from('news_media')
            .select('id,path,primary_evidence,created_at')
            .eq('post_id', post.id)
            .order('primary_evidence', ascending: false)
            .order('created_at');
        for (final item in media) {
          final bytes = await client.storage
              .from('evidence')
              .download(item['path'] as String);
          final normalized = await normalizePostImage(bytes);
          final path = '${post.id}/${item['id']}.jpg';
          try {
            await client.storage.from('news-images').uploadBinary(
                  path,
                  normalized,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    upsert: false,
                  ),
                );
            createdPaths.add(path);
          } on StorageException catch (error) {
            if (!error.message.toLowerCase().contains('already')) rethrow;
          }
          publicUrls.add(
            client.storage.from('news-images').getPublicUrl(path),
          );
        }
      }
      await client.rpc<void>(
        'moderate_news_with_media',
        params: {
          'post_id': post.id,
          'decision': decision,
          'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'image_urls': publicUrls,
        },
      );
      completed = true;
      if (decision != 'published') await _removePublicImages(post.id);
    } finally {
      if (!completed && createdPaths.isNotEmpty) {
        await client.storage.from('news-images').remove(createdPaths);
      }
    }
  }

  Future<void> _removePublicImages(String postId) async {
    final files = await client.storage.from('news-images').list(
          path: postId,
          searchOptions: const SearchOptions(limit: 100),
        );
    if (files.isEmpty) return;
    await client.storage.from('news-images').remove(
          files.map((file) => '$postId/${file.name}').toList(growable: false),
        );
  }

  Future<void> setBreaking({
    required String postId,
    required bool enabled,
    required String reason,
  }) =>
      client.rpc<void>(
        'set_breaking',
        params: {
          'post_id': postId,
          'enabled': enabled,
          'reason': reason.trim(),
        },
      );

  Future<void> groupIncident({
    required AdminNewsItem post,
    required List<AdminDuplicateCandidate> duplicates,
  }) =>
      client.rpc<void>(
        'group_incident',
        params: {
          'post_ids': [post.id, ...duplicates.map((item) => item.id)],
          'title': post.headline,
        },
      );

  Future<void> deletePost({
    required String postId,
    required String reason,
  }) =>
      client.rpc<void>(
        'super_admin_delete_post',
        params: {'post_id': postId, 'reason': reason.trim()},
      );

  Future<void> moderateIdentity({
    required String verificationId,
    required String decision,
    String? reason,
    String? note,
  }) =>
      client.rpc<void>(
        'moderate_identity',
        params: {
          'verification_id': verificationId,
          'decision': decision,
          'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
        },
      );
}
