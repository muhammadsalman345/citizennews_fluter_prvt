class LocationRow {
  const LocationRow({
    required this.id,
    required this.name,
    required this.slug,
    this.code,
    this.countryId,
    this.regionId,
    this.cityId,
    this.latitude,
    this.longitude,
    this.timezone,
  });

  final String id;
  final String name;
  final String slug;
  final String? code;
  final String? countryId;
  final String? regionId;
  final String? cityId;
  final double? latitude;
  final double? longitude;
  final String? timezone;

  factory LocationRow.fromJson(Map<String, dynamic> json) => LocationRow(
        id: json['id'] as String,
        name: (json['name'] as String?)?.trim() ?? '',
        slug: (json['slug'] as String?)?.trim() ?? '',
        code: json['code'] as String?,
        countryId: json['country_id'] as String?,
        regionId: json['region_id'] as String?,
        cityId: json['city_id'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        timezone: json['timezone'] as String?,
      );
}

class LocationSelection {
  const LocationSelection({
    this.countryId = '',
    this.regionId = '',
    this.cityId = '',
  });

  final String countryId;
  final String regionId;
  final String cityId;
}

class ResolvedLocation {
  const ResolvedLocation({
    required this.city,
    required this.country,
    required this.label,
    this.region,
    this.locality,
    this.timezone,
    this.resolutionId,
    this.matchStrategy = 'exact',
    this.distanceKm,
  });

  final LocationRow city;
  final LocationRow country;
  final LocationRow? region;
  final String label;
  final String? locality;
  final String? timezone;
  final String? resolutionId;
  final String matchStrategy;
  final double? distanceKm;

  factory ResolvedLocation.fromJson(Map<String, dynamic> json) =>
      ResolvedLocation(
        city: LocationRow.fromJson(Map<String, dynamic>.from(json['city'] as Map)),
        country: LocationRow.fromJson(Map<String, dynamic>.from(json['country'] as Map)),
        region: json['region'] is Map
            ? LocationRow.fromJson(Map<String, dynamic>.from(json['region'] as Map))
            : null,
        label: (json['label'] as String?)?.trim() ?? '',
        locality: json['locality'] as String?,
        timezone: json['timezone'] as String?,
        resolutionId: json['resolution_id'] as String?,
        matchStrategy: json['matchStrategy'] as String? ?? 'exact',
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      );
}
