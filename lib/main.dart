import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const LockInTrackerApp());
}

class LockInTrackerApp extends StatefulWidget {
  const LockInTrackerApp({super.key});

  @override
  State<LockInTrackerApp> createState() => _LockInTrackerAppState();
}

class _LockInTrackerAppState extends State<LockInTrackerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _saveTheme(isDark);
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LockIn Tracker',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: HomePage(
        onThemeChanged: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class Goal {
  String activityName;
  Duration dailyGoal;
  Goal({required this.activityName, required this.dailyGoal});

  Map<String, dynamic> toJson() => {
    'activityName': activityName,
    'dailyGoal': dailyGoal.inSeconds,
  };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    activityName: json['activityName'],
    dailyGoal: Duration(seconds: json['dailyGoal']),
  );
}

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

  factory CheckableActivity.fromJson(Map<String, dynamic> json) => CheckableActivity(
    name: json['name'],
    completionCount: json['completionCount'],
  );
}

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

class HomePage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkMode;

  const HomePage({super.key, required this.onThemeChanged, required this.isDarkMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Activity> activities = [];
  List<ActivityLog> activityLogs = [];
  List<Goal> goals = [];
  Activity? selectedActivity;
  Stopwatch stopwatch = Stopwatch();
  Duration elapsed = Duration.zero;
  Timer? _timer;

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString('activities');
    final logsJson = prefs.getString('activityLogs');
    final goalsJson = prefs.getString('goals');

    if (activitiesJson != null) {
      final List<dynamic> activitiesList = jsonDecode(activitiesJson);
      activities = activitiesList.map((json) {
        if (json['type'] == 'TimedActivity') {
          return TimedActivity.fromJson(json);
        } else {
          return CheckableActivity.fromJson(json);
        }
      }).toList();
    } else {
      activities = [
        TimedActivity(name: 'Studying'),
        TimedActivity(name: 'Workout'),
        TimedActivity(name: 'Reading'),
        TimedActivity(name: 'Cleaning'),
        CheckableActivity(name: 'Went Gym'),
      ];
    }

    if (logsJson != null) {
      final List<dynamic> logsList = jsonDecode(logsJson);
      activityLogs = logsList.map((json) => ActivityLog.fromJson(json)).toList();
    } else {
      activityLogs = [
        ActivityLog(
          activityName: 'Studying',
          date: DateTime.now(),
          duration: const Duration(hours: 2),
        ),
        ActivityLog(
          activityName: 'Studying',
          date: DateTime.now().subtract(const Duration(days: 1)),
          duration: const Duration(hours: 2),
        ),
        ActivityLog(
          activityName: 'Workout',
          date: DateTime.now().subtract(const Duration(days: 2)),
          duration: const Duration(minutes: 90),
        ),
        ActivityLog(
          activityName: 'Reading',
          date: DateTime.now().subtract(const Duration(days: 3)),
          duration: const Duration(hours: 1, minutes: 30),
        ),
        ActivityLog(
          activityName: 'Cleaning',
          date: DateTime.now(),
          duration: const Duration(hours: 1),
        ),
        ActivityLog(
          activityName: 'Workout',
          date: DateTime.now().subtract(const Duration(days: 32)),
          duration: const Duration(hours: 1, minutes: 30),
        ),
        ActivityLog(
          activityName: 'Workout',
          date: DateTime.now().subtract(const Duration(days: 367)),
          duration: const Duration(hours: 1, minutes: 30),
        ),
        ActivityLog(
          activityName: 'Went Gym',
          date: DateTime.now(),
          duration: Duration.zero,
          isCheckable: true,
        ),
        ActivityLog(
          activityName: 'Went Gym',
          date: DateTime.now(),
          duration: Duration.zero,
          isCheckable: true,
        ),
      ];
    }

    if (goalsJson != null) {
      final List<dynamic> goalsList = jsonDecode(goalsJson);
      goals = goalsList.map((json) => Goal.fromJson(json)).toList();
    } else {
      goals = [
        Goal(activityName: 'Studying', dailyGoal: const Duration(hours: 1, minutes: 30)),
        Goal(activityName: 'Workout', dailyGoal: const Duration(hours: 1)),
        Goal(activityName: 'Went Gym', dailyGoal: const Duration(minutes: 1)),
      ];
    }

    for (var log in activityLogs) {
      final activity = activities.firstWhere(
            (a) => a.name == log.activityName,
        orElse: () {
          final newActivity = TimedActivity(name: log.activityName);
          activities.add(newActivity);
          return newActivity;
        },
      );
      if (activity is TimedActivity && !log.isCheckable) {
        activity.totalTime += log.duration;
      } else if (activity is CheckableActivity && log.isCheckable) {
        activity.completionCount += 1;
      }
    }

    setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
    await prefs.setString('activityLogs', jsonEncode(activityLogs.map((log) => log.toJson()).toList()));
    await prefs.setString('goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  void startTimer() {
    if (selectedActivity == null || selectedActivity is! TimedActivity) return;
    stopwatch.start();
    _tick();
  }

  void stopTimer() {
    if (!stopwatch.isRunning) return;
    setState(() {
      stopwatch.stop();
      elapsed = stopwatch.elapsed;
    });
    _timer?.cancel();
  }

  void resetTimer() {
    if (selectedActivity == null || stopwatch.elapsed == Duration.zero) return;
    if (stopwatch.isRunning) {
      stopwatch.stop();
      _timer?.cancel();
    }
    activityLogs.add(ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime.now(),
      duration: stopwatch.elapsed,
      isCheckable: false,
    ));
    final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
    if (activity is TimedActivity) {
      activity.totalTime += stopwatch.elapsed;
    }
    setState(() {
      elapsed = Duration.zero;
      stopwatch.reset();
    });
    _saveData();
  }

  void checkActivity() {
    if (selectedActivity == null) return;
    activityLogs.add(ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime.now(),
      duration: Duration.zero,
      isCheckable: true,
    ));
    final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
    if (activity is CheckableActivity) {
      activity.completionCount += 1;
    }
    setState(() {});
    _saveData();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (stopwatch.isRunning) {
        setState(() {
          elapsed = stopwatch.elapsed;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void updateActivities() {
    setState(() {});
    _saveData();
  }

  void selectActivity(Activity? activity) {
    if (stopwatch.isRunning) return;
    setState(() {
      selectedActivity = activity;
      elapsed = Duration.zero;
      stopwatch.reset();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.timer), text: 'Tracker'),
              Tab(icon: Icon(Icons.flag), text: 'Goals'),
              Tab(icon: Icon(Icons.list), text: 'Activities'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
              Tab(icon: Icon(Icons.calendar_today), text: 'Calendar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TrackerPage(
              activities: activities,
              goals: goals,
              activityLogs: activityLogs,
              selectedActivity: selectedActivity,
              elapsed: elapsed,
              isRunning: stopwatch.isRunning,
              onSelectActivity: selectActivity,
              onStartTimer: startTimer,
              onStopTimer: stopTimer,
              onResetTimer: resetTimer,
              onCheckActivity: checkActivity,
            ),
            GoalsPage(
              goals: goals,
              activities: activities,
              onGoalChanged: (newGoals) {
                setState(() {
                  goals = newGoals;
                });
                _saveData();
              },
            ),
            ActivitiesPage(activities: activities, onUpdate: updateActivities),
            StatsPage(
              activityLogs: activityLogs,
              activities: activities,
              goals: goals,
            ),
            CalendarPage(activityLogs: activityLogs, goals: goals),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(
                isDarkMode: widget.isDarkMode,
                onThemeChanged: widget.onThemeChanged,
              ),
            ));
          },
          child: const Icon(Icons.settings),
        ),
      ),
    );
  }
}

