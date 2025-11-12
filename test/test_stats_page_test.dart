import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/stats_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final twoDaysAgo = today.subtract(const Duration(days: 2));
  final fiveDaysAgo = today.subtract(const Duration(days: 5));

  final timedActivity = TimedActivity(name: 'Work');
  final checkableActivity = CheckableActivity(name: 'Gym');
  final activities = [timedActivity, checkableActivity];

  group('HistoryDataProvider.getCurrentStreak', () {
    testWidgets('Streak = 0 when no logs or goals exist', (tester) async {
      final provider = HistoryDataProvider(
        goals: [],
        activityLogs: [],
        activities: activities,
      );

      final streak = await provider.getCurrentStreak(null);
      expect(streak, 0);
    });

    testWidgets(
        'Streak counts log days when no goals exist ("log anything" mode)',
            (tester) async {
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: today.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
            ActivityLog(
                activityName: 'Work',
                date: yesterday.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: [],
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 2);
        });

    testWidgets('Streak = 1 when log exists today, but not yesterday',
            (tester) async {
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: today.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
            ActivityLog(
                activityName: 'Work',
                date: twoDaysAgo.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: [],
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 1);
        });

    testWidgets('Streak = 0 when log exists yesterday, but not today',
            (tester) async {
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: yesterday.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: [],
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 0);
        });

    testWidgets('Streak counts days when all active daily goals are met',
            (tester) async {
          final goals = [
            Goal(
              activityName: 'Work',
              goalDuration: const Duration(hours: 1),
              goalType: GoalType.daily,
              startDate: fiveDaysAgo,
            ),
          ];
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: today.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
            ActivityLog(
                activityName: 'Work',
                date: yesterday.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: goals,
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 2);
        });

    testWidgets('Streak breaks when a daily goal is not met',
            (tester) async {
          final goals = [
            Goal(
              activityName: 'Work',
              goalDuration: const Duration(hours: 1),
              goalType: GoalType.daily,
              startDate: fiveDaysAgo,
            ),
          ];
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: today.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
            ActivityLog(
                activityName: 'Work',
                date: yesterday.add(const Duration(hours: 10)),
                duration: const Duration(minutes: 30)),
          ];
          final provider = HistoryDataProvider(
            goals: goals,
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 1);
        });

    testWidgets(
        'Streak breaks when ONE of multiple daily goals is not met',
            (tester) async {
          final goals = [
            Goal(
              activityName: 'Work',
              goalDuration: const Duration(hours: 1),
              goalType: GoalType.daily,
              startDate: fiveDaysAgo,
            ),
            Goal(
              activityName: 'Gym',
              goalDuration: const Duration(minutes: 1),
              goalType: GoalType.daily,
              startDate: fiveDaysAgo,
            ),
          ];
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: today.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
            ActivityLog(
                activityName: 'Gym',
                date: today.add(const Duration(hours: 12)),
                duration: Duration.zero,
                isCheckable: true),
            ActivityLog(
                activityName: 'Work',
                date: yesterday.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: goals,
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 1);
        });

    testWidgets(
        'Streak continues on "free days" (no active goals)',
            (tester) async {
          final goals = [
            Goal(
              activityName: 'Work',
              goalDuration: const Duration(hours: 1),
              goalType: GoalType.daily,
              startDate: fiveDaysAgo,
              endDate: yesterday.subtract(const Duration(seconds: 1)),
            ),
          ];
          final logs = [
            ActivityLog(
                activityName: 'Work',
                date: twoDaysAgo.add(const Duration(hours: 10)),
                duration: const Duration(hours: 1)),
          ];
          final provider = HistoryDataProvider(
            goals: goals,
            activityLogs: logs,
            activities: activities,
          );

          final streak = await provider.getCurrentStreak(null);
          expect(streak, 3);
        });

    testWidgets('Streak filters correctly by activity', (tester) async {
      final goals = [
        Goal(
          activityName: 'Work',
          goalDuration: const Duration(hours: 1),
          goalType: GoalType.daily,
          startDate: fiveDaysAgo,
        ),
        Goal(
          activityName: 'Gym',
          goalDuration: const Duration(minutes: 1),
          goalType: GoalType.daily,
          startDate: fiveDaysAgo,
        ),
      ];
      final logs = [
        ActivityLog(
            activityName: 'Work',
            date: today.add(const Duration(hours: 10)),
            duration: const Duration(hours: 1)),
        ActivityLog(
            activityName: 'Gym',
            date: today.add(const Duration(hours: 12)),
            duration: Duration.zero,
            isCheckable: true),
        ActivityLog(
            activityName: 'Work',
            date: yesterday.add(const Duration(hours: 10)),
            duration: const Duration(hours: 1)),
      ];
      final provider = HistoryDataProvider(
        goals: goals,
        activityLogs: logs,
        activities: activities,
      );

      final streakAll = await provider.getCurrentStreak(null);
      expect(streakAll, 1, reason: 'All activities - Gym was missed yesterday');

      final streakWork = await provider.getCurrentStreak('Work');
      expect(streakWork, 2,
          reason: 'Work only - goal met today and yesterday');

      final streakGym = await provider.getCurrentStreak('Gym');
      expect(streakGym, 1,
          reason: 'Gym only - goal met today, not yesterday');
    });
  });
}