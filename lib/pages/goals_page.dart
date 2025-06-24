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
    final now = DateTime.now();
    editableGoals = widget.activities.map((a) {
      final existingGoal = widget.goals.firstWhere(
            (g) => g.activityName == a.name,
        orElse: () => Goal(
          activityName: a.name,
          goalDuration: Duration.zero,
          startDate: now,
        ),
      );
      return Goal(
        activityName: a.name,
        goalDuration: existingGoal.goalDuration,
        goalType: existingGoal.goalType,
        startDate: existingGoal.startDate,
        endDate: existingGoal.endDate,
      );
    }).toList();
  }

  void updateGoal(
      String activityName,
      String valueText,
      bool isTimed,
      GoalType goalType,
      DateTime startDate,
      DateTime? endDate,
      ) {
    final value = int.tryParse(valueText) ?? 0;
    if (value > maxGoalMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal cannot exceed 10000 minutes or completions.')),
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
          startDate: startDate,
          endDate: endDate,
        );
      } else {
        editableGoals.add(Goal(
          activityName: activityName,
          goalDuration: Duration(minutes: value),
          goalType: goalType,
          startDate: startDate,
          endDate: endDate,
        ));
      }
      widget.onGoalChanged(editableGoals);
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate, String activityName, DateTime currentDate, TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      setState(() {
        final index = editableGoals.indexWhere((g) => g.activityName == activityName);
        if (index != -1) {
          if (isStartDate) {
            editableGoals[index].startDate = pickedDate;
          } else {
            editableGoals[index].endDate = pickedDate;
          }
          controller.text = '${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}';
          widget.onGoalChanged(editableGoals);
        }
      });
    }
  }

  void _clearEndDate(String activityName, TextEditingController controller) {
    setState(() {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        final goal = editableGoals[index];
        editableGoals[index] = Goal(
          activityName: goal.activityName,
          goalDuration: goal.goalDuration,
          goalType: goal.goalType,
          startDate: goal.startDate,
          endDate: null,
        );
        controller.clear();
        widget.onGoalChanged(editableGoals);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentActivityNames = widget.activities.map((a) => a.name).toSet();
    editableGoals.removeWhere((g) => !currentActivityNames.contains(g.activityName));
    for (var activity in widget.activities) {
      if (!editableGoals.any((g) => g.activityName == activity.name)) {
        editableGoals.add(Goal(
          activityName: activity.name,
          goalDuration: Duration.zero,
          goalType: GoalType.daily,
          startDate: DateTime.now(),
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
            startDate: DateTime.now(),
          ),
        );
        final controller = TextEditingController(text: goal.goalDuration.inMinutes.toString());
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
            activity.name,
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
                      onSubmitted: (val) => updateGoal(
                        activity.name,
                        val,
                        activity is TimedActivity,
                        goal.goalType,
                        goal.startDate,
                        goal.endDate,
                      ),
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
                        updateGoal(
                          activity.name,
                          controller.text,
                          activity is TimedActivity,
                          val,
                          goal.startDate,
                          goal.endDate,
                        );
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
                      onTap: () => _selectDate(context, true, activity.name, goal.startDate, startDateController),
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
                        hintText: 'Select end date (optional)',
                        suffixIcon: goal.endDate != null
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () => _clearEndDate(activity.name, endDateController),
                        )
                            : null,
                      ),
                      onTap: () => _selectDate(context, false, activity.name, goal.endDate ?? DateTime.now(), endDateController),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}