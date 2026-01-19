// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:test_0077/main.dart';

void main() {
  testWidgets('Wireframe basic navigation', (WidgetTester tester) async {
    final appState = AppState();
    appState.onboarded = true;
    await tester.pumpWidget(AppStateScope(notifier: appState, child: const MyApp()));

    // Dashboard title exists and add button is visible
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('เพิ่มรายการใหม่'), findsOneWidget);
  });
}
