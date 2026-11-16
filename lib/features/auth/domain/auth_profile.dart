import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.bio,
    this.avatarUrl,
    this.cityId,
  });

  final String id;
  final String fullName;
  final String username;
  final String bio;
  final String? avatarUrl;
  final String? cityId;

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
    id: json['id'] as String,
    fullName: (json['full_name'] as String?)?.trim().isNotEmpty == true
        ? (json['full_name'] as String).trim()
        : 'Reader',
    username: (json['username'] as String?)?.trim() ?? '',
    bio: (json['bio'] as String?)?.trim() ?? '',
    avatarUrl: json['avatar_url'] as String?,
    cityId: json['city_id'] as String?,
  );

  factory AuthProfile.fromUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return AuthProfile(
      id: user.id,
      fullName: (metadata['full_name'] as String?)?.trim().isNotEmpty == true
          ? (metadata['full_name'] as String).trim()
          : 'Reader',
      username: (metadata['username'] as String?)?.trim() ?? '',
      bio: '',
    );
  }
}