class TrackerPage extends StatefulWidget {
  final List<Activity> activities;
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;
  final Activity? selectedActivity;
  final Duration elapsed;
  final bool isRunning;
  final void Function(Activity?) onSelectActivity;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onCheckActivity;

  const TrackerPage({
    super.key,
    required this.activities,
    required this.goals,
    required this.activityLogs,
    required this.selectedActivity,
    required this.elapsed,
    required this.isRunning,
    required this.onSelectActivity,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onResetTimer,
    required this.onCheckActivity,
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  Map<String, Map<String, dynamic>> getTodayActivities() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    final Map<String, Map<String, dynamic>> todayActivities = {};

    for (var activity in widget.activities) {
      todayActivities[activity.name] = {
        'isTimed': activity is TimedActivity,
        'totalDuration': Duration.zero,
        'completions': 0,
      };
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(todayStart) && log.date.isBefore(todayEnd)) {
        final activityName = log.activityName;
        if (!todayActivities.containsKey(activityName)) {
          todayActivities[activityName] = {
            'isTimed': widget.activities.firstWhere(
                  (a) => a.name == activityName,
              orElse: () => TimedActivity(name: activityName),
            ) is TimedActivity,
            'totalDuration': Duration.zero,
            'completions': 0,
          };
        }

        if (log.isCheckable) {
          todayActivities[activityName]!['completions'] += 1;
        } else {
          todayActivities[activityName]!['totalDuration'] =
              (todayActivities[activityName]!['totalDuration'] as Duration) + log.duration;
        }
      }
    }

    if (widget.selectedActivity != null) {
      final activityName = widget.selectedActivity!.name;
      if (!todayActivities.containsKey(activityName)) {
        todayActivities[activityName] = {
          'isTimed': widget.selectedActivity is TimedActivity,
          'totalDuration': Duration.zero,
          'completions': 0,
        };
      }

      if (widget.selectedActivity is TimedActivity) {
        todayActivities[activityName]!['totalDuration'] =
            (todayActivities[activityName]!['totalDuration'] as Duration) + widget.elapsed;
      }
    }

    return todayActivities;
  }

