import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../location/data/location_repository.dart';
import '../../location/domain/location_models.dart';

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.entity,
    required this.action,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String entity;
  final String action;
  final String reason;
  final DateTime createdAt;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) =>
      AdminAuditEntry(
        id: _text(json['id']),
        entity: _text(json['entity']),
        action: _text(json['action']),
        reason: _text(json['reason']),
        createdAt: _date(json['created_at']),
      );
}

class AdminOverviewData {
  const AdminOverviewData({
    required this.pendingVerifications,
    required this.pendingNews,
    required this.pendingRevisions,
    required this.pendingReports,
    required this.pendingChatReports,
    required this.pendingAppeals,
    required this.pendingWithdrawals,
    required this.recentAudit,
  });

  final int pendingVerifications;
  final int pendingNews;
  final int pendingRevisions;
  final int pendingReports;
  final int pendingChatReports;
  final int pendingAppeals;
  final int pendingWithdrawals;
  final List<AdminAuditEntry> recentAudit;
}

class AdminContentReport {
  const AdminContentReport({
    required this.id,
    required this.reason,
    required this.note,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.postId,
    this.commentId,
    this.storySlug,
    this.storyHeadline,
    this.storyStatus,
    this.commentBody,
    this.commentHidden = false,
  });

  final String id;
  final String reason;
  final String note;
  final String status;
  final String? adminResponse;
  final String? postId;
  final String? commentId;
  final String? storySlug;
  final String? storyHeadline;
  final String? storyStatus;
  final String? commentBody;
  final bool commentHidden;
  final DateTime createdAt;
}

class AdminChatReport {
  const AdminChatReport({
    required this.id,
    required this.reporterId,
    required this.senderId,
    required this.messageBody,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.adminResponse,
  });

  final String id;
  final String reporterId;
  final String senderId;
  final String messageBody;
  final String reason;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;

  factory AdminChatReport.fromJson(Map<String, dynamic> json) =>
      AdminChatReport(
        id: _text(json['id']),
        reporterId: _text(json['reporter_id']),
        senderId: _text(json['sender_id']),
        messageBody: _text(json['message_body']),
        reason: _text(json['reason']),
        status: _text(json['status']),
        adminResponse: _nullable(json['admin_response']),
        createdAt: _date(json['created_at']),
      );
}

class AdminAppeal {
  const AdminAppeal({
    required this.id,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.postId,
    this.verificationId,
  });

  final String id;
  final String userId;
  final String userName;
  final String? postId;
  final String? verificationId;
  final String reason;
  final String message;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;
}

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.fullName,
    required this.username,
    required this.status,
    required this.roles,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final String status;
  final List<String> roles;
}

class AdminDeletionRequest {
  const AdminDeletionRequest({
    required this.userId,
    required this.userName,
    required this.status,
    required this.requestedAt,
    this.reason,
    this.adminNote,
  });

  final String userId;
  final String userName;
  final String status;
  final String? reason;
  final DateTime requestedAt;
  final String? adminNote;
}

class AdminWithdrawal {
  const AdminWithdrawal({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.payoutMethod,
    required this.payoutDetails,
    required this.createdAt,
    this.adminNotes,
    this.paymentReference,
    this.paidAt,
  });

  final String id;
  final String userId;
  final String userName;
  final double amount;
  final String currency;
  final String status;
  final String payoutMethod;
  final String payoutDetails;
  final String? adminNotes;
  final String? paymentReference;
  final DateTime createdAt;
  final DateTime? paidAt;

