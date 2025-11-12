import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';

enum StatsPeriod { week, month, total }

class HistoryDataProvider {
  static final bool _isTesting = Platform.environment.containsKey('FLUTTER_TEST');
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;

  HistoryDataProvider({
    required this.goals,
    required this.activityLogs,
    required this.activities,
  });

  Future<List<Map<String, dynamic>>> getGoalStatusesForPeriod(DateTime start,
      DateTime end, String? selectedActivity) async {
    try {
      final params = {
        'goals': goals,
        'activityLogs': activityLogs,
        'activities': activities,
        'start': start,
        'end': end,
        'selectedActivity': selectedActivity,
      };

      if (_isTesting) {
        return _computeGoalStatusesForPeriod(params);
      } else {
        final result = await compute(_computeGoalStatusesForPeriod, params);
        return result;
      }
    } catch (e, stackTrace) {
      //print("Error computing goal statuses:");
      //print(e);
      //print(stackTrace);
      return [];
    }
  }

  static List<Map<String, dynamic>> _computeGoalStatusesForPeriod(
      Map<String, dynamic> params) {
    final goals = params['goals'] as List<Goal>;
    final activityLogs = params['activityLogs'] as List<ActivityLog>;
    final activities = params['activities'] as List<Activity>;
    final start = params['start'] as DateTime;
    final end = params['end'] as DateTime;
    final selectedActivity = params['selectedActivity'] as String?;

    final logsByActivity = <String, List<ActivityLog>>{};
    for (var log in activityLogs) {
      logsByActivity.putIfAbsent(log.activityName, () => []).add(log);
    }

    final List<Map<String, dynamic>> statuses = [];

    for (var goal in goals.where((g) =>
    g.goalDuration > Duration.zero &&
        (selectedActivity == null || g.activityName == selectedActivity))) {

      final relevantLogs = logsByActivity[goal.activityName] ?? [];

      DateTime iterDate;
      switch (goal.goalType) {
        case GoalType.daily:
          iterDate = DateTime(start.year, start.month, start.day);
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            final dayStart = iterDate;
            final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

            final bool startsTooLate = !goal.startDate.isBefore(dayEnd);
            final bool endedTooEarly = goal.endDate != null && !goal.endDate!.isAfter(dayStart);

            if (startsTooLate || endedTooEarly) {
              iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 1);
              continue;
            }
            statuses.add(_calculateStatusForPeriod(
                goal, relevantLogs, activities, iterDate, dayEnd));
            iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 1);
          }
          break;
        case GoalType.weekly:
          iterDate = start.subtract(Duration(days: start.weekday - 1));
          iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day);
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            final dayStart = iterDate;
            final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 7);

            final bool startsTooLate = !goal.startDate.isBefore(dayEnd);
            final bool endedTooEarly = goal.endDate != null && !goal.endDate!.isAfter(dayStart);

            if (startsTooLate || endedTooEarly) {
              iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 7);
              continue;
            }
            statuses.add(_calculateStatusForPeriod(
                goal, relevantLogs, activities, iterDate, dayEnd));
            iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 7);
          }
          break;
        case GoalType.monthly:
          iterDate = DateTime(start.year, start.month, 1);
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            final dayStart = iterDate;
            final dayEnd = DateTime(iterDate.year, iterDate.month + 1, 1);

            final bool startsTooLate = !goal.startDate.isBefore(dayEnd);
            final bool endedTooEarly = goal.endDate != null && !goal.endDate!.isAfter(dayStart);

            if (startsTooLate || endedTooEarly) {
              iterDate = dayEnd;
              continue;
            }
            statuses.add(_calculateStatusForPeriod(
                goal, relevantLogs, activities, iterDate, dayEnd));
            iterDate = dayEnd;
          }
          break;
      }
    }
    return statuses;
  }

  static Map<String, dynamic> _calculateStatusForPeriod(Goal goal,
      List<ActivityLog> relevantLogs, List<Activity> activities,
      DateTime periodStart, DateTime periodEnd) {

    final activityLogsFiltered = relevantLogs.where((log) =>
    !log.date.isBefore(periodStart) &&
        log.date.isBefore(periodEnd)).toList();

    bool isCheckable = activities.any((a) =>
    a.name == goal.activityName && a is CheckableActivity);

    bool isSuccessful = false;
    if (isCheckable) {
      final completions = activityLogsFiltered
          .where((log) => log.isCheckable)
          .length;
      isSuccessful = completions >= goal.goalDuration.inMinutes;
    } else {
      final totalTime = activityLogsFiltered.fold<Duration>(
          Duration.zero, (sum, log) => sum + log.duration);
      isSuccessful = totalTime >= goal.goalDuration;
    }

    bool isPeriodEnded = periodEnd.isBefore(DateTime.now());
    return {
      'goal': goal,
      'status': isSuccessful ? 'successful' : (isPeriodEnded
          ? 'failed'
          : 'ongoing'),
      'date': periodStart,
    };
  }

  Future<int> getCurrentStreak(String? selectedActivity) async {
    //print('[STREAK DEBUG (getCurrentStreak)] Running...');
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      //print('[STREAK DEBUG (getCurrentStreak)] Today: $today');

      final firstLogDate = activityLogs.isNotEmpty
          ? activityLogs.map((e) =>
          DateTime(e.date.year, e.date.month, e.date.day)).reduce((a, b) =>
      a.isBefore(b) ? a : b)
          : today;
      //print('[STREAK DEBUG (getCurrentStreak)] First log: $firstLogDate');

      final allDailyStatuses = await getGoalStatusesForPeriod(
          firstLogDate, now, selectedActivity)
          .then((statuses) =>
          statuses
              .where((s) => (s['goal'] as Goal).goalType == GoalType.daily)
              .toList());
      //print('[STREAK DEBUG (getCurrentStreak)] Got ${allDailyStatuses.length} daily statuses.');

      final dailyStatusesGrouped = <DateTime, List<Map<String, dynamic>>>{};
      for (var status in allDailyStatuses) {
        final date = status['date'] as DateTime;
        dailyStatusesGrouped.putIfAbsent(date, () => []).add(status);
      }

      final allDailyGoals = goals
          .where((g) => g.goalType == GoalType.daily)
          .toList();
      final dailyStatusByDay = <DateTime, bool>{};

      DateTime iterDate = firstLogDate.isBefore(today) ? firstLogDate : today;
      //print('[STREAK DEBUG (getCurrentStreak)] Starting loop from: $iterDate');

      while (iterDate.isAtSameMomentAs(today) || iterDate.isBefore(today)) {
        final dayStart = iterDate;
        final dayEnd = dayStart.add(const Duration(days: 1));
        bool dayStatus = false;

        final allFilteredDailyGoals = allDailyGoals
            .where((g) => (selectedActivity == null || g.activityName == selectedActivity))
            .toList();

        if (allFilteredDailyGoals.isEmpty) {
          final logsForDay = activityLogs.where((log) =>
          log.date.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
              log.date.isBefore(dayEnd) &&
              (selectedActivity == null || log.activityName == selectedActivity)
          ).toList();

          dayStatus = logsForDay.isNotEmpty;
          if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
            //print('[STREAK DEBUG (getCurrentStreak)] Day: $dayStart. No goals. Logs: ${logsForDay.length}. Status: $dayStatus');
          }
        } else {
          final activeGoalsForDay = allFilteredDailyGoals.where((g) =>
          g.goalDuration > Duration.zero &&
              g.startDate.isBefore(dayEnd) &&
              (g.endDate == null || g.endDate!.isAfter(dayStart))
          ).toList();

          if (activeGoalsForDay.isEmpty) {
            dayStatus = true;
            if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
              //print('[STREAK DEBUG (getCurrentStreak)] Day: $dayStart. Goals exist, 0 active. Status: $dayStatus');
            }
          } else {
            final statusesForDay = dailyStatusesGrouped[dayStart] ?? [];
            final successfulCount = statusesForDay.where((s) => s['status'] == 'successful').length;
            dayStatus = successfulCount == activeGoalsForDay.length;
            if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
              //print('[STREAK DEBUG (getCurrentStreak)] Day: $dayStart. Active goals: ${activeGoalsForDay.length}. Success: $successfulCount. Status: $dayStatus');
            }
          }
        }
        dailyStatusByDay[dayStart] = dayStatus;

        iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 1);
      }
      //print('[STREAK DEBUG (getCurrentStreak)] Loop finished.');

      int currentStreak = 0;
      DateTime currentDate = today;

      while (dailyStatusByDay.containsKey(currentDate) &&
          dailyStatusByDay[currentDate] == true) {
        currentStreak++;
        currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day - 1);
      }
      //print('[STREAK DEBUG (getCurrentStreak)] Final streak: $currentStreak');
      return currentStreak;
    } catch (e, stackTrace) {
      //print('[STREAK DEBUG (getCurrentStreak)] ERROR: $e');
      print(stackTrace);
      return 0;
    }
  }
}

