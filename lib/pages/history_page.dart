import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';
import '../utils/ad_manager.dart';

enum HistoryPeriod { week, month, threeMonths, allTime }

class HistoryPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;
  final DateTime selectedDate;
  final Function(DateTime) onSelectDate;
  final int launchCount;

  const HistoryPage({
    super.key,
    required this.activityLogs,
    required this.goals,
    required this.selectedDate,
    required this.onSelectDate,
    required this.launchCount,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistoryPeriod selectedPeriod = HistoryPeriod.allTime;
  final AdManager _adManager = AdManager.instance;
  bool _isAdLoaded = false;
  final _pageSize = 30;
  final ScrollController _scrollController = ScrollController();
  List<DateTime> _visibleDays = [];
  Map<DateTime, Map<String, dynamic>> _progressCache = {};

  @override
  void initState() {
    super.initState();
    print('HistoryPage initState: launchCount = ${widget.launchCount}');
    if (widget.launchCount > 1) {
      print('HistoryPage: Attempting to load banner ad');
      _adManager.loadBannerAd(onAdLoaded: (isLoaded) {
        if (mounted) {
          setState(() {
            _isAdLoaded = isLoaded;
          });
        }
      });
    } else {
      print('HistoryPage: Skipping ad load due to launchCount <= 1');
    }
    _scrollController.addListener(_loadMoreDays);
    _calculateProgressAsync();
  }

  @override
  void dispose() {
    print('HistoryPage: Disposing');
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreDays() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        _visibleDays.length < _progressCache.length) {
      setState(() {
        _visibleDays = _progressCache.keys
            .toList()
            .sublist(0, (_visibleDays.length + _pageSize).clamp(0, _progressCache.length))
          ..sort((a, b) => b.compareTo(a));
      });
    }
  }

  Future<void> _calculateProgressAsync() async {
    final progress = await compute(_calculateGoalProgressIsolate, {
      'logs': widget.activityLogs,
      'goals': widget.goals,
      'selectedDate': widget.selectedDate,
      'selectedPeriod': selectedPeriod,
    });
    if (mounted) {
      setState(() {
        _progressCache = progress;
        _visibleDays = progress.keys.toList().sublist(0, _pageSize.clamp(0, progress.length))
          ..sort((a, b) => b.compareTo(a));
      });
    }
  }

  static Map<DateTime, Map<String, dynamic>> _calculateGoalProgressIsolate(Map<String, dynamic> params) {
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

  void _showDayDetails(BuildContext context, DateTime day, Map<String, dynamic> dayData) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final monthStart = DateTime(day.year, day.month, 1);
    final monthEnd = DateTime(day.year, day.month + 1, 1).subtract(const Duration(milliseconds: 1));

    final activities = <String, Map<String, dynamic>>{};
    for (var log in widget.activityLogs.where((log) => log.date.isAfter(dayStart) && log.date.isBefore(dayEnd))) {
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
        activities[log.activityName]!['duration'] = (activities[log.activityName]!['duration'] as Duration) + log.duration;
      }
    }

    final goalProgress = <Map<String, dynamic>>[];
    for (var goal in widget.goals.where((g) =>
    g.goalDuration > Duration.zero &&
        g.startDate.isBefore(dayEnd) &&
        (g.endDate == null || g.endDate!.isAfter(dayStart)))) {
      final activityLogs = widget.activityLogs
          .where((log) =>
      log.activityName == goal.activityName &&
          log.date.isAfter(goal.goalType == GoalType.daily
              ? dayStart
              : goal.goalType == GoalType.weekly
              ? day.subtract(Duration(days: day.weekday - 1))
              : monthStart) &&
          log.date.isBefore(goal.goalType == GoalType.daily
              ? dayEnd
              : goal.goalType == GoalType.weekly
              ? day.subtract(Duration(days: day.weekday - 1)).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59))
              : monthEnd))
          .toList();

      double percent = 0.0;
      String status = '';

      if (activityLogs.isNotEmpty) {
        if (activityLogs.any((log) => log.isCheckable)) {
          final completions = activityLogs.where((log) => log.isCheckable).length;
          percent = goal.goalDuration.inMinutes == 0 ? 0.0 : (completions / goal.goalDuration.inMinutes).clamp(0.0, 1.0);
          status = '$completions/${goal.goalDuration.inMinutes} completions';
        } else {
          final totalTime = activityLogs.fold<Duration>(Duration.zero, (sum, log) => sum + log.duration);
          percent = goal.goalDuration.inSeconds == 0 ? 0.0 : (totalTime.inSeconds / goal.goalDuration.inSeconds).clamp(0.0, 1.0);
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
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                      isCheckable ? '$completions completion(s)' : formatDuration(duration),
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
                    title: Text(
                      goal['activityName'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: goal['percent']),
                        const SizedBox(height: 4),
                        Text(goal['status']),
                        Text(goal['goalType'] == GoalType.daily
                            ? 'Daily'
                            : goal['goalType'] == GoalType.weekly
                            ? 'Weekly'
                            : 'Monthly'),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButton<HistoryPeriod>(
            value: selectedPeriod,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: HistoryPeriod.week, child: Text('Last Week')),
              DropdownMenuItem(value: HistoryPeriod.month, child: Text('Last Month')),
              DropdownMenuItem(value: HistoryPeriod.threeMonths, child: Text('Last 3 Months')),
              DropdownMenuItem(value: HistoryPeriod.allTime, child: Text('All Time')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedPeriod = val;
                _calculateProgressAsync();
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _visibleDays.length,
            itemBuilder: (context, index) {
              final day = _visibleDays[index];
              final dayData = _progressCache[day]!;
              final duration = dayData['duration'] as Duration;
              final completedDailyGoals = dayData['completedDailyGoals'] as int;
              final totalDailyGoals = dayData['totalDailyGoals'] as int;
              final dailyColor = dayData['dailyColor'] as Color;
              final completedWeeklyGoals = dayData['completedWeeklyGoals'] as int;
              final totalWeeklyGoals = dayData['totalWeeklyGoals'] as int;
              final weeklyColor = dayData['weeklyColor'] as Color;
              final completedMonthlyGoals = dayData['completedMonthlyGoals'] as int;
              final totalMonthlyGoals = dayData['totalMonthlyGoals'] as int;
              final monthlyColor = dayData['monthlyColor'] as Color;
              final checkableCompletions = dayData['checkableCompletions'] as int;

              return ListTile(
                onTap: () => _showDayDetails(context, day, dayData),
                leading: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dailyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: weeklyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: monthlyColor,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily: $completedDailyGoals/$totalDailyGoals'),
                    Text('Weekly: $completedWeeklyGoals/$totalWeeklyGoals'),
                    Text('Monthly: $completedMonthlyGoals/$totalMonthlyGoals'),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Time locked in',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      formatDuration(duration),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Checks: $checkableCompletions',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_isAdLoaded && widget.launchCount > 1) ...[
          const SizedBox(height: 20),
          _adManager.getBannerAdWidget() ?? const SizedBox.shrink(),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}