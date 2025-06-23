import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';

enum StatsPeriod { day, week, month, total }

class StatsPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;
  final List<Goal> goals;

  const StatsPage({
    super.key,
    required this.activityLogs,
    required this.activities,
    required this.goals,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod selectedPeriod = StatsPeriod.total;
  String? selectedActivity;

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

    return totals.asMap().entries.map((entry) {
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
          index = ((logDay.difference(startDate).inDays) / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += 1.0;
        }
      }
    }

    return totals.asMap().entries.map((entry) {
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
        .where((a) => a is TimedActivity)
        .fold(Duration.zero, (sum, a) => sum + (timeTotals[a.name] ?? Duration.zero))
        : timeTotals[selectedActivity] ?? Duration.zero;

    final totalCheckableInstances = selectedActivity == null
        ? widget.activities
        .where((a) => a is CheckableActivity)
        .fold(0, (sum, a) => sum + (completionTotals[a.name] ?? 0))
        : completionTotals[selectedActivity] ?? 0;

    return {
      'timeTotals': timeTotals,
      'completionTotals': completionTotals,
      'totalTimedDuration': totalTimedDuration,
      'totalCheckableInstances': totalCheckableInstances,
    };
  }

  double getMaxY(List<BarChartGroupData> barGroups) {
    if (barGroups.isEmpty) return 10.0;
    final maxYValue = barGroups
        .map((group) => group.barRods.first.toY)
        .reduce((a, b) => a > b ? a : b);
    return maxYValue > 0 ? maxYValue * 1.2 : 10.0;
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

    const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return SingleChildScrollView(
      child: Padding(
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
                  setState(() => selectedPeriod = val);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<String?>(
              value: selectedActivity,
              isExpanded: true,
              hint: const Text('Choose activity for stats and charts'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Activities')),
                ...widget.activities
                    .map((a) => DropdownMenuItem<String>(value: a.name, child: Text(a.name)))
                    .toList(),
              ],
              onChanged: (val) {
                setState(() => selectedActivity = val);
              },
            ),
            const SizedBox(height: 20),
            if (!isCheckableSelected) ...[
              Text(
                selectedActivity == null
                    ? 'Total timed activity: ${formatDuration(totalTime)}'
                    : 'Total time for $selectedActivity: ${formatDuration(totalTime)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
            if (selectedActivity == null || isCheckableSelected) ...[
              const SizedBox(height: 10),
              Text(
                selectedActivity == null
                    ? 'Total checkable completions: $totalCheckable'
                    : 'Total completions for $selectedActivity: $totalCheckable',
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
              selectedPeriod == StatsPeriod.week ? 'Time Spent per Day' : 'Time Spent per Week',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            timedChartData.isEmpty || timedChartData.every((group) => group.barRods.first.toY == 0)
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No timed activity data available for this period.'),
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
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                selectedPeriod == StatsPeriod.month
                                    ? 'W${value.toInt() + 1}'
                                    : monthLabels[value.toInt() % 12],
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
              selectedPeriod == StatsPeriod.week ? 'Completions per Day' : 'Completions per Week',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            checkableChartData.isEmpty || checkableChartData.every((group) => group.barRods.first.toY == 0)
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No checkable activity data available for this period.'),
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
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                selectedPeriod == StatsPeriod.month
                                    ? 'W${value.toInt() + 1}'
                                    : monthLabels[value.toInt() % 12],
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
          ],
        ),
      ),
    );
  }
}