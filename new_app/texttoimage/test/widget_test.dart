// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:texttoimage/app.dart';

void main() {
  testWidgets('Gallery app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppRoot());

    // In widget tests, platform channels for photo_manager aren't available,
    // so we only assert the initial frame renders.
    expect(find.byType(AppRoot), findsOneWidget);
  });
}