  @override
  Widget build(BuildContext context) {
    final todayActivities = getTodayActivities();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    final todayCompletions = widget.selectedActivity != null && widget.selectedActivity is CheckableActivity
        ? widget.activityLogs
        .where((log) =>
    log.activityName == widget.selectedActivity!.name &&
        log.date.isAfter(todayStart) &&
        log.date.isBefore(todayEnd) &&
        log.isCheckable)
        .length
        : 0;

    final filteredTodayActivities = todayActivities.entries.where((entry) {
      final activityData = entry.value;
      final isTimed = activityData['isTimed'] as bool;
      final totalDuration = activityData['totalDuration'] as Duration;
      final completions = activityData['completions'] as int;
      return isTimed ? totalDuration > Duration.zero : completions > 0;
    }).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<Activity>(
              value: widget.selectedActivity,
              hint: const Text('Choose activity'),
              isExpanded: true,
              items: widget.activities
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                  .toList(),
              onChanged: widget.onSelectActivity,
            ),
            const SizedBox(height: 20),
            if (widget.selectedActivity is TimedActivity)
              Center(
                child: Text(
                  formatDuration(widget.elapsed),
                  style: const TextStyle(fontSize: 80),
                ),
              )
            else if (widget.selectedActivity is CheckableActivity)
              Center(
                child: Text(
                  '$todayCompletions time(s)',
                  style: const TextStyle(fontSize: 80),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.selectedActivity is TimedActivity) ...[
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || widget.isRunning)
                        ? null
                        : widget.onStartTimer,
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: widget.isRunning ? widget.onStopTimer : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null || widget.elapsed == Duration.zero)
                        ? null
                        : widget.onResetTimer,
                    child: const Text('Reset'),
                  ),
                ] else if (widget.selectedActivity is CheckableActivity)
                  ElevatedButton(
                    onPressed: widget.selectedActivity == null ? null : widget.onCheckActivity,
                    child: const Text('Check'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            filteredTodayActivities.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No activities logged today.'),
            )
                : Column(
              children: filteredTodayActivities.map((entry) {
                final activityName = entry.key;
                final activityData = entry.value;
                final isTimed = activityData['isTimed'] as bool;
                final totalDuration = activityData['totalDuration'] as Duration;
                final completions = activityData['completions'] as int;

                return ListTile(
                  title: Text(activityName),
                  trailing: Text(
                    isTimed ? formatDuration(totalDuration) : '$completions time(s)',
                    style: const TextStyle(fontSize: 18),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Goals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.activities.where((a) {
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == a.name,
                  orElse: () => Goal(activityName: a.name, dailyGoal: Duration.zero),
                );
                return goal.dailyGoal > Duration.zero;
              }).length,
              itemBuilder: (context, index) {
                final filteredActivities = widget.activities.where((a) {
                  final goal = widget.goals.firstWhere(
                        (g) => g.activityName == a.name,
                    orElse: () => Goal(activityName: a.name, dailyGoal: Duration.zero),
                  );
                  return goal.dailyGoal > Duration.zero;
                }).toList();

                final a = filteredActivities[index];
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == a.name,
                  orElse: () => Goal(activityName: a.name, dailyGoal: Duration.zero),
                );

                final today = DateTime.now();
                final todayStart = DateTime(today.year, today.month, today.day);
                final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
                final todayTime = widget.activityLogs
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(todayStart) &&
                    log.date.isBefore(todayEnd))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (widget.isRunning && widget.selectedActivity?.name == a.name && a is TimedActivity
                        ? widget.elapsed
                        : Duration.zero);

                final todayCompletions = widget.activityLogs
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(todayStart) &&
                    log.date.isBefore(todayEnd) &&
                    log.isCheckable)
                    .length;

                final percent = a is TimedActivity
                    ? goal.dailyGoal.inSeconds == 0
                    ? 0.0
                    : (todayTime.inSeconds / goal.dailyGoal.inSeconds).clamp(0.0, 1.0)
                    : goal.dailyGoal.inMinutes == 0
                    ? 0.0
                    : (todayCompletions / goal.dailyGoal.inMinutes).clamp(0.0, 1.0);

                final remainingText = a is TimedActivity
                    ? (goal.dailyGoal - todayTime).isNegative
                    ? 'Goal completed!'
                    : 'Remaining: ${formatDuration(goal.dailyGoal - todayTime)}'
                    : todayCompletions >= goal.dailyGoal.inMinutes
                    ? 'Goal completed!'
                    : 'Remaining: ${goal.dailyGoal.inMinutes - todayCompletions} completion(s)';

                return ListTile(
                  title: Text(a.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: percent),
                      const SizedBox(height: 4),
                      Text(remainingText),
                    ],
                  ),
                  trailing: Text('${(percent * 100).toStringAsFixed(0)}%'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    editableGoals = widget.activities.map((a) {
      final existingGoal = widget.goals.firstWhere(
            (g) => g.activityName == a.name,
        orElse: () => Goal(activityName: a.name, dailyGoal: Duration.zero),
      );
      return Goal(activityName: a.name, dailyGoal: existingGoal.dailyGoal);
    }).toList();
  }

  void updateGoal(String activityName, String valueText, bool isTimed) {
    final value = int.tryParse(valueText) ?? 0;
    setState(() {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        editableGoals[index] = Goal(
          activityName: activityName,
          dailyGoal: isTimed ? Duration(minutes: value) : Duration(minutes: value),
        );
      } else {
        editableGoals.add(Goal(
          activityName: activityName,
          dailyGoal: isTimed ? Duration(minutes: value) : Duration(minutes: value),
        ));
      }
      widget.onGoalChanged(editableGoals);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentActivityNames = widget.activities.map((a) => a.name).toSet();
    editableGoals.removeWhere((g) => !currentActivityNames.contains(g.activityName));
    for (var activity in widget.activities) {
      if (!editableGoals.any((g) => g.activityName == activity.name)) {
        editableGoals.add(Goal(activityName: activity.name, dailyGoal: Duration.zero));
      }
    }

    return ListView.builder(
      itemCount: widget.activities.length,
      itemBuilder: (context, index) {
        final activity = widget.activities[index];
        final goal = editableGoals.firstWhere(
              (g) => g.activityName == activity.name,
          orElse: () => Goal(activityName: activity.name, dailyGoal: Duration.zero),
        );
        final controller = TextEditingController(text: goal.dailyGoal.inMinutes.toString());
        return ListTile(
          title: Text(activity.name),
          trailing: SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: activity is TimedActivity ? 'min' : 'times',
              ),
              onSubmitted: (val) => updateGoal(activity.name, val, activity is TimedActivity),
            ),
          ),
        );
      },
    );
  }
}

