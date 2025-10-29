import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/stats_page.dart';
import 'package:lockin/utils/format_utils.dart';

void main() {
  final testActivities = [
    TimedActivity(name: 'Reading'),
    CheckableActivity(name: 'Drink Water'),
    TimedActivity(name: 'Workout'),
  ];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dayBeforeYesterday = today.subtract(const Duration(days: 2));

  group('HistoryDataProvider (Public API)', () {
    group('getGoalStatusesForPeriod', () {
      final goals = [
        Goal(
            activityName: 'Reading',
            goalDuration: const Duration(minutes: 30),
            goalType: GoalType.daily,
            startDate: today.subtract(const Duration(days: 5))),
        Goal(
            activityName: 'Workout',
            goalDuration: const Duration(hours: 3),
            goalType: GoalType.weekly,
            startDate: today.subtract(const Duration(days: 30))),
        Goal(
            activityName: 'Drink Water',
            goalDuration: const Duration(minutes: 8),
            goalType: GoalType.daily,
            startDate: today.subtract(const Duration(days: 2)),
            endDate: today.subtract(const Duration(days: 1))),
      ];

      final logs = [
        ActivityLog(
            activityName: 'Reading',
            date: yesterday,
            duration: const Duration(minutes: 40)),
        ActivityLog(
            activityName: 'Reading',
            date: dayBeforeYesterday,
            duration: const Duration(minutes: 10)),
      ];

      final provider = HistoryDataProvider(
          goals: goals, activityLogs: logs, activities: testActivities);

      test('should compute statuses for all goal types', () async {
        final statuses = await provider.getGoalStatusesForPeriod(
            today.subtract(const Duration(days: 7)), today, null);

        final dailyReading =
        statuses.where((s) => s['goal'] == goals[0]).toList();
        final weeklyWorkout =
        statuses.where((s) => s['goal'] == goals[1]).toList();
        final dailyWater =
        statuses.where((s) => s['goal'] == goals[2]).toList();

        expect(dailyReading.length, 6);
        expect(weeklyWorkout.length, 2);
        expect(dailyWater.length, 1);

        expect(
            dailyReading
                .firstWhere((s) => s['date'] == yesterday)['status'],
            'successful');
        expect(
            dailyReading
                .firstWhere((s) => s['date'] == dayBeforeYesterday)['status'],
            'failed');
      });

      test('should filter by selectedActivity', () async {
        final statuses = await provider.getGoalStatusesForPeriod(
            today.subtract(const Duration(days: 7)), today, 'Reading');
        expect(
            statuses.every((s) => s['goal'].activityName == 'Reading'), isTrue);
        expect(statuses.length, 6);
      });

      test('should respect goal start and end dates', () async {
        final statuses = await provider.getGoalStatusesForPeriod(
            today.subtract(const Duration(days: 7)), today, null);
        final dailyWater =
        statuses.where((s) => s['goal'] == goals[2]).toList();

        expect(dailyWater.length, 1);
        expect(dailyWater.first['date'],
            today.subtract(const Duration(days: 2)));
      });
    });

    group('getCurrentStreak (from HistoryDataProvider)', () {
      test('should return 0 for no goals and no logs', () async {
        final provider = HistoryDataProvider(
            goals: [], activityLogs: [], activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 0);
      });

      test('should return 1 for no goals and one log today', () async {
        final logs = [
          ActivityLog(
              activityName: 'Reading',
              date: now,
              duration: const Duration(minutes: 10))
        ];
        final provider = HistoryDataProvider(
            goals: [], activityLogs: logs, activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 1);
      });

      test('should return 2 for no goals and logs yesterday and today',
              () async {
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: now,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 10)),
            ];
            final provider = HistoryDataProvider(
                goals: [], activityLogs: logs, activities: testActivities);
            final streak = await provider.getCurrentStreak(null);
            expect(streak, 2);
          });

      test('should return 0 for no goals and log yesterday but not today',
              () async {
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 10)),
            ];
            final provider = HistoryDataProvider(
                goals: [], activityLogs: logs, activities: testActivities);
            final streak = await provider.getCurrentStreak(null);
            expect(streak, 0);
          });

      test('should return 1 for one successful daily goal today', () async {
        final goals = [
          Goal(
              activityName: 'Reading',
              goalDuration: const Duration(minutes: 30),
              goalType: GoalType.daily,
              startDate: yesterday)
        ];
        final logs = [
          ActivityLog(
              activityName: 'Reading',
              date: now,
              duration: const Duration(minutes: 30))
        ];
        final provider = HistoryDataProvider(
            goals: goals, activityLogs: logs, activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 1);
      });

      test('should return 0 for one failed daily goal today', () async {
        final goals = [
          Goal(
              activityName: 'Reading',
              goalDuration: const Duration(minutes: 30),
              goalType: GoalType.daily,
              startDate: yesterday)
        ];
        final logs = [
          ActivityLog(
              activityName: 'Reading',
              date: now,
              duration: const Duration(minutes: 10))
        ];
        final provider = HistoryDataProvider(
            goals: goals, activityLogs: logs, activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 0);
      });

      test('should return 2 for successful daily goals yesterday and today',
              () async {
            final goals = [
              Goal(
                  activityName: 'Reading',
                  goalDuration: const Duration(minutes: 30),
                  goalType: GoalType.daily,
                  startDate: dayBeforeYesterday)
            ];
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: now,
                  duration: const Duration(minutes: 30)),
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 30)),
            ];
            final provider = HistoryDataProvider(
                goals: goals, activityLogs: logs, activities: testActivities);
            final streak = await provider.getCurrentStreak(null);
            expect(streak, 2);
          });

      test('should return 0 for successful yesterday, failed today',
              () async {
            final goals = [
              Goal(
                  activityName: 'Reading',
                  goalDuration: const Duration(minutes: 30),
                  goalType: GoalType.daily,
                  startDate: dayBeforeYesterday)
            ];
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: now,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 30)),
            ];
            final provider = HistoryDataProvider(
                goals: goals, activityLogs: logs, activities: testActivities);
            final streak = await provider.getCurrentStreak(null);
            expect(streak, 0);
          });

      test('should return 0 if one of two daily goals failed', () async {
        final goals = [
          Goal(
              activityName: 'Reading',
              goalDuration: const Duration(minutes: 30),
              goalType: GoalType.daily,
              startDate: yesterday),
          Goal(
              activityName: 'Workout',
              goalDuration: const Duration(minutes: 20),
              goalType: GoalType.daily,
              startDate: yesterday),
        ];
        final logs = [
          ActivityLog(
              activityName: 'Reading',
              date: now,
              duration: const Duration(minutes: 30)),
          ActivityLog(
              activityName: 'Workout',
              date: now,
              duration: const Duration(minutes: 10)),
        ];
        final provider = HistoryDataProvider(
            goals: goals, activityLogs: logs, activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 0);
      });

      test('should return 1 if both daily goals succeeded', () async {
        final goals = [
          Goal(
              activityName: 'Reading',
              goalDuration: const Duration(minutes: 30),
              goalType: GoalType.daily,
              startDate: yesterday),
          Goal(
              activityName: 'Workout',
              goalDuration: const Duration(minutes: 20),
              goalType: GoalType.daily,
              startDate: yesterday),
        ];
        final logs = [
          ActivityLog(
              activityName: 'Reading',
              date: now,
              duration: const Duration(minutes: 30)),
          ActivityLog(
              activityName: 'Workout',
              date: now,
              duration: const Duration(minutes: 20)),
        ];
        final provider = HistoryDataProvider(
            goals: goals, activityLogs: logs, activities: testActivities);
        final streak = await provider.getCurrentStreak(null);
        expect(streak, 1);
      });

      test(
          'should return 2 if goal succeeded yesterday and no goals are active today',
              () async {
            final goals = [
              Goal(
                  activityName: 'Reading',
                  goalDuration: const Duration(minutes: 30),
                  goalType: GoalType.daily,
                  startDate: dayBeforeYesterday,
                  endDate: yesterday),
            ];
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 30)),
            ];
            final provider = HistoryDataProvider(
                goals: goals, activityLogs: logs, activities: testActivities);
            final streak = await provider.getCurrentStreak(null);
            expect(streak, 2);
          });
    });
  });

  group('StatsPage Widget', () {
    Widget buildTestWidget({
      required List<ActivityLog> logs,
      required List<Activity> activities,
      required List<Goal> goals,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: StatsPage(
            activityLogs: logs,
            activities: activities,
            goals: goals,
            launchCount: 1,
          ),
        ),
      );
    }

    group('Goal Stats (Streaks)', () {
      testWidgets('should display current and longest streak correctly',
              (tester) async {
            final goals = [
              Goal(
                  activityName: 'Reading',
                  goalDuration: const Duration(minutes: 10),
                  goalType: GoalType.daily,
                  startDate: today.subtract(const Duration(days: 10)))
            ];
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: today,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: yesterday,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: dayBeforeYesterday,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 4)),
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 5)),
                  duration: const Duration(minutes: 10)),
            ];

            await tester.pumpWidget(
                buildTestWidget(logs: logs, activities: testActivities, goals: goals));
            await tester.pumpAndSettle();

            final currentStreakCard = find.ancestor(
              of: find.text('Current Streak'),
              matching: find.byType(Card),
            );
            final longestStreakCard = find.ancestor(
              of: find.text('Longest Streak'),
              matching: find.byType(Card),
            );

            expect(find.descendant(
                of: currentStreakCard, matching: find.text('3 days')), findsOneWidget);
            expect(find.descendant(
                of: longestStreakCard, matching: find.text('3 days')), findsOneWidget);
          });

      testWidgets(
          'should display longest streak when it is not the current streak',
              (tester) async {
            final goals = [
              Goal(
                  activityName: 'Reading',
                  goalDuration: const Duration(minutes: 10),
                  goalType: GoalType.daily,
                  startDate: today.subtract(const Duration(days: 10)))
            ];
            final logs = [
              ActivityLog(
                  activityName: 'Reading',
                  date: today,
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 2)),
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 3)),
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 4)),
                  duration: const Duration(minutes: 10)),
              ActivityLog(
                  activityName: 'Reading',
                  date: today.subtract(const Duration(days: 5)),
                  duration: const Duration(minutes: 10)),
            ];

            await tester.pumpWidget(
                buildTestWidget(logs: logs, activities: testActivities, goals: goals));
            await tester.pumpAndSettle();

            final currentStreakCard = find.ancestor(
              of: find.text('Current Streak'),
              matching: find.byType(Card),
            );
            final longestStreakCard = find.ancestor(
              of: find.text('Longest Streak'),
              matching: find.byType(Card),
            );

            expect(find.descendant(
                of: currentStreakCard, matching: find.text('1 days')), findsOneWidget);
            expect(find.descendant(
                of: longestStreakCard, matching: find.text('4 days')), findsOneWidget);

            final expectedDate = today.subtract(const Duration(days: 5)).toString().split(' ')[0];
            expect(find.text('Started $expectedDate'), findsOneWidget);
          });
    });

    group('Chart Data', () {
      final weekStart = today.subtract(Duration(days: now.weekday - 1));
      final logs = [
        ActivityLog(
            activityName: 'Reading',
            date: weekStart,
            duration: const Duration(minutes: 10)),
        ActivityLog(
            activityName: 'Reading',
            date: weekStart.add(const Duration(days: 2)),
            duration: const Duration(minutes: 20)),
        ActivityLog(
            activityName: 'Drink Water',
            date: weekStart,
            duration: Duration.zero,
            isCheckable: true),
        ActivityLog(
            activityName: 'Drink Water',
            date: weekStart,
            duration: Duration.zero,
            isCheckable: true),
        ActivityLog(
            activityName: 'Drink Water',
            date: weekStart.add(const Duration(days: 1)),
            duration: Duration.zero,
            isCheckable: true),
      ];

      testWidgets('getTimedChartData formats for Week', (tester) async {
        await tester.pumpWidget(
            buildTestWidget(logs: logs, activities: testActivities, goals: []));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ButtonSegment, 'Week'));
        await tester.pumpAndSettle();

        final timedChartFinder = find.ancestor(
          of: find.text('Time Spent Per Day (min)'),
          matching: find.byType(Card),
        );
        final timedChart = tester.widget<BarChart>(find.descendant(
          of: timedChartFinder,
          matching: find.byType(BarChart),
        ));

        final chartData = timedChart.data.barGroups;
        expect(chartData.length, 7);
        expect(chartData[0].barRods.first.toY, 10.0);
        expect(chartData[1].barRods.first.toY, 0.0);
        expect(chartData[2].barRods.first.toY, 20.0);
      });

      testWidgets('getCheckableChartData formats for Week', (tester) async {
        await tester.pumpWidget(
            buildTestWidget(logs: logs, activities: testActivities, goals: []));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ButtonSegment, 'Week'));
        await tester.pumpAndSettle();

        final checkableChartFinder = find.ancestor(
          of: find.text('Completions Per Day'),
          matching: find.byType(Card),
        );
        final checkableChart = tester.widget<BarChart>(find.descendant(
          of: checkableChartFinder,
          matching: find.byType(BarChart),
        ));

        final chartData = checkableChart.data.barGroups;
        expect(chartData.length, 7);
        expect(chartData[0].barRods.first.toY, 2.0);
        expect(chartData[1].barRods.first.toY, 1.0);
        expect(chartData[2].barRods.first.toY, 0.0);
      });
    });

    group('Filtered Activities Totals', () {
      final weekStart = today.subtract(Duration(days: now.weekday - 1));
      final logs = [
        ActivityLog(
            activityName: 'Reading',
            date: weekStart,
            duration: const Duration(minutes: 10)),
        ActivityLog(
            activityName: 'Reading',
            date: weekStart.subtract(const Duration(days: 1)),
            duration: const Duration(minutes: 50)),
        ActivityLog(
            activityName: 'Drink Water',
            date: weekStart,
            duration: Duration.zero,
            isCheckable: true),
        ActivityLog(
            activityName: 'Workout',
            date: weekStart,
            duration: const Duration(minutes: 30)),
      ];

      testWidgets('should filter correctly for Week period', (tester) async {
        await tester.pumpWidget(
            buildTestWidget(logs: logs, activities: testActivities, goals: []));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ButtonSegment, 'Week'));
        await tester.pumpAndSettle();

        final timedTile = find.ancestor(
            of: find.text('Total Activity Time'),
            matching: find.byType(ListTile));
        expect(
            find.descendant(
                of: timedTile,
                matching: find.text(formatDuration(const Duration(minutes: 40)))),
            findsOneWidget);

        final checkableTile = find.ancestor(
            of: find.text('Total Completions'),
            matching: find.byType(ListTile));
        expect(find.descendant(of: checkableTile, matching: find.text('1')),
            findsOneWidget);
      });

      testWidgets('should filter correctly for Total period', (tester) async {
        await tester.pumpWidget(
            buildTestWidget(logs: logs, activities: testActivities, goals: []));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ButtonSegment, 'Total'));
        await tester.pumpAndSettle();

        final timedTile = find.ancestor(
            of: find.text('Total Activity Time'),
            matching: find.byType(ListTile));
        expect(
            find.descendant(
                of: timedTile,
                matching: find.text(formatDuration(const Duration(minutes: 90)))),
            findsOneWidget);
      });

      testWidgets('should filter correctly with selectedActivity',
              (tester) async {
            await tester.pumpWidget(
                buildTestWidget(logs: logs, activities: testActivities, goals: []));
            await tester.pumpAndSettle();

            await tester.tap(find.widgetWithText(ButtonSegment, 'Total'));
            await tester.pumpAndSettle();

            await tester.tap(find.text('All Activities'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Reading').last);
            await tester.pumpAndSettle();

            final timedTile = find.ancestor(
                of: find.text('Time for Reading'),
                matching: find.byType(ListTile));
            expect(
                find.descendant(
                    of: timedTile,
                    matching: find.text(formatDuration(const Duration(minutes: 60)))),
                findsOneWidget);

            expect(find.text('Completions for Reading'), findsNothing);
          });
    });
  });
}