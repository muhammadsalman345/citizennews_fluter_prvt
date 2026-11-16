import 'package:citizennews_flutter/app/citizen_news_app.dart';
import 'package:citizennews_flutter/features/auth/data/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth values are normalized before Supabase calls', () {
    expect(
      AuthService.normalizeEmail('  Reader@Example.COM '),
      'reader@example.com',
    );
    expect(AuthService.normalizeOtp(' 12a34-567 '), '123456');
  });

  testWidgets('signup route renders the Ionic-matched account form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = CitizenNewsApp();
    app.router.go('/signup');
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Your voice matters'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);
  });

  testWidgets('verification route renders the secure identity workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final app = CitizenNewsApp();
    app.router.go('/verification');
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Identity details'), findsOneWidget);
    expect(find.text('Private ID photos'), findsOneWidget);
    expect(find.text('Live selfie'), findsOneWidget);
  });
}
