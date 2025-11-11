import 'dart:convert';
import 'package:lockin/pages/stats_page.dart' show HistoryDataProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/main.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/home_page.dart';
import 'package:lockin/pages/tracker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';


final testActivities = [
  TimedActivity(name: 'Focus'),
  CheckableActivity(name: 'Workout'),
];

final testLogs = [
  ActivityLog(activityName: 'Focus', date: DateTime.now().subtract(const Duration(days: 1)), duration: const Duration(minutes: 30)),
  ActivityLog(activityName: 'Workout', date: DateTime.now().subtract(const Duration(days: 1)), duration: Duration.zero, isCheckable: true),
];

final testGoals = [
  Goal(activityName: 'Focus', goalDuration: const Duration(hours: 1), startDate: DateTime.now()),
];

void main() {

  Future<void> setupMockPrefs() async {
    SharedPreferences.setMockInitialValues({
      'activities': jsonEncode(testActivities.map((a) => a.toJson()).toList()),
      'activityLogs': jsonEncode(testLogs.map((l) => l.toJson()).toList()),
      'goals': jsonEncode(testGoals.map((g) => g.toJson()).toList()),
      'isDarkMode': true,
    });
  }

  group('HomePage Widget Tests', () {

    setUp(() async {
      await setupMockPrefs();
    });

    testWidgets('HomePage renders correctly with tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            onThemeChanged: (_) {},
            isDarkMode: true,
            onResetData: () {},
            launchCount: 2,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Tracker'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      expect(find.byType(TrackerPage), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

  });

  group('HomePage State Logic (Data Loading)', () {

    setUp(() async {
      await setupMockPrefs();
    });

    test('_loadDataFromPrefs loads existing data correctly', () async {
      final data = await HomePage.loadDataFromPrefs(0);

      final activities = data['activities'] as List<Activity>;
      final logs = data['logs'] as List<ActivityLog>;
      final goals = data['goals'] as List<Goal>;

      expect(activities, hasLength(2));
      expect(activities.first.name, 'Focus');
      expect(activities.first, isA<TimedActivity>());
      expect(activities.last, isA<CheckableActivity>());

      expect(logs, hasLength(2));
      expect(logs.first.activityName, 'Focus');

      expect(goals, hasLength(1));
      expect(goals.first.activityName, 'Focus');
    });

    test('_loadDataFromPrefs loads default data if no data', () async {
      SharedPreferences.setMockInitialValues({});

      final data = await HomePage.loadDataFromPrefs(0);
      final activities = data['activities'] as List<Activity>;

      expect(activities, hasLength(2));
      expect(activities.first.name, 'Focus');
      expect(activities.last.name, 'Workout');
    });

    test('_loadDataFromPrefs loads default data on first launch (flag)', () async {
      SharedPreferences.setMockInitialValues({});

      final data = await HomePage.loadDataFromPrefs(1);
      final activities = data['activities'] as List<Activity>;

      expect(activities, hasLength(2));
      expect(activities.first.name, 'Focus');
      expect(activities.last.name, 'Workout');
    });

  });
}