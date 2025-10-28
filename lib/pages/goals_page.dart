import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../models/goal.dart';
import '../utils/format_utils.dart';
import '../utils/ad_manager.dart';

class GoalsPage extends StatefulWidget {
  final List<Goal> goals;
  final List<Activity> activities;
  final void Function(List<Goal>) onGoalChanged;
  final int launchCount;

  const GoalsPage({
    super.key,
    required this.goals,
    required this.activities,
    required this.onGoalChanged,
    required this.launchCount,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<Goal> editableGoals = [];
  bool showGoals = false;
  static const int maxGoalMinutes = 10000;
  final AdManager _adManager = AdManager.instance;

  final Map<String, TextEditingController> _goalValueControllers = {};
  final Map<String, TextEditingController> _startDateControllers = {};
  final Map<String, TextEditingController> _endDateControllers = {};

  @override
  void initState() {
    super.initState();
    _syncStateAndControllers();
  }

  @override
  void didUpdateWidget(GoalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals != oldWidget.goals ||
        widget.activities != oldWidget.activities) {
      setState(() {
        _syncStateAndControllers();
      });
    }
  }

  @override
  void dispose() {
    _goalValueControllers.values.forEach((c) => c.dispose());
    _startDateControllers.values.forEach((c) => c.dispose());
    _endDateControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _syncStateAndControllers() {
    final now = DateTime.now();
    final activityNames = widget.activities.map((a) => a.name).toSet();

    editableGoals = widget.activities.map((activity) {
      final existingGoal = editableGoals.firstWhere(
            (g) => g.activityName == activity.name,
        orElse: () =>
            Goal(activityName: '',
                goalType: GoalType.daily,
                startDate: now,
                goalDuration: Duration.zero),
      );

      return widget.goals.firstWhere(
            (g) =>
        g.activityName == activity.name && g.goalType ==
            (existingGoal.activityName.isNotEmpty
                ? existingGoal.goalType
                : GoalType.daily),
        orElse: () =>
            Goal(
              activityName: activity.name,
              goalDuration: Duration.zero,
              startDate: now,
              goalType: existingGoal.activityName.isNotEmpty ? existingGoal
                  .goalType : GoalType.daily,
            ),
      );
    }).toList();

    _goalValueControllers.removeWhere((key, value) {
      if (!activityNames.contains(key)) {
        value.dispose();
        return true;
      }
      return false;
    });
    _startDateControllers.removeWhere((key, value) {
      if (!activityNames.contains(key)) {
        value.dispose();
        return true;
      }
      return false;
    });
    _endDateControllers.removeWhere((key, value) {
      if (!activityNames.contains(key)) {
        value.dispose();
        return true;
      }
      return false;
    });

    for (var goal in editableGoals) {
      _goalValueControllers
          .putIfAbsent(goal.activityName, () => TextEditingController())
          .text =
      goal.goalDuration.inMinutes > 0
          ? goal.goalDuration.inMinutes.toString()
          : '';

      _startDateControllers
          .putIfAbsent(goal.activityName, () => TextEditingController())
          .text =
      '${goal.startDate.day.toString().padLeft(2, '0')}-${goal.startDate.month
          .toString().padLeft(2, '0')}-${goal.startDate.year}';

      _endDateControllers
          .putIfAbsent(goal.activityName, () => TextEditingController())
          .text =
      goal.endDate != null ? '${goal.endDate!.day.toString().padLeft(
          2, '0')}-${goal.endDate!.month.toString().padLeft(2, '0')}-${goal
          .endDate!.year}' : '';
    }
  }

  void updateGoal(String activityName,
      String valueText,
      GoalType goalType,
      DateTime startDate,
      DateTime? endDate,) {
    final value = int.tryParse(valueText) ?? 0;

    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal must be greater than 0.')),
      );
      return;
    }

    if (value > maxGoalMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Goal cannot exceed 10000 minutes or completions.')),
      );
      return;
    }

    _adManager.incrementGoalAddCount().then((_) {
      if (_adManager.shouldShowGoalAd()) {
        _adManager.showRewardedAd(
          onUserEarnedReward: () {
            _updateGoalState(activityName, value, goalType, startDate, endDate);
          },
          onAdDismissed: () {},
          onAdFailedToShow: () {},
        );
      } else {
        _updateGoalState(activityName, value, goalType, startDate, endDate);
      }
    });
  }

  void _updateGoalState(String activityName,
      int value,
      GoalType goalType,
      DateTime startDate,
      DateTime? endDate,) {
    final updatedGoals = List<Goal>.from(widget.goals);
    final existingGoalIndex = updatedGoals.indexWhere(
            (g) => g.activityName == activityName && g.goalType == goalType);

    if (existingGoalIndex != -1) {
      final existingId = updatedGoals[existingGoalIndex].id;
      final updatedGoal = Goal(
        id: existingId,
        activityName: activityName,
        goalDuration: Duration(minutes: value),
        goalType: goalType,
        startDate: startDate,
        endDate: endDate,
      );
      updatedGoals[existingGoalIndex] = updatedGoal;
    } else {
      final newGoal = Goal(
        activityName: activityName,
        goalDuration: Duration(minutes: value),
        goalType: goalType,
        startDate: startDate,
        endDate: endDate,
      );
      updatedGoals.add(newGoal);
    }
    widget.onGoalChanged(updatedGoals);
  }

  Future<void> selectDate(BuildContext context, bool isStartDate,
      String activityName, DateTime currentDate,
      TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final index = editableGoals.indexWhere((g) =>
      g.activityName == activityName);
      if (index != -1) {
        if (!isStartDate) {
          final startDate = editableGoals[index].startDate;
          if (pickedDate.isBefore(startDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('End date cannot be earlier than start date.')),
            );
            return;
          }
        }
        setState(() {
          if (isStartDate) {
            editableGoals[index].startDate = pickedDate;
          } else {
            editableGoals[index].endDate = pickedDate;
          }
          controller.text =
          '${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month
              .toString().padLeft(2, '0')}-${pickedDate.year}';
        });
      }
    }
  }

  void clearEndDate(String activityName, TextEditingController controller) {
    setState(() {
      final index = editableGoals.indexWhere((g) =>
      g.activityName == activityName);
      if (index != -1) {
        final goal = editableGoals[index];
        editableGoals[index] = Goal(
          id: goal.id,
          activityName: goal.activityName,
          goalDuration: goal.goalDuration,
          goalType: goal.goalType,
          startDate: goal.startDate,
          endDate: null,
        );
        controller.clear();
      }
    });
  }

  void deleteGoal(String id) {
    final updatedGoals = List<Goal>.from(widget.goals)
      ..removeWhere((goal) => goal.id == id);
    widget.onGoalChanged(updatedGoals);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme
        .of(context)
        .textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.activities.length,
            itemBuilder: (context, index) {
              final activity = widget.activities[index];

              if (!_goalValueControllers.containsKey(activity.name)) {
                return const SizedBox.shrink();
              }
              final goal = editableGoals.firstWhere(
                    (g) => g.activityName == activity.name,
              );
              final controller = _goalValueControllers[activity.name]!;
              final startDateController = _startDateControllers[activity.name]!;
              final endDateController = _endDateControllers[activity.name]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activity.name} ${activity is TimedActivity
                            ? '⏰'
                            : '✅'}',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Goal',
                                suffixText: activity is TimedActivity
                                    ? 'min'
                                    : 'times',
                                border: const OutlineInputBorder(),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<GoalType>(
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                border: OutlineInputBorder(),
                              ),
                              value: goal.goalType,
                              items: const [
                                DropdownMenuItem(value: GoalType.daily,
                                    child: Text('Daily')),
                                DropdownMenuItem(value: GoalType.weekly,
                                    child: Text('Weekly')),
                                DropdownMenuItem(value: GoalType.monthly,
                                    child: Text('Monthly')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    final index = editableGoals.indexWhere((
                                        g) => g.activityName == activity.name);
                                    final newGoalData = widget.goals.firstWhere(
                                          (g) =>
                                      g.activityName == activity.name &&
                                          g.goalType == val,
                                      orElse: () =>
                                          Goal(
                                            activityName: activity.name,
                                            goalDuration: Duration.zero,
                                            goalType: val,
                                            startDate: editableGoals[index]
                                                .startDate,
                                            endDate: editableGoals[index]
                                                .endDate,
                                          ),
                                    );
                                    if (index != -1) {
                                      editableGoals[index] = newGoalData;
                                      _goalValueControllers[activity.name]!
                                          .text =
                                      newGoalData.goalDuration.inMinutes > 0
                                          ? newGoalData.goalDuration.inMinutes
                                          .toString()
                                          : '';
                                      _startDateControllers[activity.name]!
                                          .text =
                                      '${newGoalData.startDate.day
                                          .toString()
                                          .padLeft(2, '0')}-${newGoalData
                                          .startDate.month.toString().padLeft(
                                          2, '0')}-${newGoalData.startDate
                                          .year}';
                                      _endDateControllers[activity.name]!.text =
                                      newGoalData.endDate != null
                                          ? '${newGoalData.endDate!.day
                                          .toString().padLeft(
                                          2, '0')}-${newGoalData.endDate!.month
                                          .toString().padLeft(
                                          2, '0')}-${newGoalData.endDate!.year}'
                                          : '';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startDateController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                hintText: 'Select start date',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(
                                    Icons.calendar_today_outlined, size: 20),
                              ),
                              onTap: () =>
                                  selectDate(context, true, activity.name,
                                      goal.startDate, startDateController),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: endDateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                hintText: 'End date (optional)',
                                border: const OutlineInputBorder(),
                                suffixIcon: goal.endDate != null
                                    ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  tooltip: 'Clear end date',
                                  onPressed: () =>
                                      clearEndDate(
                                          activity.name, endDateController),
                                )
                                    : const Icon(
                                    Icons.calendar_today_outlined, size: 20),
                              ),
                              onTap: () =>
                                  selectDate(context, false, activity.name,
                                      goal.endDate ?? DateTime.now(),
                                      endDateController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final currentGoal = editableGoals.firstWhere((
                                g) => g.activityName == activity.name);
                            updateGoal(
                              activity.name,
                              controller.text,
                              currentGoal.goalType,
                              currentGoal.startDate,
                              currentGoal.endDate,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          icon: const Icon(Icons.check),
                          label: const Text('Set Goal'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() => showGoals = !showGoals);
            },
            child: Text(showGoals ? 'Hide Goals' : 'View Goals'),
          ),
          if (showGoals) ...[
            const SizedBox(height: 16),
            Text(
              'Active Goals',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            widget.goals.isEmpty
                ? const Text('No goals available.')
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.goals.length,
              itemBuilder: (context, index) {
                final goal = widget.goals[index];
                final activity = widget.activities.firstWhere(
                      (a) => a.name == goal.activityName,
                  orElse: () => CheckableActivity(name: goal.activityName),
                );

                String goalValue;
                if (activity is TimedActivity) {
                  goalValue = formatDuration(goal.goalDuration);
                } else {
                  goalValue = '${goal.goalDuration.inMinutes} time(s)';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    title: Text('${goal.activityName} - ${goal.goalType
                        .toString()
                        .split('.')
                        .last}'),
                    subtitle: Text(
                      'Goal: $goalValue\n'
                          'Start: ${goal.startDate.day.toString().padLeft(
                          2, '0')}-${goal.startDate.month.toString().padLeft(
                          2, '0')}-${goal.startDate.year}\n'
                          'End: ${goal.endDate != null
                          ? '${goal.endDate!.day.toString().padLeft(
                          2, '0')}-${goal.endDate!.month.toString().padLeft(
                          2, '0')}-${goal.endDate!.year}'
                          : 'Ongoing'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete goal',
                      onPressed: () => deleteGoal(goal.id),
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}