import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
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
  late List<Goal> editableGoals;
  bool showGoals = false;
  static const int maxGoalMinutes = 10000;
  final AdManager _adManager = AdManager.instance;
  bool _isAdLoaded = false;

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

    print('GoalsPage initState: launchCount = ${widget.launchCount}');
    if (widget.launchCount > 1) {
      print('GoalsPage: Attempting to load banner ad');
      _adManager.loadBannerAd(onAdLoaded: (isLoaded) {
        // _analyticsManager.logAdImpression('banner', isLoaded);
        if (mounted) {
          setState(() {
            _isAdLoaded = isLoaded;
          });
        }
      });
    } else {
      print('GoalsPage: Skipping ad load due to launchCount <= 1');
    }
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

    // _analyticsManager.logButtonClick('add_set_goal', parameters: {
    //   'activity_name': activityName,
    //   'goal_type': goalType.toString().split('.').last,
    //   'value': value.toString(),
    // });

    _adManager.incrementGoalAddCount().then((_) {
      if (_adManager.shouldShowGoalAd()) {
        print("Attempting to show rewarded ad for goal add");
        // _analyticsManager.logAdImpression('rewarded', true);
        _adManager.showRewardedAd(
          onUserEarnedReward: () {
            // _analyticsManager.logAdReward('rewarded');
            _updateGoalState(activityName, value, goalType, startDate, endDate);
          },
          onAdDismissed: () {
            // _analyticsManager.logButtonClick('ad_dismissed', parameters: {'ad_type': 'rewarded'});
            print("Ad dismissed, goal not added");
          },
          onAdFailedToShow: () {
            // _analyticsManager.logAdFailed('rewarded', 'failed_to_show');
            print("Ad failed to show, goal not added");
          },
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
    setState(() {
      final updatedGoals = List<Goal>.from(widget.goals);
      updatedGoals.removeWhere((g) => g.activityName == activityName && g.goalDuration == Duration.zero);
      updatedGoals.add(Goal(
        activityName: activityName,
        goalDuration: Duration(minutes: value),
        goalType: goalType,
        startDate: startDate,
        endDate: endDate,
      ));
      widget.onGoalChanged(updatedGoals);
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        editableGoals[index] = Goal(
          activityName: activityName,
          goalDuration: Duration(minutes: value),
          goalType: goalType,
          startDate: startDate,
          endDate: endDate,
        );
      }
    });
  }

  Future<void> selectDate(BuildContext context, bool isStartDate, String activityName, DateTime currentDate, TextEditingController controller) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      // _analyticsManager.logButtonClick(isStartDate ? 'select_start_date' : 'select_end_date', parameters: {
      //   'activity_name': activityName,
      //   'date': pickedDate.toIso8601String(),
      // });
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
          final updatedGoals = List<Goal>.from(widget.goals);
          updatedGoals.removeWhere((g) => g.activityName == activityName && g.goalDuration == Duration.zero);
          updatedGoals.add(Goal(
            activityName: activityName,
            goalDuration: editableGoals[index].goalDuration,
            goalType: editableGoals[index].goalType,
            startDate: editableGoals[index].startDate,
            endDate: editableGoals[index].endDate,
          ));
          widget.onGoalChanged(updatedGoals);
        });
      }
    }
  }

  void clearEndDate(String activityName, TextEditingController controller) {
    // _analyticsManager.logButtonClick('clear_end_date', parameters: {'activity_name': activityName});
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
        final updatedGoals = List<Goal>.from(widget.goals);
        updatedGoals.removeWhere((g) => g.activityName == activityName && g.goalDuration == Duration.zero);
        updatedGoals.add(Goal(
          activityName: activityName,
          goalDuration: goal.goalDuration,
          goalType: goal.goalType,
          startDate: goal.startDate,
          endDate: null,
        ));
        widget.onGoalChanged(updatedGoals);
      }
    });
  }

  void deleteGoal(String id) {
    // _analyticsManager.logButtonClick('delete_goal', parameters: {'goal_id': id});
    final updatedGoals = List<Goal>.from(widget.goals)..removeWhere((goal) => goal.id == id);
    widget.onGoalChanged(updatedGoals);
    setState(() {
      final now = DateTime.now();
      editableGoals = widget.activities.map((a) {
        final existingGoal = updatedGoals.firstWhere(
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
                              // _analyticsManager.logButtonClick('select_goal_type', parameters: {
                              //   'goal_type': val.toString().split('.').last,
                              //   'activity_name': activity.name,
                              // });
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
                              hintText: 'Select end date (optional)',
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
                      onPressed: () => updateGoal(
                        activity.name,
                        controller.text,
                        activity is TimedActivity,
                        goal.goalType,
                        goal.startDate,
                        goal.endDate,
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(goal.goalDuration == Duration.zero ? 'Add' : 'Set'),
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
              'Goals 🔥',
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
                return ListTile(
                  title: Text('${goal.activityName} - ${goal.goalType.toString().split('.').last}'),
                  subtitle: Text(
                    'Goal: ${formatDuration(goal.goalDuration)}, '
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
          if (_isAdLoaded && widget.launchCount > 1) ...[
            const SizedBox(height: 20),
            _adManager.getBannerAdWidget() ?? const SizedBox.shrink(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  void dispose() {
    print("GoalsPage dispose called");
    super.dispose();
  }
}