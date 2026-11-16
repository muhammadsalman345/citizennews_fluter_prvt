class ReporterStory {
  const ReporterStory({
    required this.id,
    required this.slug,
    required this.headline,
    required this.summary,
    required this.status,
    required this.breaking,
    required this.categorySlug,
    required this.updatedAt,
    this.moderationReason,
    this.moderationNote,
    this.publishedAt,
    this.expiresAt,
    this.jobDeadline,
    this.jobTimezone,
  });

  final String id;
  final String slug;
  final String headline;
  final String summary;
  final String status;
  final bool breaking;
  final String categorySlug;
  final DateTime updatedAt;
  final String? moderationReason;
  final String? moderationNote;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String? jobDeadline;
  final String? jobTimezone;

  bool get isJob => categorySlug == 'jobs' || categorySlug.startsWith('jobs-');
  bool get expired {
    if (!isJob && jobDeadline == null) return false;
    return status == 'archived' ||
        jobDeadline == null ||
        expiresAt == null ||
        !expiresAt!.isAfter(DateTime.now().toUtc());
  }

  bool get canEdit => const {
        'changes_requested',
        'published',
        'corrected',
      }.contains(status);
  bool get canView => const {
        'published',
        'corrected',
        'archived',
      }.contains(status);
  bool get canAppeal => status == 'rejected' || status == 'removed';

  factory ReporterStory.fromJson(Map<String, dynamic> json) {
    final category = json['categories'] is Map
        ? Map<String, dynamic>.from(json['categories'] as Map)
        : const <String, dynamic>{};
    return ReporterStory(
      id: json['id'] as String,
      slug: json['slug']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      breaking: json['breaking'] as bool? ?? false,
      categorySlug: category['slug']?.toString() ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
      moderationReason: json['moderation_reason'] as String?,
      moderationNote: json['moderation_note'] as String?,
      publishedAt: _date(json['published_at']),
      expiresAt: _date(json['expires_at']),
      jobDeadline: json['job_deadline'] as String?,
      jobTimezone: json['job_timezone'] as String?,
    );
  }

  static DateTime? _date(dynamic value) => value == null
      ? null
      : DateTime.tryParse(value.toString())?.toUtc();
}
