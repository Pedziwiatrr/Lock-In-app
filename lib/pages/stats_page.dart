import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';

enum StatsPeriod { day, week, month, total }

class HistoryDataProvider {
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;

  HistoryDataProvider({
    required this.goals,
    required this.activityLogs,
    required this.activities,
  });

  Future<List<Map<String, dynamic>>> getGoalStatusesForPeriod(
      DateTime start, DateTime end, String? selectedActivity) async {
    print('[DEBUG] getGoalStatusesForPeriod: start=$start, end=$end, selectedActivity=$selectedActivity, goals=${goals.length}, logs=${activityLogs.length}');
    try {
      final result = await compute(_computeGoalStatusesForPeriod, {
        'goals': goals,
        'activityLogs': activityLogs,
        'activities': activities,
        'start': start,
        'end': end,
        'selectedActivity': selectedActivity,
      }).timeout(const Duration(seconds: 10), onTimeout: () {
        print('[DEBUG] getGoalStatusesForPeriod: Timed out');
        return [];
      });
      print('[DEBUG] getGoalStatusesForPeriod: Completed with ${result.length} statuses');
      return result;
    } catch (e) {
      print('[DEBUG] getGoalStatusesForPeriod: Error: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _computeGoalStatusesForPeriod(Map<String, dynamic> params) {
    final goals = params['goals'] as List<Goal>;
    final activityLogs = params['activityLogs'] as List<ActivityLog>;
    final activities = params['activities'] as List<Activity>;
    final start = params['start'] as DateTime;
    final end = params['end'] as DateTime;
    final selectedActivity = params['selectedActivity'] as String?;

    print('[DEBUG] _computeGoalStatusesForPeriod: Processing ${goals.length} goals, ${activityLogs.length} logs');
    final List<Map<String, dynamic>> statuses = [];

    for (var goal in goals.where((g) =>
    g.goalDuration > Duration.zero &&
        (selectedActivity == null || g.activityName == selectedActivity))) {
      DateTime iterDate;
      switch (goal.goalType) {
        case GoalType.daily:
          iterDate = DateTime(start.year, start.month, start.day);
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            if (goal.startDate.isAfter(iterDate) || (goal.endDate != null && goal.endDate!.isBefore(iterDate))) {
              iterDate = iterDate.add(const Duration(days: 1));
              continue;
            }
            statuses.add(_calculateStatusForPeriod(goal, activityLogs, activities, iterDate, iterDate.add(const Duration(days: 1))));
            iterDate = iterDate.add(const Duration(days: 1));
          }
          break;
        case GoalType.weekly:
          iterDate = start.subtract(Duration(days: start.weekday - 1));
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            if (goal.startDate.isAfter(iterDate.add(const Duration(days: 7))) || (goal.endDate != null && goal.endDate!.isBefore(iterDate))) {
              iterDate = iterDate.add(const Duration(days: 7));
              continue;
            }
            statuses.add(_calculateStatusForPeriod(goal, activityLogs, activities, iterDate, iterDate.add(const Duration(days: 7))));
            iterDate = iterDate.add(const Duration(days: 7));
          }
          break;
        case GoalType.monthly:
          iterDate = DateTime(start.year, start.month, 1);
          while (iterDate.isBefore(end.add(const Duration(days: 1)))) {
            final nextMonth = DateTime(iterDate.year, iterDate.month + 1, 1);
            if (goal.startDate.isAfter(nextMonth) || (goal.endDate != null && goal.endDate!.isBefore(iterDate))) {
              iterDate = nextMonth;
              continue;
            }
            statuses.add(_calculateStatusForPeriod(goal, activityLogs, activities, iterDate, nextMonth));
            iterDate = nextMonth;
          }
          break;
      }
    }
    print('[DEBUG] _computeGoalStatusesForPeriod: Returning ${statuses.length} statuses');
    return statuses;
  }

