import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/verification_models.dart';

class VerificationRepository {
  VerificationRepository(this.client);

  final SupabaseClient client;
  final Random _random = Random.secure();

  Future<IdentityVerification?> latestForCurrentUser() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final rows = await client
        .from('identity_verifications')
        .select(
          'id,user_id,document_type,front_path,back_path,selfie_path,'
          'country_id,city_id,date_of_birth,status,reason,note,created_at',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return IdentityVerification.fromJson(rows.first);
  }

  Future<List<GovernmentIdType>> governmentIdTypes(String countryId) async {
    if (countryId.isEmpty) return const [];
    final result = await client.rpc<dynamic>(
      'government_id_types',
      params: {'country': countryId},
    );
    return (result as List? ?? const [])
        .whereType<Map>()
        .map((row) => GovernmentIdType.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<String> uploadPrivate(String bucket, XFile file) async {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const AuthException('Sign in required.');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const StorageException('Choose an image smaller than 5 MB.');
    }
    final extension = _extension(file.name);
    final path =
        '$owner/${DateTime.now().toUtc().microsecondsSinceEpoch}-'
        '${_random.nextInt(1 << 32)}.$extension';
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.mimeType ?? _contentType(extension),
            upsert: false,
          ),
        );
    return path;
  }

  Future<String> submit({
    required String documentType,
    required String documentNumber,
    required String frontPath,
    required String backPath,
    required String selfiePath,
    required String countryId,
    required String cityId,
    DateTime? dateOfBirth,
  }) async {
    final result = await client.rpc<dynamic>(
      'submit_identity',
      params: {
        'document_type': documentType,
        'document_number': documentNumber,
        'front_path': frontPath,
        'back_path': backPath,
        'selfie_path': selfiePath,
        'country_id': countryId,
        'city_id': cityId,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      },
    );
    return result.toString();
  }

  Future<void> removeUnreferenced(
    String bucket,
    Iterable<String> paths,
  ) async {
    final clean = paths.where((path) => path.isNotEmpty).toList();
    if (clean.isNotEmpty) await client.storage.from(bucket).remove(clean);
  }

  String _extension(String name) {
    final value = name.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(value)
        ? (value == 'jpeg' ? 'jpg' : value)
        : 'jpg';
  }

  String _contentType(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
