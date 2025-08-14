import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/history_page.dart';
import 'package:lockin/utils/ad_manager.dart';

import 'mock_ad_manager.dart';

Map<DateTime, Map<String, dynamic>> calculateGoalProgressIsolate(Map<String, dynamic> params) {
  final logs = params['logs'] as List<ActivityLog>;
  final goals = params['goals'] as List<Goal>;
  final today = params['selectedDate'] as DateTime;
  final selectedPeriod = params['selectedPeriod'] as HistoryPeriod;

  final dayData = <DateTime, Duration>{};
  final checkableCompletions = <DateTime, int>{};
  for (var log in logs) {
    final day = DateTime(log.date.year, log.date.month, log.date.day);
    dayData[day] = (dayData[day] ?? Duration.zero) + log.duration;
    if (log.isCheckable) {
      checkableCompletions[day] = (checkableCompletions[day] ?? 0) + 1;
    }
  }

  final progress = <DateTime, Map<String, dynamic>>{};
  DateTime minDate;
  switch (selectedPeriod) {
    case HistoryPeriod.week:
      minDate = today.subtract(const Duration(days: 7));
      break;
    case HistoryPeriod.month:
      minDate = today.subtract(const Duration(days: 30));
      break;
    case HistoryPeriod.threeMonths:
      minDate = today.subtract(const Duration(days: 90));
      break;
    case HistoryPeriod.allTime:
      minDate = logs.isNotEmpty
          ? logs.map((log) => DateTime(log.date.year, log.date.month, log.date.day)).reduce((a, b) => a.isBefore(b) ? a : b)
          : DateTime(2000);
      break;
  }

  final daysDiff = today.difference(minDate).inDays;
  final goalCache = <String, List<ActivityLog>>{};

  for (int i = 0; i <= daysDiff; i++) {
    final day = today.subtract(Duration(days: i));
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayKey = dayStart;

    final weekDay = day.weekday;
    final weekStart = DateTime(day.year, day.month, day.day - weekDay + 1);
    final weekEnd = weekStart.add(const Duration(days: 7));

    final monthStart = DateTime(day.year, day.month, 1);
    final monthEnd = DateTime(day.year, day.month + 1, 1);

    for (var goal in goals.where((g) => g.goalDuration > Duration.zero && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart)))) {
      if (!goalCache.containsKey(goal.activityName)) {
        goalCache[goal.activityName] = logs.where((log) => log.activityName == goal.activityName).toList();
      }
    }

    int completedDailyGoals = 0;
    int totalDailyGoals = goals.where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.daily && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).length;

    int completedWeeklyGoals = 0;
    int totalWeeklyGoals = goals.where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.weekly && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).length;

    int completedMonthlyGoals = 0;
    int totalMonthlyGoals = goals.where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.monthly && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).length;

    for (var goal in goals.where((g) => g.goalDuration > Duration.zero && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart)))) {
      DateTime periodStart, periodEnd;
      switch (goal.goalType) {
        case GoalType.daily:
          periodStart = dayStart;
          periodEnd = dayEnd;
          break;
        case GoalType.weekly:
          periodStart = weekStart;
          periodEnd = weekEnd;
          break;
        case GoalType.monthly:
          periodStart = monthStart;
          periodEnd = monthEnd;
          break;
      }

      final activityLogsInPeriod = goalCache[goal.activityName]!.where((log) => !log.date.isBefore(periodStart) && log.date.isBefore(periodEnd)).toList();
      bool isCompleted = false;
      if (activityLogsInPeriod.isNotEmpty) {
        if (activityLogsInPeriod.any((log) => log.isCheckable)) {
          final completions = activityLogsInPeriod.where((log) => log.isCheckable).length;
          if (completions >= goal.goalDuration.inMinutes) {
            isCompleted = true;
          }
        } else {
          final totalTime = activityLogsInPeriod.fold<Duration>(Duration.zero, (sum, log) => sum + log.duration);
          if (totalTime >= goal.goalDuration) {
            isCompleted = true;
          }
        }
      }

      if (isCompleted) {
        if (goal.goalType == GoalType.daily) completedDailyGoals++;
        else if (goal.goalType == GoalType.weekly) completedWeeklyGoals++;
        else if (goal.goalType == GoalType.monthly) completedMonthlyGoals++;
      }
    }

    progress[dayKey] = {
      'completedDailyGoals': completedDailyGoals,
      'totalDailyGoals': totalDailyGoals,
      'dailyColor': totalDailyGoals == 0 ? Colors.grey : completedDailyGoals == totalDailyGoals ? Colors.green : completedDailyGoals > 0 ? Colors.yellow : Colors.red,
      'completedWeeklyGoals': completedWeeklyGoals,
      'totalWeeklyGoals': totalWeeklyGoals,
      'weeklyColor': totalWeeklyGoals == 0 ? Colors.grey : completedWeeklyGoals == totalWeeklyGoals ? Colors.green : completedWeeklyGoals > 0 ? Colors.yellow : Colors.red,
      'completedMonthlyGoals': completedMonthlyGoals,
      'totalMonthlyGoals': totalMonthlyGoals,
      'monthlyColor': totalMonthlyGoals == 0 ? Colors.grey : completedMonthlyGoals == totalMonthlyGoals ? Colors.green : completedMonthlyGoals > 0 ? Colors.yellow : Colors.red,
      'duration': dayData[dayKey] ?? Duration.zero,
      'checkableCompletions': checkableCompletions[dayKey] ?? 0,
    };
  }
  return progress;
}

