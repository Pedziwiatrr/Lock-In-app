import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';

enum CalendarPeriod { week, month, threeMonths, allTime }

class CalendarPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;
  final DateTime selectedDate;
  final Function(DateTime) onSelectDate;

  const CalendarPage({
    super.key,
    required this.activityLogs,
    required this.goals,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarPeriod selectedPeriod = CalendarPeriod.allTime;

  Map<DateTime, Duration> _aggregateByDay() {
    Map<DateTime, Duration> result = {};
    for (var log in widget.activityLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      result[day] = (result[day] ?? Duration.zero) + log.duration;
    }
    return result;
  }

  Map<DateTime, Map<String, dynamic>> _calculateGoalProgress() {
    final progress = <DateTime, Map<String, dynamic>>{};
    final dayData = _aggregateByDay();
    final today = widget.selectedDate;

    DateTime minDate;
    switch (selectedPeriod) {
      case CalendarPeriod.week:
        minDate = today.subtract(const Duration(days: 7));
        break;
      case CalendarPeriod.month:
        minDate = today.subtract(const Duration(days: 30));
        break;
      case CalendarPeriod.threeMonths:
        minDate = today.subtract(const Duration(days: 90));
        break;
      case CalendarPeriod.allTime:
        minDate = widget.activityLogs.isNotEmpty
            ? widget.activityLogs
            .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
            .reduce((a, b) => a.isBefore(b) ? a : b)
            : DateTime(2000);
        break;
    }

    final daysDiff = today.difference(minDate).inDays;

    for (int i = 0; i <= daysDiff; i++) {
      final day = today.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      final dayKey = DateTime(day.year, day.month, day.day);

      int completedDailyGoals = 0;
      int totalDailyGoals = widget.goals
          .where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.daily)
          .length;

      int completedWeeklyGoals = 0;
      int totalWeeklyGoals = widget.goals
          .where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.weekly)
          .length;

      final weekStart = day.subtract(Duration(days: day.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      for (var goal in widget.goals.where((g) => g.goalDuration > Duration.zero)) {
        final activity = widget.activityLogs
            .where((log) =>
        log.activityName == goal.activityName &&
            log.date.isAfter(
                goal.goalType == GoalType.daily ? dayStart : weekStart) &&
            log.date.isBefore(goal.goalType == GoalType.daily ? dayEnd : weekEnd))
            .toList();

        bool isCompleted = false;
        if (activity.isNotEmpty) {
          if (activity.any((log) => log.isCheckable)) {
            final completions = activity.where((log) => log.isCheckable).length;
            if (completions >= goal.goalDuration.inMinutes) {
              isCompleted = true;
            }
          } else {
            final totalTime = activity.fold<Duration>(
                Duration.zero, (sum, log) => sum + log.duration);
            if (totalTime >= goal.goalDuration) {
              isCompleted = true;
            }
          }
        }

        if (isCompleted) {
          if (goal.goalType == GoalType.daily) {
            completedDailyGoals++;
          } else {
            completedWeeklyGoals++;
          }
        }
      }

      Color dailyColor;
      if (totalDailyGoals == 0) {
        dailyColor = Colors.grey;
      } else if (completedDailyGoals == totalDailyGoals) {
        dailyColor = Colors.green;
      } else if (completedDailyGoals > 0) {
        dailyColor = Colors.yellow;
      } else {
        dailyColor = Colors.red;
      }

      Color weeklyColor;
      if (totalWeeklyGoals == 0) {
        weeklyColor = Colors.grey;
      } else if (completedWeeklyGoals == totalWeeklyGoals) {
        weeklyColor = Colors.green;
      } else if (completedWeeklyGoals > 0) {
        weeklyColor = Colors.yellow;
      } else {
        weeklyColor = Colors.red;
      }

      progress[day] = {
        'completedDailyGoals': completedDailyGoals,
        'totalDailyGoals': totalDailyGoals,
        'dailyColor': dailyColor,
        'completedWeeklyGoals': completedWeeklyGoals,
        'totalWeeklyGoals': totalWeeklyGoals,
        'weeklyColor': weeklyColor,
        'duration': dayData[dayKey] ?? Duration.zero,
      };
    }

    return progress;
  }

  void _showDayDetails(BuildContext context, DateTime day, Map<String, dynamic> dayData) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

    final Map<String, Map<String, dynamic>> activities = {};
    for (var log in widget.activityLogs.where((log) =>
    log.date.isAfter(dayStart) && log.date.isBefore(dayEnd))) {
      if (!activities.containsKey(log.activityName)) {
        activities[log.activityName] = {
          'isCheckable': log.isCheckable,
          'duration': Duration.zero,
          'completions': 0,
        };
      }
      if (log.isCheckable) {
        activities[log.activityName]!['completions'] += 1;
      } else {
        activities[log.activityName]!['duration'] =
            (activities[log.activityName]!['duration'] as Duration) + log.duration;
      }
    }

    final List<Map<String, dynamic>> goalProgress = [];
    for (var goal in widget.goals.where((g) => g.goalDuration > Duration.zero)) {
      final activityLogs = widget.activityLogs
          .where((log) =>
      log.activityName == goal.activityName &&
          log.date.isAfter(dayStart) &&
          log.date.isBefore(dayEnd))
          .toList();

      double percent = 0.0;
      String status = '';

      if (activityLogs.isNotEmpty) {
        if (activityLogs.any((log) => log.isCheckable)) {
          final completions = activityLogs.where((log) => log.isCheckable).length;
          percent = goal.goalDuration.inMinutes == 0
              ? 0.0
              : (completions / goal.goalDuration.inMinutes).clamp(0.0, 1.0);
          status = '$completions/${goal.goalDuration.inMinutes} completions';
        } else {
          final totalTime = activityLogs.fold<Duration>(
              Duration.zero, (sum, log) => sum + log.duration);
          percent = goal.goalDuration.inSeconds == 0
              ? 0.0
              : (totalTime.inSeconds / goal.goalDuration.inSeconds).clamp(0.0, 1.0);
          status = '${formatDuration(totalTime)}/${formatDuration(goal.goalDuration)}';
        }
      } else {
        status = 'No activity logged';
      }

      goalProgress.add({
        'activityName': goal.activityName,
        'goalType': goal.goalType,
        'percent': percent,
        'status': status,
      });
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activities',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No activities logged for this day.'),
                )
              else
                ...activities.entries.map((entry) {
                  final activityName = entry.key;
                  final data = entry.value;
                  final isCheckable = data['isCheckable'] as bool;
                  final duration = data['duration'] as Duration;
                  final completions = data['completions'] as int;
                  return ListTile(
                    title: Text(activityName),
                    subtitle: Text(
                      isCheckable
                          ? '$completions completion(s)'
                          : formatDuration(duration),
                    ),
                  );
                }).toList(),
              const SizedBox(height: 16),
              const Text(
                'Goal Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (goalProgress.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No goals set for this day.'),
                )
              else
                ...goalProgress.map((goal) {
                  return ListTile(
                    title: Text(goal['activityName']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: goal['percent']),
                        const SizedBox(height: 4),
                        Text(goal['status']),
                        Text(goal['goalType'] == GoalType.daily ? 'Daily' : 'Weekly'),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateGoalProgress();
    final sortedDays = progress.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButton<CalendarPeriod>(
            value: selectedPeriod,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: CalendarPeriod.week, child: Text('Last Week')),
              DropdownMenuItem(value: CalendarPeriod.month, child: Text('Last Month')),
              DropdownMenuItem(
                  value: CalendarPeriod.threeMonths, child: Text('Last 3 Months')),
              DropdownMenuItem(value: CalendarPeriod.allTime, child: Text('All Time')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedPeriod = val;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final day = sortedDays[index];
              final dayData = progress[day]!;
              final duration = dayData['duration'] as Duration;
              final completedDailyGoals = dayData['completedDailyGoals'] as int;
              final totalDailyGoals = dayData['totalDailyGoals'] as int;
              final dailyColor = dayData['dailyColor'] as Color;
              final completedWeeklyGoals = dayData['completedWeeklyGoals'] as int;
              final totalWeeklyGoals = dayData['totalWeeklyGoals'] as int;
              final weeklyColor = dayData['weeklyColor'] as Color;

              return ListTile(
                onTap: () => _showDayDetails(context, day, dayData),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dailyColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: weeklyColor,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completed daily goals: $completedDailyGoals/$totalDailyGoals'),
                    Text(
                        'Completed weekly goals: $completedWeeklyGoals/$totalWeeklyGoals'),
                  ],
                ),
                trailing: Text(formatDuration(duration)),
              );
            },
          ),
        ),
      ],
    );
  }
}