import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safetrace/main.dart';
import 'package:safetrace/services/config_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ConfigService.init();
  });

  testWidgets('Dashboard Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SafeTraceApp());
    await tester.pumpAndSettle();

    // Verify that the Dashboard screen is shown with title SAFETRACE.
    expect(find.text('SAFETRACE'), findsOneWidget);
  });
}

