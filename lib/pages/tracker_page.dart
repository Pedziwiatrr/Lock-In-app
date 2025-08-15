import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final VoidCallback onFinishTimer;
  final VoidCallback onCheckActivity;
  final void Function(Duration) onAddManualTime;
  final void Function(Duration) onSubtractManualTime;
  final void Function(int) onAddManualCompletion;
  final void Function(int) onSubtractManualCompletion;

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
    required this.onFinishTimer,
    required this.onCheckActivity,
    required this.onAddManualTime,
    required this.onSubtractManualTime,
    required this.onAddManualCompletion,
    required this.onSubtractManualCompletion,
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const int maxManualTimeMinutes = 10000;
  static const int maxManualCompletions = 10000;
  final AdManager _adManager = AdManager.instance;
  int? _currentStreak;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _updateStreak();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  void didUpdateWidget(TrackerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityLogs != oldWidget.activityLogs || widget.goals != oldWidget.goals || widget.selectedActivity != oldWidget.selectedActivity) {
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
    final dateEnd = dateStart.add(const Duration(days: 1));
    final Map<String, Map<String, dynamic>> dateActivities = {};

    for (var activity in widget.activities) {
      dateActivities[activity.name] = {
        'isTimed': activity is TimedActivity,
        'totalDuration': Duration.zero,
        'completions': 0,
      };
    }

    for (var log in widget.activityLogs.where((log) => !log.date.isBefore(dateStart) && log.date.isBefore(dateEnd))) {
      final activityName = log.activityName;
      if (!dateActivities.containsKey(activityName)) continue;

      final activity = widget.activities.firstWhere((a) => a.name == activityName, orElse: () => CheckableActivity(name: ''));
      if(activity.name.isEmpty) continue;

      if (activity is CheckableActivity) {
        dateActivities[activityName]!['completions'] += 1;
      } else if (activity is TimedActivity) {
        dateActivities[activityName]!['totalDuration'] = (dateActivities[activityName]!['totalDuration'] as Duration) + log.duration;
      }
    }

    if (isToday &&
        widget.elapsed > Duration.zero &&
        widget.selectedActivity != null &&
        widget.selectedActivity is TimedActivity) {
      final activityName = widget.selectedActivity!.name;
      if (dateActivities.containsKey(activityName)) {
        dateActivities[activityName]!['totalDuration'] =
            (dateActivities[activityName]!['totalDuration'] as Duration) + widget.elapsed;
      }
    }

    return dateActivities;
  }

  void showInputDialog(String title, String hint, bool isTimed, Function(int) onSave) {
    final bool cheatsEnabled = widget.activities.any((a) => a.name == 'sv_cheats 1');

    final int timeLimit = cheatsEnabled ? maxManualTimeMinutes : 300;
    final int completionLimit = cheatsEnabled ? maxManualCompletions : 30;

    final int currentLimit = isTimed ? timeLimit : completionLimit;
    final String unit = isTimed ? "minutes" : "completions";

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
            helperText: 'Max $currentLimit $unit',
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              final intVal = int.tryParse(value);
              if (value.isNotEmpty && intVal != null && intVal > 0 && intVal <= currentLimit) {
                Navigator.pop(context);
                onSave(intVal);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Enter a number between 1 and $currentLimit.'),
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

  void _handleCheckAndAd() {
    if (widget.isRunning) widget.onStopTimer();
    _adManager.incrementCheckUsage().then((_) {
      if (widget.selectedActivity is CheckableActivity && _adManager.shouldShowCheckAd()) {
        _adManager.showRewardedAd(
          onUserEarnedReward: widget.onCheckActivity,
          onAdDismissed: () {},
          onAdFailedToShow: widget.onCheckActivity,
        );
      } else {
        widget.onCheckActivity();
      }
    });
  }

  void _handleAddManual(int intVal) {
    if (widget.isRunning) widget.onStopTimer();
    final action = widget.selectedActivity is TimedActivity
        ? () => widget.onAddManualTime(Duration(minutes: intVal))
        : () => widget.onAddManualCompletion(intVal);

    _adManager.incrementStoperUsage().then((_) {
      bool shouldShow = widget.selectedActivity is TimedActivity
          ? _adManager.shouldShowAd(Duration(minutes: intVal))
          : _adManager.shouldShowCheckAd();
      if (shouldShow) {
        _adManager.showRewardedAd(
          onUserEarnedReward: action,
          onAdDismissed: () {},
          onAdFailedToShow: action,
        );
      } else {
        action();
      }
    });
  }

  void _handleSubtractManual(int intVal) {
    if (widget.isRunning) widget.onStopTimer();
    final action = widget.selectedActivity is TimedActivity
        ? () => widget.onSubtractManualTime(Duration(minutes: intVal))
        : () => widget.onAddManualCompletion(intVal);

    _adManager.incrementStoperUsage().then((_) {
      bool shouldShow = widget.selectedActivity is TimedActivity
          ? _adManager.shouldShowAd(Duration(minutes: intVal))
          : _adManager.shouldShowCheckAd();
      if (shouldShow) {
        _adManager.showRewardedAd(
          onUserEarnedReward: action,
          onAdDismissed: () {},
          onAdFailedToShow: action,
        );
      } else {
        action();
      }
    });
  }

  void _handleFinish() {
    final timeToLog = widget.elapsed;
    if (timeToLog == Duration.zero) return;
    if (widget.selectedActivity is TimedActivity && _adManager.shouldShowAd(timeToLog)) {
      _adManager.showRewardedAd(
        onUserEarnedReward: widget.onFinishTimer,
        onAdDismissed: () {},
        onAdFailedToShow: widget.onFinishTimer,
      );
    } else {
      widget.onFinishTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;

    final dateActivities = getActivitiesForSelectedDate();
    final dateStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    final dateCompletions = widget.selectedActivity != null && widget.selectedActivity is CheckableActivity
        ? dateActivities[widget.selectedActivity!.name]!['completions'] as int
        : 0;

    final filteredDateActivities = dateActivities.entries.where((entry) => (entry.value['isTimed'] as bool) ? (entry.value['totalDuration'] as Duration > Duration.zero) : (entry.value['completions'] as int > 0)).toList();

    bool canSubtractTime = false;
    bool canSubtractCompletion = false;
    if (widget.selectedActivity != null) {
      final relevantLogs = widget.activityLogs.where((log) => log.activityName == widget.selectedActivity!.name && !log.date.isBefore(dateStart) && log.date.isBefore(dateEnd)).toList();
      canSubtractTime = widget.selectedActivity is TimedActivity && relevantLogs.any((log) => log.duration > Duration.zero);
      canSubtractCompletion = widget.selectedActivity is CheckableActivity && relevantLogs.any((log) => log.isCheckable);
    }

    final activeGoals = widget.goals.where((goal) {
      return widget.activities.any((a) => a.name == goal.activityName) &&
          goal.goalDuration > Duration.zero &&
          goal.startDate.isBefore(dateEnd) &&
          (goal.endDate == null || goal.endDate!.isAfter(dateStart));
    }).toList();

    Widget mainDisplay;
    if (widget.selectedActivity is TimedActivity) {
      final totalForDay = dateActivities[widget.selectedActivity!.name]?['totalDuration'] ?? Duration.zero;
      mainDisplay = Center(child: Text(formatDuration(totalForDay), style: const TextStyle(fontSize: 60)));
    } else if (widget.selectedActivity is CheckableActivity) {
      mainDisplay = Center(child: Text('$dateCompletions time(s)', style: const TextStyle(fontSize: 60)));
    } else {
      mainDisplay = const Center(child: Text('00:00:00', style: const TextStyle(fontSize: 60, color: Colors.grey)));
    }

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
                    onChanged: widget.onSelectActivity,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: widget.selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (pickedDate != null) widget.onSelectDate(pickedDate);
                  },
                  child: Text('${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            mainDisplay,
            const SizedBox(height: 20),
            if (isToday)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.selectedActivity is TimedActivity) ...[
                    ElevatedButton(onPressed: (widget.selectedActivity == null || widget.isRunning) ? null : widget.onStartTimer, child: const Text('Start')),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: widget.isRunning ? widget.onStopTimer : null, child: const Text('Stop')),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: (widget.selectedActivity == null || widget.elapsed == Duration.zero) ? null : _handleFinish, child: const Text('Finish')),
                  ] else if (widget.selectedActivity is CheckableActivity)
                    ElevatedButton(onPressed: (widget.selectedActivity == null) ? null : _handleCheckAndAd, child: const Text('Check', style: TextStyle(fontSize: 20))),
                ],
              ),
            const SizedBox(height: 10),
            if (widget.selectedActivity != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => showInputDialog(
                        widget.selectedActivity is TimedActivity ? 'Add Time' : 'Add Completions',
                        widget.selectedActivity is TimedActivity ? 'Enter minutes' : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (intVal) => _handleAddManual(intVal)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('+', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: ((widget.selectedActivity is TimedActivity && !canSubtractTime) || (widget.selectedActivity is CheckableActivity && !canSubtractCompletion))
                        ? null
                        : () => showInputDialog(
                        widget.selectedActivity is TimedActivity ? 'Subtract Time' : 'Subtract Completions',
                        widget.selectedActivity is TimedActivity ? 'Enter minutes' : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (intVal) => _handleSubtractManual(intVal)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('-', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Text(isToday ? 'Today' : 'Selected Date (${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year})', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            filteredDateActivities.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No activities logged for this date.'))
                : Column(children: filteredDateActivities.map((entry) => ListTile(title: Text(entry.key), trailing: Text((entry.value['isTimed'] as bool) ? formatDuration(entry.value['totalDuration'] as Duration) : '${entry.value['completions']} time(s)', style: const TextStyle(fontSize: 18)))).toList()),
            const SizedBox(height: 20),
            const Text('✅ Goals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            activeGoals.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No goals set for this date.'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeGoals.length,
              itemBuilder: (context, index) {
                final goal = activeGoals[index];
                final activity = widget.activities.firstWhere((act) => act.name == goal.activityName, orElse: () => CheckableActivity(name: ''));
                if(activity.name.isEmpty) return const SizedBox.shrink();

                final monthStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
                final monthEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month + 1, 0).add(const Duration(days: 1));

                final dayStart = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
                final weekStart = dayStart.subtract(Duration(days: widget.selectedDate.weekday - 1));
                final weekEnd = weekStart.add(const Duration(days: 7));

                final goalPeriodStart = goal.goalType == GoalType.daily ? dateStart : goal.goalType == GoalType.weekly ? weekStart : monthStart;
                final goalPeriodEnd = goal.goalType == GoalType.daily ? dateEnd : goal.goalType == GoalType.weekly ? weekEnd : monthEnd;

                double percent = 0.0;
                String progressText;
                String timeLeftText = '';

                if (goal.goalType != GoalType.daily) {
                  final now = DateTime.now();
                  final endOfPeriod = goal.goalType == GoalType.weekly ? weekEnd : monthEnd;
                  final timeLeft = endOfPeriod.difference(now);

                  if (timeLeft.isNegative) {
                    timeLeftText = 'Period ended';
                  } else if (timeLeft.inHours < 48) {
                    timeLeftText = '${timeLeft.inHours} hours left';
                  } else {
                    timeLeftText = '${timeLeft.inDays} days left';
                  }
                }

                if (activity is TimedActivity) {
                  final loggedTimeInPeriod = widget.activityLogs
                      .where((log) => log.activityName == activity.name && !log.date.isBefore(goalPeriodStart) && log.date.isBefore(goalPeriodEnd))
                      .fold(Duration.zero, (sum, log) => sum + log.duration);
                  final totalTime = loggedTimeInPeriod + ((widget.selectedActivity?.name == activity.name && isToday) ? widget.elapsed : Duration.zero);

                  percent = goal.goalDuration.inSeconds == 0 ? 0.0 : (totalTime.inSeconds / goal.goalDuration.inSeconds).clamp(0.0, 1.0);
                  progressText = '${formatDuration(totalTime)} / ${formatDuration(goal.goalDuration)}';
                } else {
                  final completionsInPeriod = widget.activityLogs
                      .where((log) => log.activityName == activity.name && log.isCheckable && !log.date.isBefore(goalPeriodStart) && log.date.isBefore(goalPeriodEnd))
                      .length;

                  percent = goal.goalDuration.inMinutes == 0 ? 0.0 : (completionsInPeriod / goal.goalDuration.inMinutes).clamp(0.0, 1.0);
                  progressText = '$completionsInPeriod / ${goal.goalDuration.inMinutes} time(s)';
                }

                return ListTile(
                  title: Text('${activity.name} (${goal.goalType.toString().split('.').last})'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(percent >= 1.0 ? Colors.green : Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(progressText, style: const TextStyle(fontSize: 12)),
                          if (timeLeftText.isNotEmpty)
                            Text(timeLeftText, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary)),
                          Text('${(percent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(_currentStreak == null ? '🔥 Current Streak: ...' : '🔥 Current Streak: $_currentStreak days 🔥', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}