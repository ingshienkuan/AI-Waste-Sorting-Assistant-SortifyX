// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Basic smoke test for SortifyX.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sortifyx_app/main.dart';

void main() {
  testWidgets('App boots and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SortifyXApp());

    expect(find.text('SortifyX'), findsOneWidget);
    expect(find.text('AI Waste Sorting Assistant'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
