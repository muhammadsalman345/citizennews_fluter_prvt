import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/admin_repository.dart';
import 'admin_remaining_tabs.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({this.initialTab = 'overview', super.key});

  final String initialTab;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const tabs = [
    'overview',
    'verification',
    'news',
    'revisions',
    'reports',
    'chat-reports',
    'appeals',
    'users',
    'deletions',
    'withdrawals',
    'categories',
    'locations',
    'settings',
    'contact',
    'audit',
  ];

  AdminRepository? _repository;
  List<AdminVerificationItem> _queue = const [];
  List<AdminNewsItem> _newsQueue = const [];
  List<AdminRevisionItem> _revisions = const [];
  AdminVerificationItem? _selected;
  AdminVerificationReview? _review;
  AdminNewsItem? _selectedNews;
  AdminNewsReview? _newsReview;
  String _newsFilter = 'pending';
  String _newsQuery = '';
  String _revisionFilter = 'pending_review';
  late String _tab;
  bool _initialized = false;
  bool _loading = true;
  bool _busy = false;
  int _operationsRefresh = 0;
  String? _error;
  final _reason = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = tabs.contains(widget.initialTab) ? widget.initialTab : 'overview';
  }

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
    _repository = AdminRepository(client);
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repository!.verificationQueue(),
        _repository!.newsQueue(),
        _repository!.revisions(),
      ]);
      if (mounted) {
        setState(() {
          _queue = results[0] as List<AdminVerificationItem>;
          _newsQueue = results[1] as List<AdminNewsItem>;
          _revisions = results[2] as List<AdminRevisionItem>;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshWorkspace() async {
    setState(() => _operationsRefresh++);
    await _load();
  }

  void _selectTab(String tab) {
    if (!tabs.contains(tab)) return;
    setState(() {
      _tab = tab;
      _selected = null;
      _review = null;
      _selectedNews = null;
      _newsReview = null;
    });
  }

  Future<void> _inspect(AdminVerificationItem item) async {
    setState(() {
      _selected = item;
      _review = null;
      _busy = true;
      _error = null;
      _reason.text = item.verification.reason ?? '';
      _note.text = item.verification.note ?? '';
    });
    try {
      final review = await _repository!.inspect(item.verification);
      if (mounted && _selected?.verification.id == item.verification.id) {
        setState(() => _review = review);
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(String decision) async {
    final selected = _selected;
    if (selected == null || _busy) return;
    if (decision != 'approved' && _reason.text.trim().isEmpty) {
      setState(() => _error = 'A reason is required for this decision.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.moderateIdentity(
        verificationId: selected.verification.id,
        decision: decision,
        reason: _reason.text,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _selected = null;
        _review = null;
        _reason.clear();
        _note.clear();
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _inspectNews(AdminNewsItem item) async {
    setState(() {
      _selectedNews = item;
      _newsReview = null;
      _busy = true;
      _error = null;
      _reason.clear();
      _note.clear();
    });
    try {
      final review = await _repository!.inspectNews(item.id);
      if (mounted && _selectedNews?.id == item.id) {
        setState(() => _newsReview = review);
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moderateNews(String decision) async {
    final post = _selectedNews;
    if (post == null || _busy) return;
    if ((decision == 'rejected' || decision == 'removed') &&
        _reason.text.trim().isEmpty) {
      setState(() => _error = 'A reason is required for this decision.');
      return;
    }
    if (decision == 'changes_requested' && _note.text.trim().isEmpty) {
      setState(() => _error = 'Explain the changes the reporter must make.');
      return;
    }
    await _runNewsAction(
      () => _repository!.moderateNews(
        post: post,
        decision: decision,
        reason: _reason.text,
        note: _note.text,
      ),
    );
  }

  Future<void> _toggleBreaking() async {
    final post = _selectedNews;
    if (post == null || _reason.text.trim().isEmpty) {
      setState(
        () => _error = 'A reason is required to change breaking status.',
      );
      return;
    }
    await _runNewsAction(
      () => _repository!.setBreaking(
        postId: post.id,
        enabled: !post.breaking,
        reason: _reason.text,
      ),
    );
  }

  Future<void> _groupIncident() async {
    final post = _selectedNews;
    final review = _newsReview;
    if (post == null || review == null || review.duplicates.isEmpty) return;
    await _runNewsAction(
      () =>
          _repository!.groupIncident(post: post, duplicates: review.duplicates),
    );
  }

  Future<void> _deleteNews() async {
    final post = _selectedNews;
    if (post == null || _reason.text.trim().isEmpty) {
      setState(() => _error = 'A deletion reason is required.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete story?'),
        content: Text(
          'Delete “${post.headline}”? This super-admin action is audited and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runNewsAction(
      () => _repository!.deletePost(postId: post.id, reason: _reason.text),
    );
  }

  Future<void> _runNewsAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _selectedNews = null;
        _newsReview = null;
        _reason.clear();
        _note.clear();
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reviewRevision(
    AdminRevisionItem revision,
    String decision,
  ) async {
    String? reason;
    if (decision == 'rejected') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject correction'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Required rejection reason',
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
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.isEmpty) return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository!.reviewRevision(
        revisionId: revision.id,
        decision: decision,
        reason: reason,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthScope.watch(context);
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    final tabInfo = _adminTabInfo(_tab);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMax,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 12 : 28,
              24,
              mobile ? 12 : 28,
              80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminWorkspaceHeader(
                  superAdmin: session.isSuperAdmin,
                  loading: _loading,
                  onRefresh: _refreshWorkspace,
                ),
                const SizedBox(height: 12),
                _AdminTabNavigation(
                  tabs: tabs,
                  selected: _tab,
                  onSelected: _selectTab,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _AdminNotice(message: _error!),
                ],
                const SizedBox(height: 14),
                _AdminSectionHeader(info: tabInfo),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else
                  Expanded(child: _content()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_selected != null) return _reviewPanel();
    if (_selectedNews != null) return _newsReviewPanel();
    if (_tab == 'verification') return _verificationQueue();
    if (_tab == 'news') return _newsModerationQueue();
    if (_tab == 'revisions') return _revisionQueue();
    final session = AuthScope.read(context);
    return AdminRemainingTab(
      tab: _tab,
      refreshToken: _operationsRefresh,
      isSuperAdmin: session.isSuperAdmin,
      onOpenTab: _selectTab,
    );
  }

  Widget _verificationQueue() {
    final rows = _queue
        .where((item) => item.verification.status == 'pending')
        .toList();
    if (rows.isEmpty) {
      return const _AdminEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'Verification queue is clear',
        message: 'There are no pending identity verifications right now.',
      );
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final item = rows[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_search_outlined),
            ),
            title: Text(item.fullName),
            subtitle: Text(
              '@${item.username} - ${item.verification.documentType}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _inspect(item),
          ),
        );
      },
    );
  }

  Widget _newsModerationQueue() {
    final query = _newsQuery.trim().toLowerCase();
    final rows = _newsQueue
        .where((item) {
          final statusMatches =
              _newsFilter == 'all' || item.status == _newsFilter;
          final queryMatches =
              query.isEmpty ||
              item.headline.toLowerCase().contains(query) ||
              item.username.toLowerCase().contains(query) ||
              item.fullName.toLowerCase().contains(query);
          return statusMatches && queryMatches;
        })
        .toList(growable: false);
    return ListView(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Search headline or reporter',
          ),
          onChanged: (value) => setState(() => _newsQuery = value),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: const [
              'pending',
              'under_review',
              'changes_requested',
              'published',
              'rejected',
              'removed',
              'archived',
              'all',
            ].length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final status = const [
                'pending',
                'under_review',
                'changes_requested',
                'published',
                'rejected',
                'removed',
                'archived',
                'all',
              ][index];
              return ChoiceChip(
                label: Text(status.replaceAll('_', ' ')),
                selected: _newsFilter == status,
                onSelected: (_) => setState(() => _newsFilter = status),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _AdminEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No matching stories',
            message: 'Try another moderation status or search term.',
          )
        else
          for (final item in rows) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    item.status == 'pending'
                        ? Icons.hourglass_top_rounded
                        : Icons.article_outlined,
                  ),
                ),
                title: Text(item.headline),
                subtitle: Text(
                  '@${item.username} • ${item.status.replaceAll('_', ' ')} • '
                  '${item.accuracy.toStringAsFixed(0)} m GPS',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _inspectNews(item),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _newsReviewPanel() {
    final post = _selectedNews!;
    final review = _newsReview;
    final session = AuthScope.watch(context);
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _selectedNews = null;
                    _newsReview = null;
                  }),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('News queue'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(post.status.replaceAll('_', ' '))),
                    if (post.breaking)
                      const Chip(
                        avatar: Icon(Icons.bolt_rounded, size: 17),
                        label: Text('Breaking'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.headline,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('@${post.username} • ${post.fullName}'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('Rating ${post.rating.toStringAsFixed(1)}'),
                    ),
                    Chip(
                      label: Text(
                        'Trust ${post.trustScore.toStringAsFixed(0)} / 100',
                      ),
                    ),
                    Chip(label: Text('${post.followers} followers')),
                  ],
                ),
                const Divider(height: 26),
                if (_busy && review == null)
                  const Center(child: CircularProgressIndicator())
                else if (review != null) ...[
                  Text(
                    'Private photo evidence (${review.media.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (review.media.isEmpty)
                    const Text('This category was submitted without a photo.')
                  else
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: review.media.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final media = review.media[index];
                          return SizedBox(
                            width: 300,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.network(
                                      media.signedUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: AppColors.surface,
                                            child: Center(
                                              child: Text(
                                                'Private evidence unavailable.',
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                                Text(
                                  media.primary
                                      ? 'Primary evidence'
                                      : 'Additional evidence',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  _AdminNotice(
                    danger: false,
                    message:
                        'Exact evidence location: ${post.latitude}, ${post.longitude}\n'
                        'Accuracy: ${post.accuracy.toStringAsFixed(1)} m • '
                        'Captured: ${_adminDate(post.capturedAt)}\n'
                        'Media source: ${post.deviceMetadata['media_source'] ?? 'none'}\n'
                        'Risk flags: ${post.riskFlags.isEmpty ? 'none' : post.riskFlags.join(', ')}',
                  ),
                  const SizedBox(height: 10),
                  ExpansionTile(
                    title: const Text('Device metadata'),
                    children: [
                      SelectableText(post.deviceMetadata.toString()),
                      const SizedBox(height: 10),
                    ],
                  ),
                  if (review.duplicates.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _AdminNotice(
                      message: review.duplicates
                          .map(
                            (item) =>
                                '${item.headline} (${(item.similarity * 100).toStringAsFixed(0)}% similar)',
                          )
                          .join('\n'),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _groupIncident,
                        icon: const Icon(Icons.hub_outlined),
                        label: const Text('Group duplicate incident'),
                      ),
                    ),
                  ],
                  const Divider(height: 26),
                  Text(post.summary),
                  const SizedBox(height: 12),
                  SelectableText(
                    _adminBodyText(post.body),
                    style: const TextStyle(height: 1.55),
                  ),
                  if (post.source.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Source / evidence: ${post.source}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const Divider(height: 26),
                  TextField(
                    controller: _reason,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Decision reason',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _note,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Admin note / requested changes',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('published'),
                        icon: const Icon(Icons.publish_rounded),
                        label: const Text('Publish'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('under_review'),
                        child: const Text('Mark under review'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('changes_requested'),
                        child: const Text('Request changes'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('rejected'),
                        child: const Text('Reject'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('removed'),
                        child: const Text('Remove'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _moderateNews('archived'),
                        child: const Text('Archive'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _toggleBreaking,
                        icon: const Icon(Icons.bolt_rounded),
                        label: Text(
                          post.breaking
                              ? 'Remove breaking status'
                              : 'Mark breaking',
                        ),
                      ),
                      if (session.isSuperAdmin && post.status != 'removed')
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.redDark,
                          ),
                          onPressed: _busy ? null : _deleteNews,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: const Text('Delete permanently'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Publishing copies only reviewed private evidence into the public news-images bucket. Exact GPS and private evidence paths are never exposed to readers.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _revisionQueue() {
    final rows = _revisions
        .where(
          (item) => _revisionFilter == 'all' || item.status == _revisionFilter,
        )
        .toList(growable: false);
    return ListView(
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final status in const [
              'pending_review',
              'approved',
              'rejected',
              'all',
            ])
              ChoiceChip(
                label: Text(status.replaceAll('_', ' ')),
                selected: _revisionFilter == status,
                onSelected: (_) => setState(() => _revisionFilter = status),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(
              child: Text('No correction revisions in this status.'),
            ),
          )
        else
          for (final revision in rows) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        Chip(label: Text(revision.status.replaceAll('_', ' '))),
                        Chip(label: Text('Live: ${revision.postStatus}')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      revision.headline,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '@${revision.username} • ${revision.reporterName} • '
                      '${_adminDate(revision.createdAt)}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    _AdminNotice(
                      danger: false,
                      message:
                          'Reporter correction note:\n'
                          '${revision.correctionNote}',
                    ),
                    if (revision.jobDeadline != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Job deadline: ${revision.jobDeadline} '
                        '(${revision.jobTimezone ?? 'UTC'})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Compare live and proposed content'),
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 720;
                            final width = wide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: width,
                                  child: _RevisionVersion(
                                    label: 'Currently live',
                                    headline: revision.originalHeadline,
                                    summary: revision.originalSummary,
                                    body: _adminBodyText(revision.originalBody),
                                    source: revision.originalSource,
                                  ),
                                ),
                                SizedBox(
                                  width: width,
                                  child: _RevisionVersion(
                                    label: 'Proposed correction',
                                    headline: revision.headline,
                                    summary: revision.summary,
                                    body: _adminBodyText(revision.body),
                                    source: revision.source,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    if (revision.reason?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _AdminNotice(message: revision.reason!),
                    ],
                    if (revision.status == 'pending_review') ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewRevision(revision, 'approved'),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve correction'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewRevision(revision, 'rejected'),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject correction'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Approval updates the live story through review_revision and records a correction history entry. Until approval, the public article remains unchanged.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  String _adminBodyText(Map<String, dynamic> node) {
    if (node['type'] == 'text') return node['text']?.toString() ?? '';
    if (node['type'] == 'hardBreak') return '\n';
    final children = (node['content'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _adminBodyText(Map<String, dynamic>.from(item)))
        .where((text) => text.isNotEmpty)
        .toList(growable: false);
    final type = node['type']?.toString();
    if (type == 'bulletList') {
      return children.map((text) => '• $text').join('\n');
    }
    if (type == 'orderedList') {
      return [
        for (var index = 0; index < children.length; index++)
          '${index + 1}. ${children[index]}',
      ].join('\n');
    }
    if (type == 'doc') return children.join('\n\n');
    return children.join();
  }

  String _adminDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _reviewPanel() {
    final selected = _selected!;
    final review = _review;
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _selected = null;
                    _review = null;
                  }),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Verification queue'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  selected.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('@${selected.username}'),
                const SizedBox(height: 14),
                if (_busy && review == null)
                  const Center(child: CircularProgressIndicator())
                else if (review != null) ...[
                  _ContextGrid(values: review.context.values),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > 700
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _EvidenceImage(
                              label: 'ID front',
                              url: review.frontUrl,
                            ),
                          ),
                          if (review.backUrl != null)
                            SizedBox(
                              width: width,
                              child: _EvidenceImage(
                                label: 'ID back',
                                url: review.backUrl!,
                              ),
                            ),
                          SizedBox(
                            width: width,
                            child: _EvidenceImage(
                              label: 'Live selfie',
                              url: review.selfieUrl,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reason,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText:
                          'Decision reason (required for reject/suspend)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(labelText: 'Admin note'),
                  ),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _decide('approved'),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve reporter'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _decide('rejected'),
                        child: const Text('Reject'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _decide('suspended'),
                        child: const Text('Suspend'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class _AdminTabInfo {
  const _AdminTabInfo(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

_AdminTabInfo _adminTabInfo(String tab) => switch (tab) {
      'overview' => const _AdminTabInfo(
          'Overview',
          'Monitor priority queues and recent administrative activity.',
          Icons.space_dashboard_outlined,
        ),
      'verification' => const _AdminTabInfo(
          'Identity verification',
          'Review private identity evidence and reporter eligibility.',
          Icons.verified_user_outlined,
        ),
      'news' => const _AdminTabInfo(
          'News moderation',
          'Review submitted stories, evidence, risk flags and publication status.',
          Icons.fact_check_outlined,
        ),
      'revisions' => const _AdminTabInfo(
          'Corrections',
          'Compare published stories with reporter correction requests.',
          Icons.change_circle_outlined,
        ),
      'reports' => const _AdminTabInfo(
          'Content reports',
          'Investigate reader reports against stories and comments.',
          Icons.flag_outlined,
        ),
      'chat-reports' => const _AdminTabInfo(
          'Chat reports',
          'Review reported private messages and take account action.',
          Icons.report_gmailerrorred_outlined,
        ),
      'appeals' => const _AdminTabInfo(
          'Appeals',
          'Resolve editorial and identity-verification appeals.',
          Icons.gavel_outlined,
        ),
      'users' => const _AdminTabInfo(
          'Users',
          'Manage account access, trust, points and administrative roles.',
          Icons.manage_accounts_outlined,
        ),
      'deletions' => const _AdminTabInfo(
          'Deletion requests',
          'Review retained account deletion requests and their audit context.',
          Icons.person_remove_outlined,
        ),
      'withdrawals' => const _AdminTabInfo(
          'Withdrawals',
          'Review reporter payouts and audited wallet adjustments.',
          Icons.payments_outlined,
        ),
      'categories' => const _AdminTabInfo(
          'Categories',
          'Maintain the newsroom category directory.',
          Icons.category_outlined,
        ),
      'locations' => const _AdminTabInfo(
          'Locations',
          'Maintain countries, regions, cities and timezone data.',
          Icons.location_city_outlined,
        ),
      'settings' => const _AdminTabInfo(
          'System settings',
          'Update protected JSON configuration for the platform.',
          Icons.tune_rounded,
        ),
      'contact' => const _AdminTabInfo(
          'Contact inbox',
          'Read support, privacy and editorial messages from users.',
          Icons.contact_mail_outlined,
        ),
      'audit' => const _AdminTabInfo(
          'Audit log',
          'Review recorded administrative actions and their reasons.',
          Icons.history_rounded,
        ),
      _ => const _AdminTabInfo(
          'Administration',
          'Manage CitizenNews operations.',
          Icons.admin_panel_settings_outlined,
        ),
    };

class _AdminWorkspaceHeader extends StatelessWidget {
  const _AdminWorkspaceHeader({
    required this.superAdmin,
    required this.loading,
    required this.onRefresh,
  });

  final bool superAdmin;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101826), Color(0xFF26374D)],
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
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          superAdmin
                              ? 'SUPER ADMIN ACCESS'
                              : 'ADMIN ACCESS',
                          style: const TextStyle(
                            color: Color(0xFFFF8A8A),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Newsroom control center',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Moderation, safety, users and platform operations in one audited workspace.',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
                side: const BorderSide(color: Color(0xFF526175)),
              ),
              icon: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh workspace'),
            ),
          ],
        ),
      );
}

class _AdminTabNavigation extends StatelessWidget {
  const _AdminTabNavigation({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.paper,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 58,
          child: ListView.separated(
            padding: const EdgeInsets.all(6),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              final info = _adminTabInfo(tab);
              final active = selected == tab;
              return Material(
                color: active ? AppColors.red : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => onSelected(tab),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          info.icon,
                          size: 18,
                          color: active ? Colors.white : AppColors.muted,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          info.label,
                          style: TextStyle(
                            color: active ? Colors.white : AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _AdminSectionHeader extends StatelessWidget {
  const _AdminSectionHeader({required this.info});

  final _AdminTabInfo info;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, color: AppColors.red, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  info.description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.success, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _ContextGrid extends StatelessWidget {
  const _ContextGrid({required this.values});

  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final entry in values.entries)
        if (entry.value != null)
          Container(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 340),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(entry.value.toString()),
              ],
            ),
          ),
    ],
  );
}

class _RevisionVersion extends StatelessWidget {
  const _RevisionVersion({
    required this.label,
    required this.headline,
    required this.summary,
    required this.body,
    required this.source,
  });

  final String label;
  final String headline;
  final String summary;
  final String body;
  final String source;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.red,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(headline, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(summary, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 9),
        SelectableText(body, style: const TextStyle(height: 1.45)),
        if (source.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(
            'Source: $source',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    ),
  );
}

class _EvidenceImage extends StatelessWidget {
  const _EvidenceImage({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.network(
          url,
          height: 230,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 230,
            child: Center(child: Text('Private image could not be loaded.')),
          ),
        ),
      ),
    ],
  );
}

class _AdminNotice extends StatelessWidget {
  const _AdminNotice({required this.message, this.danger = true});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: (danger ? AppColors.red : AppColors.focus).withValues(alpha: .07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (danger ? AppColors.red : AppColors.focus).withValues(
          alpha: .25,
        ),
      ),
    ),
    child: Text(message),
  );
}
