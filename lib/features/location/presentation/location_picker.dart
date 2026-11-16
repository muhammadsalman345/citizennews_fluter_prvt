import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/location_models.dart';
import 'location_scope.dart';

Future<LocationSelection?> showLocationPicker(BuildContext context) {
  return showModalBottomSheet<LocationSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.paper,
    builder: (_) => LocationScope(
      controller: LocationScope.read(context),
      child: const _LocationPickerSheet(),
    ),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = LocationScope.watch(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Choose news location', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('picker-country-${location.countryId}'),
              initialValue: location.countryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Country'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Choose country')),
                for (final country in location.countries)
                  DropdownMenuItem(value: country.id, child: Text(country.name)),
              ],
              onChanged: location.loading
                  ? null
                  : (value) => location.selectCountry(value ?? ''),
            ),
            if (location.regions.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('picker-region-${location.regionId}'),
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
            ],
            if (location.countryId.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () => location.searchCities(value),
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Search city',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: location.loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.red))
                  : ListView.separated(
                      itemCount: location.cities.length + (location.hasMoreCities ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == location.cities.length) {
                          return TextButton(
                            onPressed: () => location.loadCities(append: true),
                            child: const Text('Load more cities'),
                          );
                        }
                        final city = location.cities[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(city.name),
                          trailing: city.id == location.cityId
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.red)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await location.selectCity(city.id);
                            if (context.mounted) Navigator.pop(context, location.selection);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: location.detecting
                  ? null
                  : () async {
                      await location.detectCurrentLocation();
                      if (context.mounted && location.cityId.isNotEmpty) {
                        Navigator.pop(context, location.selection);
                      }
                    },
              icon: const Icon(Icons.my_location_rounded, color: AppColors.red),
              label: Text(location.detecting ? 'Locating…' : 'Use my location'),
            ),
          ],
        ),
      ),
    );
  }
}
