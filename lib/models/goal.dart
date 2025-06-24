enum GoalType { daily, weekly }

class Goal {
  String activityName;
  Duration goalDuration;
  GoalType goalType;
  DateTime startDate;
  DateTime? endDate;

  Goal({
    required this.activityName,
    required this.goalDuration,
    this.goalType = GoalType.daily,
    required this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'activityName': activityName,
    'goalDuration': goalDuration.inSeconds,
    'goalType': goalType.toString(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    activityName: json['activityName'],
    goalDuration: Duration(seconds: json['goalDuration']),
    goalType: json['goalType'] == GoalType.weekly.toString()
        ? GoalType.weekly
        : GoalType.daily,
    startDate: DateTime.parse(json['startDate']),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
  );
}