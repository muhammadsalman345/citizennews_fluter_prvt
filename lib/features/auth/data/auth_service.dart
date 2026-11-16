import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_error.dart';

class AuthService {
  const AuthService._(this.client);

  final SupabaseClient? client;

  bool get isConfigured => client != null;

  static Future<AuthService> initialize() async {
    if (!AppConfig.isSupabaseConfigured) return const AuthService._(null);
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    return AuthService._(Supabase.instance.client);
  }

  factory AuthService.unconfigured() => const AuthService._(null);

  SupabaseClient get requireClient {
    final value = client;
    if (value == null) throw const AuthConfigurationException();
    return value;
  }

  Future<bool> usernameAvailable(String username) async {
    final result = await requireClient.rpc<dynamic>(
      'username_available',
      params: {'candidate': username.trim().toLowerCase()},
    );
    return result == true;
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String phoneE164,
    required String phoneCountry,
    required String cityId,
  }) {
    final acceptedAt = DateTime.now().toUtc().toIso8601String();
    return requireClient.auth.signUp(
      email: normalizeEmail(email),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'username': username.trim().toLowerCase(),
        'phone_e164': phoneE164,
        'phone_country': phoneCountry.toUpperCase(),
        'city_id': cityId,
        'terms_accepted_at': acceptedAt,
        'guidelines_accepted_at': acceptedAt,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return requireClient.auth.signInWithPassword(
      email: normalizeEmail(email),
      password: password,
    );
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return requireClient.auth.verifyOTP(
      email: normalizeEmail(email),
      token: normalizeOtp(token),
      type: OtpType.email,
    );
  }

  Future<void> resendSignupOtp(String email) async {
    await requireClient.auth.resend(
      type: OtpType.email,
      email: normalizeEmail(email),
    );
  }

  Future<void> requestPasswordReset(String email) {
    return requireClient.auth.resetPasswordForEmail(
      normalizeEmail(email),
      redirectTo: AppConfig.authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await requireClient.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => requireClient.auth.signOut();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String normalizeOtp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 6 ? digits : digits.substring(0, 6);
  }

  static bool isExistingSignupUser(User? user) =>
      user != null && user.identities != null && user.identities!.isEmpty;
}
