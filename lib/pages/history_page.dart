import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../models/activity.dart';
import '../utils/format_utils.dart';
import '../utils/ad_manager.dart';

enum HistoryPeriod { week, month, threeMonths, allTime }
enum _GoalStatus { green, yellow, red, grey }

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
  //bool _isAdLoaded = false;
  final _pageSize = 30;
  final ScrollController _scrollController = ScrollController();
  List<DateTime> _visibleDays = [];
  Map<DateTime, Map<String, dynamic>> _progressCache = {};
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    /*
    if (widget.launchCount > 1) {
      _adManager.loadBannerAd(onAdLoaded: (isLoaded) {
        if (mounted) setState(() => _isAdLoaded = isLoaded);
      });
    }
    */
    _scrollController.addListener(_loadMoreDays);
    _calculateProgressAsync();
  }

  @override
  void didUpdateWidget(HistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityLogs != oldWidget.activityLogs ||
        widget.goals != oldWidget.goals) {
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8 &&
        _visibleDays.length < _progressCache.length) {
      setState(() {
        final currentLength = _visibleDays.length;
        final newLength =
        (currentLength + _pageSize).clamp(0, _progressCache.length);
        _visibleDays = _progressCache.keys.toList().sublist(0, newLength)
          ..sort((a, b) => b.compareTo(a));
      });
    }
  }

  Future<void> _calculateProgressAsync() async {
    if (_isCalculating) return;
    setState(() => _isCalculating = true);

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
        _visibleDays =
        progress.keys.toList().sublist(0, _pageSize.clamp(0, progress.length))
          ..sort((a, b) => b.compareTo(a));
        _isCalculating = false;
      });
    }
  }

  static Map<DateTime, Map<String, dynamic>> _calculateGoalProgressIsolate(
      Map<String, dynamic> params) {
    final logs = params['logs'] as List<ActivityLog>;
    final goals = params['goals'] as List<Goal>;
    final activities = params['activities'] as List<Activity>;
    final today = params['selectedDate'] as DateTime;
    final selectedPeriod = params['selectedPeriod'] as HistoryPeriod;

    final logsByDay = <DateTime, List<ActivityLog>>{};
    for (var log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      (logsByDay[day] ??= []).add(log);
    }

    final activitiesMap = {for (var a in activities) a.name: a};

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
    }

    final daysInRange = today.difference(minDate).inDays;
    for (int i = 0; i <= daysInRange; i++) {
      final day = today.subtract(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);

      final dailyLogs = logsByDay[dayKey] ?? [];

      final dayStart = dayKey;
      final dayEnd = dayKey.add(const Duration(days: 1));

      final weekStart = dayKey.subtract(Duration(days: day.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));

      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 0).add(const Duration(days: 1));

      final logsInWeek = logsByDay.entries.where((e) => !e.key.isBefore(weekStart) && e.key.isBefore(weekEnd)).expand((e) => e.value).toList();
      final logsInMonth = logsByDay.entries.where((e) => !e.key.isBefore(monthStart) && e.key.isBefore(monthEnd)).expand((e) => e.value).toList();

      final dailyGoals = goals.where((g) => g.goalType == GoalType.daily && g.goalDuration > Duration.zero && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).toList();
      final weeklyGoals = goals.where((g) => g.goalType == GoalType.weekly && g.goalDuration > Duration.zero && g.startDate.isBefore(weekEnd) && (g.endDate == null || g.endDate!.isAfter(weekStart))).toList();
      final monthlyGoals = goals.where((g) => g.goalType == GoalType.monthly && g.goalDuration > Duration.zero && g.startDate.isBefore(monthEnd) && (g.endDate == null || g.endDate!.isAfter(monthStart))).toList();

      int completedDaily = dailyGoals.where((goal) => _isGoalCompletedInPeriod(goal, activitiesMap[goal.activityName], dailyLogs)).length;
      int completedWeekly = weeklyGoals.where((goal) => _isGoalCompletedInPeriod(goal, activitiesMap[goal.activityName], logsInWeek)).length;
      int completedMonthly = monthlyGoals.where((goal) => _isGoalCompletedInPeriod(goal, activitiesMap[goal.activityName], logsInMonth)).length;

      final dayActivities = <String, Map<String, dynamic>>{};
      for (var log in dailyLogs) {
        final activity = activitiesMap[log.activityName];
        if (activity == null) continue;
        final entry = dayActivities.putIfAbsent(log.activityName, () => {'isTimed': activity is TimedActivity, 'duration': Duration.zero, 'completions': 0});
        if (activity is TimedActivity) {
          entry['duration'] = (entry['duration'] as Duration) + log.duration;
        } else {
          entry['completions'] = (entry['completions'] as int) + 1;
        }
      }

      final activeGoals = goals.where((g) => g.goalDuration > Duration.zero && g.startDate.isBefore(dayEnd) && (g.endDate == null || g.endDate!.isAfter(dayStart))).toList();
      final goalDetails = activeGoals.map((goal) {
        final activity = activitiesMap[goal.activityName];
        if (activity == null) return null;

        final periodLogs = goal.goalType == GoalType.daily ? dailyLogs : (goal.goalType == GoalType.weekly ? logsInWeek : logsInMonth);
        final relevantLogs = periodLogs.where((log) => log.activityName == goal.activityName).toList();

        double percent = 0.0;
        String progressText;

        if (activity is TimedActivity) {
          final totalTime = relevantLogs.fold(Duration.zero, (sum, log) => sum + log.duration);
          percent = goal.goalDuration.inSeconds == 0 ? 0.0 : (totalTime.inSeconds / goal.goalDuration.inSeconds).clamp(0.0, 1.0);
          progressText = '${formatDuration(totalTime)} / ${formatDuration(goal.goalDuration)}';
        } else {
          final completions = relevantLogs.length;
          percent = goal.goalDuration.inMinutes == 0 ? 0.0 : (completions / goal.goalDuration.inMinutes).clamp(0.0, 1.0);
          progressText = '$completions / ${goal.goalDuration.inMinutes} time(s)';
        }

        return {
          'activityName': goal.activityName,
          'goalType': goal.goalType.toString().split('.').last,
          'percent': percent,
          'progressText': progressText,
          'status': percent >= 1.0 ? _GoalStatus.green : (percent > 0 ? _GoalStatus.yellow : _GoalStatus.red),
        };
      }).where((details) => details != null).toList();


      progress[dayKey] = {
        'completedDailyGoals': completedDaily,
        'totalDailyGoals': dailyGoals.length,
        'dailyStatus': dailyGoals.isEmpty ? _GoalStatus.grey : (completedDaily >= dailyGoals.length ? _GoalStatus.green : (completedDaily > 0 ? _GoalStatus.yellow : _GoalStatus.red)),
        'completedWeeklyGoals': completedWeekly,
        'totalWeeklyGoals': weeklyGoals.length,
        'weeklyStatus': weeklyGoals.isEmpty ? _GoalStatus.grey : (completedWeekly >= weeklyGoals.length ? _GoalStatus.green : (completedWeekly > 0 ? _GoalStatus.yellow : _GoalStatus.red)),
        'completedMonthlyGoals': completedMonthly,
        'totalMonthlyGoals': monthlyGoals.length,
        'monthlyStatus': monthlyGoals.isEmpty ? _GoalStatus.grey : (completedMonthly >= monthlyGoals.length ? _GoalStatus.green : (completedMonthly > 0 ? _GoalStatus.yellow : _GoalStatus.red)),
        'duration': dailyLogs.fold(Duration.zero, (prev, log) => prev + log.duration),
        'checkableCompletions': dailyLogs.where((log) => log.isCheckable).length,
        'dayActivities': dayActivities,
        'goalDetails': goalDetails,
      };
    }
    return progress;
  }

  static bool _isGoalCompletedInPeriod(Goal goal, Activity? activity, List<ActivityLog> logsInPeriod) {
    if (activity == null) return false;
    final relevantLogs = logsInPeriod.where((log) => log.activityName == goal.activityName);
    if (activity is TimedActivity) {
      final totalDuration = relevantLogs.fold<Duration>(Duration.zero, (prev, log) => prev + log.duration);
      return totalDuration >= goal.goalDuration;
    } else if (activity is CheckableActivity) {
      final completions = relevantLogs.length;
      return completions >= goal.goalDuration.inMinutes;
    }
    return false;
  }

  Color _mapStatusToColor(_GoalStatus status) {
    switch (status) {
      case _GoalStatus.green:
        return Colors.green;
      case _GoalStatus.yellow:
        return Colors.yellow;
      case _GoalStatus.red:
        return Colors.red;
      case _GoalStatus.grey:
      default:
        return Colors.grey.shade700;
    }
  }

  void _showDayDetails(BuildContext context, DateTime day, Map<String, dynamic> dayData) {
    final activitiesLogged = (dayData['dayActivities'] as Map<String, dynamic>).entries.toList();
    final goalDetails = (dayData['goalDetails'] as List<dynamic>).toList();

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
                ...activitiesLogged.map((entry) {
                  final data = entry.value as Map<String, dynamic>;
                  return ListTile(
                    title: Text(entry.key),
                    trailing: Text(data['isTimed']
                        ? formatDuration(data['duration'])
                        : '${data['completions']} time(s)'),
                  );
                }),
              const SizedBox(height: 16),
              const Text('Goal Progress', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (goalDetails.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No goals were active on this day.'))
              else
                ...goalDetails.map((details) {
                  final detailMap = details as Map<String, dynamic>;
                  final percent = detailMap['percent'] as double;
                  final progressColor = _mapStatusToColor(detailMap['status'] as _GoalStatus);

                  return ListTile(
                    title: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: progressColor)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${detailMap['activityName']} (${detailMap['goalType']})')),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(detailMap['progressText'] as String, style: const TextStyle(fontSize: 12)),
                            Text('${(percent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
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
              if (val == null || val == selectedPeriod || _isCalculating) return;
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
          child: _isCalculating && _progressCache.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _progressCache.isEmpty
              ? const Center(child: Text("No history data."))
              : ListView.builder(
            controller: _scrollController,
            itemCount: _visibleDays.length < _progressCache.length ? _visibleDays.length + 1 : _visibleDays.length,
            itemBuilder: (context, index) {
              if (index == _visibleDays.length) {
                return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
              }
              final day = _visibleDays[index];
              final dayData = _progressCache[day]!;
              final duration = dayData['duration'] as Duration;
              final completedDailyGoals = dayData['completedDailyGoals'] as int;
              final totalDailyGoals = dayData['totalDailyGoals'] as int;
              final dailyStatus = dayData['dailyStatus'] as _GoalStatus;
              final completedWeeklyGoals = dayData['completedWeeklyGoals'] as int;
              final totalWeeklyGoals = dayData['totalWeeklyGoals'] as int;
              final weeklyStatus = dayData['weeklyStatus'] as _GoalStatus;
              final completedMonthlyGoals = dayData['completedMonthlyGoals'] as int;
              final totalMonthlyGoals = dayData['totalMonthlyGoals'] as int;
              final monthlyStatus = dayData['monthlyStatus'] as _GoalStatus;
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
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _mapStatusToColor(dailyStatus))),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Weekly Goals: $completedWeeklyGoals/$totalWeeklyGoals',
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _mapStatusToColor(weeklyStatus))),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Monthly Goals: $completedMonthlyGoals/$totalMonthlyGoals',
                      child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: _mapStatusToColor(monthlyStatus))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        /*
        if (_isAdLoaded && widget.launchCount > 1)
          _adManager.getBannerAdWidget() ?? const SizedBox.shrink(),
        */
        const SizedBox(height: 80),
      ],
    );
  }
}