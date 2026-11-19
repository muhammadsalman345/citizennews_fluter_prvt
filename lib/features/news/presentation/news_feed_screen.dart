import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/ads/ad_widgets.dart';
import '../../../core/ads/ads_policy.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/network/network_controller.dart';
import '../../../core/network/network_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../location/presentation/location_scope.dart';
import '../data/news_repository.dart';
import '../data/feed_cache.dart';
import '../domain/news_models.dart';
import 'news_story_card.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({this.initialTab = 'latest', super.key});

  final String initialTab;

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final _search = TextEditingController();
  final _cache = const FeedCache();
  NewsRepository? _repository;
  NetworkController? _network;
  List<NewsCategory> _categories = const [];
  List<NewsSummary> _news = const [];
  final Map<String, int> _reactions = {};
  final Map<String, bool> _savedStories = {};
  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _dislikeDeltas = {};
  final Set<String> _busyStories = {};
  late String _tab;
  String _category = '';
  int _page = 0;
  bool _initialized = false;
  bool _loading = true;
  bool _more = false;
  bool _wasOnline = true;
  String? _error;
  String? _cacheMessage;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
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
    _repository = NewsRepository(client);
    _network = NetworkScope.read(context);
    _wasOnline = _network!.online;
    _network!.addListener(_handleNetworkChange);
    _initialize();
  }

  @override
  void dispose() {
    _network?.removeListener(_handleNetworkChange);
    _search.dispose();
    super.dispose();
  }

  void _handleNetworkChange() {
    final online = _network?.online ?? true;
    final reconnected = !_wasOnline && online;
    _wasOnline = online;
    if (reconnected && mounted && !_loading && _repository != null) {
      unawaited(_load());
    }
  }

  Future<void> _initialize() async {
    try {
      final categories = await _repository!.categories();
      if (mounted) setState(() => _categories = categories);
    } catch (error) {
      // A category failure must not prevent a cached feed from opening.
      if (mounted && !(_network?.offline ?? false)) {
        setState(() => _error = AppError.message(error));
      }
    }
    await _load();
  }

  Future<void> _load({bool append = false}) async {
    final location = LocationScope.read(context);
    final query = _search.text.trim();
    final city = _tab == 'nearby' ? location.cityId : '';
    final country = _tab == 'worldwide' ? '' : location.countryId;
    final region = _tab == 'nearby' ? location.regionId : '';
    final cacheable = !append && query.isEmpty && _tab != 'following';
    final cacheKey = FeedCache.key(
      tab: _tab,
      city: city,
      country: country,
      region: region,
      category: _category,
    );
    setState(() {
      _loading = true;
      _error = null;
      _cacheMessage = null;
      if (!append) _page = 0;
    });
    try {
      if (_network?.offline ?? false) {
        if (append) {
          if (_page > 0) _page--;
          if (mounted) {
            setState(
              () => _error = 'Connect to the internet to load more stories.',
            );
          }
          return;
        }
        final cached = cacheable ? await _cache.read(cacheKey) : null;
        if (!mounted) return;
        if (cached?.isNotEmpty == true) {
          setState(() {
            _news = cached!;
            _more = false;
            _cacheMessage = 'Showing saved stories from this device.';
          });
        } else {
          setState(() {
            _news = const [];
            _more = false;
            _error = 'No saved stories are available for this feed.';
          });
        }
        return;
      }
      final rows = await _repository!.search(
        query: query,
        city: city,
        country: country,
        region: region,
        category: _category,
        tab: _tab,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _news = append ? [..._news, ...rows] : rows;
        _more = rows.length == 12;
        if (!append) {
          _reactions.clear();
          _savedStories.clear();
          _likeDeltas.clear();
          _dislikeDeltas.clear();
          _busyStories.clear();
        }
      });
      unawaited(_hydrateInteractions(rows));
      if (cacheable) unawaited(_cache.write(cacheKey, rows));
    } catch (error) {
      if (append && _page > 0) _page--;
      final cached = cacheable ? await _cache.read(cacheKey) : null;
      if (!mounted) return;
      if (cached?.isNotEmpty == true) {
        setState(() {
          _news = cached!;
          _more = false;
          _cacheMessage = 'Could not refresh. Showing saved stories.';
        });
      } else {
        setState(() => _error = AppError.message(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    _page++;
    await _load(append: true);
  }

  Future<void> _hydrateInteractions(List<NewsSummary> stories) async {
    if (stories.isEmpty || !AuthScope.read(context).isSignedIn) return;
    final repository = _repository;
    if (repository == null) return;

    final states = await Future.wait(
      stories.map((story) async {
        try {
          final values = await Future.wait<dynamic>([
            repository.currentReaction(story.id),
            repository.isBookmarked(story.id),
          ]);
          return (
            id: story.id,
            reaction: values[0] as int,
            saved: values[1] as bool,
          );
        } catch (_) {
          // Feed remains usable if an individual interaction cannot be loaded.
          return null;
        }
      }),
    );
    if (!mounted) return;

    final visibleIds = _news.map((story) => story.id).toSet();
    setState(() {
      for (final state in states) {
        if (state == null || !visibleIds.contains(state.id)) continue;
        _reactions.putIfAbsent(state.id, () => state.reaction);
        _savedStories.putIfAbsent(state.id, () => state.saved);
      }
    });
  }

  bool _requireSignIn(NewsSummary story) {
    if (AuthScope.read(context).isSignedIn) return true;
    context.go(
      '/login?returnTo=${Uri.encodeQueryComponent('/news/${story.slug}')}',
    );
    return false;
  }

  Future<void> _react(NewsSummary story, int value) async {
    if (!_requireSignIn(story) || _busyStories.contains(story.id)) return;
    setState(() => _busyStories.add(story.id));
    try {
      final current = _reactions[story.id] ??
          await _repository!.currentReaction(story.id);
      final next = current == value ? 0 : value;
      await _repository!.react(story.id, next);
      if (!mounted) return;
      setState(() {
        _reactions[story.id] = next;
        var likes = _likeDeltas[story.id] ?? 0;
        var dislikes = _dislikeDeltas[story.id] ?? 0;
        if (current == 1) likes--;
        if (current == -1) dislikes--;
        if (next == 1) likes++;
        if (next == -1) dislikes++;
        _likeDeltas[story.id] = likes;
        _dislikeDeltas[story.id] = dislikes;
      });
    } catch (error) {
      _message(AppError.message(error), danger: true);
    } finally {
      if (mounted) setState(() => _busyStories.remove(story.id));
    }
  }

  Future<void> _toggleSave(NewsSummary story) async {
    if (!_requireSignIn(story) || _busyStories.contains(story.id)) return;
    setState(() => _busyStories.add(story.id));
    try {
      final current = _savedStories[story.id] ??
          await _repository!.isBookmarked(story.id);
      await _repository!.setBookmark(story.id, !current);
      if (!mounted) return;
      setState(() => _savedStories[story.id] = !current);
      _message(current ? 'Removed from saved stories.' : 'Story saved.');
    } catch (error) {
      _message(AppError.message(error), danger: true);
    } finally {
      if (mounted) setState(() => _busyStories.remove(story.id));
    }
  }

  Future<void> _share(NewsSummary story) async {
    await Clipboard.setData(
      ClipboardData(text: '${story.headline}\n/news/${story.slug}'),
    );
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

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            mobile ? 14 : 36,
            20,
            mobile ? 14 : 36,
            90,
          ),
          children: [
            _FeedHeader(
              tab: _tab,
              locationLabel: location.selectedLabel,
            ),
            const SizedBox(height: 18),
            _FeedTabs(
              selected: _tab,
              onSelected: (tab) {
                setState(() => _tab = tab);
                _load();
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paper,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 9,
                runSpacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: mobile ? double.infinity : 360,
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText: 'Search news, places or topics',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Search',
                          onPressed: _load,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                  ),
                  if (_tab != 'worldwide')
                    OutlinedButton.icon(
                      onPressed: location.detecting
                          ? null
                          : () async {
                              await location.detectCurrentLocation();
                              await _load();
                            },
                      icon: location.detecting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(
                        location.selectedLabel.isEmpty
                            ? 'Use my location'
                            : location.selectedLabel,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/explore'),
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: const Text('Explore places'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'All news',
                    selected: _category.isEmpty,
                    onTap: () {
                      setState(() => _category = '');
                      _load();
                    },
                  ),
                  for (final category in _categories)
                    _CategoryChip(
                      label: category.name,
                      selected: _category == category.id,
                      onTap: () {
                        context.push(
                          '/category/${Uri.encodeComponent(category.slug)}',
                        );
                      },
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 15),
              _FeedError(message: _error!, retry: _load),
            ],
            if (_cacheMessage != null) ...[
              const SizedBox(height: 15),
              _CachedFeedNotice(message: _cacheMessage!),
            ],
            const SizedBox(height: 18),
            if (_loading && _news.isEmpty)
              const _FeedLoading()
            else if (_news.isEmpty)
              _EmptyFeed(
                nearby: _tab == 'nearby',
                chooseCity: () => context.go('/explore'),
              )
            else ...[
              for (var index = 0; index < _news.length; index++) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: NewsStoryCard(
                      key: ValueKey('feed-story-${_news[index].id}'),
                      story: _news[index],
                      reaction: _reactions[_news[index].id] ?? 0,
                      saved: _savedStories[_news[index].id] ?? false,
                      busy: _busyStories.contains(_news[index].id),
                      likeCount:
                          _news[index].likes +
                          (_likeDeltas[_news[index].id] ?? 0),
                      dislikeCount:
                          _news[index].dislikes +
                          (_dislikeDeltas[_news[index].id] ?? 0),
                      onLike: () => _react(_news[index], 1),
                      onDislike: () => _react(_news[index], -1),
                      onComment: () =>
                          context.push('/news/${_news[index].slug}'),
                      onSave: () => _toggleSave(_news[index]),
                      onShare: () => _share(_news[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (AdsPolicy.canShowNativeAfter(_news, index)) ...[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: CitizenNativeAd(
                        key: ValueKey('home-feed-ad-${(index + 1) ~/ 3}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              if (_more)
                Center(
                  child: SizedBox(
                    width: 280,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _loadMore,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _loading ? 'Loading stories...' : 'Load more stories',
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.tab, required this.locationLabel});

  final String tab;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    final title = switch (tab) {
      'trending' => 'What people are reading',
      'nearby' => 'News around you',
      'following' => 'From people you follow',
      'worldwide' => 'News from around the world',
      _ => 'Latest stories',
    };
    final subtitle = switch (tab) {
      'trending' => 'Popular reporting and conversations right now.',
      'nearby' when locationLabel.isNotEmpty => locationLabel,
      'nearby' => 'Choose a city for a more relevant local feed.',
      'following' => 'Updates from followed reporters, places and topics.',
      'worldwide' => 'Fresh reporting across countries and communities.',
      _ => 'Fresh reporting from verified community reporters.',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.red,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CITIZENNEWS FEED',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        children: [
          for (var index = 0; index < 2; index++) ...[
            Container(
              height: 360,
              decoration: BoxDecoration(
                color: AppColors.paper,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ),
  );
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const tabs = [
    ('latest', 'Latest', Icons.schedule_rounded),
    ('trending', 'Trending', Icons.local_fire_department_rounded),
    ('nearby', 'For you', Icons.near_me_rounded),
    ('following', 'Following', Icons.people_alt_outlined),
    ('worldwide', 'World', Icons.public_rounded),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.paper,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _FeedTabButton(
                label: tab.$2,
                icon: tab.$3,
                selected: selected == tab.$1,
                onTap: () => onSelected(tab.$1),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FeedTabButton extends StatelessWidget {
  const _FeedTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.red : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.nearby, required this.chooseCity});
  final bool nearby;
  final VoidCallback chooseCity;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        children: [
          const Icon(
            Icons.location_searching_rounded,
            size: 42,
            color: AppColors.red,
          ),
          const SizedBox(height: 12),
          Text(
            nearby ? 'No nearby stories yet' : 'No stories found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (nearby)
            OutlinedButton(
              onPressed: chooseCity,
              child: const Text('Choose another city'),
            ),
        ],
      ),
    ),
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline_rounded, color: AppColors.red),
      title: Text(message),
      trailing: TextButton(onPressed: retry, child: const Text('Retry')),
    ),
  );
}

class _CachedFeedNotice extends StatelessWidget {
  const _CachedFeedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: ListTile(
      leading: const Icon(Icons.offline_pin_rounded, color: AppColors.red),
      title: Text(message),
    ),
  );
}
