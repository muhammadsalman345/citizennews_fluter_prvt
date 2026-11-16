import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../location/data/location_repository.dart';
import '../domain/report_models.dart';
import 'post_image_normalizer.dart';

class ReportingRepository {
  ReportingRepository(this.client)
      : locations = LocationRepository(client);

  final SupabaseClient client;
  final LocationRepository locations;
  final _picker = ImagePicker();
  final _random = Random.secure();

  static const _lastCaptureKey = 'citizennews.report.last_capture';

  Future<List<ReportingCategory>> categories() async {
    final rows = await client.from('categories').select('id,name,slug,active').order('name');
    return rows
        .map((row) => ReportingCategory.fromJson(row))
        .where((row) => row.active && row.slug != 'breaking')
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> ownPost(String id) async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return client
        .from('news_posts')
        .select('*')
        .eq('id', id)
        .eq('reporter_id', user.id)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> media(String postId) async {
    final rows = await client
        .from('news_media')
        .select('path,primary_evidence')
        .eq('post_id', postId)
        .order('primary_evidence', ascending: false);
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<ReportLocation> locate({String source = 'none'}) async {
    final position = await _position();
    return _context(position, position, source);
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location services before reporting news.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Precise location permission is required to report news.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.accuracy < 0 || position.accuracy > 100) {
      throw Exception('GPS accuracy is too weak. Move outdoors and retry.');
    }
    if (DateTime.now().difference(position.timestamp).abs() >
        const Duration(minutes: 1)) {
      throw Exception('The GPS reading is stale. Refresh and try again.');
    }
    return position;
  }

  Future<ReportLocation> _context(
    Position before,
    Position after,
    String source,
  ) async {
    final movement = Geolocator.distanceBetween(
      before.latitude,
      before.longitude,
      after.latitude,
      after.longitude,
    );
    if (movement > max(200, before.accuracy + after.accuracy)) {
      throw Exception('Location changed too much while adding the photo.');
    }
    final resolved = await locations.resolve(
      latitude: after.latitude,
      longitude: after.longitude,
      purpose: 'report',
    );
    if (resolved.resolutionId?.isNotEmpty != true) {
      throw Exception('The server could not issue a reporting-location ticket.');
    }
    final flags = <String>[];
    final preferences = await SharedPreferences.getInstance();
    final previousRaw = preferences.getString(_lastCaptureKey);
    if (previousRaw != null) {
      try {
        final previous = Map<String, dynamic>.from(jsonDecode(previousRaw) as Map);
        final previousAt = DateTime.parse(previous['captured_at'] as String);
        final seconds = max(
          1,
          DateTime.now().toUtc().difference(previousAt.toUtc()).inMilliseconds /
              1000,
        );
        final distance = Geolocator.distanceBetween(
          (previous['latitude'] as num).toDouble(),
          (previous['longitude'] as num).toDouble(),
          after.latitude,
          after.longitude,
        );
        if (distance / seconds > 100) flags.add('impossible_movement');
      } catch (_) {
        // Corrupt device-only risk history must not block a valid capture.
      }
    }
    final capturedAt = DateTime.now().toUtc();
    await preferences.setString(
      _lastCaptureKey,
      jsonEncode({
        'latitude': after.latitude,
        'longitude': after.longitude,
        'captured_at': capturedAt.toIso8601String(),
      }),
    );
    return ReportLocation(
      latitude: after.latitude,
      longitude: after.longitude,
      accuracy: after.accuracy,
      capturedAt: capturedAt,
      cityId: resolved.city.id,
      cityName: resolved.label,
      resolutionId: resolved.resolutionId!,
      timezone: resolved.timezone,
      locality: resolved.locality,
      mediaSource: source,
      deviceMetadata: {
        'media_source': source,
        'platform': defaultTargetPlatform.name,
        'operatingSystem': defaultTargetPlatform.name,
      },
      riskFlags: flags,
    );
  }

  Future<ReportImage?> camera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 78,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return null;
    final before = await _position();
    final after = await _position();
    return ReportImage(
      file: file,
      location: await _context(before, after, 'camera'),
    );
  }

