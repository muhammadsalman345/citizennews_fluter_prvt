import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_error.dart';
import '../data/location_repository.dart';
import '../domain/location_models.dart';

class LocationController extends ChangeNotifier {
  LocationController(this.repository);

  static const _countryKey = 'citizennews.location.country';
  static const _regionKey = 'citizennews.location.region';
  static const _cityKey = 'citizennews.location.city';

  final LocationRepository repository;
  List<LocationRow> countries = const [];
  List<LocationRow> regions = const [];
  List<LocationRow> cities = const [];
  String countryId = '';
  String regionId = '';
  String cityId = '';
  String cityQuery = '';
  bool ready = false;
  bool loading = false;
  bool detecting = false;
  bool hasMoreCities = false;
  int cityPage = 0;
  String? error;
  ResolvedLocation? resolvedLocation;
  int _request = 0;

  LocationSelection get selection => LocationSelection(
        countryId: countryId,
        regionId: regionId,
        cityId: cityId,
      );

  LocationRow? get selectedCountry => _find(countries, countryId);
  LocationRow? get selectedRegion => _find(regions, regionId);
  LocationRow? get selectedCity => _find(cities, cityId);
  String get selectedLabel => resolvedLocation?.label ??
      [selectedCity?.name, selectedRegion?.name, selectedCountry?.name]
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .join(', ');

  Future<void> initialize() async {
    if (loading || ready) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      countries = await repository.countries();
      final preferences = await SharedPreferences.getInstance();
      countryId = preferences.getString(_countryKey) ?? '';
      regionId = preferences.getString(_regionKey) ?? '';
      cityId = preferences.getString(_cityKey) ?? '';
      if (!countries.any((country) => country.id == countryId)) {
        countryId = '';
        regionId = '';
        cityId = '';
      }
      if (countryId.isNotEmpty) await _hydrateSelection();
    } catch (exception) {
      error = AppError.message(exception);
    } finally {
      ready = true;
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectCountry(String value) async {
    countryId = value;
    regionId = '';
    cityId = '';
    cityQuery = '';
    resolvedLocation = null;
    regions = const [];
    cities = const [];
    await _saveSelection();
    notifyListeners();
    if (countryId.isNotEmpty) await _hydrateSelection();
  }

  Future<void> selectRegion(String value) async {
    regionId = value;
    cityId = '';
    cityQuery = '';
    resolvedLocation = null;
    cities = const [];
    await _saveSelection();
    notifyListeners();
    await loadCities();
  }

  Future<void> selectCity(String value) async {
    cityId = value;
    resolvedLocation = null;
    final city = _find(cities, cityId);
    if (city?.regionId != null) regionId = city!.regionId!;
    await _saveSelection();
    notifyListeners();
  }

  Future<void> searchCities(String query) async {
    cityQuery = query.trim();
    cityId = '';
    await loadCities();
  }

  Future<void> loadCities({bool append = false}) async {
    if (countryId.isEmpty) return;
    final request = ++_request;
    if (append) {
      cityPage++;
    } else {
      cityPage = 0;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await repository.cities(
        countryId: countryId,
        regionId: regionId,
        query: cityQuery,
        page: cityPage,
      );
      if (request != _request) return;
      cities = append ? [...cities, ...rows] : rows;
      hasMoreCities = rows.length == 50;
    } catch (exception) {
      if (request == _request) error = AppError.message(exception);
    } finally {
      if (request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> detectCurrentLocation() async {
    if (detecting) return;
    detecting = true;
    error = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Turn on location services to find nearby news.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is blocked. Enable it in device settings.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final resolved = await repository.resolve(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      resolvedLocation = resolved;
      cityQuery = '';
      cityPage = 0;
      countryId = resolved.country.id;
      regionId = resolved.region?.id ?? '';
      cityId = resolved.city.id;
      if (!countries.any((row) => row.id == resolved.country.id)) {
        countries = [...countries, resolved.country];
      }
      regions = await repository.regions(countryId);
      cities = await repository.cities(
        countryId: countryId,
        regionId: regionId,
      );
      hasMoreCities = cities.length == 50;
      if (!cities.any((row) => row.id == resolved.city.id)) {
        cities = [resolved.city, ...cities];
      }
      await _saveSelection();
    } catch (exception) {
      error = AppError.message(exception);
    } finally {
      detecting = false;
      notifyListeners();
    }
  }

  Future<void> clearSelection() async {
    countryId = '';
    regionId = '';
    cityId = '';
    cityQuery = '';
    regions = const [];
    cities = const [];
    resolvedLocation = null;
    await _saveSelection();
    notifyListeners();
  }

  Future<void> _hydrateSelection() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      regions = await repository.regions(countryId);
      await loadCities();
      if (cityId.isNotEmpty && !cities.any((city) => city.id == cityId)) {
        final savedCity = await repository.city(cityId);
        if (savedCity != null) cities = [savedCity, ...cities];
      }
    } catch (exception) {
      error = AppError.message(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSelection() async {
    final preferences = await SharedPreferences.getInstance();
    if (countryId.isEmpty) {
      await preferences.remove(_countryKey);
    } else {
      await preferences.setString(_countryKey, countryId);
    }
    if (regionId.isEmpty) {
      await preferences.remove(_regionKey);
    } else {
      await preferences.setString(_regionKey, regionId);
    }
    if (cityId.isEmpty) {
      await preferences.remove(_cityKey);
    } else {
      await preferences.setString(_cityKey, cityId);
    }
  }

  LocationRow? _find(List<LocationRow> rows, String id) {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }
}
