class ActivityLog {
  String activityName;
  DateTime date;
  Duration duration;
  bool isCheckable;

  ActivityLog({
    required this.activityName,
    required this.date,
    required this.duration,
    this.isCheckable = false,
  });

  Map<String, dynamic> toJson() => {
    'activityName': activityName,
    'date': date.toIso8601String(),
    'duration': duration.inSeconds,
    'isCheckable': isCheckable,
  };

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
    activityName: json['activityName'],
    date: DateTime.parse(json['date']),
    duration: Duration(seconds: json['duration']),
    isCheckable: json['isCheckable'],
  );
}