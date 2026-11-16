import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../domain/location_models.dart';

class LocationRepository {
  const LocationRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get client {
    final value = _client;
    if (value == null) throw const AuthConfigurationException();
    return value;
  }

  Future<List<LocationRow>> countries() async {
    final rows = await client
        .from('countries')
        .select('id,name,slug,code')
        .eq('active', true)
        .order('name')
        .limit(300);
    return _rows(rows);
  }

  Future<List<LocationRow>> regions(String countryId) async {
    if (countryId.isEmpty) return const [];
    final rows = await client
        .from('regions')
        .select('id,country_id,name,slug,code')
        .eq('country_id', countryId)
        .order('name')
        .limit(1000);
    return _rows(rows);
  }

  Future<List<LocationRow>> cities({
    required String countryId,
    String regionId = '',
    String query = '',
    int page = 0,
  }) async {
    if (countryId.isEmpty) return const [];
    final result = await client.rpc<dynamic>(
      'location_cities',
      params: {
        'country': countryId,
        'region': regionId.isEmpty ? null : regionId,
        'query': query.trim(),
        'page': page.clamp(0, 10000),
      },
    );
    return _rows(result);
  }

  Future<LocationRow?> city(String id) async {
    if (id.isEmpty) return null;
    final row = await client
        .from('cities')
        .select('id,country_id,region_id,name,slug,latitude,longitude,timezone')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : LocationRow.fromJson(row);
  }

  Future<LocationRow?> countryBySlug(String slug) async {
    if (slug.isEmpty) return null;
    final row = await client
        .from('countries')
        .select('id,name,slug,code')
        .eq('slug', slug)
        .eq('active', true)
        .maybeSingle();
    return row == null ? null : LocationRow.fromJson(row);
  }

  Future<LocationRow?> regionBySlug(String countryId, String slug) async {
    if (countryId.isEmpty || slug.isEmpty) return null;
    final row = await client
        .from('regions')
        .select('id,country_id,name,slug,code')
        .eq('country_id', countryId)
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : LocationRow.fromJson(row);
  }

  Future<LocationRow?> cityBySlug(String countryId, String slug) async {
    if (countryId.isEmpty || slug.isEmpty) return null;
    final row = await client
        .from('cities')
        .select(
          'id,country_id,region_id,name,slug,latitude,longitude,timezone',
        )
        .eq('country_id', countryId)
        .eq('slug', slug)
        .eq('active', true)
        .maybeSingle();
    return row == null ? null : LocationRow.fromJson(row);
  }

  Future<List<LocationRow>> areas(String cityId) async {
    if (cityId.isEmpty) return const [];
    final rows = await client
        .from('areas')
        .select('id,city_id,name,slug,latitude,longitude')
        .eq('city_id', cityId)
        .order('name');
    return _rows(rows);
  }

  Future<ResolvedLocation> resolve({
    required double latitude,
    required double longitude,
    String purpose = 'browse',
  }) async {
    final response = await client.functions.invoke(
      'resolve-location',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'purpose': purpose,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) throw Exception(data['error']);
    if (data['matched'] == false) {
      throw Exception('Geographic data for this location is not available yet.');
    }
    return ResolvedLocation.fromJson(data);
  }

  List<LocationRow> _rows(dynamic value) => (value as List? ?? const [])
      .whereType<Map>()
      .map((row) => LocationRow.fromJson(Map<String, dynamic>.from(row)))
      .toList(growable: false);
}
