import 'dart:async';

import 'package:flutter/material.dart';
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

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({this.initialTab = 'nearby', super.key});

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
            setState(() => _error = 'Connect to the internet to load more stories.');
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
      });
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

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(mobile ? 14 : 36, 20, mobile ? 14 : 36, 90),
          children: [
            const Text(
              'LIVE LOCAL EDITION',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            const SizedBox(height: 15),
            _FeedTabs(
              selected: _tab,
              onSelected: (tab) {
                setState(() => _tab = tab);
                _load();
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                OutlinedButton.icon(
                  onPressed: location.detecting
                      ? null
                      : () async {
                          await location.detectCurrentLocation();
                          await _load();
                        },
                  icon: const Icon(Icons.my_location_rounded),
                  label: Text(
                    location.selectedLabel.isEmpty
                        ? 'Use my location'
                        : location.selectedLabel,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/explore'),
                  child: const Text('Choose city'),
                ),
                SizedBox(
                  width: mobile ? double.infinity : 320,
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Search stories',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                ),
              ],
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
                        context.go(
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_news.isEmpty)
              _EmptyFeed(
                nearby: _tab == 'nearby',
                chooseCity: () => context.go('/explore'),
              )
            else ...[
              for (var index = 0; index < _news.length; index++) ...[
                _NewsCard(story: _news[index]),
                const SizedBox(height: 12),
                if (AdsPolicy.canShowNativeAfter(_news, index)) ...[
                  const CitizenNativeAd(),
                  const SizedBox(height: 12),
                ],
              ],
              if (_more)
                OutlinedButton(
                  onPressed: _loading ? null : _loadMore,
                  child: Text(_loading ? 'Loading...' : 'Load more'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in const ['nearby', 'latest', 'trending', 'following', 'worldwide'])
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text('${tab[0].toUpperCase()}${tab.substring(1)}'),
                  selected: selected == tab,
                  onSelected: (_) => onSelected(tab),
                ),
              ),
          ],
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.story});
  final NewsSummary story;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/news/${story.slug}'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 650;
              final image = story.imageUrl == null
                  ? Container(
                      color: AppColors.surface,
                      height: wide ? 220 : 190,
                      child: const Center(child: Icon(Icons.newspaper_rounded, size: 44)),
                    )
                  : Image.network(
                      story.imageUrl!,
                      height: wide ? 220 : 190,
                      width: wide ? 300 : double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.surface,
                        height: 190,
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    );
              final content = Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(story.category.toUpperCase(), style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 10)),
                        if (story.breaking) const Text('BREAKING', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 10)),
                        if (story.corrected) const Text('CORRECTED', style: TextStyle(color: AppColors.focus, fontWeight: FontWeight.w800, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(story.headline, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 7),
                    Text(story.summary, maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    Text('${story.fullName}${story.verified ? ' - verified' : ''} - ${story.city}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('${story.views} views  ${story.likes} likes  ${story.comments} comments', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              );
              return wide
                  ? Row(children: [SizedBox(width: 300, child: image), Expanded(child: content)])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [image, content]);
            },
          ),
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
              const Icon(Icons.location_searching_rounded, size: 42, color: AppColors.red),
              const SizedBox(height: 12),
              Text(nearby ? 'No nearby stories yet' : 'No stories found', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (nearby) OutlinedButton(onPressed: chooseCity, child: const Text('Choose another city')),
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
