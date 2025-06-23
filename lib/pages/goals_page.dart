import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity.dart';
import '../models/goal.dart';

class GoalsPage extends StatefulWidget {
  final List<Goal> goals;
  final List<Activity> activities;
  final void Function(List<Goal>) onGoalChanged;

  const GoalsPage({
    super.key,
    required this.goals,
    required this.activities,
    required this.onGoalChanged,
  });

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  late List<Goal> editableGoals;
  static const int maxGoalMinutes = 10000;

  @override
  void initState() {
    super.initState();
    editableGoals = widget.activities.map((a) {
      final existingGoal = widget.goals.firstWhere(
            (g) => g.activityName == a.name,
        orElse: () => Goal(activityName: a.name, goalDuration: Duration.zero),
      );
      return Goal(
        activityName: a.name,
        goalDuration: existingGoal.goalDuration,
        goalType: existingGoal.goalType,
      );
    }).toList();
  }

  void updateGoal(
      String activityName, String valueText, bool isTimed, GoalType goalType) {
    final value = int.tryParse(valueText) ?? 0;
    if (value > maxGoalMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Goal cannot exceed 10000 minutes or completions.')),
      );
      return;
    }
    setState(() {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        editableGoals[index] = Goal(
          activityName: activityName,
          goalDuration: Duration(minutes: value),
          goalType: goalType,
        );
      } else {
        editableGoals.add(Goal(
          activityName: activityName,
          goalDuration: Duration(minutes: value),
          goalType: goalType,
        ));
      }
      widget.onGoalChanged(editableGoals);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentActivityNames = widget.activities.map((a) => a.name).toSet();
    editableGoals
        .removeWhere((g) => !currentActivityNames.contains(g.activityName));
    for (var activity in widget.activities) {
      if (!editableGoals.any((g) => g.activityName == activity.name)) {
        editableGoals.add(Goal(
          activityName: activity.name,
          goalDuration: Duration.zero,
          goalType: GoalType.daily,
        ));
      }
    }

    return ListView.builder(
      itemCount: widget.activities.length,
      itemBuilder: (context, index) {
        final activity = widget.activities[index];
        final goal = editableGoals.firstWhere(
              (g) => g.activityName == activity.name,
          orElse: () => Goal(
            activityName: activity.name,
            goalDuration: Duration.zero,
            goalType: GoalType.daily,
          ),
        );
        final controller =
        TextEditingController(text: goal.goalDuration.inMinutes.toString());
        bool isDaily = goal.goalType == GoalType.daily;

        return ListTile(
          title: Text(activity.name),
          subtitle: Row(
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    suffixText: activity is TimedActivity ? 'min' : 'times',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (val) => updateGoal(activity.name, val,
                      activity is TimedActivity, isDaily ? GoalType.daily : GoalType.weekly),
                ),
              ),
              const SizedBox(width: 20),
              DropdownButton<bool>(
                value: isDaily,
                items: const [
                  DropdownMenuItem(value: true, child: Text('Daily')),
                  DropdownMenuItem(value: false, child: Text('Weekly')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    updateGoal(activity.name, controller.text,
                        activity is TimedActivity, val ? GoalType.daily : GoalType.weekly);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}