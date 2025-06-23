import 'package:flutter/material.dart';
import '../models/activity.dart';
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