import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../models/activity.dart';
import '../utils/format_utils.dart';
import '../utils/ad_manager.dart';

enum HistoryPeriod { week, month, threeMonths, allTime }

class HistoryPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;
  final List<Activity> activities;
  final DateTime selectedDate;
  final Function(DateTime) onSelectDate;
  final int launchCount;

  const HistoryPage({
    super.key,
    required this.activityLogs,
    required this.goals,
    required this.activities,
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
    if (widget.launchCount > 1) {
      _adManager.loadBannerAd(onAdLoaded: (isLoaded) {
        if (mounted) setState(() => _isAdLoaded = isLoaded);
      });
    }
    _scrollController.addListener(_loadMoreDays);
    _calculateProgressAsync();
  }

  @override
  void didUpdateWidget(HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityLogs != oldWidget.activityLogs || widget.goals != oldWidget.goals) {
      _calculateProgressAsync();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreDays);
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreDays() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        _visibleDays.length < _progressCache.length) {
      setState(() {
        final currentLength = _visibleDays.length;
        final newLength = (currentLength + _pageSize).clamp(0, _progressCache.length);
        _visibleDays = _progressCache.keys.toList().sublist(0, newLength)
          ..sort((a, b) => b.compareTo(a));
      });
    }
  }

  Future<void> _calculateProgressAsync() async {
    final progress = await compute(_calculateGoalProgressIsolate, {
      'logs': widget.activityLogs,
      'goals': widget.goals,
      'activities': widget.activities,
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
    final activities = params['activities'] as List<Activity>;
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
      default:
        minDate = logs.isNotEmpty
            ? logs.map((log) => DateTime(log.date.year, log.date.month, log.date.day)).reduce((a, b) => a.isBefore(b) ? a : b)
            : today;
        break;
    }

    final days = today.difference(minDate).inDays;
    for (int i = 0; i <= days; i++) {
      final day = today.subtract(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);

      final dayStart = dayKey;
      final dayEnd = dayKey.add(const Duration(days: 1));

      final weekStart = dayKey.subtract(Duration(days: day.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 0).add(const Duration(days: 1));

      final dailyGoals = goals.where((g) => g.goalType == GoalType.daily && g.goalDuration > Duration.zero && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).toList();
      final weeklyGoals = goals.where((g) => g.goalType == GoalType.weekly && g.goalDuration > Duration.zero && g.startDate.isBefore(weekEnd) && (g.endDate == null || g.endDate!.isAfter(weekStart))).toList();
      final monthlyGoals = goals.where((g) => g.goalType == GoalType.monthly && g.goalDuration > Duration.zero && g.startDate.isBefore(monthEnd) && (g.endDate == null || g.endDate!.isAfter(monthStart))).toList();

      int completedDaily = 0;
      for (var goal in dailyGoals) {
        final activity = activities.firstWhere((a) => a.name == goal.activityName, orElse: () => CheckableActivity(name: ''));
        if (activity.name.isEmpty) continue;
        if (_isGoalCompletedInPeriod(goal, activity, logs, dayStart, dayEnd)) {
          completedDaily++;
        }
      }

      int completedWeekly = 0;
      for (var goal in weeklyGoals) {
        final activity = activities.firstWhere((a) => a.name == goal.activityName, orElse: () => CheckableActivity(name: ''));
        if (activity.name.isEmpty) continue;
        if (_isGoalCompletedInPeriod(goal, activity, logs, weekStart, weekEnd)) {
          completedWeekly++;
        }
      }

      int completedMonthly = 0;
      for (var goal in monthlyGoals) {
        final activity = activities.firstWhere((a) => a.name == goal.activityName, orElse: () => CheckableActivity(name: ''));
        if (activity.name.isEmpty) continue;
        if (_isGoalCompletedInPeriod(goal, activity, logs, monthStart, monthEnd)) {
          completedMonthly++;
        }
      }

      progress[dayKey] = {
        'completedDailyGoals': completedDaily,
        'totalDailyGoals': dailyGoals.length,
        'dailyColor': dailyGoals.isEmpty ? Colors.grey.shade700 : completedDaily >= dailyGoals.length ? Colors.green : completedDaily > 0 ? Colors.yellow : Colors.red,
        'completedWeeklyGoals': completedWeekly,
        'totalWeeklyGoals': weeklyGoals.length,
        'weeklyColor': weeklyGoals.isEmpty ? Colors.grey.shade700 : completedWeekly >= weeklyGoals.length ? Colors.green : completedWeekly > 0 ? Colors.yellow : Colors.red,
        'completedMonthlyGoals': completedMonthly,
        'totalMonthlyGoals': monthlyGoals.length,
        'monthlyColor': monthlyGoals.isEmpty ? Colors.grey.shade700 : completedMonthly >= monthlyGoals.length ? Colors.green : completedMonthly > 0 ? Colors.yellow : Colors.red,
        'duration': dayData[dayKey] ?? Duration.zero,
        'checkableCompletions': checkableCompletions[dayKey] ?? 0,
      };
    }
    return progress;
  }

  static bool _isGoalCompletedInPeriod(Goal goal, Activity activity, List<ActivityLog> allLogs, DateTime periodStart, DateTime periodEnd) {
    final logsInPeriod = allLogs.where((log) => log.activityName == goal.activityName && !log.date.isBefore(periodStart) && log.date.isBefore(periodEnd));
    if (activity is TimedActivity) {
      final totalDuration = logsInPeriod.fold<Duration>(Duration.zero, (prev, log) => prev + log.duration);
      return totalDuration >= goal.goalDuration;
    } else if (activity is CheckableActivity) {
      final completions = logsInPeriod.length;
      return completions >= goal.goalDuration.inMinutes;
    }
    return false;
  }

  void _showDayDetails(BuildContext context, DateTime day, Map<String, dynamic> dayData) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final activitiesLogged = <String, Map<String, dynamic>>{};
    for (var log in widget.activityLogs.where((log) => log.date.isAfter(dayStart) && log.date.isBefore(dayEnd))) {
      final activity = widget.activities.firstWhere((a) => a.name == log.activityName, orElse: () => CheckableActivity(name: ''));
      if(activity.name.isEmpty) continue;

      if (!activitiesLogged.containsKey(log.activityName)) {
        activitiesLogged[log.activityName] = {
          'isTimed': activity is TimedActivity,
          'duration': Duration.zero,
          'completions': 0,
        };
      }
      if (activity is TimedActivity) {
        activitiesLogged[log.activityName]!['duration'] = (activitiesLogged[log.activityName]!['duration'] as Duration) + log.duration;
      } else {
        activitiesLogged[log.activityName]!['completions'] += 1;
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Logged Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (activitiesLogged.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No activities logged for this day.'))
              else
                ...activitiesLogged.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key),
                    trailing: Text(entry.value['isTimed']
                        ? formatDuration(entry.value['duration'])
                        : '${entry.value['completions']} time(s)'),
                  );
                }).toList(),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
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
              if (val == null || val == selectedPeriod) return;
              setState(() {
                selectedPeriod = val;
                _progressCache = {};
                _visibleDays = [];
              });
              _calculateProgressAsync();
            },
          ),
        ),
        Expanded(
          child: _progressCache.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
            controller: _scrollController,
            itemCount: _visibleDays.length + 1,
            itemBuilder: (context, index) {
              if (index == _visibleDays.length) {
                return _visibleDays.length < _progressCache.length
                    ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()))
                    : const SizedBox.shrink();
              }
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
                title: Text(
                  '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: duration == Duration.zero && checkableCompletions == 0
                    ? const Text('No activity')
                    : Text('Time: ${formatDuration(duration)} | Checks: $checkableCompletions'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Daily Goals: $completedDailyGoals/$totalDailyGoals',
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: dailyColor)),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Weekly Goals: $completedWeeklyGoals/$totalWeeklyGoals',
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: weeklyColor)),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Monthly Goals: $completedMonthlyGoals/$totalMonthlyGoals',
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: monthlyColor)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_isAdLoaded && widget.launchCount > 1) _adManager.getBannerAdWidget() ?? const SizedBox.shrink(),
        const SizedBox(height: 80),
      ],
    );
  }
}