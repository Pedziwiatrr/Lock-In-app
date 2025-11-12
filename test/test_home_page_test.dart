import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/main.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/home_page.dart';
import 'package:lockin/pages/tracker_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

late List<Activity> testActivities;
late List<ActivityLog> testLogs;
late List<Goal> testGoals;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

  Future<void> setupMockPrefs() async {
    testActivities = [
      TimedActivity(name: 'Focus'),
      CheckableActivity(name: 'Workout'),
    ];

    testLogs = [
      ActivityLog(
          activityName: 'Focus',
          date: DateTime.now().subtract(const Duration(days: 1)),
          duration: const Duration(minutes: 30)),
      ActivityLog(
          activityName: 'Workout',
          date: DateTime.now().subtract(const Duration(days: 1)),
          duration: Duration.zero,
          isCheckable: true),
      ActivityLog(
          activityName: 'Focus',
          date: DateTime.now().subtract(const Duration(days: 2)),
          duration: const Duration(minutes: 15)),
    ];

    testGoals = [
      Goal(
          activityName: 'Focus',
          goalDuration: const Duration(hours: 1),
          startDate: DateTime.now()),
      Goal(
          activityName: 'Workout',
          goalDuration: const Duration(minutes: 1),
          startDate: DateTime.now()),
    ];

    SharedPreferences.setMockInitialValues({
      'activities': jsonEncode(testActivities.map((a) => a.toJson()).toList()),
      'activityLogs': jsonEncode(testLogs.map((l) => l.toJson()).toList()),
      'goals': jsonEncode(testGoals.map((g) => g.toJson()).toList()),
      'isDarkMode': true,
    });
  }

  final homePageKey = GlobalKey<HomePageState>();

  Future<void> pumpHomePage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: HomePage(
          key: homePageKey,
          onThemeChanged: (_) {},
          isDarkMode: true,
          launchCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomePage Widget Tests', () {
    setUp(() async {
      await setupMockPrefs();
    });

    testWidgets('HomePage renders correctly with tabs',
            (WidgetTester tester) async {
          await pumpHomePage(tester);

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

    test('loadDataFromPrefs loads existing data correctly', () async {
      final data = await HomePage.loadDataFromPrefs(0);

      final activities = data['activities'] as List<Activity>;
      final logs = data['logs'] as List<ActivityLog>;
      final goals = data['goals'] as List<Goal>;

      expect(activities, hasLength(2));
      expect(activities.first.name, 'Focus');
      expect(activities.first, isA<TimedActivity>());
      expect(activities.last, isA<CheckableActivity>());

      expect(logs, hasLength(3));
      expect(logs.first.activityName, 'Focus');
      expect(logs.last.activityName, 'Focus');

      expect(goals, hasLength(2));
      expect(goals.first.activityName, 'Focus');
      expect(goals.last.activityName, 'Workout');
    });

    test('loadDataFromPrefs does not load default data when flag is 0',
            () async {
          SharedPreferences.setMockInitialValues({});

          final data = await HomePage.loadDataFromPrefs(0);
          final activities = data['activities'] as List<Activity>;

          expect(activities, hasLength(0));
        });

    test('loadDataFromPrefs loads default data on first launch (flag 1)',
            () async {
          SharedPreferences.setMockInitialValues({});

          final data = await HomePage.loadDataFromPrefs(1);
          final activities = data['activities'] as List<Activity>;

          expect(activities, hasLength(2));
          expect(activities.first.name, 'Focus');
          expect(activities.last.name, 'Workout');
        });
  });

  group('HomePage State Logic (Updates)', () {
    setUp(() async {
      await setupMockPrefs();
    });

    testWidgets('handleRenameActivity updates activity, logs, and goals',
            (WidgetTester tester) async {
          await pumpHomePage(tester);

          final state = homePageKey.currentState!;
          expect(state, isNotNull);

          expect(state.activities.firstWhere((a) => a.name == 'Focus'), isNotNull);
          expect(
              state.activityLogs.where((l) => l.activityName == 'Focus').length, 2);
          expect(state.goals.where((g) => g.activityName == 'Focus').length, 1);

          expect(
              state.activities.firstWhere((a) => a.name == 'Deep Work',
                  orElse: () => TimedActivity(name: "dummy")),
              isA<TimedActivity>().having((a) => a.name, 'name', 'dummy'));

          final activityToRename =
          state.activities.firstWhere((a) => a.name == 'Focus');
          const newName = 'Deep Work';

          await tester.runAsync(() async {
            state.handleRenameActivity(activityToRename, newName);
          });

          await tester.pump();

          expect(
              state.activities.firstWhere((a) => a.name == 'Deep Work',
                  orElse: () => TimedActivity(name: "dummy")),
              isA<TimedActivity>().having((a) => a.name, 'name', 'Deep Work'));
          expect(
              state.activities.firstWhere((a) => a.name == 'Focus',
                  orElse: () => TimedActivity(name: "dummy")),
              isA<TimedActivity>().having((a) => a.name, 'name', 'dummy'));

          expect(
              state.activityLogs.where((l) => l.activityName == 'Deep Work').length,
              2);
          expect(state.activityLogs.where((l) => l.activityName == 'Focus').length, 0);

          expect(state.goals.where((g) => g.activityName == 'Deep Work').length, 1);
          expect(state.goals.where((g) => g.activityName == 'Focus').length, 0);

          expect(state.activities.firstWhere((a) => a.name == 'Workout'), isNotNull);
          expect(
              state.activityLogs.where((l) => l.activityName == 'Workout').length, 1);
          expect(state.goals.where((g) => g.activityName == 'Workout').length, 1);
        });
  });
}