  static Map<String, dynamic> _calculateStatusForPeriod(Goal goal, List<ActivityLog> allLogs, List<Activity> activities, DateTime periodStart, DateTime periodEnd) {
    final activityLogsFiltered = allLogs.where((log) =>
    log.activityName == goal.activityName &&
        !log.date.isBefore(periodStart) &&
        log.date.isBefore(periodEnd)).toList();

    bool isCheckable = activities.any((a) => a.name == goal.activityName && a is CheckableActivity);

    bool isSuccessful = false;
    if (isCheckable) {
      final completions = activityLogsFiltered.where((log) => log.isCheckable).length;
      isSuccessful = completions >= goal.goalDuration.inMinutes;
    } else {
      final totalTime = activityLogsFiltered.fold<Duration>(Duration.zero, (sum, log) => sum + log.duration);
      isSuccessful = totalTime >= goal.goalDuration;
    }

    bool isPeriodEnded = periodEnd.isBefore(DateTime.now());
    return {
      'goal': goal,
      'status': isSuccessful ? 'successful' : (isPeriodEnded ? 'failed' : 'ongoing'),
      'date': periodStart,
    };
  }

  Future<int> getCurrentStreak(String? selectedActivity) async {
    print('[DEBUG] getCurrentStreak: Starting, selectedActivity=$selectedActivity');
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstLogDate = activityLogs.isNotEmpty
          ? activityLogs.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b)
          : today;

      final allDailyStatuses = await getGoalStatusesForPeriod(firstLogDate, now, selectedActivity);

      final dailyStatusesByDate = <DateTime, bool>{};
      for (var status in allDailyStatuses.where((s) => (s['goal'] as Goal).goalType == GoalType.daily)) {
        final date = status['date'] as DateTime;
        final isSuccess = status['status'] == 'successful';
        dailyStatusesByDate[date] = dailyStatusesByDate.containsKey(date) ? dailyStatusesByDate[date]! && isSuccess : isSuccess;
      }

