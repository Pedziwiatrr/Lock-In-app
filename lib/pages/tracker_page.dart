import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';
import '../pages/stats_page.dart' show HistoryDataProvider;
import '../utils/ad_manager.dart';
import 'dart:io';

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

  bool get _isTesting {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    if (!_isTesting) {
      _updateStreak();
    }
  }

  Future<void> _requestPermissions() async {
    if (_isTesting) return;
    await Permission.notification.request();
  }

  @override
  void didUpdateWidget(TrackerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activityLogs != oldWidget.activityLogs || widget.goals != oldWidget.goals || widget.selectedActivity != oldWidget.selectedActivity) {
      if (!_isTesting) {
        _updateStreak();
      }
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

    final int timeLimit = cheatsEnabled ? maxManualTimeMinutes : 360;
    final int completionLimit = cheatsEnabled ? maxManualCompletions : 30;

    final int currentLimit = isTimed ? timeLimit : completionLimit;
    final String unit = isTimed ? "minutes" : "completions";

    final hoursController = TextEditingController();
    final minutesController = TextEditingController();
    final completionController = TextEditingController();

    String limitText;
    if (isTimed) {
      final int hours = currentLimit ~/ 60;
      limitText = 'Max $hours hours ($currentLimit minutes)';
    } else {
      limitText = 'Max $currentLimit $unit';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: isTimed
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hoursController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(':'),
                ),
                Expanded(
                  child: TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(limitText, style: Theme.of(context).textTheme.bodySmall),
          ],
        )
            : TextField(
          controller: completionController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            helperText: limitText,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (isTimed) {
                final int hours = int.tryParse(hoursController.text.trim()) ?? 0;
                final int minutes = int.tryParse(minutesController.text.trim()) ?? 0;
                final totalMinutes = (hours * 60) + minutes;

                if (totalMinutes > 0 && totalMinutes <= currentLimit) {
                  Navigator.pop(context);
                  onSave(totalMinutes);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Total time must be between 1 minute and $currentLimit minutes.'),
                    ),
                  );
                }
              } else {
                final value = completionController.text.trim();
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
        : () => widget.onSubtractManualCompletion(intVal);

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

  Widget _buildStreakCard(BuildContext context) {
    final int streakValue = _currentStreak ?? 0;
    final theme = Theme.of(context);
    final color = streakValue > 0 ? Colors.orange[700] : theme.colorScheme.onSurfaceVariant;
    final icon = streakValue > 0 ? Icons.local_fire_department : Icons.hourglass_empty_rounded;

    return Card(
      elevation: 4,
      shadowColor: streakValue > 0 ? Colors.orange.withOpacity(0.3) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STREAK',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '$streakValue ${streakValue == 1 ? 'day' : 'days'}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      mainDisplay = Center(child: Text(formatDuration(widget.elapsed), style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300)));
    } else if (widget.selectedActivity is CheckableActivity) {
      mainDisplay = Center(child: Text('$dateCompletions x', style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w300)));
    } else {
      mainDisplay = const Center(child: Text('00:00:00', style: TextStyle(fontSize: 60, fontWeight: FontWeight.w300, color: Colors.grey)));
    }

    final Map<String, Activity> uniqueActivitiesMap = {
      for (var a in widget.activities) a.name: a,
    };
    final List<Activity> uniqueActivitiesForDropdown = uniqueActivitiesMap.values.toList();
    final Activity? selectedActivityForDropdown = widget.selectedActivity != null
        ? uniqueActivitiesMap[widget.selectedActivity!.name]
        : null;


    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Activity>(
                    value: selectedActivityForDropdown,
                    hint: const Text('Select activity'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Activity',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                    ),
                    items: uniqueActivitiesForDropdown.map((a) {
                      final String emoji = a is TimedActivity ? '⏰' : '✅';
                      return DropdownMenuItem(
                        value: a,
                        child: Text(
                          '$emoji ${a.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return uniqueActivitiesForDropdown.map<Widget>((Activity a) {
                        final String emoji = a is TimedActivity ? '⏰' : '✅';
                        return Text(
                          '$emoji ${a.name}',
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList();
                    },
                    onChanged: widget.isRunning ? null : widget.onSelectActivity,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  onPressed: widget.isRunning ? null : () async {
                    final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: widget.selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now());
                    if (pickedDate != null) widget.onSelectDate(pickedDate);
                  },
                  label: Text('${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year.toString().substring(2)}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: mainDisplay,
            ),
            const SizedBox(height: 20),

            if (isToday)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.selectedActivity is TimedActivity) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: (widget.selectedActivity == null || widget.isRunning) ? null : widget.onStartTimer,
                      label: const Text('Start'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: widget.isRunning ? widget.onStopTimer : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stop),
                          const SizedBox(width: 8),
                          const Text('Stop'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.done_all_rounded),
                      onPressed: (widget.selectedActivity == null || widget.elapsed == Duration.zero) ? null : _handleFinish,
                      label: const Text('Finish'),
                    ),
                  ] else if (widget.selectedActivity is CheckableActivity)
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      onPressed: (widget.selectedActivity == null) ? null : _handleCheckAndAd,
                      label: const Text('Check', style: TextStyle(fontSize: 20)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),

            if (widget.selectedActivity != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => showInputDialog(
                        widget.selectedActivity is TimedActivity ? 'Add time' : 'Add completions',
                        widget.selectedActivity is TimedActivity ? 'Enter hours and minutes' : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (intVal) => _handleAddManual(intVal)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.add, size: 30),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: ((widget.selectedActivity is TimedActivity && !canSubtractTime) || (widget.selectedActivity is CheckableActivity && !canSubtractCompletion))
                        ? null
                        : () => showInputDialog(
                        widget.selectedActivity is TimedActivity ? 'Subtract time' : 'Subtract completions',
                        widget.selectedActivity is TimedActivity ? 'Enter hours and minutes' : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (intVal) => _handleSubtractManual(intVal)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                      padding: const EdgeInsets.all(16),
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.remove, size: 30),
                  ),
                ],
              ),
            const SizedBox(height: 30),

            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Today\'s activities' : 'Activities from ${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    filteredDateActivities.isEmpty
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No activities on this day.'))
                        : Column(children: filteredDateActivities.map((entry) => ListTile(title: Text(entry.key), trailing: Text((entry.value['isTimed'] as bool) ? formatDuration(entry.value['totalDuration'] as Duration) : '${entry.value['completions']} x', style: const TextStyle(fontSize: 18)))).toList()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active goals', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    activeGoals.isEmpty
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No active goals for this day.'))
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
                          progressText = '$completionsInPeriod / ${goal.goalDuration.inMinutes} x';
                        }

                        final goalTypeString = goal.goalType.toString().split('.').last;
                        final bool hasCustomTitle = goal.title != null && goal.title!.isNotEmpty;
                        final String displayTitle = hasCustomTitle
                            ? '${goal.title} - ${activity.name} ($goalTypeString)'
                            : '${activity.name} ($goalTypeString)';

                        return ListTile(
                          title: Text(displayTitle),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percent,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(5),
                                backgroundColor: theme.colorScheme.surfaceVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(percent >= 1.0 ? Colors.green : theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(progressText, style: const TextStyle(fontSize: 12)),
                                  if (timeLeftText.isNotEmpty)
                                    Text(timeLeftText, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                                  Text('${(percent * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            _buildStreakCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}