class GoalStatsData {
  final int successful;
  final int ongoing;
  final int currentStreak;
  final int longestStreak;
  final DateTime? longestStreakStart;

  GoalStatsData({
    required this.successful,
    required this.ongoing,
    required this.currentStreak,
    required this.longestStreak,
    this.longestStreakStart,
  });
}

class StatsPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;
  final List<Goal> goals;
  final int launchCount;

  const StatsPage({
    super.key,
    required this.activityLogs,
    required this.activities,
    required this.goals,
    required this.launchCount,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with AutomaticKeepAliveClientMixin {
  StatsPeriod selectedPeriod = StatsPeriod.total;
  String? selectedActivity;
  Future<GoalStatsData>? _goalStatsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchGoalData();
  }

  @override
  void didUpdateWidget(covariant StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals != oldWidget.goals || widget.activityLogs != oldWidget.activityLogs || widget.activities != oldWidget.activities) {
      _fetchGoalData();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _fetchGoalData() {
    setState(() {
      _goalStatsFuture = _getCombinedGoalData();
    });
  }

  Future<GoalStatsData> _getCombinedGoalData() async {
    //print('[STREAK DEBUG (_getCombinedGoalData)] Running...');
    try {
      final historyProvider = HistoryDataProvider(
        goals: widget.goals,
        activityLogs: widget.activityLogs,
        activities: widget.activities,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      //print('[STREAK DEBUG (_getCombinedGoalData)] Today: $today');

      final firstLogDate = widget.activityLogs.isNotEmpty
          ? widget.activityLogs.map((e) => DateTime(e.date.year, e.date.month, e.date.day)).reduce((a, b) => a.isBefore(b) ? a : b)
          : today;
      //print('[STREAK DEBUG (_getCombinedGoalData)] First log: $firstLogDate');

      final allStatuses = await historyProvider.getGoalStatusesForPeriod(firstLogDate, now, selectedActivity);
      //print('[STREAK DEBUG (_getCombinedGoalData)] Got ${allStatuses.length} total statuses.');

      final allDailyStatuses = allStatuses.where((s) => (s['goal'] as Goal).goalType == GoalType.daily).toList();
      final dailyStatusesGrouped = <DateTime, List<Map<String, dynamic>>>{};
      for (var status in allDailyStatuses) {
        final date = status['date'] as DateTime;
        dailyStatusesGrouped.putIfAbsent(date, () => []).add(status);
      }

      final allDailyGoals = widget.goals.where((g) => g.goalType == GoalType.daily).toList();
      //print('[STREAK DEBUG (_getCombinedGoalData)] Found ${allDailyGoals.length} daily goals.');
      final dailyStatusByDay = <DateTime, bool>{};

      DateTime iterDate = firstLogDate.isBefore(today) ? firstLogDate : today;
      //print('[STREAK DEBUG (_getCombinedGoalData)] Starting loop from: $iterDate');

      while (iterDate.isAtSameMomentAs(today) || iterDate.isBefore(today)) {
        final dayStart = iterDate;
        final dayEnd = dayStart.add(const Duration(days: 1));
        bool dayStatus = false;

        final allFilteredDailyGoals = allDailyGoals
            .where((g) => (selectedActivity == null || g.activityName == selectedActivity))
            .toList();

        if (allFilteredDailyGoals.isEmpty) {
          final logsForDay = widget.activityLogs.where((log) =>
          log.date.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
              log.date.isBefore(dayEnd) &&
              (selectedActivity == null || log.activityName == selectedActivity)
          ).toList();

          dayStatus = logsForDay.isNotEmpty;
          if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
            //print('[STREAK DEBUG (_getCombinedGoalData)] Day: $dayStart. No goals. Logs: ${logsForDay.length}. Status: $dayStatus');
          }
        } else {

          final activeGoalsForDay = allFilteredDailyGoals.where((g) =>
          g.goalDuration > Duration.zero &&
              g.startDate.isBefore(dayEnd) &&
              (g.endDate == null || g.endDate!.isAfter(dayStart))
          ).toList();

          if (activeGoalsForDay.isEmpty) {
            dayStatus = true;
            if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
              //print('[STREAK DEBUG (_getCombinedGoalData)] Day: $dayStart. Goals exist, 0 active. Status: $dayStatus');
            }
          } else {
            final statusesForDay = dailyStatusesGrouped[dayStart] ?? [];
            final successfulCount = statusesForDay.where((s) => s['status'] == 'successful').length;
            dayStatus = successfulCount == activeGoalsForDay.length;
            if (dayStart.isAfter(today.subtract(const Duration(days: 5))) || dayStart.isAtSameMomentAs(today)) {
              //print('[STREAK DEBUG (_getCombinedGoalData)] Day: $dayStart. Active goals: ${activeGoalsForDay.length}. Success: $successfulCount. Status: $dayStatus');
            }
          }
        }

        dailyStatusByDay[dayStart] = dayStatus;

        iterDate = DateTime(iterDate.year, iterDate.month, iterDate.day + 1);
      }
      //print('[STREAK DEBUG (_getCombinedGoalData)] Loop finished.');

      int currentStreak = 0;
      DateTime currentDate = today;

      while(dailyStatusByDay.containsKey(currentDate) && dailyStatusByDay[currentDate] == true) {
        //print('[STREAK DEBUG (_getCombinedGoalData)] Counting streak... $currentDate = true');
        currentStreak++;
        currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day - 1);
      }
      if (!dailyStatusByDay.containsKey(currentDate)) {
        //print('[STREAK DEBUG (_getCombinedGoalData)] Streak stopped. No key for: $currentDate');
      } else if (dailyStatusByDay[currentDate] == false) {
        //print('[STREAK DEBUG (_getCombinedGoalData)] Streak stopped. $currentDate = false');
      }
      //print('[STREAK DEBUG (_getCombinedGoalData)] Final currentStreak: $currentStreak');

      int longestStreak = 0;
      DateTime? longestStreakStart;
      int tempStreak = 0;
      DateTime? tempStreakStart;

      final sortedDates = dailyStatusByDay.keys.toList()..sort((a,b) => b.compareTo(a));

      for (var date in sortedDates) {
        if (dailyStatusByDay[date] == true) {
          tempStreak++;
          tempStreakStart ??= date;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
            if (tempStreakStart != null) {
              longestStreakStart = DateTime(tempStreakStart.year, tempStreakStart.month, tempStreakStart.day - (tempStreak - 1));
            }
          }
          tempStreak = 0;
          tempStreakStart = null;
        }
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
        if (tempStreakStart != null) {
          longestStreakStart = DateTime(tempStreakStart.year, tempStreakStart.month, tempStreakStart.day - (tempStreak - 1));
        }
      }
      //print('[STREAK DEBUG (_getCombinedGoalData)] Final longestStreak: $longestStreak');

      int successful = allStatuses.where((s) => s['status'] == 'successful').length;
      int ongoing = allStatuses.where((s) => s['status'] == 'ongoing').length;

      final result = GoalStatsData(
        successful: successful,
        ongoing: ongoing,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        longestStreakStart: longestStreakStart,
      );

      //print('[STREAK DEBUG (_getCombinedGoalData)] Returning data.');
      return result;

    } catch (e, stackTrace) {
      //print('[STREAK DEBUG (_getCombinedGoalData)] CRITICAL ERROR:');
      //print(e);
      //print(stackTrace);
      return GoalStatsData(successful: 0, ongoing: 0, currentStreak: 0, longestStreak: 0);
    }
  }

  List<BarChartGroupData> getTimedChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars = 0;
    DateTime startDate;
    DateTime endDate;

    switch (selectedPeriod) {
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 7));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    for (var log in widget.activityLogs.where((log) => !log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if ((logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) && logDay.isBefore(endDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.week) {
          index = logDay.difference(startDate).inDays;
        } else if (selectedPeriod == StatsPeriod.month) {
          index = ((logDay.difference(startDate).inDays) / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += (log.duration.inSeconds / 60.0);
        }
      }
    }

    final result = totals.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Theme.of(context).colorScheme.primary,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
    return result;
  }

  List<BarChartGroupData> getCheckableChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars;
    DateTime startDate;
    DateTime endDate;

    switch (selectedPeriod) {
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        endDate = startDate.add(const Duration(days: 7));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    for (var log in widget.activityLogs.where((log) => log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if ((logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) && logDay.isBefore(endDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.week) {
          index = logDay.difference(startDate).inDays;
        } else if (selectedPeriod == StatsPeriod.month) {
          index = ((logDay.difference(startDate)).inDays / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += 1.0;
        }
      }
    }

    final result = totals.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Theme.of(context).colorScheme.secondary,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
    return result;
  }

  double getMaxY(List<BarChartGroupData> barGroups) {
    if (barGroups.isEmpty) return 10.0;
    final maxYValue = barGroups
        .map((group) => group.barRods.first.toY)
        .reduce((a, b) => a > b ? a : b);
    return maxYValue > 0 ? maxYValue * 1.2 : 10.0;
  }

  List<String> getMonthLabels() {
    final now = DateTime.now();
    final List<String> labels = [];
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (int i = 11; i >= 0; i--) {
      final monthIndex = (now.month - i - 1) % 12;
      labels.add(monthNames[monthIndex >= 0 ? monthIndex : monthIndex + 12]);
    }
    return labels;
  }

  Map<String, dynamic> filteredActivities() {
    DateTime now = DateTime.now();
    DateTime from;
    DateTime to;

    switch (selectedPeriod) {
      case StatsPeriod.week:
        from = now.subtract(Duration(days: now.weekday - 1));
        from = DateTime(from.year, from.month, from.day);
        to = from.add(const Duration(days: 7));
        break;
      case StatsPeriod.month:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1);
        break;
      case StatsPeriod.total:
        from = DateTime(2000);
        to = DateTime(now.year, now.month, now.day + 1);
        break;
    }

    if (selectedPeriod == StatsPeriod.total && widget.activityLogs.isNotEmpty) {
      from = widget.activityLogs
          .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }


    Map<String, Duration> timeTotals = {};
    Map<String, int> completionTotals = {};

    for (var activity in widget.activities) {
      timeTotals[activity.name] = Duration.zero;
      completionTotals[activity.name] = 0;
    }

    for (var log in widget.activityLogs) {
      if ((log.date.isAfter(from) || log.date.isAtSameMomentAs(from)) && log.date.isBefore(to)) {
        if (log.isCheckable) {
          completionTotals[log.activityName] = (completionTotals[log.activityName] ?? 0) + 1;
        } else {
          timeTotals[log.activityName] = (timeTotals[log.activityName] ?? Duration.zero) + log.duration;
        }
      }
    }

    final totalTimedDuration = selectedActivity == null
        ? widget.activities
        .whereType<TimedActivity>()
        .fold(Duration.zero, (sum, a) => sum + (timeTotals[a.name] ?? Duration.zero))
        : timeTotals[selectedActivity] ?? Duration.zero;

    final totalCheckableInstances = selectedActivity == null
        ? widget.activities
        .whereType<CheckableActivity>()
        .fold(0, (sum, a) => sum + (completionTotals[a.name] ?? 0))
        : completionTotals[selectedActivity] ?? 0;

    return {
      'timeTotals': timeTotals,
      'completionTotals': completionTotals,
      'totalTimedDuration': totalTimedDuration,
      'totalCheckableInstances': totalCheckableInstances,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stats = filteredActivities();
    final timeTotals = stats['timeTotals'] as Map<String, Duration>;
    final completionTotals = stats['completionTotals'] as Map<String, int>;
    final totalTime = stats['totalTimedDuration'] as Duration;
    final totalCheckable = stats['totalCheckableInstances'] as int;
    final isCheckableSelected = selectedActivity != null &&
        widget.activities
            .firstWhere((a) => a.name == selectedActivity, orElse: () => widget.activities.first)
        is CheckableActivity;

    final timedChartData = getTimedChartData();
    final checkableChartData = getCheckableChartData();
    final monthLabels = getMonthLabels();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<GoalStatsData>(
            future: _goalStatsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading goal data.'));
              }
              final goalStatusData = snapshot.data ?? GoalStatsData(successful: 0, ongoing: 0, currentStreak: 0, longestStreak: 0);
              final longestStreakSubtitle = goalStatusData.longestStreak == 0
                  ? 'No streak yet'
                  : 'Started ${goalStatusData.longestStreakStart?.toString().split(' ')[0] ?? 'N/A'}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatCard(
                    icon: Icons.check_circle_outline,
                    title: 'Goals Completed',
                    value: '${goalStatusData.successful}',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  _StatCard(
                    icon: Icons.local_fire_department_outlined,
                    title: 'Current Streak',
                    value: '${goalStatusData.currentStreak} days',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _StatCard(
                    icon: Icons.military_tech_outlined,
                    title: 'Longest Streak',
                    value: '${goalStatusData.longestStreak} days',
                    subtitle: longestStreakSubtitle,
                    color: Colors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          SegmentedButton<StatsPeriod>(
            segments: const [
              ButtonSegment(value: StatsPeriod.week, label: Text('Week'), icon: Icon(Icons.view_week)),
              ButtonSegment(value: StatsPeriod.month, label: Text('Month'), icon: Icon(Icons.calendar_month)),
              ButtonSegment(value: StatsPeriod.total, label: Text('Total'), icon: Icon(Icons.all_inclusive)),
            ],
            selected: {selectedPeriod},
            onSelectionChanged: (Set<StatsPeriod> newSelection) {
              setState(() {
                selectedPeriod = newSelection.first;
                _fetchGoalData();
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: selectedActivity,
            decoration: const InputDecoration(
              labelText: 'Filter by Activity',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            hint: const Text('All Activities'),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All Activities')),
              ...widget.activities
                  .map((a) => DropdownMenuItem<String>(value: a.name, child: Text(a.name))),
            ],
            onChanged: (val) {
              setState(() {
                selectedActivity = val;
                _fetchGoalData();
              });
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  if (!isCheckableSelected)
                    ListTile(
                      leading: const Icon(Icons.timer_outlined, color: Colors.blue),
                      title: Text(
                        selectedActivity == null
                            ? 'Total Activity Time'
                            : 'Time for $selectedActivity',
                        style: textTheme.titleMedium,
                      ),
                      trailing: Text(
                        formatDuration(totalTime),
                        style: textTheme.titleLarge?.copyWith(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (selectedActivity == null || isCheckableSelected)
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                      title: Text(
                        selectedActivity == null
                            ? 'Total Completions'
                            : 'Completions for $selectedActivity',
                        style: textTheme.titleMedium,
                      ),
                      trailing: Text(
                        '$totalCheckable',
                        style: textTheme.titleLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.activities.isNotEmpty)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Breakdown', style: textTheme.headlineSmall),
                  ),
                  ...((selectedActivity == null
                      ? widget.activities
                      : widget.activities.where((a) => a.name == selectedActivity))
                      .map((a) {
                    final percent = a is TimedActivity
                        ? (stats['totalTimedDuration'] as Duration).inSeconds == 0
                        ? 0.0
                        : ((timeTotals[a.name]?.inSeconds ?? 0) /
                        (stats['totalTimedDuration'] as Duration).inSeconds)
                        .clamp(0.0, 1.0)
                        : (stats['totalCheckableInstances'] as int) == 0
                        ? 0.0
                        : ((completionTotals[a.name] ?? 0) /
                        (stats['totalCheckableInstances'] as int))
                        .clamp(0.0, 1.0);
                    return ListTile(
                      key: ValueKey(a.name),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(a.name),
                      subtitle: percent > 0 ? LinearProgressIndicator(
                        value: percent,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ) : null,
                      trailing: Text(
                        a is TimedActivity
                            ? formatDuration(timeTotals[a.name] ?? Duration.zero)
                            : '${completionTotals[a.name] ?? 0} times',
                        style: textTheme.bodyLarge,
                      ),
                      onTap: () {
                        setState(() {
                          final oldIndex = widget.activities.indexOf(a);
                          final newIndex = oldIndex == 0 ? widget.activities.length - 1 : oldIndex - 1;
                          final activity = widget.activities.removeAt(oldIndex);
                          widget.activities.insert(newIndex, activity);
                        });
                      },
                    );
                  }).toList()),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPeriod == StatsPeriod.week ? 'Time Spent Per Day (min)' : 'Time Spent Over Time (min)',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  timedChartData.isEmpty || timedChartData.every((group) => group.barRods.first.toY == 0)
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No timed activity data for this period.'),
                    ),
                  )
                      : AspectRatio(
                    aspectRatio: 1.7,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor,
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: textTheme.labelSmall,
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                String text;
                                if (selectedPeriod == StatsPeriod.week) {
                                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  text = days[value.toInt()];
                                } else if (selectedPeriod == StatsPeriod.month) {
                                  text = 'W${value.toInt() + 1}';
                                } else {
                                  text = monthLabels[value.toInt()];
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(text, style: textTheme.labelSmall),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: timedChartData,
                        maxY: getMaxY(timedChartData),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              '${rod.toY.toStringAsFixed(1)} min',
                              TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPeriod == StatsPeriod.week ? 'Completions Per Day' : 'Completions Over Time',
                    style: textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  checkableChartData.isEmpty || checkableChartData.every((group) => group.barRods.first.toY == 0)
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No completion data for this period.'),
                    ),
                  )
                      : AspectRatio(
                    aspectRatio: 1.7,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor,
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) => Text(
                                '${value.toInt()}',
                                style: textTheme.labelSmall,
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                String text;
                                if (selectedPeriod == StatsPeriod.week) {
                                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                  text = days[value.toInt()];
                                } else if (selectedPeriod == StatsPeriod.month) {
                                  text = 'W${value.toInt() + 1}';
                                } else {
                                  text = monthLabels[value.toInt()];
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(text, style: textTheme.labelSmall),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: checkableChartData,
                        maxY: getMaxY(checkableChartData),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              '${rod.toY.toInt()} completions',
                              TextStyle(fontSize: 12, color: theme.colorScheme.onSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}