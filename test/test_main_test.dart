import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:lockin/main.dart';
import 'package:lockin/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() {
  group('main.dart Tests', () {
    test('getNotificationContent formats correctly', () {
      expect(getNotificationContent(0), 'Locked in for: less than 1 minute\nKeep up the good work!');
      expect(getNotificationContent(1), 'Locked in for: 1 minute\nKeep up the good work!');
      expect(getNotificationContent(30), 'Locked in for: 30 minutes\nKeep up the good work!');
    });

    group('LockInTrackerApp State', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
      });

      testWidgets('LockInTrackerApp loads dark theme by default', (WidgetTester tester) async {

        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(const LockInTrackerApp(launchCount: 1));

        await tester.pumpAndSettle();

        final MaterialApp app = tester.widget(find.byType(MaterialApp));
        expect(app.themeMode, ThemeMode.dark);
      });

      testWidgets('LockInTrackerApp loads light theme if saved', (WidgetTester tester) async {

        SharedPreferences.setMockInitialValues({'isDarkMode': false});

        await tester.pumpWidget(const LockInTrackerApp(launchCount: 1));

        await tester.pumpAndSettle();

        final MaterialApp app = tester.widget(find.byType(MaterialApp));
        expect(app.themeMode, ThemeMode.light);
      });


      testWidgets('HomePage is the home widget', (WidgetTester tester) async {

        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(const LockInTrackerApp(launchCount: 1));

        await tester.pumpAndSettle();

        expect(find.byType(HomePage), findsOneWidget);
      });
    });
  });
}