  Future<List<ReportImage>> gallery(int limit) async {
    final files = await _picker.pickMultiImage(
      imageQuality: 78,
      maxWidth: 1600,
      maxHeight: 1600,
      limit: limit,
    );
    if (files.isEmpty) return const [];
    final before = await _position();
    final after = await _position();
    final location = await _context(before, after, 'gallery');
    return [
      for (var index = 0; index < files.length; index++)
        ReportImage(
          file: files[index],
          location: ReportLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: location.accuracy,
            capturedAt: location.capturedAt,
            cityId: location.cityId,
            cityName: location.cityName,
            resolutionId: location.resolutionId,
            timezone: location.timezone,
            locality: location.locality,
            mediaSource: 'gallery',
            deviceMetadata: {
              ...location.deviceMetadata,
              'media_index': index,
            },
            riskFlags: location.riskFlags,
          ),
        ),
    ];
  }

  Future<String> savePost({
    required String postId,
    required String headline,
    required String summary,
    required Map<String, dynamic> body,
    required String categoryId,
    required String source,
    required List<String> tags,
    required ReportLocation? location,
    DateTime? eventTime,
    String? jobDeadline,
    String? jobTimezone,
    String? existingId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in required.');
    final editable = {
      'headline': headline.trim(),
      'summary': summary.trim(),
      'body': body,
      'category_id': categoryId,
      'source': source.trim(),
      'tags': tags,
      'event_time': eventTime?.toUtc().toIso8601String(),
      'job_deadline': jobDeadline,
      'job_timezone': jobDeadline == null ? null : jobTimezone,
    };
    if (existingId != null) {
      await client
          .from('news_posts')
          .update(editable)
          .eq('id', existingId)
          .eq('reporter_id', user.id)
          .inFilter('status', ['draft', 'changes_requested'])
          .select('id')
          .single();
      return existingId;
    }
    final freshLocation = location;
    if (freshLocation == null) {
      throw Exception('A fresh reporting location is required.');
    }
    try {
      await client.from('news_posts').insert({
        ...editable,
        'id': postId,
        'reporter_id': user.id,
        'slug': _storySlug(headline, postId),
        'status': 'draft',
        'latitude': freshLocation.latitude,
        'longitude': freshLocation.longitude,
        'accuracy': freshLocation.accuracy,
        'captured_at': freshLocation.capturedAt.toUtc().toIso8601String(),
        'city_id': freshLocation.cityId,
        'location_resolution_id': freshLocation.resolutionId,
        'device_metadata': freshLocation.deviceMetadata,
        'risk_flags': freshLocation.riskFlags,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final previous = await ownPost(postId);
      final status = previous?['status']?.toString();
      if (status == 'pending' || status == 'under_review') return postId;
      if (status != 'draft') throw Exception('This story can no longer be edited.');
      await client
          .from('news_posts')
          .update(editable)
          .eq('id', postId)
          .eq('reporter_id', user.id)
          .eq('status', 'draft')
          .select('id')
          .single();
    }
    return postId;
  }

  Future<void> createRevision({
    required String revisionId,
    required String postId,
    required String headline,
    required String summary,
    required Map<String, dynamic> body,
    required String source,
    required String correctionNote,
    String? jobDeadline,
    String? jobTimezone,
  }) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    try {
      await client.from('news_revisions').insert({
        'id': revisionId,
        'post_id': postId,
        'reporter_id': owner,
        'headline': headline.trim(),
        'summary': summary.trim(),
        'body': body,
        'source': source.trim(),
        'correction_note': correctionNote.trim(),
        'job_deadline': jobDeadline,
        'job_timezone': jobDeadline == null ? null : jobTimezone,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      await client
          .from('news_revisions')
          .select('id')
          .eq('id', revisionId)
          .eq('reporter_id', owner)
          .single();
    }
  }

  Future<ReportImage> uploadEvidence({
    required String postId,
    required ReportImage image,
    required bool primary,
  }) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    final path = image.evidencePath ?? '$owner/${_uuid()}.jpg';
    final input = await image.file.readAsBytes();
    final bytes = await normalizePostImage(input);
    try {
      await client.storage.from('evidence').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      if (!error.message.toLowerCase().contains('already')) rethrow;
    }
    try {
      await client.from('news_media').insert({
        'post_id': postId,
        'owner_id': owner,
        'path': path,
        'mime_type': 'image/jpeg',
        'primary_evidence': primary,
        'captured_at': image.location.capturedAt.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        await client.storage.from('evidence').remove([path]);
        rethrow;
      }
    }
    return image.withPath(path);
  }

  Future<String> submit(String postId) async {
    final status = await client.rpc<dynamic>(
      'submit_news_post',
      params: {'post_id': postId},
    );
    final value = status.toString();
    if (value != 'pending' && value != 'under_review') {
      throw Exception('The server did not confirm review-queue submission.');
    }
    return value;
  }

  String newId() => _uuid();

  String evidencePath() {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    return '$owner/${_uuid()}.jpg';
  }

  String _storySlug(String headline, String id) {
    var stem = headline
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (stem.isEmpty) stem = 'story';
    if (stem.length > 90) stem = stem.substring(0, 90).replaceAll(RegExp(r'-+$'), '');
    return '$stem-${id.replaceAll('-', '').substring(0, 12)}';
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
