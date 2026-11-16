import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AppError {
  static String message(Object error) {
    final raw = switch (error) {
      AuthException exception => exception.message,
      PostgrestException exception => exception.message,
      _ => error.toString(),
    };

    if (error is AuthConfigurationException) return error.message;
    if (RegExp(
      r'invalid login credentials',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'The email or password is incorrect.';
    }
    if (RegExp(
      r'user already registered|email.*already',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'An account already exists for this email.';
    }
    if (RegExp(
      r'username_taken|duplicate.*username',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'That username is already taken.';
    }
    if (RegExp(r'otp|token', caseSensitive: false).hasMatch(raw) &&
        RegExp(r'invalid|expired', caseSensitive: false).hasMatch(raw)) {
      return 'The verification code is invalid or has expired.';
    }
    if (RegExp(
      r'rate limit|too many requests',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (RegExp(
      r'socket|network|failed host lookup|connection',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'Check your internet connection and try again.';
    }
    if (raw.startsWith('Exception: ')) return raw.substring(11);
    return 'Something went wrong. Please try again.';
  }
}

class AuthConfigurationException implements Exception {
  const AuthConfigurationException([
    this.message =
        'Supabase is not configured. Create config.json from config.example.json and run with --dart-define-from-file=config.json.',
  ]);

  final String message;

  @override
  String toString() => message;
}
