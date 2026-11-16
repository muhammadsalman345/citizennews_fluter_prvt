import '../../news/domain/news_models.dart';

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.status,
    required this.requestedAt,
  });

  final String status;
  final DateTime? requestedAt;

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) =>
      AccountDeletionRequest(
        status: json['status']?.toString() ?? '',
        requestedAt: DateTime.tryParse(
          json['requested_at']?.toString() ?? '',
        ),
      );
}

class AccountFollow {
  const AccountFollow({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.label,
    this.username,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String label;
  final String? username;
}

class AccountFollowingData {
  const AccountFollowingData({
    required this.follows,
    required this.stories,
  });

  final List<AccountFollow> follows;
  final List<NewsSummary> stories;
}

class AccountComment {
  const AccountComment({
    required this.id,
    required this.postId,
    required this.body,
    required this.createdAt,
    this.headline,
    this.slug,
  });

  final String id;
  final String postId;
  final String body;
  final DateTime? createdAt;
  final String? headline;
  final String? slug;
}

class AccountAppeal {
  const AccountAppeal({
    required this.id,
    required this.reason,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminResponse,
    this.postId,
    this.verificationId,
  });

  final String id;
  final String reason;
  final String message;
  final String status;
  final String? adminResponse;
  final String? postId;
  final String? verificationId;
  final DateTime? createdAt;

  factory AccountAppeal.fromJson(Map<String, dynamic> json) => AccountAppeal(
    id: json['id']?.toString() ?? '',
    reason: json['reason']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    adminResponse: json['admin_response']?.toString(),
    postId: json['post_id']?.toString(),
    verificationId: json['verification_id']?.toString(),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );
}

class AccountReport {
  const AccountReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String reason;
  final String status;
  final String? note;
  final DateTime? createdAt;

  factory AccountReport.fromJson(Map<String, dynamic> json) => AccountReport(
    id: json['id']?.toString() ?? '',
    reason: json['reason']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    note: json['note']?.toString(),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
  );
}

class AccountAppealsData {
  const AccountAppealsData({
    required this.appeals,
    required this.reports,
    required this.canAppealVerification,
  });

  final List<AccountAppeal> appeals;
  final List<AccountReport> reports;
  final bool canAppealVerification;
}
