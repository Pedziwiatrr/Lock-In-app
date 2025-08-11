import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';
import '../pages/stats_page.dart' show HistoryDataProvider;
import '../utils/ad_manager.dart';

class TrackerPage extends StatefulWidget {
  final List<Activity> activities;
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;
  final Activity? selectedActivity;
  final DateTime selectedDate;
  final Duration elapsed;
  final bool isRunning;
  final void Function(Activity?) onSelectActivity;
  final void Function(DateTime) onSelectDate;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onCheckActivity;
  final void Function(Duration) onAddManualTime;
  final void Function(Duration) onSubtractManualTime;
  final void Function(int) onAddManualCompletion;
  final void Function(int) onSubtractManualCompletion;
  final int launchCount;

  const TrackerPage({
    super.key,
    required this.activities,
    required this.goals,
    required this.activityLogs,
    required this.selectedActivity,
    required this.selectedDate,
    required this.elapsed,
    required this.isRunning,
    required this.onSelectActivity,
    required this.onSelectDate,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onResetTimer,
    required this.onCheckActivity,
    required this.onAddManualTime,
    required this.onSubtractManualTime,
    required this.onAddManualCompletion,
    required this.onSubtractManualCompletion,
    required this.launchCount,
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const int maxManualTimeMinutes = 1000;
  static const int maxManualCompletions = 100;
  final AdManager _adManager = AdManager.instance;
  int? _currentStreak;

  @override
  void initState() {
    super.initState();
    _updateStreak();
  }

  @override
  void didUpdateWidget(TrackerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityLogs != oldWidget.activityLogs || widget.goals != oldWidget.goals) {
      _updateStreak();
    }
  }

  void _updateStreak() {
    final historyProvider = HistoryDataProvider(
      goals: widget.goals,
      activityLogs: widget.activityLogs,
      activities: widget.activities,
    );
    historyProvider.getCurrentStreak(null).then((value) {
      if (mounted) {
        setState(() {
          _currentStreak = value;
        });
      }
    });
  }

  Map<String, Map<String, dynamic>> getActivitiesForSelectedDate() {
    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
    final dateStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59, 999);
    final Map<String, Map<String, dynamic>> dateActivities = {};

    for (var activity in widget.activities) {
      dateActivities[activity.name] = {
        'isTimed': activity is TimedActivity,
        'totalDuration': Duration.zero,
        'completions': 0,
      };
    }

    for (var log in widget.activityLogs.where((log) => log.date.isAfter(dateStart) && log.date.isBefore(dateEnd))) {
      final activityName = log.activityName;
      if (!dateActivities.containsKey(activityName)) {
        dateActivities[activityName] = {
          'isTimed': widget.activities.any((a) => a.name == activityName && a is TimedActivity),
          'totalDuration': Duration.zero,
          'completions': 0,
        };
      }
      if (log.isCheckable) {
        dateActivities[activityName]!['completions'] += 1;
      } else if (dateActivities[activityName]!['isTimed']) {
        dateActivities[activityName]!['totalDuration'] = (dateActivities[activityName]!['totalDuration'] as Duration) + log.duration;
      }
    }

    if (widget.selectedActivity != null &&
        widget.selectedActivity is TimedActivity &&
        isToday &&
        widget.isRunning) {
      final activityName = widget.selectedActivity!.name;
      dateActivities[activityName]!['totalDuration'] =
          (dateActivities[activityName]!['totalDuration'] as Duration) + widget.elapsed;
    }

    return dateActivities;
  }

  void showInputDialog(String title, String hint, bool isTimed, Function(int) onSave) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            helperText: isTimed ? 'Max $maxManualTimeMinutes minutes' : 'Max $maxManualCompletions completions',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              final intVal = int.tryParse(value);
              if (value.isNotEmpty && intVal != null && intVal > 0 && intVal <= (isTimed ? maxManualTimeMinutes : maxManualCompletions)) {
                Navigator.pop(context);
                onSave(intVal);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Enter a number between 1 and ${isTimed ? maxManualTimeMinutes : maxManualCompletions}.'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleStopTimer() {
    widget.onStopTimer();
    _handleAdAndSave();
  }

