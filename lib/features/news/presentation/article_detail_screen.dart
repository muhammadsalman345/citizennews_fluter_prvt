import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ads/ad_widgets.dart';
import '../../../core/ads/ads_policy.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/seo/seo_builders.dart';
import '../../../core/seo/seo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../data/news_repository.dart';
import '../domain/news_models.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({required this.slug, super.key});
  final String slug;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  static const reportReasons = [
    'Fake / Misleading',
    'Wrong Location',
    'Old News',
    'Graphic Content',
    'Personal Information',
    'Spam',
    'Hate/Harassment',
    'Other',
  ];

  final _comment = TextEditingController();
  final _gallery = PageController();
  final _commentsKey = GlobalKey();
  NewsRepository? _repository;
  NewsArticle? _article;
  List<NewsComment> _comments = const [];
  List<CorrectionEntry> _history = const [];
  String? _replyTo;
  int _reaction = 0;
  int _image = 0;
  bool _saved = false;
  bool _following = false;
  bool _loading = true;
  bool _busy = false;
  bool _initialized = false;
  String? _error;
  String? _commentsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final client = AuthScope.read(context).service.client;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = 'Supabase is not configured.';
      });
      return;
    }
    _repository = NewsRepository(client);
    _load();
  }

  @override
  void didUpdateWidget(covariant ArticleDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug && _repository != null) {
      _article = null;
      _comments = const [];
      _history = const [];
      _load();
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    _gallery.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final article = await _repository!.article(widget.slug);
      if (article == null) throw Exception('This story was not found.');
      final signedIn = AuthScope.read(context).isSignedIn;
      final results = await Future.wait<dynamic>([
        _repository!.comments(article.summary.id),
        _repository!
            .correctionHistory(article.summary.slug)
            .catchError((_) => <CorrectionEntry>[]),
        if (signedIn)
          _repository!.currentReaction(article.summary.id)
        else
          Future.value(0),
        if (signedIn)
          _repository!.isBookmarked(article.summary.id)
        else
          Future.value(false),
        if (signedIn)
          _repository!.isFollowingReporter(article.summary.reporterId)
        else
          Future.value(false),
      ]);
      if (!mounted) return;
      setState(() {
        _article = article;
        _comments = results[0] as List<NewsComment>;
        _history = results[1] as List<CorrectionEntry>;
        _reaction = results[2] as int;
        _saved = results[3] as bool;
        _following = results[4] as bool;
        _commentsError = null;
      });
      SeoService.apply(articleSeo(article));
      _recordView(article.summary.id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = AppError.message(error));
        SeoService.apply(
          noIndexSeo('/news/${Uri.encodeComponent(widget.slug)}'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recordView(String postId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      var key = preferences.getString('citizennews.view.session');
      if (key == null) {
        key =
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
        await preferences.setString('citizennews.view.session', key);
      }
      final day = DateTime.now().toUtc().toIso8601String().split('T').first;
      final recorded =
          preferences.getBool('citizennews.view.$postId.$day') ?? false;
      if (!recorded) {
        await _repository!.recordView(postId, key);
        await preferences.setBool('citizennews.view.$postId.$day', true);
      }
    } catch (_) {
      // View tracking must never prevent the public article from opening.
    }
  }

  bool _requireSignIn() {
    if (AuthScope.read(context).isSignedIn) return true;
    context.go(
      '/login?returnTo=${Uri.encodeQueryComponent('/news/${widget.slug}')}',
    );
    return false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(AppError.message(error), danger: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _react(int value) async {
    if (!_requireSignIn()) return;
    await _run(() async {
      final next = _reaction == value ? 0 : value;
      await _repository!.react(_article!.summary.id, next);
      setState(() => _reaction = next);
      await _refreshArticle();
    });
  }

  Future<void> _bookmark() async {
    if (!_requireSignIn()) return;
    await _run(() async {
      await _repository!.setBookmark(_article!.summary.id, !_saved);
      setState(() => _saved = !_saved);
      _message(_saved ? 'Story saved.' : 'Story removed from saved items.');
    });
  }

  Future<void> _follow() async {
    if (!_requireSignIn()) return;
    await _run(() async {
      await _repository!.setReporterFollow(
        _article!.summary.reporterId,
        !_following,
      );
      setState(() => _following = !_following);
    });
  }

  Future<void> _refreshArticle() async {
    final latest = await _repository!.article(widget.slug);
    if (mounted && latest != null) setState(() => _article = latest);
  }

  Future<void> _sendComment() async {
    if (!_requireSignIn() || _comment.text.trim().isEmpty) return;
    await _run(() async {
      await _repository!.addComment(
        _article!.summary.id,
        _comment.text,
        parentId: _replyTo,
      );
      _comment.clear();
      setState(() => _replyTo = null);
      await _reloadComments();
      await _refreshArticle();
    });
  }

  Future<void> _reloadComments() async {
    try {
      final rows = await _repository!.comments(_article!.summary.id);
      if (mounted) {
        setState(() {
          _comments = rows;
          _commentsError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _commentsError = AppError.message(error));
    }
  }

  Future<void> _deleteComment(NewsComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await _repository!.deleteComment(comment.id);
      await _reloadComments();
      await _refreshArticle();
    });
  }

  Future<void> _reportStory() async {
    if (!_requireSignIn()) return;
    final report = await _reportDialog('Report this story');
    if (report == null) return;
    await _run(() async {
      await _repository!.reportStory(
        _article!.summary.id,
        report.$1,
        report.$2,
      );
      _message('Report submitted for admin review.');
    });
  }

  Future<void> _reportComment(NewsComment comment) async {
    if (!_requireSignIn()) return;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report comment'),
        content: TextField(
          controller: controller,
          maxLength: 2000,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What is wrong with this comment?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || note.isEmpty) return;
    await _run(() async {
      await _repository!.reportComment(comment.id, note);
      _message('Comment report submitted.');
    });
  }

  Future<(String, String)?> _reportDialog(String title) async {
    var reason = reportReasons.first;
    final note = TextEditingController();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                items: [
                  for (final item in reportReasons)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) =>
                    setDialogState(() => reason = value ?? reason),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLength: 2000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional details',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, (reason, note.text.trim())),
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    return result;
  }

  Future<void> _share() async {
    final article = _article!;
    final text = '${article.summary.headline}\n/news/${article.summary.slug}';
    await Clipboard.setData(ClipboardData(text: text));
    _message('Story link copied.');
  }

  void _message(String text, {bool danger = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: danger ? AppColors.redDark : AppColors.ink,
      ),
    );
  }

  void _scrollToComments() {
    final commentsContext = _commentsKey.currentContext;
    if (commentsContext == null) return;
    Scrollable.ensureVisible(
      commentsContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .05,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _article == null) {
      return _ArticleError(message: _error ?? 'Story not found.', retry: _load);
    }
    final article = _article!;
    final story = article.summary;
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      top: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 36,
          20,
          mobile ? 14 : 36,
          100,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 9,
                    runSpacing: 8,
                    children: [
                      _ArticleTag(
                        label: story.category.toUpperCase(),
                        color: AppColors.red,
                        onTap: story.categorySlug?.isNotEmpty == true
                            ? () => context.push(
                                '/category/${Uri.encodeComponent(story.categorySlug!)}',
                              )
                            : null,
                      ),
                      _ArticleTag(
                        label: story.city,
                        color: AppColors.focus,
                        onTap:
                            story.countrySlug?.isNotEmpty == true &&
                                story.citySlug?.isNotEmpty == true
                            ? () => context.push(
                                '/city/${Uri.encodeComponent(story.countrySlug!)}/${Uri.encodeComponent(story.citySlug!)}',
                              )
                            : null,
                      ),
                      if (story.breaking)
                        const _ArticleTag(
                          label: 'BREAKING',
                          color: AppColors.red,
                        ),
                      if (story.corrected)
                        const _ArticleTag(
                          label: 'CORRECTED',
                          color: AppColors.focus,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    story.headline,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: mobile ? 34 : 50,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    story.summary,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.55,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _articleByline(story),
                  if (article.images.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _galleryView(article),
                  ],
                  const SizedBox(height: 14),
                  _actions(story),
                  if (article.correctionNote?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    _CorrectionNotice(note: article.correctionNote!),
                  ],
                  const SizedBox(height: 22),
                  _ArticleBody(body: article.body),
                  if (AdsPolicy.isAdSafeStory(story)) ...[
                    const SizedBox(height: 22),
                    const CitizenBannerAd(),
                  ],
                  if (article.source.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoBox(label: 'Source / evidence', value: article.source),
                  ],
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text('Correction history'),
                      children: [
                        for (final item in _history)
                          ListTile(
                            title: Text(item.note),
                            subtitle: Text(_date(item.reviewedAt)),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _reporterCard(story),
                  const SizedBox(height: 30),
                  Row(
                    key: _commentsKey,
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: AppColors.red,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Conversation',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      Text(
                        '${story.comments} comments',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _commentComposer(),
                  if (_commentsError != null) ...[
                    const SizedBox(height: 10),
                    _InfoBox(
                      label: 'Comments unavailable',
                      value: _commentsError!,
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_comments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No comments yet. Start the conversation.'),
                      ),
                    )
                  else
                    ..._commentWidgets(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _articleByline(NewsSummary story) => Row(
    children: [
      InkWell(
        customBorder: const CircleBorder(),
        onTap: story.username.isEmpty
            ? null
            : () => context.push(
                '/reporter/${Uri.encodeComponent(story.username)}',
              ),
        child: CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.surface,
          backgroundImage: story.avatarUrl?.isNotEmpty == true
              ? NetworkImage(story.avatarUrl!)
              : null,
          child: story.avatarUrl?.isNotEmpty == true
              ? null
              : Text(
                  story.fullName.isEmpty ? 'C' : story.fullName[0],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    story.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (story.verified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: AppColors.focus,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_date(story.publishedAt)} · ${story.views} views',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Share story',
        onPressed: _share,
        icon: const Icon(Icons.ios_share_rounded),
      ),
    ],
  );

  Widget _galleryView(NewsArticle article) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      children: [
        PageView.builder(
          controller: _gallery,
          itemCount: article.images.length,
          onPageChanged: (value) => setState(() => _image = value),
          itemBuilder: (context, index) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              article.images[index],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surface,
                child: Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
        ),
        if (article.images.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: Chip(
              label: Text('${_image + 1} / ${article.images.length}'),
            ),
          ),
      ],
    ),
  );

  Widget _reporterCard(NewsSummary story) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.surface,
            backgroundImage: story.avatarUrl?.isNotEmpty != true
                ? null
                : NetworkImage(story.avatarUrl!),
            child: story.avatarUrl?.isNotEmpty != true
                ? Text(
                    story.fullName.isEmpty ? 'C' : story.fullName[0],
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  )
                : null,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: story.username.isEmpty
                      ? null
                      : () => context.push(
                          '/reporter/${Uri.encodeComponent(story.username)}',
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          story.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (story.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.focus,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${story.username} · Community reporter',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _follow,
            style: _following
                ? OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                  )
                : null,
            child: Text(_following ? 'Following' : 'Follow'),
          ),
        ],
      ),
    ),
  );

  Widget _actions(NewsSummary story) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionButton(
            icon: _reaction == 1
                ? Icons.thumb_up_rounded
                : Icons.thumb_up_outlined,
            label: '${story.likes}',
            selected: _reaction == 1,
            onTap: _busy ? null : () => _react(1),
          ),
          _ActionButton(
            icon: _reaction == -1
                ? Icons.thumb_down_rounded
                : Icons.thumb_down_outlined,
            label: '${story.dislikes}',
            selected: _reaction == -1,
            onTap: _busy ? null : () => _react(-1),
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: '${story.comments}',
            onTap: _scrollToComments,
          ),
          _ActionButton(
            icon: _saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            label: _saved ? 'Saved' : 'Save',
            selected: _saved,
            onTap: _busy ? null : _bookmark,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: _share,
          ),
          _ActionButton(
            icon: Icons.flag_outlined,
            label: 'Report',
            onTap: _busy ? null : _reportStory,
          ),
        ],
      ),
    ),
  );

  Widget _commentComposer() {
    final session = AuthScope.watch(context);
    if (!session.isSignedIn) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: _requireSignIn,
          child: const Text('Sign in to comment'),
        ),
      );
    }
    NewsComment? reply;
    for (final item in _comments) {
      if (item.id == _replyTo) {
        reply = item;
        break;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reply != null)
              Row(
                children: [
                  Expanded(child: Text('Replying to ${reply.fullName}')),
                  IconButton(
                    onPressed: () => setState(() => _replyTo = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            TextField(
              controller: _comment,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add a responsible, relevant comment...',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy ? null : _sendComment,
                child: Text(reply == null ? 'Post comment' : 'Post reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _commentWidgets() {
    final ids = _comments.map((item) => item.id).toSet();
    return _comments
        .map((comment) {
          final reply =
              comment.parentId != null && ids.contains(comment.parentId);
          final canDelete =
              comment.userId == AuthScope.read(context).user?.id ||
              AuthScope.read(context).isAdmin;
          return Padding(
            padding: EdgeInsets.only(left: reply ? 28 : 0, bottom: 9),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surface,
                          backgroundImage: comment.avatarUrl?.isNotEmpty == true
                              ? NetworkImage(comment.avatarUrl!)
                              : null,
                          child: comment.avatarUrl?.isNotEmpty == true
                              ? null
                              : Text(
                                  comment.fullName.isEmpty
                                      ? 'R'
                                      : comment.fullName[0],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _date(comment.createdAt),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      comment.body,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (AuthScope.read(context).isSignedIn)
                          TextButton(
                            onPressed: () =>
                                setState(() => _replyTo = comment.id),
                            child: const Text('Reply'),
                          ),
                        if (canDelete)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _deleteComment(comment),
                            child: const Text('Delete'),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _reportComment(comment),
                          child: const Text('Report'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  String _date(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ArticleTag extends StatelessWidget {
  const _ArticleTag({required this.label, required this.color, this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .45,
          ),
        ),
      ),
    ),
  );
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({required this.body});
  final Map<String, dynamic> body;

  @override
  Widget build(BuildContext context) {
    final content = body['content'] as List? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content
          .whereType<Map>()
          .map((raw) => _node(context, Map<String, dynamic>.from(raw)))
          .toList(),
    );
  }

  Widget _node(BuildContext context, Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? '';
    final children = (node['content'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (type == 'heading') {
      final level = ((node['attrs'] as Map?)?['level'] as num?)?.toInt() ?? 2;
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          _plain(children),
          style: level == 1
              ? Theme.of(context).textTheme.headlineLarge
              : Theme.of(context).textTheme.titleLarge,
        ),
      );
    }
    if (type == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.red, width: 4)),
        ),
        child: Text(
          _plain(children),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 17,
            height: 1.6,
          ),
        ),
      );
    }
    if (type == 'bulletList' || type == 'orderedList') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${type == 'orderedList' ? '${index + 1}.' : '•'} ${_plain([children[index]])}',
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
              ),
          ],
        ),
      );
    }
    if (type == 'horizontalRule') return const Divider(height: 32);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Text.rich(
        TextSpan(children: _spans(children)),
        style: const TextStyle(
          fontSize: 17,
          height: 1.72,
          color: AppColors.ink,
        ),
      ),
    );
  }

  List<InlineSpan> _spans(List<Map<String, dynamic>> nodes) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node['type'] == 'text') {
        var style = const TextStyle();
        for (final raw
            in (node['marks'] as List? ?? const []).whereType<Map>()) {
          final mark = raw['type']?.toString();
          if (mark == 'bold')
            style = style.merge(const TextStyle(fontWeight: FontWeight.w700));
          if (mark == 'italic')
            style = style.merge(const TextStyle(fontStyle: FontStyle.italic));
          if (mark == 'link')
            style = style.merge(
              const TextStyle(
                color: AppColors.focus,
                decoration: TextDecoration.underline,
              ),
            );
        }
        spans.add(TextSpan(text: node['text']?.toString() ?? '', style: style));
      } else if (node['type'] == 'hardBreak') {
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.addAll(
          _spans(
            (node['content'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
          ),
        );
      }
    }
    return spans;
  }

  String _plain(List<Map<String, dynamic>> nodes) => nodes
      .map((node) {
        if (node['type'] == 'text') return node['text']?.toString() ?? '';
        return _plain(
          (node['content'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      })
      .join(' ');
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 19),
    label: Text(label),
    style: TextButton.styleFrom(
      foregroundColor: selected ? AppColors.red : AppColors.muted,
      backgroundColor: selected
          ? AppColors.red.withValues(alpha: .07)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

class _CorrectionNotice extends StatelessWidget {
  const _CorrectionNotice({required this.note});
  final String note;
  @override
  Widget build(BuildContext context) =>
      _InfoBox(label: 'Corrected article', value: note);
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.focus.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.focus.withValues(alpha: .2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}

class _ArticleError extends StatelessWidget {
  const _ArticleError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 50,
            color: AppColors.red,
          ),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
