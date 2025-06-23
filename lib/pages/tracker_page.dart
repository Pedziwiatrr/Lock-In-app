import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';

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
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const int maxManualTimeMinutes = 1000;
  static const int maxManualCompletions = 100;

  Map<String, Map<String, dynamic>> getActivitiesForSelectedDate() {
    final dateStart =
    DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month,
        widget.selectedDate.day, 23, 59, 59, 999);
    final Map<String, Map<String, dynamic>> dateActivities = {};

    for (var activity in widget.activities) {
      dateActivities[activity.name] = {
        'isTimed': activity is TimedActivity,
        'totalDuration': Duration.zero,
        'completions': 0,
      };
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(dateStart) && log.date.isBefore(dateEnd)) {
        final activityName = log.activityName;
        if (!dateActivities.containsKey(activityName)) {
          dateActivities[activityName] = {
            'isTimed': widget.activities.firstWhere(
                  (a) => a.name == activityName,
              orElse: () => TimedActivity(name: activityName),
            ) is TimedActivity,
            'totalDuration': Duration.zero,
            'completions': 0,
          };
        }

        if (log.isCheckable) {
          dateActivities[activityName]!['completions'] += 1;
        } else if (dateActivities[activityName]!['isTimed']) {
          dateActivities[activityName]!['totalDuration'] =
              (dateActivities[activityName]!['totalDuration'] as Duration) + log.duration;
        }
      }
    }

    if (widget.selectedActivity != null &&
        widget.selectedDate.day == DateTime.now().day) {
      final activityName = widget.selectedActivity!.name;
      if (!dateActivities.containsKey(activityName)) {
        dateActivities[activityName] = {
          'isTimed': widget.selectedActivity is TimedActivity,
          'totalDuration': Duration.zero,
          'completions': 0,
        };
      }

      if (widget.selectedActivity is TimedActivity) {
        dateActivities[activityName]!['totalDuration'] =
            (dateActivities[activityName]!['totalDuration'] as Duration) + widget.elapsed;
      }
    }

    return dateActivities;
  }

  void showInputDialog(
      String title, String hint, bool isTimed, Function(String) onSave) {
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
              helperText: isTimed
                  ? 'Max $maxManualTimeMinutes minutes'
                  : 'Max $maxManualCompletions completions'),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
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
              if (value.isNotEmpty &&
                  intVal != null &&
                  intVal > 0 &&
                  intVal <= (isTimed ? maxManualTimeMinutes : maxManualCompletions)) {
                onSave(value);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Enter a number between 1 and ${isTimed ? maxManualTimeMinutes : maxManualCompletions}.'),
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

  @override
  Widget build(BuildContext context) {
    final dateActivities = getActivitiesForSelectedDate();
    final dateStart =
    DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month,
        widget.selectedDate.day, 23, 59, 59, 999);
    final dateCompletions = widget.selectedActivity != null &&
        widget.selectedActivity is CheckableActivity
        ? widget.activityLogs
        .where((log) =>
    log.activityName == widget.selectedActivity!.name &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd) &&
        log.isCheckable)
        .length
        : 0;

    final filteredDateActivities = dateActivities.entries.where((entry) {
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
          .where((log) =>
      log.activityName == widget.selectedActivity!.name &&
          log.date.isAfter(dateStart) &&
          log.date.isBefore(dateEnd))
          .toList();
      canSubtractTime = widget.selectedActivity is TimedActivity &&
          relevantLogs.any((log) => !log.isCheckable && log.duration > Duration.zero);
      canSubtractCompletion = widget.selectedActivity is CheckableActivity &&
          relevantLogs.any((log) => log.isCheckable);
    }

    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;

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
                    items: widget.activities
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                        .toList(),
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
                  formatDuration(widget.elapsed),
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
                    onPressed: (widget.selectedActivity == null ||
                        widget.isRunning ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : widget.onStartTimer,
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: widget.isRunning ? widget.onStopTimer : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        widget.elapsed == Duration.zero ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : widget.onResetTimer,
                    child: const Text('Finish'),
                  ),
                ] else if (widget.selectedActivity is CheckableActivity)
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : widget.onCheckActivity,
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
                    onPressed: (widget.selectedActivity == null ||
                        widget.isRunning ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : () {
                      showInputDialog(
                        widget.selectedActivity is TimedActivity
                            ? 'Add Time'
                            : 'Add Completions',
                        widget.selectedActivity is TimedActivity
                            ? 'Enter minutes'
                            : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (value) {
                          final intVal = int.parse(value);
                          if (widget.selectedActivity is TimedActivity) {
                            widget
                                .onAddManualTime(Duration(minutes: intVal));
                          } else {
                            widget.onAddManualCompletion(intVal);
                          }
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('+', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        (widget.selectedActivity is TimedActivity &&
                            !canSubtractTime) ||
                        (widget.selectedActivity is CheckableActivity &&
                            !canSubtractCompletion) ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : () {
                      showInputDialog(
                        widget.selectedActivity is TimedActivity
                            ? 'Subtract Time'
                            : 'Subtract Completions',
                        widget.selectedActivity is TimedActivity
                            ? 'Enter minutes'
                            : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (value) {
                          final intVal = int.parse(value);
                          if (widget.selectedActivity is TimedActivity) {
                            widget.onSubtractManualTime(Duration(minutes: intVal));
                          } else {
                            widget.onSubtractManualCompletion(intVal);
                          }
                        },
                      );
                    },
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              'Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            widget.activities.where((a) {
              final goal = widget.goals.firstWhere(
                    (g) => g.activityName == a.name,
                orElse: () => Goal(activityName: a.name, goalDuration: Duration.zero),
              );
              return goal.goalDuration > Duration.zero;
            }).isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No goals set. Add goals in the Goals tab.'),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.activities.where((a) {
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == a.name,
                  orElse: () =>
                      Goal(activityName: a.name, goalDuration: Duration.zero),
                );
                return goal.goalDuration > Duration.zero;
              }).length,
              itemBuilder: (context, index) {
                final filteredActivities = widget.activities.where((a) {
                  final goal = widget.goals.firstWhere(
                        (g) => g.activityName == a.name,
                    orElse: () =>
                        Goal(activityName: a.name, goalDuration: Duration.zero),
                  );
                  return goal.goalDuration > Duration.zero;
                }).toList();

                final activity = filteredActivities[index];
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == activity.name,
                  orElse: () =>
                      Goal(activityName: activity.name, goalDuration: Duration.zero),
                );

                final dateStart = DateTime(
                    widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
                final dateEnd = DateTime(widget.selectedDate.year,
                    widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59, 999);
                final dateTime = widget.activityLogs
                    .where((log) =>
                log.activityName == activity.name &&
                    log.date.isAfter(dateStart) &&
                    log.date.isBefore(dateEnd))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (widget.isRunning &&
                        widget.selectedActivity?.name == activity.name &&
                        widget.selectedDate.day == DateTime.now().day
                        ? widget.elapsed
                        : Duration.zero);

                final dateCompletions = widget.activityLogs
                    .where((log) =>
                log.activityName == activity.name &&
                    log.date.isAfter(dateStart) &&
                    log.date.isBefore(dateEnd) &&
                    log.isCheckable)
                    .length;

                final percent = activity is TimedActivity
                    ? goal.goalDuration.inSeconds == 0
                    ? 0.0
                    : (dateTime.inSeconds / goal.goalDuration.inSeconds)
                    .clamp(0.0, 1.0)
                    : goal.goalDuration.inMinutes == 0
                    ? 0.0
                    : (dateCompletions / goal.goalDuration.inMinutes)
                    .clamp(0.0, 1.0);

                final remainingText = activity is TimedActivity
                    ? (goal.goalDuration - dateTime).isNegative
                    ? 'Goal completed!'
                    : 'Remaining: ${formatDuration(goal.goalDuration - dateTime)}'
                    : dateCompletions >= goal.goalDuration.inMinutes
                    ? 'Goal completed!'
                    : 'Remaining: ${goal.goalDuration.inMinutes - dateCompletions} completion(s)';

                return ListTile(
                  title: Text(activity.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: percent),
                      const SizedBox(height: 4),
                      Text(remainingText),
                      Text(
                          goal.goalType == GoalType.daily ? 'Daily' : 'Weekly'),
                    ],
                  ),
                  trailing: Text('${(percent * 100).toStringAsFixed(0)}%'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}