void main() {
  final realAdManager = AdManager.instance;
  setUpAll(() {
    AdManager.instance = MockAdManager();
  });

  tearDownAll(() {
    AdManager.instance = realAdManager;
  });

  group('History Page - Unit Tests (calculateGoalProgressIsolate)', () {
    final today = DateTime(2025, 8, 14);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(const Duration(days: 3));
    final lastMonth = today.subtract(const Duration(days: 30));

    final logs = [
      ActivityLog(activityName: 'Focus', date: today, duration: const Duration(hours: 1), isCheckable: false),
      ActivityLog(activityName: 'Workout', date: today, duration: Duration.zero, isCheckable: true),
      ActivityLog(activityName: 'Focus', date: yesterday, duration: const Duration(hours: 2), isCheckable: false),
      ActivityLog(activityName: 'Focus', date: startOfWeek, duration: const Duration(hours: 4), isCheckable: false),
      ActivityLog(activityName: 'Read', date: lastMonth, duration: const Duration(minutes: 45), isCheckable: false),
    ];

    test('should correctly calculate fully completed daily goals', () {
      final goals = [
        Goal(activityName: 'Focus', goalDuration: const Duration(hours: 1), startDate: today, goalType: GoalType.daily),
        Goal(activityName: 'Workout', goalDuration: const Duration(minutes: 1), startDate: today, goalType: GoalType.daily),
      ];
      final params = {'logs': logs, 'goals': goals, 'selectedDate': today, 'selectedPeriod': HistoryPeriod.allTime};
      final result = calculateGoalProgressIsolate(params);
      final todayData = result[DateTime(today.year, today.month, today.day)];

      expect(todayData!['completedDailyGoals'], 2);
    });

    test('should correctly calculate partially completed daily goals', () {
      final goals = [
        Goal(activityName: 'Focus', goalDuration: const Duration(hours: 1), startDate: today, goalType: GoalType.daily),
        Goal(activityName: 'Workout', goalDuration: const Duration(minutes: 2), startDate: today, goalType: GoalType.daily),
      ];
      final params = {'logs': logs, 'goals': goals, 'selectedDate': today, 'selectedPeriod': HistoryPeriod.allTime};
      final result = calculateGoalProgressIsolate(params);
      final todayData = result[DateTime(today.year, today.month, today.day)];

      expect(todayData!['completedDailyGoals'], 1);
    });

    test('should correctly calculate weekly and monthly goals', () {
      final goals = [
        Goal(activityName: 'Focus', goalDuration: const Duration(hours: 5), startDate: startOfWeek, goalType: GoalType.weekly),
        Goal(activityName: 'Read', goalDuration: const Duration(hours: 1), startDate: lastMonth, goalType: GoalType.monthly),
      ];
      final params = {'logs': logs, 'goals': goals, 'selectedDate': today, 'selectedPeriod': HistoryPeriod.allTime};
      final result = calculateGoalProgressIsolate(params);
      final todayData = result[DateTime(today.year, today.month, today.day)];

      expect(todayData!['completedWeeklyGoals'], 1);
    });
  });
}