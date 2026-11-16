abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'citizennews://reset-password',
  );

  static String get publishableKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey;

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') && publishableKey.isNotEmpty;
}