  void _handleAdAndSave() {
    if (widget.selectedActivity is TimedActivity && _adManager.shouldShowAd(widget.elapsed)) {
      _adManager.showRewardedAd(
        onUserEarnedReward: widget.onResetTimer,
        onAdDismissed: widget.onResetTimer,
        onAdFailedToShow: widget.onResetTimer,
      );
    } else {
      widget.onResetTimer();
    }
  }

  void _handleCheckAndAd() {
    if (widget.isRunning) {
      widget.onStopTimer();
    }
    _adManager.incrementCheckUsage().then((_) {
      if (widget.selectedActivity is CheckableActivity && _adManager.shouldShowCheckAd()) {
        _adManager.showRewardedAd(
          onUserEarnedReward: widget.onCheckActivity,
          onAdDismissed: widget.onCheckActivity,
          onAdFailedToShow: widget.onCheckActivity,
        );
      } else {
        widget.onCheckActivity();
      }
    });
  }

  void _handleAddManual(int intVal) {
    if (widget.isRunning) {
      widget.onStopTimer();
    }
    if (widget.selectedActivity is TimedActivity) {
      _adManager.incrementStoperUsage().then((_) {
        if (_adManager.shouldShowAd(Duration(minutes: intVal))) {
          _adManager.showRewardedAd(
            onUserEarnedReward: () => widget.onAddManualTime(Duration(minutes: intVal)),
            onAdDismissed: () => widget.onAddManualTime(Duration(minutes: intVal)),
            onAdFailedToShow: () => widget.onAddManualTime(Duration(minutes: intVal)),
          );
        } else {
          widget.onAddManualTime(Duration(minutes: intVal));
        }
      });
    } else if (widget.selectedActivity is CheckableActivity) {
      _adManager.incrementCheckUsage().then((_) {
        if (_adManager.shouldShowCheckAd()) {
          _adManager.showRewardedAd(
            onUserEarnedReward: () => widget.onAddManualCompletion(intVal),
            onAdDismissed: () => widget.onAddManualCompletion(intVal),
            onAdFailedToShow: () => widget.onAddManualCompletion(intVal),
          );
        } else {
          widget.onAddManualCompletion(intVal);
        }
      });
    }
  }

