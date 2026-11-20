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
import '../../../core/seo/seo_builders.dart';
import '../../../core/seo/seo_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_scope.dart';
import '../../location/data/location_repository.dart';
import '../../location/domain/location_models.dart';
import '../data/news_repository.dart';
import '../data/feed_cache.dart';
import '../domain/news_models.dart';
import 'news_story_card.dart';

enum ScopedFeedKind { country, region, city, category }

class ScopedNewsFeedScreen extends StatefulWidget {
  const ScopedNewsFeedScreen({
    required this.kind,
    required this.slug,
    this.countrySlug = '',
    super.key,
  });

  final ScopedFeedKind kind;
  final String slug;
  final String countrySlug;

  @override
  State<ScopedNewsFeedScreen> createState() => _ScopedNewsFeedScreenState();
}

class _ScopedNewsFeedScreenState extends State<ScopedNewsFeedScreen> {
  final _search = TextEditingController();
  final _cache = const FeedCache();
  NewsRepository? _newsRepository;
  LocationRepository? _locationRepository;
  NetworkController? _network;
  List<NewsCategory> _categories = const [];
  List<LocationRow> _areas = const [];
  List<NewsSummary> _stories = const [];
  final Map<String, int> _reactions = {};
  final Map<String, bool> _savedStories = {};
  final Map<String, int> _likeDeltas = {};
  final Map<String, int> _dislikeDeltas = {};
  final Set<String> _busyStories = {};
  LocationRow? _country;
  LocationRow? _region;
  LocationRow? _city;
  NewsCategory? _routeCategory;
  String _categoryId = '';
  String _areaId = '';
  String _sort = 'latest';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int _page = 0;
  int _loadVersion = 0;
  int _followVersion = 0;
  bool _initialized = false;
  bool _loading = true;
  bool _scopeReady = false;
  bool _more = false;
  bool _notFound = false;
  bool _followed = false;
  bool _followBusy = false;
  bool _wasOnline = true;
  String? _error;
  String? _cacheMessage;

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
    _newsRepository = NewsRepository(client);
    _locationRepository = LocationRepository(client);
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
    if (reconnected && mounted && !_loading) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
      _cacheMessage = null;
      _notFound = false;
      _scopeReady = false;
    });
    try {
      if (_network?.offline ?? false) {
        final cached = _search.text.trim().isEmpty
            ? await _cache.read(_cacheKey)
            : null;
        if (!mounted) return;
        setState(() {
          _scopeReady = true;
          _stories = cached ?? const [];
          _more = false;
          if (cached?.isNotEmpty == true) {
            _cacheMessage = 'Showing saved stories from this device.';
          } else {
            _error = 'No saved stories are available for this feed.';
          }
        });
        return;
      }
      _categories = await _newsRepository!.categories();
      switch (widget.kind) {
        case ScopedFeedKind.country:
          _country = await _locationRepository!.countryBySlug(widget.slug);
          _notFound = _country == null;
          break;
        case ScopedFeedKind.region:
          _country = await _locationRepository!.countryBySlug(
            widget.countrySlug,
          );
          if (_country == null) {
            _notFound = true;
          } else {
            _region = await _locationRepository!.regionBySlug(
              _country!.id,
              widget.slug,
            );
            _notFound = _region == null;
          }
          break;
        case ScopedFeedKind.city:
          _country = await _locationRepository!.countryBySlug(
            widget.countrySlug,
          );
          if (_country == null) {
            _notFound = true;
          } else {
            _city = await _locationRepository!.cityBySlug(
              _country!.id,
              widget.slug,
            );
            _notFound = _city == null;
            if (_city != null) {
              _areas = await _locationRepository!.areas(_city!.id);
              if (_city!.regionId?.isNotEmpty == true) {
                final regions = await _locationRepository!.regions(
                  _country!.id,
                );
                for (final region in regions) {
                  if (region.id == _city!.regionId) {
                    _region = region;
                    break;
                  }
                }
              }
            }
          }
          break;
        case ScopedFeedKind.category:
          _routeCategory = await _newsRepository!.categoryBySlug(widget.slug);
          _notFound = _routeCategory == null;
          _categoryId = _routeCategory?.id ?? '';
          break;
      }
      _scopeReady = true;
      _updateSeo();
      if (_notFound) return;
      await Future.wait([_load(), _refreshFollow()]);
    } catch (error) {
      final cached = _search.text.trim().isEmpty
          ? await _cache.read(_cacheKey)
          : null;
      if (mounted) {
        setState(() {
          if (cached?.isNotEmpty == true) {
            _scopeReady = true;
            _stories = cached!;
            _more = false;
            _cacheMessage = 'Could not refresh. Showing saved stories.';
          } else {
            _error = AppError.message(error);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _seoPath => switch (widget.kind) {
    ScopedFeedKind.country => '/country/${widget.slug}',
    ScopedFeedKind.region =>
      '/region/${widget.countrySlug}/${widget.slug}',
    ScopedFeedKind.city => '/city/${widget.countrySlug}/${widget.slug}',
    ScopedFeedKind.category => '/category/${widget.slug}',
  };

  void _updateSeo() {
    if (_notFound) {
      SeoService.apply(noIndexSeo(_seoPath));
      return;
    }
    final (title, description) = switch (widget.kind) {
      ScopedFeedKind.country => (
        '${_country?.name ?? 'Country'} News',
        'Read verified local and breaking news from ${_country?.name ?? 'this country'} on CitizenNews.',
      ),
      ScopedFeedKind.region => (
        '${_region?.name ?? 'Regional'} News',
        'Read verified news from ${_region?.name ?? 'this region'}, ${_country?.name ?? ''} on CitizenNews.',
      ),
      ScopedFeedKind.city => (
        '${_city?.name ?? 'City'} News',
        'Read verified local and breaking news from ${_city?.name ?? 'this city'}, ${_country?.name ?? ''} on CitizenNews.',
      ),
      ScopedFeedKind.category => (
        '${_routeCategory?.name ?? 'Category'} News',
        'Read the latest verified ${(_routeCategory?.name ?? '').toLowerCase()} stories on CitizenNews.',
      ),
    };
    SeoService.apply(
      scopedFeedSeo(title: title, description: description, path: _seoPath),
    );
  }

  Future<void> _load({bool append = false}) async {
    final version = ++_loadVersion;
    final query = _search.text.trim();
    final cacheable = !append && query.isEmpty;
    final cacheKey = _cacheKey;
    if (!append) _page = 0;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _cacheMessage = null;
      });
    }
    try {
      if (_network?.offline ?? false) {
        if (append) {
          if (_page > 0) _page--;
          if (mounted && version == _loadVersion) {
            setState(
              () => _error = 'Connect to the internet to load more stories.',
            );
          }
          return;
        }
        final cached = cacheable ? await _cache.read(cacheKey) : null;
        if (!mounted || version != _loadVersion) return;
        setState(() {
          _stories = cached ?? const [];
          _more = false;
          if (cached?.isNotEmpty == true) {
            _cacheMessage = 'Showing saved stories from this device.';
          } else {
            _error = 'No saved stories are available for this feed.';
          }
        });
        return;
      }
      final rows = await _newsRepository!.search(
        query: query,
        country: _country?.id ?? '',
        region: _region?.id ?? '',
        city: _city?.id ?? '',
        category: _categoryId,
        area: _areaId,
        tab: _sort,
        page: _page,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _stories = append ? [..._stories, ...rows] : rows;
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
      if (mounted && version == _loadVersion) {
        setState(() {
          if (cached?.isNotEmpty == true) {
            _stories = cached!;
            _more = false;
            _cacheMessage = 'Could not refresh. Showing saved stories.';
          } else {
            _error = AppError.message(error);
          }
        });
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  ({String type, String id, String label})? get _followTarget {
    if (_areaId.isNotEmpty) {
      LocationRow? area;
      for (final value in _areas) {
        if (value.id == _areaId) {
          area = value;
          break;
        }
      }
      if (area != null) return (type: 'area', id: area.id, label: area.name);
    }
    if (_city != null) {
      return (type: 'city', id: _city!.id, label: _city!.name);
    }
    if (_routeCategory != null) {
      return (
        type: 'category',
        id: _routeCategory!.id,
        label: _routeCategory!.name,
      );
    }
    return null;
  }

  Future<void> _refreshFollow() async {
    final version = ++_followVersion;
    final target = _followTarget;
    if (target == null || _newsRepository!.client.auth.currentUser == null) {
      if (mounted) setState(() => _followed = false);
      return;
    }
    final followed = await _newsRepository!.isFollowing(target.type, target.id);
    if (mounted && version == _followVersion && target == _followTarget) {
      setState(() => _followed = followed);
    }
  }

  Future<void> _toggleFollow() async {
    final target = _followTarget;
    if (target == null || _followBusy) return;
    final session = AuthScope.read(context);
    if (!session.isSignedIn) {
      final returnTo = GoRouterState.of(context).uri.toString();
      context.go(
        Uri(path: '/login', queryParameters: {'returnTo': returnTo}).toString(),
      );
      return;
    }
    setState(() => _followBusy = true);
    try {
      await _newsRepository!.setFollowing(target.type, target.id, !_followed);
      if (mounted) {
        setState(() => _followed = !_followed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _followed
                  ? 'Following ${target.label}.'
                  : 'Unfollowed ${target.label}.',
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

  Future<void> _pickDate(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: (from ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = value;
        if (_dateTo != null && _dateTo!.isBefore(value)) _dateTo = value;
      } else {
        _dateTo = value;
        if (_dateFrom != null && _dateFrom!.isAfter(value)) _dateFrom = value;
      }
    });
    await _load();
  }

  Future<void> _loadMore() async {
    _page++;
    await _load(append: true);
  }

  Future<void> _hydrateInteractions(List<NewsSummary> stories) async {
    if (stories.isEmpty || !AuthScope.read(context).isSignedIn) return;
    final repository = _newsRepository;
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
          return null;
        }
      }),
    );
    if (!mounted) return;
    final visibleIds = _stories.map((story) => story.id).toSet();
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
          await _newsRepository!.currentReaction(story.id);
      final next = current == value ? 0 : value;
      await _newsRepository!.react(story.id, next);
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
          await _newsRepository!.isBookmarked(story.id);
      await _newsRepository!.setBookmark(story.id, !current);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading && !_scopeReady)
                      const Padding(
                        padding: EdgeInsets.all(50),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (!_scopeReady)
                      _FeedNotice(
                        message: _error ?? 'This feed could not be loaded.',
                        retry: _initialize,
                      )
                    else if (_notFound)
                      _NotFound(kind: widget.kind)
                    else ...[
                      _ScopedFeedHeader(
                        kind: widget.kind,
                        title: _title,
                        subtitle: _subtitle,
                        visibleStories: _stories.length,
                      ),
                      const SizedBox(height: 16),
                      _controls(mobile),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _FeedNotice(message: _error!, retry: _load),
                      ],
                      if (_cacheMessage != null) ...[
                        const SizedBox(height: 12),
                        _CachedFeedNotice(message: _cacheMessage!),
                      ],
                      const SizedBox(height: 18),
                      if (_loading && _stories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(50),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_stories.isEmpty)
                        const _EmptyScopedFeed()
                      else ...[
                        for (
                          var index = 0;
                          index < _stories.length;
                          index++
                        ) ...[
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: NewsStoryCard(
                                key: ValueKey(
                                  'scoped-story-${_stories[index].id}',
                                ),
                                story: _stories[index],
                                reaction:
                                    _reactions[_stories[index].id] ?? 0,
                                saved:
                                    _savedStories[_stories[index].id] ?? false,
                                busy: _busyStories.contains(
                                  _stories[index].id,
                                ),
                                likeCount:
                                    _stories[index].likes +
                                    (_likeDeltas[_stories[index].id] ?? 0),
                                dislikeCount:
                                    _stories[index].dislikes +
                                    (_dislikeDeltas[_stories[index].id] ?? 0),
                                onLike: () => _react(_stories[index], 1),
                                onDislike: () => _react(_stories[index], -1),
                                onComment: () => context.push(
                                  '/news/${_stories[index].slug}',
                                ),
                                onSave: () => _toggleSave(_stories[index]),
                                onShare: () => _share(_stories[index]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (AdsPolicy.canShowBannerAfter(
                            _stories,
                            index,
                          )) ...[
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: const CitizenBannerAd(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (AdsPolicy.canShowNativeAfter(
                            _stories,
                            index,
                          )) ...[
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 760,
                                ),
                                child: CitizenNativeAd(
                                  key: ValueKey(
                                    'scoped-feed-ad-${(index + 1) ~/ 3}',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                        if (_more)
                          OutlinedButton(
                            onPressed: _loading ? null : _loadMore,
                            child: Text(_loading ? 'Loading...' : 'Load more'),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(bool mobile) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Latest'),
                selected: _sort == 'latest',
                onSelected: (_) {
                  setState(() => _sort = 'latest');
                  _load();
                },
              ),
              ChoiceChip(
                label: const Text('Trending'),
                selected: _sort == 'trending',
                onSelected: (_) {
                  setState(() => _sort = 'trending');
                  _load();
                },
              ),
              if (_followTarget != null)
                OutlinedButton.icon(
                  onPressed: _followBusy ? null : _toggleFollow,
                  icon: Icon(
                    _followed
                        ? Icons.notifications_active_rounded
                        : Icons.add_alert_outlined,
                  ),
                  label: Text(_followed ? 'Following' : 'Follow'),
                ),
              TextButton.icon(
                onPressed: () => context.push('/explore'),
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Explore places'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: 'Search within this feed',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
          if (_routeCategory == null) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All news',
                    selected: _categoryId.isEmpty,
                    onTap: () {
                      setState(() => _categoryId = '');
                      _load();
                    },
                  ),
                  for (final category in _categories)
                    _FilterChip(
                      label: category.name,
                      selected: _categoryId == category.id,
                      onTap: () {
                        setState(() => _categoryId = category.id);
                        _load();
                      },
                    ),
                ],
              ),
            ),
          ],
          if (_areas.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('scope-area-$_areaId'),
              initialValue: _areaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Area'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All areas')),
                for (final area in _areas)
                  DropdownMenuItem(value: area.id, child: Text(area.name)),
              ],
              onChanged: (value) async {
                setState(() => _areaId = value ?? '');
                await Future.wait([_load(), _refreshFollow()]);
              },
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _dateFrom == null ? 'From date' : 'From ${_date(_dateFrom!)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _dateTo == null ? 'To date' : 'To ${_date(_dateTo!)}',
                ),
              ),
              if (_dateFrom != null || _dateTo != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                    });
                    _load();
                  },
                  child: const Text('Clear dates'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  String get _title => switch (widget.kind) {
    ScopedFeedKind.country => '${_country?.name ?? _routeLabel} news',
    ScopedFeedKind.region => '${_region?.name ?? _routeLabel} news',
    ScopedFeedKind.city => '${_city?.name ?? _routeLabel} news',
    ScopedFeedKind.category => '${_routeCategory?.name ?? _routeLabel} news',
  };

  String get _routeLabel => widget.slug
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String get _cacheKey => FeedCache.scopedKey(
    kind: widget.kind.name,
    slug: widget.slug,
    countrySlug: widget.countrySlug,
    sort: _sort,
    category: widget.kind == ScopedFeedKind.category
        ? widget.slug
        : _categoryId,
    area: _areaId,
    dateFrom: _dateFrom == null ? '' : _date(_dateFrom!),
    dateTo: _dateTo == null ? '' : _date(_dateTo!),
  );

  String get _subtitle => switch (widget.kind) {
    ScopedFeedKind.country => 'Published reporting from this country.',
    ScopedFeedKind.region =>
      'Local reporting from ${_country?.name ?? 'this country'}.',
    ScopedFeedKind.city => [
      _region?.name,
      _country?.name,
    ].whereType<String>().join(', '),
    ScopedFeedKind.category =>
      'Latest verified reporting in this news category.',
  };

  String _date(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

class _ScopedFeedHeader extends StatelessWidget {
  const _ScopedFeedHeader({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.visibleStories,
  });

  final ScopedFeedKind kind;
  final String title;
  final String subtitle;
  final int visibleStories;

  IconData get _icon => switch (kind) {
    ScopedFeedKind.country => Icons.public_rounded,
    ScopedFeedKind.region => Icons.map_outlined,
    ScopedFeedKind.city => Icons.location_city_rounded,
    ScopedFeedKind.category => Icons.topic_outlined,
  };

  String get _eyebrow => switch (kind) {
    ScopedFeedKind.country => 'COUNTRY FEED',
    ScopedFeedKind.region => 'REGIONAL FEED',
    ScopedFeedKind.city => 'LOCAL FEED',
    ScopedFeedKind.category => 'TOPIC FEED',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.red.withValues(alpha: .08),
          AppColors.focus.withValues(alpha: .035),
        ],
      ),
      border: Border.all(color: AppColors.red.withValues(alpha: .15)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_icon, color: AppColors.red),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _eyebrow,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        if (visibleStories > 0) ...[
          const SizedBox(width: 10),
          Chip(
            avatar: const Icon(Icons.article_outlined, size: 16),
            label: Text('$visibleStories'),
          ),
        ],
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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

class _FeedNotice extends StatelessWidget {
  const _FeedNotice({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline_rounded),
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

class _EmptyScopedFeed extends StatelessWidget {
  const _EmptyScopedFeed();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(34),
      child: Column(
        children: [
          Icon(Icons.newspaper_outlined, size: 42, color: AppColors.red),
          SizedBox(height: 12),
          Text(
            'No stories match these filters yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.kind});

  final ScopedFeedKind kind;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          const Icon(Icons.location_off_outlined, size: 46),
          const SizedBox(height: 12),
          Text(
            '${kind.name[0].toUpperCase()}${kind.name.substring(1)} not found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => context.push('/explore'),
            child: const Text('Explore news locations'),
          ),
        ],
      ),
    ),
  );
}
