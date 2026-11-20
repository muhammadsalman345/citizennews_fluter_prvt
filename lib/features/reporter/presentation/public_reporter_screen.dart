import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/seo/seo_builders.dart';
import '../../../core/seo/seo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../news/presentation/news_story_card.dart';
import '../data/public_reporter_repository.dart';
import '../domain/public_reporter.dart';

class PublicReporterScreen extends StatefulWidget {
  const PublicReporterScreen({required this.username, super.key});

  final String username;

  @override
  State<PublicReporterScreen> createState() => _PublicReporterScreenState();
}

class _PublicReporterScreenState extends State<PublicReporterScreen> {
  PublicReporterRepository? _repository;
  PublicReporterData? _data;
  bool _initialized = false;
  bool _loading = true;
  bool _followBusy = false;
  String? _error;

  @override
  void didUpdateWidget(covariant PublicReporterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username && _repository != null) {
      _data = null;
      _load();
    }
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
    _repository = PublicReporterRepository(client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository!.load(widget.username);
      if (mounted) {
        if (data == null) {
          setState(() => _error = 'This reporter was not found.');
          SeoService.apply(
            noIndexSeo('/reporter/${Uri.encodeComponent(widget.username)}'),
          );
        } else {
          setState(() => _data = data);
          SeoService.apply(reporterSeo(data));
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = AppError.message(error));
        SeoService.apply(
          noIndexSeo('/reporter/${Uri.encodeComponent(widget.username)}'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final data = _data;
    if (data == null || _followBusy) return;
    final session = AuthScope.read(context);
    if (!session.isSignedIn) {
      context.go(
        Uri(
          path: '/login',
          queryParameters: {
            'returnTo': '/reporter/${Uri.encodeComponent(widget.username)}',
          },
        ).toString(),
      );
      return;
    }
    setState(() => _followBusy = true);
    try {
      await _repository!.setFollow(data.reporter.id, !data.followed);
      if (mounted) {
        final followed = !data.followed;
        final nextFollowers = followed
            ? data.stats.followers + 1
            : data.stats.followers > 0
            ? data.stats.followers - 1
            : 0;
        setState(
          () => _data = data.copyWith(
            followed: followed,
            stats: data.stats.copyWith(followers: nextFollowers),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data.followed
                  ? 'Reporter unfollowed.'
                  : 'Reporter added to following.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(error));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 36,
            24,
            mobile ? 14 : 36,
            90,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.contentMax,
                ),
                child: _body(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _data == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline_rounded),
          title: Text(_error!),
          trailing: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    }
    final data = _data;
    if (data == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.person_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Reporter not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/reporters'),
                child: const Text('Browse reporters'),
              ),
            ],
          ),
        ),
      );
    }
    final session = AuthScope.watch(context);
    final ownProfile = session.user?.id == data.reporter.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_error!),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 650;
                final avatar = CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.ink,
                  backgroundImage: data.reporter.avatarUrl?.isNotEmpty == true
                      ? NetworkImage(data.reporter.avatarUrl!)
                      : null,
                  child: data.reporter.avatarUrl?.isNotEmpty == true
                      ? null
                      : Text(
                          data.reporter.fullName.isEmpty
                              ? 'R'
                              : data.reporter.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                );
                final details = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CITIZEN REPORTER',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data.reporter.fullName,
                      textAlign: compact ? TextAlign.center : TextAlign.left,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      '@${data.reporter.username}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (data.reporter.cityName?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        data.reporter.cityName!,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    if (data.reporter.bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        data.reporter.bio,
                        textAlign: compact ? TextAlign.center : TextAlign.left,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: compact
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      children: [
                        if (!ownProfile)
                          FilledButton.icon(
                            onPressed: _followBusy ? null : _toggleFollow,
                            icon: Icon(
                              data.followed
                                  ? Icons.person_remove_outlined
                                  : Icons.person_add_alt_rounded,
                            ),
                            label: Text(
                              data.followed ? 'Unfollow' : 'Follow reporter',
                            ),
                          ),
                        if (!ownProfile && session.isSignedIn)
                          OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/messages/${data.reporter.id}'),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Message'),
                          ),
                        if (ownProfile)
                          OutlinedButton.icon(
                            onPressed: () => context.go('/account'),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit profile'),
                          ),
                      ],
                    ),
                  ],
                );
                return compact
                    ? Column(
                        children: [
                          avatar,
                          const SizedBox(height: 14),
                          details,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          avatar,
                          const SizedBox(width: 22),
                          Expanded(child: details),
                        ],
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatsGrid(stats: data.stats),
        const SizedBox(height: 22),
        Text(
          'Published stories',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        if (data.stories.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'This reporter has no published stories yet.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final story in data.stories) ...[
            NewsStoryCard(story: story),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final PublicReporterStats stats;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      _Metric(label: 'Published', value: '${stats.published}'),
      _Metric(label: 'Followers', value: '${stats.followers}'),
      _Metric(label: 'Views', value: '${stats.views}'),
      _Metric(label: 'Likes', value: '${stats.likes}'),
      _Metric(label: 'Rating', value: '${stats.rating} / 5'),
      _Metric(label: 'Trust', value: '${stats.trust} / 100'),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
}