  Map<String, String>? get structuredPayoutDetails {
    try {
      final value = jsonDecode(payoutDetails);
      if (value is! Map) return null;
      final result = <String, String>{};
      for (final key in const [
        'bankName',
        'accountHolder',
        'accountNumber',
        'bankCode',
        'phoneNumber',
      ]) {
        final text = value[key]?.toString().trim() ?? '';
        if (text.isNotEmpty) result[key] = text;
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}

class AdminCategoryRecord {
  const AdminCategoryRecord({
    required this.id,
    required this.name,
    required this.slug,
    required this.active,
  });

  final String id;
  final String name;
  final String slug;
  final bool active;

  factory AdminCategoryRecord.fromJson(Map<String, dynamic> json) =>
      AdminCategoryRecord(
        id: _text(json['id']),
        name: _text(json['name']),
        slug: _text(json['slug']),
        active: json['active'] != false,
      );
}

class AdminSettingRecord {
  const AdminSettingRecord({required this.key, required this.value});

  final String key;
  final dynamic value;

  String get prettyValue => const JsonEncoder.withIndent('  ').convert(value);
}

class AdminContactMessage {
  const AdminContactMessage({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String subject;
  final String message;
  final DateTime createdAt;

  factory AdminContactMessage.fromJson(Map<String, dynamic> json) =>
      AdminContactMessage(
        id: _text(json['id']),
        name: _text(json['name']),
        email: _text(json['email']),
        subject: _text(json['subject']),
        message: _text(json['message']),
        createdAt: _date(json['created_at']),
      );
}

class AdminOperationsRepository {
  AdminOperationsRepository(this.client)
    : locations = LocationRepository(client);

  final SupabaseClient client;
  final LocationRepository locations;
  final Random _random = Random.secure();

  Future<AdminOverviewData> overview() async {
    final results = await Future.wait<dynamic>([
      client.from('identity_verifications').select('status').limit(500),
      client.from('news_posts').select('status').limit(500),
      client.from('news_revisions').select('status').limit(500),
      client.from('news_reports').select('status').limit(500),
      client.rpc<dynamic>('admin_chat_reports'),
      client.from('appeals').select('status').limit(500),
      client.from('withdrawal_requests').select('status').limit(500),
      audit(limit: 10),
    ]);
    return AdminOverviewData(
      pendingVerifications: _count(results[0], const {'pending'}),
      pendingNews: _count(results[1], const {'pending'}),
      pendingRevisions: _count(results[2], const {'pending_review'}),
      pendingReports: _count(results[3], const {'pending', 'investigating'}),
      pendingChatReports: _count(results[4], const {
        'pending',
        'investigating',
      }),
      pendingAppeals: _count(results[5], const {'pending'}),
      pendingWithdrawals: _count(results[6], const {'pending', 'approved'}),
      recentAudit: results[7] as List<AdminAuditEntry>,
    );
  }

  Future<List<AdminContentReport>> contentReports({int limit = 51}) async {
    final reports = _rows(
      await client
          .from('news_reports')
          .select(
            'id,user_id,post_id,comment_id,reason,note,status,'
            'admin_response,resolved_at,created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit),
    );
    final commentIds = reports
        .map((row) => _nullable(row['comment_id']))
        .whereType<String>()
        .toSet()
        .toList();
    final comments = commentIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await client
                .from('comments')
                .select('id,post_id,body,hidden')
                .inFilter('id', commentIds),
          );
    final commentById = {for (final row in comments) _text(row['id']): row};
    final postIds = <String>{};
    for (final report in reports) {
      final direct = _nullable(report['post_id']);
      final comment = commentById[_nullable(report['comment_id'])];
      final fromComment = _nullable(comment?['post_id']);
      if (direct != null) postIds.add(direct);
      if (fromComment != null) postIds.add(fromComment);
    }
    final posts = postIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await client
                .from('news_posts')
                .select('id,slug,headline,status')
                .inFilter('id', postIds.toList()),
          );
    final postById = {for (final row in posts) _text(row['id']): row};
    return reports
        .map((row) {
          final comment = commentById[_nullable(row['comment_id'])];
          final postId =
              _nullable(row['post_id']) ?? _nullable(comment?['post_id']);
          final post = postById[postId];
          return AdminContentReport(
            id: _text(row['id']),
            reason: _text(row['reason']),
            note: _text(row['note']),
            status: _text(row['status']),
            adminResponse: _nullable(row['admin_response']),
            postId: postId,
            commentId: _nullable(row['comment_id']),
            storySlug: _nullable(post?['slug']),
            storyHeadline: _nullable(post?['headline']),
            storyStatus: _nullable(post?['status']),
            commentBody: _nullable(comment?['body']),
            commentHidden: comment?['hidden'] == true,
            createdAt: _date(row['created_at']),
          );
        })
        .toList(growable: false);
  }

  Future<List<AdminChatReport>> chatReports({int limit = 51}) async {
    final value = await client.rpc<dynamic>('admin_chat_reports');
    return _rows(
      value,
    ).take(limit).map(AdminChatReport.fromJson).toList(growable: false);
  }

  Future<List<AdminAppeal>> appeals({int limit = 51}) async {
    final rows = _rows(
      await client
          .from('appeals')
          .select(
            'id,user_id,post_id,verification_id,reason,message,status,'
            'admin_response,created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit),
    );
    final names = await _profileNames(
      rows.map((row) => _text(row['user_id'])).toSet(),
    );
    return rows
        .map(
          (row) => AdminAppeal(
            id: _text(row['id']),
            userId: _text(row['user_id']),
            userName: names[_text(row['user_id'])] ?? 'Unknown user',
            postId: _nullable(row['post_id']),
            verificationId: _nullable(row['verification_id']),
            reason: _text(row['reason']),
            message: _text(row['message']),
            status: _text(row['status']),
            adminResponse: _nullable(row['admin_response']),
            createdAt: _date(row['created_at']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminUserRecord>> users({int limit = 51}) async {
    final profiles = _rows(
      await client
          .from('profiles')
          .select('id,full_name,username,avatar_url')
          .order('created_at', ascending: false)
          .limit(limit),
    );
    final ids = profiles.map((row) => _text(row['id'])).toList();
    final roleRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await client
                .from('user_roles')
                .select('user_id,role')
                .inFilter('user_id', ids),
          );
    final statusRows = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : _rows(
            await client
                .from('account_status')
                .select('user_id,status')
                .inFilter('user_id', ids),
          );
    final statusById = {
      for (final row in statusRows)
        _text(row['user_id']): _text(row['status'], fallback: 'active'),
    };
    final rolesById = <String, List<String>>{};
    for (final row in roleRows) {
      final id = _text(row['user_id']);
      final role = _text(row['role']);
      if (id.isNotEmpty && role.isNotEmpty) {
        rolesById.putIfAbsent(id, () => <String>[]).add(role);
      }
    }
    return profiles
        .map((profile) {
          final id = _text(profile['id']);
          return AdminUserRecord(
            id: id,
            fullName: _text(profile['full_name'], fallback: 'Unknown user'),
            username: _text(profile['username']),
            avatarUrl: _nullable(profile['avatar_url']),
            status: statusById[id] ?? 'active',
            roles: List.unmodifiable(rolesById[id] ?? const <String>[]),
          );
        })
        .toList(growable: false);
  }

  Future<List<AdminDeletionRequest>> deletionRequests({int limit = 51}) async {
    final rows = _rows(
      await client
          .from('account_deletion_requests')
          .select('user_id,status,reason,requested_at,admin_note')
          .order('requested_at', ascending: false)
          .limit(limit),
    );
    final names = await _profileNames(
      rows.map((row) => _text(row['user_id'])).toSet(),
    );
    return rows
        .map(
          (row) => AdminDeletionRequest(
            userId: _text(row['user_id']),
            userName: names[_text(row['user_id'])] ?? 'Unknown user',
            status: _text(row['status']),
            reason: _nullable(row['reason']),
            requestedAt: _date(row['requested_at']),
            adminNote: _nullable(row['admin_note']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminWithdrawal>> withdrawals({int limit = 51}) async {
    final rows = _rows(
      await client
          .from('withdrawal_requests')
          .select(
            'id,user_id,amount,currency,status,payout_method,payout_details,'
            'admin_notes,payment_reference,paid_at,created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit),
    );
    final details = _rows(await client.rpc<dynamic>('admin_payout_details'));
    final detailsById = {
      for (final row in details)
        _text(row['withdrawal_id']): _text(row['payout_details']),
    };
    final names = await _profileNames(
      rows.map((row) => _text(row['user_id'])).toSet(),
    );
    return rows
        .map(
          (row) => AdminWithdrawal(
            id: _text(row['id']),
            userId: _text(row['user_id']),
            userName: names[_text(row['user_id'])] ?? 'Unknown user',
            amount: _number(row['amount']),
            currency: _text(row['currency'], fallback: 'USD'),
            status: _text(row['status']),
            payoutMethod: _text(row['payout_method']),
            payoutDetails:
                detailsById[_text(row['id'])] ?? _text(row['payout_details']),
            adminNotes: _nullable(row['admin_notes']),
            paymentReference: _nullable(row['payment_reference']),
            createdAt: _date(row['created_at']),
            paidAt: _optionalDate(row['paid_at']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<AdminCategoryRecord>> categories() async => _rows(
    await client.from('categories').select('id,name,slug,active').order('name'),
  ).map(AdminCategoryRecord.fromJson).toList(growable: false);

  Future<List<AdminSettingRecord>> settings() async =>
      _rows(await client.from('settings').select('key,value').order('key'))
          .map(
            (row) =>
                AdminSettingRecord(key: _text(row['key']), value: row['value']),
          )
          .toList(growable: false);

  Future<List<AdminContactMessage>> contacts({int limit = 51}) async => _rows(
    await client
        .from('contact_messages')
        .select('id,name,email,subject,message,created_at')
        .order('created_at', ascending: false)
        .limit(limit),
  ).map(AdminContactMessage.fromJson).toList(growable: false);

  Future<List<AdminAuditEntry>> audit({int limit = 51}) async => _rows(
    await client
        .from('admin_audit_logs')
        .select('id,entity,action,reason,created_at')
        .order('created_at', ascending: false)
        .limit(limit),
  ).map(AdminAuditEntry.fromJson).toList(growable: false);

  Future<void> resolveReport(
    String reportId,
    String decision,
    String response,
  ) async {
    await client.rpc<dynamic>(
      'resolve_report',
      params: {
        'report_id': reportId,
        'decision': decision,
        'response': response.trim(),
      },
    );
  }

  Future<void> hideCommentAndResolve(
    AdminContentReport report,
    String response,
  ) async {
    final commentId = report.commentId;
    if (commentId == null) return;
    await client.rpc<dynamic>(
      'moderate_comment',
      params: {
        'comment_id': commentId,
        'hidden': true,
        'reason': response.trim(),
      },
    );
    await resolveReport(report.id, 'resolved', response);
  }

  Future<void> resolveChatReport({
    required String reportId,
    required String decision,
    required String response,
    bool suspendSender = false,
  }) async {
    await client.rpc<dynamic>(
      'resolve_chat_report',
      params: {
        'report_id': reportId,
        'decision': decision,
        'response': response.trim(),
        'block_sender': suspendSender,
      },
    );
  }

  Future<void> resolveAppeal(
    String appealId,
    String decision,
    String response,
  ) async {
    await client.rpc<dynamic>(
      'resolve_appeal',
      params: {
        'appeal_id': appealId,
        'decision': decision,
        'response': response.trim(),
      },
    );
  }

  Future<void> accountAction(
    String userId,
    String action,
    String reason,
  ) async {
    await client.rpc<dynamic>(
      'admin_account',
      params: {'user_id': userId, 'action': action, 'reason': reason.trim()},
    );
  }

  Future<void> adjustTrust(String userId, double score, String reason) async {
    await client.rpc<dynamic>(
      'adjust_trust',
      params: {'user_id': userId, 'score': score, 'reason': reason.trim()},
    );
  }

  Future<void> adjustPoints(String userId, int points, String reason) async {
    await client.rpc<dynamic>(
      'adjust_points',
      params: {'user_id': userId, 'points': points, 'reason': reason.trim()},
    );
  }

  Future<void> reviewWithdrawal({
    required String withdrawalId,
    required String decision,
    required String note,
    String? paymentReference,
  }) async {
    await client.rpc<dynamic>(
      'review_withdrawal',
      params: {
        'withdrawal_id': withdrawalId,
        'decision': decision,
        'note': note.trim(),
        'payment_reference_input': paymentReference?.trim().isEmpty == true
            ? null
            : paymentReference?.trim(),
      },
    );
  }

  Future<void> adjustWallet(String userId, double amount, String reason) async {
    await client.rpc<dynamic>(
      'adjust_wallet',
      params: {'user_id': userId, 'amount': amount, 'reason': reason.trim()},
    );
  }

  Future<void> addCategory(String name) async {
    final clean = name.trim();
    final slug = clean
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (clean.isEmpty || slug.isEmpty)
      throw Exception('Enter a valid category name.');
    await client.from('categories').insert({'name': clean, 'slug': slug});
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await client.from('settings').update({'value': value}).eq('key', key);
  }

  Future<List<LocationRow>> countries() => locations.countries();

  Future<List<LocationRow>> regions(String countryId) =>
      locations.regions(countryId);

  Future<List<LocationRow>> cities(String countryId, String regionId) =>
      locations.cities(countryId: countryId, regionId: regionId);

  Future<void> addCity({
    required String name,
    required String countryId,
    String? regionId,
    String? timezone,
    required double latitude,
    required double longitude,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || countryId.isEmpty) {
      throw Exception('City name and country are required.');
    }
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw Exception('Enter valid latitude and longitude coordinates.');
    }
    final base = clean
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final suffix = _random
        .nextInt(0xffffffff)
        .toRadixString(16)
        .padLeft(8, '0');
    await client.from('cities').insert({
      'name': clean,
      'slug': '${base.isEmpty ? 'city' : base}-$suffix',
      'country_id': countryId,
      'region_id': regionId?.isEmpty == true ? null : regionId,
      'timezone': timezone?.trim().isEmpty == true ? null : timezone?.trim(),
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  Future<Map<String, String>> _profileNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = _rows(
      await client
          .from('profiles')
          .select('id,full_name')
          .inFilter('id', ids.toList()),
    );
    return {
      for (final row in rows)
        _text(row['id']): _text(row['full_name'], fallback: 'Unknown user'),
    };
  }

  int _count(dynamic value, Set<String> statuses) => _rows(
    value,
  ).where((row) => statuses.contains(row['status']?.toString())).length;
}

List<Map<String, dynamic>> _rows(dynamic value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((row) => Map<String, dynamic>.from(row))
    .toList(growable: false);

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullable(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _number(dynamic value) => switch (value) {
  num number => number.toDouble(),
  _ => double.tryParse(value?.toString() ?? '') ?? 0,
};

DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _optionalDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
