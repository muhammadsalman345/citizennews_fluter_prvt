import 'package:image_picker/image_picker.dart';

class ReportingCategory {
  const ReportingCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.active,
  });
  final String id;
  final String name;
  final String slug;
  final bool active;

  bool get cameraOnly =>
      slug == 'accident' || slug == 'accidents' || slug.startsWith('accidents-');
  bool get isJobs => slug == 'jobs';
  bool get isJobChild => slug.startsWith('jobs-');

  factory ReportingCategory.fromJson(Map<String, dynamic> json) =>
      ReportingCategory(
        id: json['id'] as String,
        name: json['name']?.toString() ?? '',
        slug: json['slug']?.toString() ?? '',
        active: json['active'] as bool? ?? false,
      );
}

class ReportLocation {
  const ReportLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    required this.cityId,
    required this.cityName,
    required this.resolutionId,
    required this.mediaSource,
    required this.deviceMetadata,
    required this.riskFlags,
    this.timezone,
    this.locality,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
  final String cityId;
  final String cityName;
  final String resolutionId;
  final String mediaSource;
  final Map<String, dynamic> deviceMetadata;
  final List<String> riskFlags;
  final String? timezone;
  final String? locality;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'city_id': cityId,
        'city_name': cityName,
        'location_resolution_id': resolutionId,
        'media_source': mediaSource,
        'device_metadata': deviceMetadata,
        'risk_flags': riskFlags,
        'location_timezone': timezone,
        'locality': locality,
      };

  factory ReportLocation.fromJson(Map<String, dynamic> json) => ReportLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
        capturedAt: DateTime.parse(json['captured_at'] as String),
        cityId: json['city_id'] as String,
        cityName: json['city_name']?.toString() ?? '',
        resolutionId: json['location_resolution_id'] as String,
        mediaSource: json['media_source']?.toString() ?? 'none',
        deviceMetadata: Map<String, dynamic>.from(
          json['device_metadata'] as Map? ?? const {},
        ),
        riskFlags: (json['risk_flags'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        timezone: json['location_timezone'] as String?,
        locality: json['locality'] as String?,
      );
}

class ReportImage {
  const ReportImage({
    required this.file,
    required this.location,
    this.evidencePath,
  });
  final XFile file;
  final ReportLocation location;
  final String? evidencePath;

  ReportImage withPath(String path) =>
      ReportImage(file: file, location: location, evidencePath: path);
}