      int currentStreak = 0;
      DateTime currentDate = today;
      while (dailyStatusesByDate[currentDate] == true) {
        currentStreak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      }
      print('[DEBUG] getCurrentStreak: Returning streak=$currentStreak');
      return currentStreak;
    } catch (e) {
      print('[DEBUG] getCurrentStreak: Error: $e');
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

class _StatsPageState extends State<StatsPage> {
  StatsPeriod selectedPeriod = StatsPeriod.total;
  String? selectedActivity;
  Future<GoalStatsData>? _goalStatsFuture;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] StatsPage initState: launchCount=${widget.launchCount}, goals=${widget.goals.length}, logs=${widget.activityLogs.length}, activities=${widget.activities.length}');
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
    print('[DEBUG] StatsPage: Disposing');
    super.dispose();
  }

  void _fetchGoalData() {
    setState(() {
      _goalStatsFuture = _getCombinedGoalData();
    });
  }

  Future<GoalStatsData> _getCombinedGoalData() async {
    print('[DEBUG] _getCombinedGoalData: Starting for selectedActivity=$selectedActivity');
    try {
      final historyProvider = HistoryDataProvider(
        goals: widget.goals,
        activityLogs: widget.activityLogs,
        activities: widget.activities,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final firstLogDate = widget.activityLogs.isNotEmpty
          ? widget.activityLogs.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b)
          : today;

      final allStatuses = await historyProvider.getGoalStatusesForPeriod(firstLogDate, now, selectedActivity);

      final dailyStatusesByDate = <DateTime, bool>{};
      for(var status in allStatuses.where((s) => (s['goal'] as Goal).goalType == GoalType.daily)) {
        final date = status['date'] as DateTime;
        final isSuccess = status['status'] == 'successful';
        dailyStatusesByDate[date] = dailyStatusesByDate.containsKey(date) ? dailyStatusesByDate[date]! && isSuccess : isSuccess;
      }

      int currentStreak = 0;
      DateTime currentDate = today;
      while(dailyStatusesByDate[currentDate] == true) {
        currentStreak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      }

      int longestStreak = 0;
      DateTime? longestStreakStart;
      int tempStreak = 0;
      DateTime? tempStreakStart;

      final sortedDates = dailyStatusesByDate.keys.toList()..sort((a,b) => b.compareTo(a));

      for (var date in sortedDates) {
        if (dailyStatusesByDate[date] == true) {
          tempStreak++;
          tempStreakStart ??= date;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
            longestStreakStart = tempStreakStart?.subtract(Duration(days: tempStreak -1));
          }
          tempStreak = 0;
          tempStreakStart = null;
        }
      }
      if (tempStreak > longestStreak) {
        longestStreak = tempStreak;
        longestStreakStart = tempStreakStart?.subtract(Duration(days: tempStreak - 1));
      }

      int successful = allStatuses.where((s) => s['status'] == 'successful').length;
      int ongoing = allStatuses.where((s) => s['status'] == 'ongoing').length;

      final result = GoalStatsData(
        successful: successful,
        ongoing: ongoing,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        longestStreakStart: longestStreakStart,
      );

      print('[DEBUG] _getCombinedGoalData: Completed successfully.');
      return result;

    } catch (e) {
      print('[DEBUG] _getCombinedGoalData: Error: $e');
      return GoalStatsData(successful: 0, ongoing: 0, currentStreak: 0, longestStreak: 0);
    }
  }

  List<BarChartGroupData> getTimedChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars = 0;
    DateTime startDate;

    switch (selectedPeriod) {
      case StatsPeriod.day:
        numBars = 1;
        startDate = today;
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    print('[DEBUG] getTimedChartData: period=$selectedPeriod, startDate=$startDate, numBars=$numBars');
    for (var log in widget.activityLogs.where((log) => !log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if (logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.day) {
          if (logDay.isAtSameMomentAs(today)) {
            index = 0;
          } else {
            continue;
          }
        } else if (selectedPeriod == StatsPeriod.week) {
          index = logDay.difference(startDate).inDays;
        } else if (selectedPeriod == StatsPeriod.month) {
          index = ((logDay.difference(startDate).inDays) / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += log.duration.inMinutes.toDouble();
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
    print('[DEBUG] getTimedChartData: Generated ${result.length} bars');
    return result;
  }

  List<BarChartGroupData> getCheckableChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars;
    DateTime startDate;

    switch (selectedPeriod) {
      case StatsPeriod.day:
        numBars = 1;
        startDate = today;
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    print('[DEBUG] getCheckableChartData: period=$selectedPeriod, startDate=$startDate, numBars=$numBars');
    for (var log in widget.activityLogs.where((log) => log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if (logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.day) {
          if (logDay.isAtSameMomentAs(today)) {
            index = 0;
          } else {
            continue;
          }
        } else if (selectedPeriod == StatsPeriod.week) {
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
    print('[DEBUG] getCheckableChartData: Generated ${result.length} bars');
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

    switch (selectedPeriod) {
      case StatsPeriod.day:
        from = DateTime(now.year, now.month, now.day);
        break;
      case StatsPeriod.week:
        from = now.subtract(Duration(days: now.weekday - 1));
        break;
      case StatsPeriod.month:
        from = DateTime(now.year, now.month, 1);
        break;
      case StatsPeriod.total:
        from = widget.activityLogs.isNotEmpty
            ? widget.activityLogs
            .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
            .reduce((a, b) => a.isBefore(b) ? a : b)
            : DateTime(2000);
        break;
    }

    Map<String, Duration> timeTotals = {};
    Map<String, int> completionTotals = {};

    for (var activity in widget.activities) {
      timeTotals[activity.name] = Duration.zero;
      completionTotals[activity.name] = 0;
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(from) || log.date.isAtSameMomentAs(from)) {
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

    print('[DEBUG] filteredActivities: timeTotals=$timeTotals, completionTotals=$completionTotals');
    return {
      'timeTotals': timeTotals,
      'completionTotals': completionTotals,
      'totalTimedDuration': totalTimedDuration,
      'totalCheckableInstances': totalCheckableInstances,
    };
  }

  @override
  Widget build(BuildContext context) {
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

    print('[DEBUG] StatsPage build: selectedPeriod=$selectedPeriod, selectedActivity=$selectedActivity');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<StatsPeriod>(
            value: selectedPeriod,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: StatsPeriod.day, child: Text('Day')),
              DropdownMenuItem(value: StatsPeriod.week, child: Text('Week')),
              DropdownMenuItem(value: StatsPeriod.month, child: Text('Month')),
              DropdownMenuItem(value: StatsPeriod.total, child: Text('Total')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  selectedPeriod = val;
                  _fetchGoalData();
                });
              }
            },
          ),
          const SizedBox(height: 10),
          DropdownButton<String?>(
            value: selectedActivity,
            isExpanded: true,
            hint: const Text('Select activity for stats'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All activities')),
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
          const SizedBox(height: 20),
          if (!isCheckableSelected) ...[
            Text(
              selectedActivity == null
                  ? '⏰ Total activity time: ${formatDuration(totalTime)}'
                  : '⏰ Time for $selectedActivity: ${formatDuration(totalTime)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
          if (selectedActivity == null || isCheckableSelected) ...[
            const SizedBox(height: 10),
            Text(
              selectedActivity == null
                  ? '✅ Total completions: $totalCheckable'
                  : '✅ Completions for $selectedActivity: $totalCheckable',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 20),
          Column(
            children: (selectedActivity == null
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
                title: Text(a.name),
                subtitle: LinearProgressIndicator(value: percent),
                trailing: Text(
                  a is TimedActivity
                      ? formatDuration(timeTotals[a.name] ?? Duration.zero)
                      : '${completionTotals[a.name] ?? 0} times',
                  style: const TextStyle(fontSize: 20),
                ),
                leading: const Icon(Icons.drag_handle),
                onTap: () {
                  setState(() {
                    final oldIndex = widget.activities.indexOf(a);
                    final newIndex = oldIndex == 0 ? widget.activities.length - 1 : oldIndex - 1;
                    final activity = widget.activities.removeAt(oldIndex);
                    widget.activities.insert(newIndex, activity);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            selectedPeriod == StatsPeriod.week ? 'Time spent per day' : 'Minutes spent over time',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          timedChartData.isEmpty || timedChartData.every((group) => group.barRods.first.toY == 0)
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No timed activity data for this period.'),
          )
              : SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (selectedPeriod == StatsPeriod.day) {
                          return const Text('');
                        } else if (selectedPeriod == StatsPeriod.week) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        } else if (selectedPeriod == StatsPeriod.month) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'W${value.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthLabels[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                barGroups: timedChartData,
                maxY: getMaxY(timedChartData),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()} min',
                      const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            selectedPeriod == StatsPeriod.week ? 'Completions per day' : 'Completions over time',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          checkableChartData.isEmpty || checkableChartData.every((group) => group.barRods.first.toY == 0)
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No completion data for this period.'),
          )
              : SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (selectedPeriod == StatsPeriod.day) {
                          return const Text('');
                        } else if (selectedPeriod == StatsPeriod.week) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        } else if (selectedPeriod == StatsPeriod.month) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'W${value.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthLabels[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                barGroups: checkableChartData,
                maxY: getMaxY(checkableChartData),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      '${rod.toY.toInt()} completions',
                      const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Goals',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<GoalStatsData>(
            future: _goalStatsFuture,
            builder: (context, snapshot) {
              print('[DEBUG] FutureBuilder goalStatus: state=${snapshot.connectionState}, error=${snapshot.error}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                print('[DEBUG] FutureBuilder goalStatus: Error: ${snapshot.error}');
                return const Text('Error loading goal data.');
              }
              final goalStatusData = snapshot.data ?? GoalStatsData(successful: 0, ongoing: 0, currentStreak: 0, longestStreak: 0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 Goals Completed: ${goalStatusData.successful}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🔥 Current Streak: ${goalStatusData.currentStreak} days',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    goalStatusData.longestStreak == 0
                        ? '🔥 Longest Streak: None'
                        : '🔥 Longest Streak: ${goalStatusData.longestStreak} days (started ${goalStatusData.longestStreakStart?.toString().split(' ')[0] ?? 'N/A'})',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}