import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/reporter_stories_repository.dart';
import '../domain/reporter_story.dart';

class MyStoriesScreen extends StatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  State<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends State<MyStoriesScreen> {
  static const filters = [
    'all',
    'published',
    'pending',
    'changes_requested',
    'rejected',
    'archived',
    'expired',
  ];

  ReporterStoriesRepository? _repository;
  List<ReporterStory> _stories = const [];
  String _filter = 'all';
  String? _error;
  bool _initialized = false;
  bool _loading = true;

  List<ReporterStory> get _filtered => _stories.where((story) {
        if (_filter == 'all') return true;
        if (_filter == 'expired') return story.expired;
        return story.status == _filter;
      }).toList(growable: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      _loading = false;
      _error = 'Supabase is not configured.';
      return;
    }
    _repository = ReporterStoriesRepository(client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repository!.ownStories();
      if (mounted) setState(() => _stories = rows);
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appeal(ReporterStory story) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appeal editorial decision'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 2000,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Why should this decision be reviewed?',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit appeal'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || message.isEmpty) return;
    try {
      await _repository!.appeal(postId: story.id, message: message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appeal submitted for admin review.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 70),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.contentMax,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _StoryNotice(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filters.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 7),
                          itemBuilder: (context, index) {
                            final filter = filters[index];
                            return ChoiceChip(
                              label: Text(_label(filter)),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_filtered.isEmpty)
                        _empty()
                      else
                        for (final story in _filtered) ...[
                          _storyCard(story),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101826), Color(0xFF202D41)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Wrap(
          spacing: 18,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.library_books_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORTER NEWSROOM',
                    style: TextStyle(
                      color: Color(0xFFFF8A8A),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'My stories',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Track editorial status, update drafts and review the performance of your reporting.',
                    style: TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/dashboard'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF526175)),
                  ),
                  icon: const Icon(Icons.dashboard_outlined),
                  label: const Text('Dashboard'),
                ),
                FilledButton.icon(
                  onPressed: () => context.push('/report-news'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New story'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _storyCard(ReporterStory story) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _StatusChip(status: story.status),
                  if (story.breaking)
                    const Chip(
                      avatar: Icon(Icons.bolt_rounded, size: 17),
                      label: Text('Breaking'),
                    ),
                  if (story.expired) const Chip(label: Text('Expired job')),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                story.headline,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (story.summary.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  story.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 7),
              Text(
                'Updated ${_date(story.updatedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (story.jobDeadline != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Application deadline: ${story.jobDeadline} (${story.jobTimezone ?? 'UTC'})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (story.moderationReason?.isNotEmpty == true ||
                  story.moderationNote?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _StoryNotice(
                  message: [
                    story.moderationReason,
                    story.moderationNote,
                  ].whereType<String>().where((text) => text.isNotEmpty).join('\n'),
                  danger: story.status == 'rejected' ||
                      story.status == 'removed',
                ),
              ],
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (story.canEdit)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/report-news/edit/${story.id}'),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(
                        story.status == 'published' ||
                                story.status == 'corrected'
                            ? 'Submit correction'
                            : 'Make changes',
                      ),
                    ),
                  if (story.canView)
                    TextButton.icon(
                      onPressed: () => context.push('/news/${story.slug}'),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('View story'),
                    ),
                  if (story.canView)
                    TextButton.icon(
                      onPressed: () => context.push('/analytics/${story.id}'),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('Analytics'),
                    ),
                  if (story.canAppeal)
                    OutlinedButton.icon(
                      onPressed: () => _appeal(story),
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('Appeal'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _empty() => Card(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            children: [
              const Icon(Icons.article_outlined, size: 44),
              const SizedBox(height: 10),
              Text(
                'No stories in this status',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Submit verified local news to start your newsroom.'),
            ],
          ),
        ),
      );

  String _label(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  String _date(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'published' || 'corrected' => (AppColors.success, Icons.check_circle),
      'pending' => (AppColors.focus, Icons.schedule_rounded),
      'changes_requested' => (const Color(0xFFB66A00), Icons.edit_note_rounded),
      'rejected' || 'removed' => (AppColors.red, Icons.error_outline_rounded),
      'archived' => (AppColors.muted, Icons.archive_outlined),
      _ => (AppColors.muted, Icons.circle),
    };
    return Chip(
      avatar: Icon(
        icon,
        size: icon == Icons.circle ? 9 : 17,
        color: color,
      ),
      label: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      backgroundColor: color.withValues(alpha: .07),
      side: BorderSide(color: color.withValues(alpha: .2)),
    );
  }
}

class _StoryNotice extends StatelessWidget {
  const _StoryNotice({required this.message, this.danger = true});
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (danger ? AppColors.red : AppColors.focus)
              .withValues(alpha: .07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (danger ? AppColors.red : AppColors.focus)
                .withValues(alpha: .22),
          ),
        ),
        child: Text(message),
      );
}
