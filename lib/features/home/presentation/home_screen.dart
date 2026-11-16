import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../location/application/location_controller.dart';
import '../../location/presentation/location_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  int selectedCategory = 0;

  static const tabs = [
    'Nearby',
    'Latest',
    'Trending',
    'Following',
    'Worldwide',
  ];
  static const categories = [
    'All news',
    'Local',
    'Politics',
    'Business',
    'Technology',
    'Sports',
  ];

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.contentMax,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile
                    ? 16
                    : 40,
                18,
                MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile
                    ? 16
                    : 40,
                72,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _EditionBar(),
                  const SizedBox(height: 8),
                  _FeedTabs(
                    labels: tabs,
                    selected: selectedTab,
                    onSelected: (value) => setState(() => selectedTab = value),
                  ),
                  const SizedBox(height: 12),
                  _FeedTools(location: location),
                  if (location.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      location.error!,
                      style: const TextStyle(color: AppColors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _CategoryStrip(
                    labels: categories,
                    selected: selectedCategory,
                    onSelected: (value) =>
                        setState(() => selectedCategory = value),
                  ),
                  const SizedBox(height: 26),
                  _LocationReadyState(location: location),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditionBar extends StatelessWidget {
  const _EditionBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'LIVE LOCAL EDITION',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'EDITORIAL POLICY',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTabs extends StatelessWidget {
  const _FeedTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selected;
          return InkWell(
            onTap: () => onSelected(index),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              margin: const EdgeInsets.only(right: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppColors.red : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: active ? AppColors.red : AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FeedTools extends StatelessWidget {
  const _FeedTools({required this.location});

  final LocationController location;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: location.detecting ? null : location.detectCurrentLocation,
          icon: const Icon(
            Icons.my_location_rounded,
            color: AppColors.red,
            size: 18,
          ),
          label: Text(
            location.detecting
                ? 'Locating…'
                : location.selectedLabel.isEmpty
                    ? 'Use my location'
                    : location.selectedLabel,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            shape: const StadiumBorder(),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/explore'),
          child: const Text('Search city'),
        ),
        SizedBox(
          width: mobile ? double.infinity : 225,
          height: 40,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search stories',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: () => onSelected(index),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                backgroundColor: active ? AppColors.ink : AppColors.paper,
                foregroundColor: active ? Colors.white : AppColors.ink,
                side: BorderSide(
                  color: active ? AppColors.ink : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(labels[index]),
            ),
          );
        }),
      ),
    );
  }
}

class _LocationReadyState extends StatelessWidget {
  const _LocationReadyState({required this.location});

  final LocationController location;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'LOCATION DIRECTORY READY',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              location.selectedLabel.isEmpty
                  ? 'Choose where you want your news'
                  : location.selectedLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Text(
                'Browse countries, filter regions, search cities, or use precise GPS to set your nearby-news location. Your selection is saved on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
