import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../application/location_controller.dart';
import '../domain/location_models.dart';
import 'location_scope.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _countrySearch = TextEditingController();
  final _citySearch = TextEditingController();
  Timer? _cityDebounce;
  int _countryLimit = 12;

  @override
  void dispose() {
    _cityDebounce?.cancel();
    _countrySearch.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    final mobile = MediaQuery.sizeOf(context).width <= AppBreakpoints.mobile;
    final query = _countrySearch.text.trim().toLowerCase();
    final countries = location.countries.where((country) {
      return query.isEmpty ||
          country.name.toLowerCase().contains(query) ||
          (country.code?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMax),
          child: Padding(
            padding: EdgeInsets.fromLTRB(mobile ? 16 : 40, 28, mobile ? 16 : 40, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DirectoryHeader(location: location),
                const SizedBox(height: 20),
                if (location.error != null) _ErrorNotice(message: location.error!),
                if (location.error != null) const SizedBox(height: 14),
                _CurrentLocationCard(location: location),
                const SizedBox(height: 24),
                if (!location.ready || (location.loading && location.countries.isEmpty))
                  const _LoadingGrid()
                else if (location.countryId.isEmpty)
                  ..._countryDirectory(location, countries)
                else
                  ..._cityDirectory(location, mobile),
                const SizedBox(height: 34),
                const _Attribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _countryDirectory(
    LocationController location,
    List<LocationRow> countries,
  ) {
    final visible = countries.take(_countryLimit).toList(growable: false);
    return [
      TextField(
        controller: _countrySearch,
        onChanged: (_) => setState(() => _countryLimit = 12),
        decoration: const InputDecoration(
          labelText: 'Search country',
          hintText: 'Country name or code',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 18),
      if (visible.isEmpty)
        const _EmptyDirectory(message: 'No countries match your search.')
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 3
                : constraints.maxWidth >= 580
                    ? 2
                    : 1;
            const gap = 12.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final country in visible)
                  SizedBox(
                    width: width,
                    child: _PlaceCard(
                      code: country.code?.toUpperCase() ?? 'CN',
                      title: country.name,
                      subtitle: 'Browse cities',
                      onPressed: () => location.selectCountry(country.id),
                    ),
                  ),
              ],
            );
          },
        ),
      if (countries.length > visible.length) ...[
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => setState(() => _countryLimit += 12),
            child: const Text('More countries'),
          ),
        ),
      ],
    ];
  }

  List<Widget> _cityDirectory(LocationController location, bool mobile) {
    final selectedCountry = location.selectedCountry;
    final selectedRegion = location.selectedRegion;
    return [
      if (selectedCountry != null)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go(
                '/country/${Uri.encodeComponent(selectedCountry.slug)}',
              ),
              icon: const Icon(Icons.public_rounded),
              label: Text('${selectedCountry.name} news'),
            ),
            if (selectedRegion != null)
              OutlinedButton.icon(
                onPressed: () => context.go(
                  '/region/${Uri.encodeComponent(selectedCountry.slug)}/${Uri.encodeComponent(selectedRegion.slug)}',
                ),
                icon: const Icon(Icons.map_outlined),
                label: Text('${selectedRegion.name} news'),
              ),
          ],
        ),
      if (selectedCountry != null) const SizedBox(height: 14),
      Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          SizedBox(
            width: mobile ? double.infinity : 320,
            child: DropdownButtonFormField<String>(
              key: ValueKey('explore-region-${location.regionId}'),
              initialValue: location.regionId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Region'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All regions')),
                for (final region in location.regions)
                  DropdownMenuItem(value: region.id, child: Text(region.name)),
              ],
              onChanged: location.loading
                  ? null
                  : (value) => location.selectRegion(value ?? ''),
            ),
          ),
          SizedBox(
            width: mobile ? double.infinity : 420,
            child: TextField(
              controller: _citySearch,
              onChanged: (value) {
                _cityDebounce?.cancel();
                _cityDebounce = Timer(
                  const Duration(milliseconds: 300),
                  () => location.searchCities(value),
                );
              },
              decoration: const InputDecoration(
                labelText: 'Search city',
                hintText: 'Start typing a city name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (location.loading)
        const _LoadingGrid()
      else if (location.cities.isEmpty)
        const _EmptyDirectory(message: 'No cities found for this selection.')
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950
                ? 3
                : constraints.maxWidth >= 580
                    ? 2
                    : 1;
            const gap = 12.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final city in location.cities)
                  SizedBox(
                    width: width,
                    child: _PlaceCard(
                      code: '⌖',
                      title: city.name,
                      subtitle: _regionName(location.regions, city.regionId),
                      selected: city.id == location.cityId,
                      onPressed: () async {
                        await location.selectCity(city.id);
                        if (!context.mounted) return;
                        final country = location.selectedCountry;
                        if (country == null) return;
                        context.go(
                          '/city/${Uri.encodeComponent(country.slug)}/${Uri.encodeComponent(city.slug)}',
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      if (!location.loading && location.hasMoreCities) ...[
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => location.loadCities(append: true),
            child: const Text('More cities'),
          ),
        ),
      ],
    ];
  }

  String _regionName(List<LocationRow> regions, String? id) {
    if (id == null) return 'Local news';
    for (final region in regions) {
      if (region.id == id) return region.name;
    }
    return 'Local news';
  }
}

class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.location});

  final LocationController location;

  @override
  Widget build(BuildContext context) {
    final browsingCities = location.countryId.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXPLORE DIRECTORY',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                browsingCities ? 'Cities' : 'Countries',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 5),
              Text(
                browsingCities
                    ? 'Choose a region or search for a city.'
                    : 'Choose a country to browse its local news cities.',
              ),
            ],
          ),
        ),
        if (browsingCities)
          TextButton.icon(
            onPressed: location.loading ? null : () => location.selectCountry(''),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('All countries'),
          ),
      ],
    );
  }
}

class _CurrentLocationCard extends StatelessWidget {
  const _CurrentLocationCard({required this.location});

  final LocationController location;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.red,
                  child: Icon(Icons.location_on_outlined),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR NEWS LOCATION',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      location.selectedLabel.isEmpty
                          ? 'No city selected'
                          : location.selectedLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: location.detecting ? null : location.detectCurrentLocation,
              icon: location.detecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(location.detecting ? 'Locating…' : 'Use my location'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.selected = false,
  });

  final String code;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.red : AppColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isEmpty ? 'Local news' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                color: selected ? AppColors.red : AppColors.muted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: .07),
        border: Border.all(color: AppColors.red.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(color: AppColors.red),
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        child: Center(child: Text(message, style: const TextStyle(color: AppColors.muted))),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Location data: GeoNames · OpenStreetMap contributors',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.muted, fontSize: 10),
    );
  }
}
