enum AccountAccessStatus { active, suspended, unknown }

enum AppRole { user, reporter, trustedReporter, admin, superAdmin }

extension AppRoleValue on AppRole {
  String get databaseValue => switch (this) {
        AppRole.user => 'user',
        AppRole.reporter => 'reporter',
        AppRole.trustedReporter => 'trusted_reporter',
        AppRole.admin => 'admin',
        AppRole.superAdmin => 'super_admin',
      };

  static AppRole? parse(String value) => switch (value) {
        'user' => AppRole.user,
        'reporter' => AppRole.reporter,
        'trusted_reporter' => AppRole.trustedReporter,
        'admin' => AppRole.admin,
        'super_admin' => AppRole.superAdmin,
        _ => null,
      };
}
