abstract class Activity {
  String name;
  Activity({required this.name});

  Map<String, dynamic> toJson();
}

class TimedActivity extends Activity {
  Duration totalTime;
  TimedActivity({required super.name, this.totalTime = Duration.zero});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'TimedActivity',
    'name': name,
    'totalTime': totalTime.inSeconds,
  };

  factory TimedActivity.fromJson(Map<String, dynamic> json) => TimedActivity(
    name: json['name'],
    totalTime: Duration(seconds: json['totalTime']),
  );
}

class CheckableActivity extends Activity {
  int completionCount;
  CheckableActivity({required super.name, this.completionCount = 0});

  @override
  Map<String, dynamic> toJson() => {
    'type': 'CheckableActivity',
    'name': name,
    'completionCount': completionCount,
  };

  factory CheckableActivity.fromJson(Map<String, dynamic> json) =>
      CheckableActivity(
        name: json['name'],
        completionCount: json['completionCount'],
      );
}