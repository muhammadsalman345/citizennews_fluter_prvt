class GovernmentIdType {
  const GovernmentIdType({
    required this.type,
    required this.label,
    required this.requiresBack,
  });

  final String type;
  final String label;
  final bool requiresBack;

  factory GovernmentIdType.fromJson(Map<String, dynamic> json) =>
      GovernmentIdType(
        type: json['type']?.toString() ?? '',
        label: json['label']?.toString() ?? json['type']?.toString() ?? '',
        requiresBack: json['requires_back'] as bool? ?? true,
      );
}

class IdentityVerification {
  const IdentityVerification({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.frontPath,
    required this.backPath,
    required this.selfiePath,
    required this.countryId,
    required this.cityId,
    required this.status,
    required this.createdAt,
    this.dateOfBirth,
    this.reason,
    this.note,
  });

  final String id;
  final String userId;
  final String documentType;
  final String frontPath;
  final String backPath;
  final String selfiePath;
  final String countryId;
  final String cityId;
  final String status;
  final DateTime createdAt;
  final DateTime? dateOfBirth;
  final String? reason;
  final String? note;

  factory IdentityVerification.fromJson(Map<String, dynamic> json) =>
      IdentityVerification(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        documentType: json['document_type']?.toString() ?? '',
        frontPath: json['front_path']?.toString() ?? '',
        backPath: json['back_path']?.toString() ?? '',
        selfiePath: json['selfie_path']?.toString() ?? '',
        countryId: json['country_id']?.toString() ?? '',
        cityId: json['city_id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        dateOfBirth: DateTime.tryParse(json['date_of_birth']?.toString() ?? ''),
        reason: json['reason'] as String?,
        note: json['note'] as String?,
      );
}

class VerificationReviewContext {
  const VerificationReviewContext({
    required this.values,
    required this.attempts,
  });

  final Map<String, dynamic> values;
  final List<Map<String, dynamic>> attempts;

  factory VerificationReviewContext.fromJson(Map<String, dynamic> json) {
    final rawAttempts = json['attempts'] as List? ?? const [];
    return VerificationReviewContext(
      values: Map.unmodifiable({...json}..remove('attempts')),
      attempts: rawAttempts
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );
  }
}
