enum GoalType { daily, weekly }

class Goal {
  String activityName;
  Duration goalDuration;
  GoalType goalType;

  Goal({
    required this.activityName,
    required this.goalDuration,
    this.goalType = GoalType.daily,
  });

  Map<String, dynamic> toJson() => {
    'activityName': activityName,
    'goalDuration': goalDuration.inSeconds,
    'goalType': goalType.toString(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    activityName: json['activityName'],
    goalDuration: Duration(seconds: json['goalDuration']),
    goalType: json['goalType'] == GoalType.weekly.toString()
        ? GoalType.weekly
        : GoalType.daily,
  );
}