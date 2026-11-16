import 'package:citizennews_flutter/app/citizen_news_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the CitizenNews mobile shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(CitizenNewsApp());
    await tester.pumpAndSettle();

    expect(find.text('LIVE LOCAL EDITION'), findsOneWidget);
    expect(find.text('Post news'), findsOneWidget);
    expect(find.text('Nearby'), findsOneWidget);
  });
}
