import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:little_steps_mvp/app.dart';
import 'package:little_steps_mvp/screens/login_screen.dart';
import 'package:little_steps_mvp/screens/main_shell.dart';

void main() {
  testWidgets('App starts on Login screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LittleStepsApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Home opens Attendance screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();

    // Home screen वरचे card दिसते
    expect(find.text('Mark attendance'), findsOneWidget);

    // Card दाबल्यावर Attendance screen उघडते
    await tester.tap(find.text('Mark attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Save & notify parents'), findsOneWidget);
  });
}