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

  @override
  void initState() {
    super.initState();
    _syncEditableGoals();
  }

  @override
  void didUpdateWidget(GoalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.goals != oldWidget.goals || widget.activities != oldWidget.activities) {
      setState(() {
        _syncEditableGoals();
      });
    }
  }

  void _syncEditableGoals() {
    final now = DateTime.now();
    editableGoals = widget.activities.map((activity) {
      return widget.goals.firstWhere(
            (g) => g.activityName == activity.name,
        orElse: () => Goal(
          activityName: activity.name,
          goalDuration: Duration.zero,
          startDate: now,
          goalType: GoalType.daily,
        ),
      );
    }).toList();
  }

  void updateGoal(
      String activityName,
      String valueText,
      GoalType goalType,
      DateTime startDate,
      DateTime? endDate,
      ) {
    final value = int.tryParse(valueText) ?? 0;

    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal must be greater than 0.')),
      );
      return;
    }

    if (value > maxGoalMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal cannot exceed 10000 minutes or completions.')),
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

  void _updateGoalState(
      String activityName,
      int value,
      GoalType goalType,
      DateTime startDate,
      DateTime? endDate,
      ) {
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

  Future<void> selectDate(BuildContext context, bool isStartDate, String activityName, DateTime currentDate, TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        if (!isStartDate) {
          final startDate = editableGoals[index].startDate;
          if (pickedDate.isBefore(startDate)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('End date cannot be earlier than start date.')),
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
          controller.text = '${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}';
        });
      }
    }
  }

  void clearEndDate(String activityName, TextEditingController controller) {
    setState(() {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
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
    final updatedGoals = List<Goal>.from(widget.goals)..removeWhere((goal) => goal.id == id);
    widget.onGoalChanged(updatedGoals);
  }

  @override
  Widget build(BuildContext context) {
    final currentActivityNames = widget.activities.map((a) => a.name).toSet();
    if (editableGoals.any((g) => !currentActivityNames.contains(g.activityName))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted) {
          setState(() {
            editableGoals.removeWhere((g) => !currentActivityNames.contains(g.activityName));
          });
        }
      });
    }
    for (var activity in widget.activities) {
      if (!editableGoals.any((g) => g.activityName == activity.name)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) {
            setState(() {
              editableGoals.add(Goal(
                activityName: activity.name,
                goalDuration: Duration.zero,
                goalType: GoalType.daily,
                startDate: DateTime.now(),
              ));
            });
          }
        });
      }
    }

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
              final goal = editableGoals.firstWhere(
                    (g) => g.activityName == activity.name,
                orElse: () => Goal(
                  activityName: activity.name,
                  goalDuration: Duration.zero,
                  goalType: GoalType.daily,
                  startDate: DateTime.now(),
                ),
              );
              final controller = TextEditingController(text: goal.goalDuration.inMinutes > 0 ? goal.goalDuration.inMinutes.toString() : '');
              final startDateController = TextEditingController(
                text: '${goal.startDate.day.toString().padLeft(2, '0')}-${goal.startDate.month.toString().padLeft(2, '0')}-${goal.startDate.year}',
              );
              final endDateController = TextEditingController(
                text: goal.endDate != null
                    ? '${goal.endDate!.day.toString().padLeft(2, '0')}-${goal.endDate!.month.toString().padLeft(2, '0')}-${goal.endDate!.year}'
                    : '',
              );

              return ListTile(
                title: Text(
                  '${activity.name} ${activity is TimedActivity ? '⏰' : '✅'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Goal',
                              suffixText: activity is TimedActivity ? 'min' : 'times',
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 20),
                        DropdownButton<GoalType>(
                          value: goal.goalType,
                          items: const [
                            DropdownMenuItem(value: GoalType.daily, child: Text('Daily')),
                            DropdownMenuItem(value: GoalType.weekly, child: Text('Weekly')),
                            DropdownMenuItem(value: GoalType.monthly, child: Text('Monthly')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                final index = editableGoals.indexWhere((g) => g.activityName == activity.name);
                                final newGoalData = widget.goals.firstWhere(
                                      (g) => g.activityName == activity.name && g.goalType == val,
                                  orElse: () => Goal(
                                    activityName: activity.name,
                                    goalDuration: Duration.zero,
                                    goalType: val,
                                    startDate: editableGoals[index].startDate,
                                    endDate: editableGoals[index].endDate,
                                  ),
                                );
                                if (index != -1) {
                                  editableGoals[index] = newGoalData;
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: startDateController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              hintText: 'Select start date',
                            ),
                            onTap: () => selectDate(context, true, activity.name, goal.startDate, startDateController),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 150,
                          child: TextField(
                            controller: endDateController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              hintText: 'End date (optional)',
                              suffixIcon: goal.endDate != null
                                  ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () => clearEndDate(activity.name, endDateController),
                              )
                                  : null,
                            ),
                            onTap: () => selectDate(context, false, activity.name, goal.endDate ?? DateTime.now(), endDateController),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final currentGoal = editableGoals.firstWhere((g) => g.activityName == activity.name);
                        updateGoal(
                          activity.name,
                          controller.text,
                          currentGoal.goalType,
                          currentGoal.startDate,
                          currentGoal.endDate,
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Set'),
                    ),
                  ],
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
            const Text(
              'Goals',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

                return ListTile(
                  title: Text('${goal.activityName} - ${goal.goalType.toString().split('.').last}'),
                  subtitle: Text(
                    'Goal: $goalValue, '
                        'Start: ${goal.startDate.day.toString().padLeft(2, '0')}-${goal.startDate.month.toString().padLeft(2, '0')}-${goal.startDate.year}, '
                        'End: ${goal.endDate != null ? '${goal.endDate!.day.toString().padLeft(2, '0')}-${goal.endDate!.month.toString().padLeft(2, '0')}-${goal.endDate!.year}' : 'Ongoing'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteGoal(goal.id),
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