enum StatsPeriod { day, week, month, total }

class StatsPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;
  final List<Goal> goals;

  const StatsPage({
    super.key,
    required this.activityLogs,
    required this.activities,
    required this.goals,
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod selectedPeriod = StatsPeriod.total;

  Duration getGoalForActivity(String name) {
    final goal = widget.goals.firstWhere(
          (g) => g.activityName == name,
      orElse: () => Goal(activityName: name, dailyGoal: Duration.zero),
    );
    return goal.dailyGoal;
  }

  Map<String, dynamic> filteredActivities() {
    DateTime now = DateTime.now();
    DateTime from;

    switch (selectedPeriod) {
      case StatsPeriod.day:
        from = DateTime(now.year, now.month, now.day);
        break;
      case StatsPeriod.week:
        from = now.subtract(Duration(days: now.weekday - 1));
        break;
      case StatsPeriod.month:
        from = DateTime(now.year, now.month, 1);
        break;
      case StatsPeriod.total:
        from = DateTime(2000);
        break;
    }

    Map<String, Duration> timeTotals = {};
    Map<String, int> completionTotals = {};

    for (var activity in widget.activities) {
      timeTotals[activity.name] = Duration.zero;
      completionTotals[activity.name] = 0;
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(from)) {
        if (log.isCheckable) {
          completionTotals[log.activityName] = (completionTotals[log.activityName] ?? 0) + 1;
        } else {
          timeTotals[log.activityName] = (timeTotals[log.activityName] ?? Duration.zero) + log.duration;
        }
      }
    }

    return {'timeTotals': timeTotals, 'completionTotals': completionTotals};
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final stats = filteredActivities();
    final timeTotals = stats['timeTotals'] as Map<String, Duration>;
    final completionTotals = stats['completionTotals'] as Map<String, int>;
    final totalTime = timeTotals.values.fold<Duration>(Duration.zero, (sum, t) => sum + t);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButton<StatsPeriod>(
            value: selectedPeriod,
            items: const [
              DropdownMenuItem(value: StatsPeriod.day, child: Text('Last Day')),
              DropdownMenuItem(value: StatsPeriod.week, child: Text('Last Week')),
              DropdownMenuItem(value: StatsPeriod.month, child: Text('Last Month')),
              DropdownMenuItem(value: StatsPeriod.total, child: Text('Total')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedPeriod = val;
              });
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Total timed activity: ${formatDuration(totalTime)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: widget.activities.map((a) {
                final goalDuration = getGoalForActivity(a.name);
                final percent = a is TimedActivity
                    ? goalDuration.inSeconds == 0
                    ? 0.0
                    : ((timeTotals[a.name]?.inSeconds ?? 0) / goalDuration.inSeconds).clamp(0.0, 1.0)
                    : goalDuration.inMinutes == 0
                    ? 0.0
                    : ((completionTotals[a.name] ?? 0) / goalDuration.inMinutes).clamp(0.0, 1.0);
                return ListTile(
                  title: Text(a.name),
                  subtitle: LinearProgressIndicator(value: percent),
                  trailing: Text(a is TimedActivity
                      ? formatDuration(timeTotals[a.name] ?? Duration.zero)
                      : '${completionTotals[a.name] ?? 0} times'),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ActivitiesPage extends StatefulWidget {
  final List<Activity> activities;
  final VoidCallback onUpdate;

  const ActivitiesPage({
    super.key,
    required this.activities,
    required this.onUpdate,
  });

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  bool _isTimedActivity = true;

  void addActivity() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Activity name'),
              ),
              Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _isTimedActivity,
                    onChanged: (val) {
                      setDialogState(() {
                        _isTimedActivity = val!;
                      });
                    },
                  ),
                  const Text('Timed'),
                  Radio<bool>(
                    value: false,
                    groupValue: _isTimedActivity,
                    onChanged: (val) {
                      setDialogState(() {
                        _isTimedActivity = val!;
                      });
                    },
                  ),
                  const Text('Checkable'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && !widget.activities.any((a) => a.name == name)) {
                  setState(() {
                    widget.activities.add(_isTimedActivity
                        ? TimedActivity(name: name)
                        : CheckableActivity(name: name));
                  });
                  widget.onUpdate();
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void renameActivity(int index) {
    final controller = TextEditingController(text: widget.activities[index].name);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Activity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  widget.activities[index].name = name;
                });
                widget.onUpdate();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void deleteActivity(int index) {
    setState(() {
      widget.activities.removeAt(index);
    });
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: addActivity,
          icon: const Icon(Icons.add),
          label: const Text('Add Activity'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.activities.length,
            itemBuilder: (context, index) {
              final a = widget.activities[index];
              return ListTile(
                title: Text(a.name),
                subtitle: Text(a is TimedActivity ? 'Timed' : 'Checkable'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => renameActivity(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => deleteActivity(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum CalendarPeriod { week, month, threeMonths, allTime }

class CalendarPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;

  const CalendarPage({
    super.key,
    required this.activityLogs,
    required this.goals,
  });

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarPeriod selectedPeriod = CalendarPeriod.allTime;

  Map<DateTime, Duration> _aggregateByDay() {
    Map<DateTime, Duration> result = {};
    for (var log in widget.activityLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      result[day] = (result[day] ?? Duration.zero) + log.duration;
    }
    return result;
  }

  Map<DateTime, Map<String, dynamic>> _calculateGoalProgress() {
    final progress = <DateTime, Map<String, dynamic>>{};
    final dayData = _aggregateByDay();
    final today = DateTime.now();

    DateTime minDate;
    switch (selectedPeriod) {
      case CalendarPeriod.week:
        minDate = today.subtract(const Duration(days: 7));
        break;
      case CalendarPeriod.month:
        minDate = today.subtract(const Duration(days: 30));
        break;
      case CalendarPeriod.threeMonths:
        minDate = today.subtract(const Duration(days: 90));
        break;
      case CalendarPeriod.allTime:
        minDate = widget.activityLogs.isNotEmpty
            ? widget.activityLogs
            .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
            .reduce((a, b) => a.isBefore(b) ? a : b)
            : DateTime(2000);
        break;
    }

    final daysDiff = today.difference(minDate).inDays;

    for (int i = 0; i <= daysDiff; i++) {
      final day = today.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
      final dayKey = DateTime(day.year, day.month, day.day);

      int completedGoals = 0;
      final totalGoals = widget.goals.where((g) => g.dailyGoal > Duration.zero).length;

      for (var goal in widget.goals.where((g) => g.dailyGoal > Duration.zero)) {
        final activity = widget.activityLogs
            .where((log) =>
        log.activityName == goal.activityName &&
            log.date.isAfter(dayStart) &&
            log.date.isBefore(dayEnd))
            .toList();

        bool isCompleted = false;
        if (activity.isNotEmpty) {
          if (activity.any((log) => log.isCheckable)) {
            final completions = activity.where((log) => log.isCheckable).length;
            if (completions >= goal.dailyGoal.inMinutes) {
              isCompleted = true;
            }
          } else {
            final totalTime = activity.fold<Duration>(
                Duration.zero, (sum, log) => sum + log.duration);
            if (totalTime >= goal.dailyGoal) {
              isCompleted = true;
            }
          }
        }

        if (isCompleted) {
          completedGoals++;
        }
      }

      Color color;
      if (totalGoals == 0) {
        color = Colors.grey;
      } else if (completedGoals == totalGoals) {
        color = Colors.green;
      } else if (completedGoals > 0) {
        color = Colors.yellow;
      } else {
        color = Colors.red;
      }

      progress[dayKey] = {
        'completedGoals': completedGoals,
        'totalGoals': totalGoals,
        'color': color,
        'duration': dayData[dayKey] ?? Duration.zero,
      };
    }

    return progress;
  }

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateGoalProgress();
    final sortedDays = progress.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButton<CalendarPeriod>(
            value: selectedPeriod,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: CalendarPeriod.week, child: Text('Last Week')),
              DropdownMenuItem(value: CalendarPeriod.month, child: Text('Last Month')),
              DropdownMenuItem(value: CalendarPeriod.threeMonths, child: Text('Last 3 Months')),
              DropdownMenuItem(value: CalendarPeriod.allTime, child: Text('All Time')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedPeriod = val;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDays.length,
            itemBuilder: (context, index) {
              final day = sortedDays[index];
              final dayData = progress[day]!;
              final duration = dayData['duration'] as Duration;
              final completedGoals = dayData['completedGoals'] as int;
              final totalGoals = dayData['totalGoals'] as int;
              final color = dayData['color'] as Color;

              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                title: Text(
                    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'),
                subtitle: Text('Completed goals: $completedGoals/$totalGoals'),
                trailing: Text(formatDuration(duration)),
              );
            },
          ),
        ),
      ],
    );
  }
}



class SettingsPage extends StatelessWidget {
  final bool isDarkMode;
  final void Function(bool) onThemeChanged;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: SwitchListTile(
          title: const Text('Dark Mode'),
          value: isDarkMode,
          onChanged: onThemeChanged,
        ),
      ),
    );
  }
}