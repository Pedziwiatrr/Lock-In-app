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
    activityName: json['activityName'] as String? ?? 'Unnamed',
    date: DateTime.parse(json['date'] as String),
    duration: Duration(seconds: (json['duration'] as int?) ?? 0),
    isCheckable: (json['isCheckable'] as bool?) ?? false,
  );
}