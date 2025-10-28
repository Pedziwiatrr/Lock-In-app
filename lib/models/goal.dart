import 'package:uuid/uuid.dart';

enum GoalType { daily, weekly, monthly }

class Goal {
  final String id;
  final String? title;
  String activityName;
  Duration goalDuration;
  GoalType goalType;
  DateTime startDate;
  DateTime? endDate;

  Goal({
    String? id,
    required this.activityName,
    required this.goalDuration,
    this.goalType = GoalType.daily,
    required this.startDate,
    this.endDate,
    this.title,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityName': activityName,
    'goalDuration': goalDuration.inSeconds,
    'goalType': goalType.toString(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] ?? const Uuid().v4(),
    activityName: json['activityName'],
    goalDuration: Duration(seconds: json['goalDuration']),
    goalType: json['goalType'] == 'GoalType.weekly'
        ? GoalType.weekly
        : json['goalType'] == 'GoalType.monthly'
        ? GoalType.monthly
        : GoalType.daily,
    startDate: DateTime.parse(json['startDate']),
    endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
  );
}