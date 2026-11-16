import 'package:citizennews_flutter/features/auth/domain/account_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('database role values map without granting unknown roles', () {
    expect(AppRoleValue.parse('user'), AppRole.user);
    expect(AppRoleValue.parse('trusted_reporter'), AppRole.trustedReporter);
    expect(AppRoleValue.parse('super_admin'), AppRole.superAdmin);
    expect(AppRoleValue.parse('owner'), isNull);
  });

  test('every role serializes to the existing database contract', () {
    expect(
      AppRole.values.map((role) => role.databaseValue),
      ['user', 'reporter', 'trusted_reporter', 'admin', 'super_admin'],
    );
  });
}
