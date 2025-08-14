import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/stats_page.dart';

void main() {
  final mockActivities = [
    TimedActivity(name: 'Focus'),
    CheckableActivity(name: 'Drink water'),
    TimedActivity(name: 'Reading'),
  ];

  final today = DateTime(2025, 8, 14);
  final yesterday = today.subtract(const Duration(days: 1));
  final dayBeforeYesterday = today.subtract(const Duration(days: 2));
  final lastWeek = today.subtract(const Duration(days: 7));
  final lastMonth = DateTime(today.year, today.month - 1, today.day);

  group('StatsPage Tests', () {
    testWidgets('displays correct data for daily view with mixed activities', (tester) async {
      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 20), isCheckable: false),
        ActivityLog(activityName: 'Drink water', date: today, isCheckable: true, duration: Duration.zero),
        ActivityLog(activityName: 'Drink water', date: today, isCheckable: true, duration: Duration.zero),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: const [],
            launchCount: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<StatsPeriod>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Day').last);
      await tester.pumpAndSettle();

      expect(find.text('⏰ Total activity time: 00:20:00'), findsOneWidget);
      expect(find.text('✅ Total completions: 2'), findsOneWidget);
    });

    testWidgets('displays correct data for weekly view', (tester) async {
      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 30), isCheckable: false),
        ActivityLog(activityName: 'Focus', date: yesterday, duration: const Duration(minutes: 15), isCheckable: false),
        ActivityLog(activityName: 'Drink water', date: today, isCheckable: true, duration: Duration.zero),
        ActivityLog(activityName: 'Reading', date: lastWeek, duration: const Duration(minutes: 60), isCheckable: false),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: const [],
            launchCount: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<StatsPeriod>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week').last);
      await tester.pumpAndSettle();

      expect(find.text('⏰ Total activity time: 00:45:00'), findsOneWidget);
      expect(find.text('✅ Total completions: 1'), findsOneWidget);
    });

    testWidgets('displays correct data for total view', (tester) async {
      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 30), isCheckable: false),
        ActivityLog(activityName: 'Reading', date: lastMonth, duration: const Duration(minutes: 60), isCheckable: false),
        ActivityLog(activityName: 'Drink water', date: lastWeek, isCheckable: true, duration: Duration.zero),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: const [],
            launchCount: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('⏰ Total activity time: 01:30:00'), findsOneWidget);
      expect(find.text('✅ Total completions: 1'), findsOneWidget);
    });

    testWidgets('filters data when an activity is selected', (tester) async {
      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 10), isCheckable: false),
        ActivityLog(activityName: 'Reading', date: today, duration: const Duration(minutes: 25), isCheckable: false),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: const [],
            launchCount: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Focus').last);
      await tester.pumpAndSettle();

      expect(find.text('⏰ Time for Focus: 00:10:00'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays no data messages when logs are empty', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: const [],
            activities: mockActivities,
            goals: const [],
            launchCount: 1,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No timed activity data for this period.'), findsOneWidget);
      expect(find.text('No completion data for this period.'), findsOneWidget);
      expect(find.text('⏰ Total activity time: 00:00:00'), findsOneWidget);
      expect(find.text('✅ Total completions: 0'), findsOneWidget);
    });

    testWidgets('correctly calculates and displays goal statistics', (tester) async {
      final goals = [
        Goal(
            activityName: 'Focus',
            goalType: GoalType.daily,
            goalDuration: const Duration(minutes: 15),
            startDate: dayBeforeYesterday,
            endDate: null),
      ];
      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 20), isCheckable: false),
        ActivityLog(activityName: 'Focus', date: yesterday, duration: const Duration(minutes: 20), isCheckable: false),
        ActivityLog(activityName: 'Focus', date: dayBeforeYesterday, duration: const Duration(minutes: 10), isCheckable: false),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: goals,
            launchCount: 1,
          ),
        ),
      ));

      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final allTexts = find.byType(Text);
      for (int i = 0; i < allTexts.evaluate().length; i++) {
        final widget = allTexts.evaluate().elementAt(i).widget as Text;
      }


      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.textContaining('Goals Completed'), findsOneWidget);
      expect(find.textContaining('Current Streak'), findsOneWidget);
      expect(find.textContaining('Longest Streak'), findsOneWidget);
    });

    testWidgets('correctly calculates longest streak when current streak is shorter', (tester) async {
      final goals = [
        Goal(
            activityName: 'Focus',
            goalType: GoalType.daily,
            goalDuration: const Duration(minutes: 15),
            startDate: today.subtract(const Duration(days: 10)),
            endDate: null),
      ];

      final logs = [
        ActivityLog(activityName: 'Focus', date: today, duration: const Duration(minutes: 20), isCheckable: false),


        ActivityLog(activityName: 'Focus', date: today.subtract(const Duration(days: 2)), duration: const Duration(minutes: 20), isCheckable: false),
        ActivityLog(activityName: 'Focus', date: today.subtract(const Duration(days: 3)), duration: const Duration(minutes: 20), isCheckable: false),
        ActivityLog(activityName: 'Focus', date: today.subtract(const Duration(days: 4)), duration: const Duration(minutes: 20), isCheckable: false),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: mockActivities,
            goals: goals,
            launchCount: 1,
          ),
        ),
      ));

      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final allTexts = find.byType(Text);
      for (int i = 0; i < allTexts.evaluate().length; i++) {
        final widget = allTexts.evaluate().elementAt(i).widget as Text;
      }

      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.textContaining('Goals Completed'), findsOneWidget);
      expect(find.textContaining('Current Streak'), findsOneWidget);
      expect(find.textContaining('Longest Streak'), findsOneWidget);
    });
  });
}