  void _handleSubtractManual(int intVal) {
    if (widget.isRunning) {
      widget.onStopTimer();
    }
    if (widget.selectedActivity is TimedActivity) {
      _adManager.incrementStoperUsage().then((_) {
        if (_adManager.shouldShowAd(Duration(minutes: intVal))) {
          _adManager.showRewardedAd(
            onUserEarnedReward: () => widget.onSubtractManualTime(Duration(minutes: intVal)),
            onAdDismissed: () => widget.onSubtractManualTime(Duration(minutes: intVal)),
            onAdFailedToShow: () => widget.onSubtractManualTime(Duration(minutes: intVal)),
          );
        } else {
          widget.onSubtractManualTime(Duration(minutes: intVal));
        }
      });
    } else if (widget.selectedActivity is CheckableActivity) {
      _adManager.incrementCheckUsage().then((_) {
        if (_adManager.shouldShowCheckAd()) {
          _adManager.showRewardedAd(
            onUserEarnedReward: () => widget.onSubtractManualCompletion(intVal),
            onAdDismissed: () => widget.onSubtractManualCompletion(intVal),
            onAdFailedToShow: () => widget.onSubtractManualCompletion(intVal),
          );
        } else {
          widget.onSubtractManualCompletion(intVal);
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;

    final dateActivities = getActivitiesForSelectedDate();
    final dateStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59, 999);

    final dateCompletions = widget.selectedActivity != null && widget.selectedActivity is CheckableActivity
        ? widget.activityLogs
        .where((log) =>
    log.activityName == widget.selectedActivity!.name &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd) &&
        log.isCheckable)
        .length
        : 0;

    final filteredDateActivities = dateActivities.entries
        .where((entry) {
      final activityData = entry.value;
      final isTimed = activityData['isTimed'] as bool;
      final totalDuration = activityData['totalDuration'] as Duration;
      final completions = activityData['completions'] as int;
      return isTimed ? totalDuration > Duration.zero : completions > 0;
    }).toList();

    bool canSubtractTime = false;
    bool canSubtractCompletion = false;
    if (widget.selectedActivity != null) {
      final relevantLogs = widget.activityLogs
          .where((log) => log.activityName == widget.selectedActivity!.name && log.date.isAfter(dateStart) && log.date.isBefore(dateEnd))
          .toList();
      canSubtractTime = widget.selectedActivity is TimedActivity && relevantLogs.any((log) => !log.isCheckable && log.duration > Duration.zero);
      canSubtractCompletion = widget.selectedActivity is CheckableActivity && relevantLogs.any((log) => log.isCheckable);
    }

    final filteredActivitiesWithGoals = widget.activities.where((activity) {
      final goal = widget.goals.firstWhere(
            (g) =>
        g.activityName == activity.name &&
            g.startDate.isBefore(dateEnd) &&
            (g.endDate == null || g.endDate!.isAfter(dateStart)) &&
            g.goalDuration > Duration.zero,
        orElse: () => Goal(
          activityName: activity.name,
          goalDuration: Duration.zero,
          startDate: DateTime(2000),
        ),
      );
      return goal.goalDuration > Duration.zero;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Activity>(
                    value: widget.selectedActivity,
                    hint: const Text('Choose activity'),
                    isExpanded: true,
                    items: widget.activities.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                    onChanged: (activity) {
                      widget.onSelectActivity(activity);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      widget.onSelectDate(pickedDate);
                    }
                  },
                  child: Text(
                    '${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.selectedActivity is TimedActivity)
              Center(
                child: Text(
                  formatDuration(dateActivities[widget.selectedActivity!.name]!['totalDuration'] as Duration),
                  style: const TextStyle(fontSize: 60),
                ),
              )
            else if (widget.selectedActivity is CheckableActivity)
              Center(
                child: Text(
                  '$dateCompletions time(s)',
                  style: const TextStyle(fontSize: 60),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.selectedActivity is TimedActivity) ...[
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || widget.isRunning || !isToday)
                        ? null
                        : () => _adManager.incrementStoperUsage().then((_) => widget.onStartTimer()),
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: widget.isRunning ? _handleStopTimer : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || widget.elapsed == Duration.zero || !isToday)
                        ? null
                        : () {
                      if (widget.isRunning) {
                        _handleStopTimer();
                      } else {
                        _handleAdAndSave();
                      }
                    },
                    child: const Text('Finish'),
                  ),
                ] else if (widget.selectedActivity is CheckableActivity)
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || !isToday)
                        ? null
                        : _handleCheckAndAd,
                    child: const Text('Check', style: TextStyle(fontSize: 20)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.selectedActivity != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || widget.isRunning || !isToday)
                        ? null
                        : () => showInputDialog(
                      widget.selectedActivity is TimedActivity ? 'Add Time' : 'Add Completions',
                      widget.selectedActivity is TimedActivity ? 'Enter minutes' : 'Enter number of completions',
                      widget.selectedActivity is TimedActivity,
                          (intVal) => _handleAddManual(intVal),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('+', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        (widget.selectedActivity is TimedActivity && !canSubtractTime) ||
                        (widget.selectedActivity is CheckableActivity && !canSubtractCompletion) ||
                        !isToday)
                        ? null
                        : () => showInputDialog(
                      widget.selectedActivity is TimedActivity ? 'Subtract Time' : 'Subtract Completions',
                      widget.selectedActivity is TimedActivity ? 'Enter minutes' : 'Enter number of completions',
                      widget.selectedActivity is TimedActivity,
                          (intVal) => _handleSubtractManual(intVal),
                    ),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('-', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Text(
              isToday
                  ? 'Today'
                  : 'Selected Date (${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year})',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            filteredDateActivities.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No activities logged for this date.'),
            )
                : Column(
              children: filteredDateActivities.map((entry) {
                final activityName = entry.key;
                final activityData = entry.value;
                final isTimed = activityData['isTimed'] as bool;
                final totalDuration = activityData['totalDuration'] as Duration;
                final completions = activityData['completions'] as int;

                return ListTile(
                  title: Text(activityName),
                  trailing: Text(
                    isTimed ? formatDuration(totalDuration) : '$completions time(s)',
                    style: const TextStyle(fontSize: 18),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              '✅ Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            filteredActivitiesWithGoals.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No goals set for this date.'),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredActivitiesWithGoals.length,
              itemBuilder: (context, index) {
                final activity = filteredActivitiesWithGoals[index];
                final goal = widget.goals.firstWhere(
                      (g) =>
                  g.activityName == activity.name &&
                      g.startDate.isBefore(dateEnd) &&
                      (g.endDate == null || g.endDate!.isAfter(dateStart)),
                  orElse: () => Goal(
                    activityName: activity.name,
                    goalDuration: Duration.zero,
                    startDate: DateTime(2000),
                  ),
                );

                final monthStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
                final monthEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 1).subtract(const Duration(milliseconds: 1));
                final weekStart = dateStart.subtract(Duration(days: widget.selectedDate.weekday - 1));
                final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

                final goalPeriodStart = goal.goalType == GoalType.daily
                    ? dateStart
                    : goal.goalType == GoalType.weekly
                    ? weekStart
                    : monthStart;

                final goalPeriodEnd = goal.goalType == GoalType.daily
                    ? dateEnd
                    : goal.goalType == GoalType.weekly
                    ? weekEnd
                    : monthEnd;

                final dateTime = widget.activityLogs
                    .where((log) =>
                log.activityName == activity.name &&
                    log.date.isAfter(goalPeriodStart) &&
                    log.date.isBefore(goalPeriodEnd))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (widget.isRunning &&
                        widget.selectedActivity?.name == activity.name &&
                        isToday
                        ? widget.elapsed
                        : Duration.zero);

                final dateCompletions = widget.activityLogs
                    .where((log) =>
                log.activityName == activity.name &&
                    log.date.isAfter(goalPeriodStart) &&
                    log.date.isBefore(goalPeriodEnd) &&
                    log.isCheckable)
                    .length;

                double percent = 0.0;
                String remainingText = '';
                if (activity is TimedActivity) {
                  percent = goal.goalDuration.inSeconds == 0
                      ? 0.0
                      : (dateTime.inSeconds / goal.goalDuration.inSeconds).clamp(0.0, 1.0);
                  remainingText = (goal.goalDuration - dateTime).isNegative
                      ? 'Goal completed!'
                      : 'Remaining: ${formatDuration(goal.goalDuration - dateTime)}';
                } else {
                  percent = goal.goalDuration.inMinutes == 0
                      ? 0.0
                      : (dateCompletions / goal.goalDuration.inMinutes).clamp(0.0, 1.0);
                  remainingText = dateCompletions >= goal.goalDuration.inMinutes
                      ? 'Goal completed!'
                      : 'Remaining: ${goal.goalDuration.inMinutes - dateCompletions} completion(s)';
                }

                return ListTile(
                  title: Text(
                    activity.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: percent),
                      const SizedBox(height: 4),
                      Text(remainingText),
                      Text(goal.goalType == GoalType.daily
                          ? 'Daily'
                          : goal.goalType == GoalType.weekly
                          ? 'Weekly'
                          : 'Monthly'),
                    ],
                  ),
                  trailing: Text('${(percent * 100).toStringAsFixed(0)}%'),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              _currentStreak == null
                  ? '🔥 Current Streak: ... 🔥'
                  : '🔥 Current Streak: $_currentStreak days 🔥',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}