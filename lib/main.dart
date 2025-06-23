import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
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
        onResetData: () {},
      ),
    );
  }
}

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
  final VoidCallback onResetData;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.onResetData,
  });

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
  DateTime selectedDate = DateTime.now();

  static const int maxLogs = 1000;
  static const int maxManualTimeMinutes = 1000;
  static const int maxManualCompletions = 50;
  static const int maxActivities = 10;
  static const int maxGoals = 10;

  Future<void> _loadData(int shouldLoadDefaultData) async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString('activities');
    final logsJson = prefs.getString('activityLogs');
    final goalsJson = prefs.getString('goals');

    if (activitiesJson != null) {
      final List<dynamic> activitiesList = jsonDecode(activitiesJson);
      activities = activitiesList
          .map((json) {
        if (json['type'] == 'TimedActivity') {
          return TimedActivity.fromJson(json);
        } else {
          return CheckableActivity.fromJson(json);
        }
      })
          .take(maxActivities)
          .toList();
    } else if (shouldLoadDefaultData == 1) {
      activities = [
        TimedActivity(name: 'Focus'),
        CheckableActivity(name: 'Drink water'),
      ];
    }

    if (logsJson != null) {
      final List<dynamic> logsList = jsonDecode(logsJson);
      activityLogs = logsList
          .map((json) => ActivityLog.fromJson(json))
          .toList()
          .take(maxLogs)
          .toList();
      activityLogs = activityLogs.map((log) {
        if (log.activityName == 'Drink water') {
          return ActivityLog(
            activityName: log.activityName,
            date: log.date,
            duration: Duration.zero,
            isCheckable: true,
          );
        }
        return log;
      }).toList();
    }

    if (goalsJson != null) {
      final List<dynamic> goalsList = jsonDecode(goalsJson);
      goals = goalsList
          .map((json) => Goal.fromJson(json))
          .take(maxGoals)
          .toList();
    }

    for (var log in activityLogs) {
      final activity = activities.firstWhere(
            (a) => a.name == log.activityName,
        orElse: () {
          if (activities.length >= maxActivities) return activities.first;
          final newActivity = log.isCheckable
              ? CheckableActivity(name: log.activityName)
              : TimedActivity(name: log.activityName);
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
    if (activityLogs.length > maxLogs) {
      activityLogs = activityLogs
          .sublist(activityLogs.length - maxLogs, activityLogs.length);
    }
    if (activities.length > maxActivities) {
      activities = activities.sublist(0, maxActivities);
    }
    if (goals.length > maxGoals) {
      goals = goals.sublist(0, maxGoals);
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(
          'activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
      await prefs.setString('activityLogs',
          jsonEncode(activityLogs.map((log) => log.toJson()).toList()));
      await prefs.setString(
          'goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
      print(
          'Data saved: ${activities.length} activities, ${activityLogs.length} logs, ${goals.length} goals');
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _resetData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      activities = [];
      activityLogs = [];
      goals = [];
      selectedActivity = null;
      elapsed = Duration.zero;
      stopwatch.reset();
      _timer?.cancel();
    });
    await prefs.remove('activities');
    await prefs.remove('activityLogs');
    await prefs.remove('goals');
    await _loadData(1);
    print('All data reset and reinitialized');
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
    if (activityLogs.length >= maxLogs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
      );
      return;
    }
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
          DateTime.now().hour, DateTime.now().minute),
      duration: stopwatch.elapsed,
      isCheckable: false,
    );
    setState(() {
      activityLogs.add(log);
      final activity =
      activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += stopwatch.elapsed;
      }
      elapsed = Duration.zero;
      stopwatch.reset();
    });
    print(
        'Timer reset: Added log for ${log.activityName} on ${log.date} with duration ${log.duration}');
    _saveData();
  }

  void checkActivity() {
    if (selectedActivity == null || activityLogs.length >= maxLogs) {
      if (activityLogs.length >= maxLogs) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
        );
      }
      return;
    }
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
          DateTime.now().hour, DateTime.now().minute),
      duration: Duration.zero,
      isCheckable: true,
    );
    setState(() {
      activityLogs.add(log);
      final activity =
      activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is CheckableActivity) {
        activity.completionCount += 1;
      }
    });
    print('Check activity: Added log for ${log.activityName} on ${log.date}');
    _saveData();
  }

  void addManualTime(Duration duration) {
    if (selectedActivity == null ||
        selectedActivity is! TimedActivity ||
        duration <= Duration.zero ||
        duration > Duration(minutes: maxManualTimeMinutes) ||
        activityLogs.length >= maxLogs) {
      if (duration > Duration(minutes: maxManualTimeMinutes)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Manual time cannot exceed 1000 minutes.')),
        );
      } else if (activityLogs.length >= maxLogs) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
        );
      }
      return;
    }
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
          DateTime.now().hour, DateTime.now().minute),
      duration: duration,
      isCheckable: false,
    );
    setState(() {
      activityLogs.add(log);
      final activity =
      activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += duration;
      }
    });
    print(
        'Manual time added: ${log.activityName} on ${log.date} with duration ${log.duration}');
    _saveData();
  }

  void subtractManualTime(Duration duration) {
    if (selectedActivity == null ||
        selectedActivity is! TimedActivity ||
        duration <= Duration.zero) return;
    final dateStart =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, 23, 59, 59, 999);
    final relevantLogs = activityLogs
        .where((log) =>
    log.activityName == selectedActivity!.name &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd) &&
        !log.isCheckable)
        .toList();
    if (relevantLogs.isEmpty) return;

    setState(() {
      relevantLogs.sort((a, b) => b.date.compareTo(a.date));
      final logToRemove = relevantLogs.first;
      activityLogs.remove(logToRemove);
      final activity =
      activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime -= logToRemove.duration;
        if (activity.totalTime < Duration.zero)
          activity.totalTime = Duration.zero;
      }
    });
    print(
        'Manual time subtracted: ${selectedActivity!.name} on $selectedDate with duration $duration');
    _saveData();
  }

  void addManualCompletion(int count) {
    if (selectedActivity == null ||
        selectedActivity is! CheckableActivity ||
        count <= 0 ||
        count > maxManualCompletions ||
        activityLogs.length + count > maxLogs) {
      if (count > maxManualCompletions) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Manual completions cannot exceed 50.')),
        );
      } else if (activityLogs.length + count > maxLogs) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
        );
      }
      return;
    }
    setState(() {
      for (int i = 0; i < count; i++) {
        final log = ActivityLog(
          activityName: selectedActivity!.name,
          date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              DateTime.now().hour, DateTime.now().minute),
          duration: Duration.zero,
          isCheckable: true,
        );
        activityLogs.add(log);
        final activity =
        activities.firstWhere((a) => a.name == selectedActivity!.name);
        if (activity is CheckableActivity) {
          activity.completionCount += 1;
        }
      }
    });
    print(
        'Manual completions added: $count for ${selectedActivity!.name} on $selectedDate');
    _saveData();
  }

  void subtractManualCompletion(int count) {
    if (selectedActivity == null ||
        selectedActivity is! CheckableActivity ||
        count <= 0) return;
    final dateStart =
    DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, 23, 59, 59, 999);
    final relevantLogs = activityLogs
        .where((log) =>
    log.activityName == selectedActivity!.name &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd) &&
        log.isCheckable)
        .toList();
    if (relevantLogs.isEmpty) return;

    setState(() {
      relevantLogs.sort((a, b) => b.date.compareTo(a.date));
      for (int i = 0; i < min(count, relevantLogs.length); i++) {
        activityLogs.remove(relevantLogs[i]);
        final activity =
        activities.firstWhere((a) => a.name == selectedActivity!.name);
        if (activity is CheckableActivity) {
          activity.completionCount -= 1;
          if (activity.completionCount < 0) activity.completionCount = 0;
        }
      }
    });
    print(
        'Manual completions subtracted: $count for ${selectedActivity!.name} on $selectedDate');
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
    print('Activities updated: ${activities.length} activities');
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

  void selectDate(DateTime date) {
    setState(() {
      selectedDate = date;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData(1);
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
            selectedDate: selectedDate,
            elapsed: elapsed,
            isRunning: stopwatch.isRunning,
            onSelectActivity: selectActivity,
            onSelectDate: selectDate,
            onStartTimer: startTimer,
            onStopTimer: stopTimer,
            onResetTimer: resetTimer,
            onCheckActivity: checkActivity,
            onAddManualTime: addManualTime,
            onSubtractManualTime: subtractManualTime,
            onAddManualCompletion: addManualCompletion,
            onSubtractManualCompletion: subtractManualCompletion,
          ),
          GoalsPage(
            goals: goals,
            activities: activities,
            onGoalChanged: (newGoals) {
              setState(() {
                goals = newGoals.take(maxGoals).toList();
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
              onResetData: _resetData,
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
  final DateTime selectedDate;
  final Duration elapsed;
  final bool isRunning;
  final void Function(Activity?) onSelectActivity;
  final void Function(DateTime) onSelectDate;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onCheckActivity;
  final void Function(Duration) onAddManualTime;
  final void Function(Duration) onSubtractManualTime;
  final void Function(int) onAddManualCompletion;
  final void Function(int) onSubtractManualCompletion;

  const TrackerPage({
    super.key,
    required this.activities,
    required this.goals,
    required this.activityLogs,
    required this.selectedActivity,
    required this.selectedDate,
    required this.elapsed,
    required this.isRunning,
    required this.onSelectActivity,
    required this.onSelectDate,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onResetTimer,
    required this.onCheckActivity,
    required this.onAddManualTime,
    required this.onSubtractManualTime,
    required this.onAddManualCompletion,
    required this.onSubtractManualCompletion,
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  static const int maxManualTimeMinutes = 1000;
  static const int maxManualCompletions = 100;

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  Map<String, Map<String, dynamic>> getActivitiesForSelectedDate() {
    final dateStart =
    DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month,
        widget.selectedDate.day, 23, 59, 59, 999);
    final Map<String, Map<String, dynamic>> dateActivities = {};

    for (var activity in widget.activities) {
      dateActivities[activity.name] = {
        'isTimed': activity is TimedActivity,
        'totalDuration': Duration.zero,
        'completions': 0,
      };
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(dateStart) && log.date.isBefore(dateEnd)) {
        final activityName = log.activityName;
        if (!dateActivities.containsKey(activityName)) {
          dateActivities[activityName] = {
            'isTimed': widget.activities.firstWhere(
                  (a) => a.name == activityName,
              orElse: () => TimedActivity(name: activityName),
            ) is TimedActivity,
            'totalDuration': Duration.zero,
            'completions': 0,
          };
        }

        if (log.isCheckable) {
          dateActivities[activityName]!['completions'] += 1;
        } else if (dateActivities[activityName]!['isTimed']) {
          dateActivities[activityName]!['totalDuration'] =
              (dateActivities[activityName]!['totalDuration'] as Duration) + log.duration;
        }
      }
    }

    if (widget.selectedActivity != null &&
        widget.selectedDate.day == DateTime.now().day) {
      final activityName = widget.selectedActivity!.name;
      if (!dateActivities.containsKey(activityName)) {
        dateActivities[activityName] = {
          'isTimed': widget.selectedActivity is TimedActivity,
          'totalDuration': Duration.zero,
          'completions': 0,
        };
      }

      if (widget.selectedActivity is TimedActivity) {
        dateActivities[activityName]!['totalDuration'] =
            (dateActivities[activityName]!['totalDuration'] as Duration) + widget.elapsed;
      }
    }

    return dateActivities;
  }

  void showInputDialog(
      String title, String hint, bool isTimed, Function(String) onSave) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              hintText: hint,
              helperText: isTimed
                  ? 'Max $maxManualTimeMinutes minutes'
                  : 'Max $maxManualCompletions completions'),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              final intVal = int.tryParse(value);
              if (value.isNotEmpty &&
                  intVal != null &&
                  intVal > 0 &&
                  intVal <= (isTimed ? maxManualTimeMinutes : maxManualCompletions)) {
                onSave(value);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Enter a number between 1 and ${isTimed ? maxManualTimeMinutes : maxManualCompletions}.'),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateActivities = getActivitiesForSelectedDate();
    final dateStart =
    DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    final dateEnd = DateTime(widget.selectedDate.year, widget.selectedDate.month,
        widget.selectedDate.day, 23, 59, 59, 999);
    final dateCompletions = widget.selectedActivity != null &&
        widget.selectedActivity is CheckableActivity
        ? widget.activityLogs
        .where((log) =>
    log.activityName == widget.selectedActivity!.name &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd) &&
        log.isCheckable)
        .length
        : 0;

    final filteredDateActivities = dateActivities.entries.where((entry) {
      final activityData = entry.value;
      final isTimed = activityData['isTimed'] as bool;
      final totalDuration = activityData['totalDuration'] as Duration;
      final completions = activityData['completions'] as int;
      return isTimed ? totalDuration > Duration.zero : completions > 0;
    }).toList();

    bool canSubtractTime = false;
    bool canSubtractCompletion = false;
    if (widget.selectedActivity != null) {
      final relevantLogs = widget.activityLogs
          .where((log) =>
      log.activityName == widget.selectedActivity!.name &&
          log.date.isAfter(dateStart) &&
          log.date.isBefore(dateEnd))
          .toList();
      canSubtractTime = widget.selectedActivity is TimedActivity &&
          relevantLogs.any((log) => !log.isCheckable && log.duration > Duration.zero);
      canSubtractCompletion = widget.selectedActivity is CheckableActivity &&
          relevantLogs.any((log) => log.isCheckable);
    }

    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Activity>(
                    value: widget.selectedActivity,
                    hint: const Text('Choose activity'),
                    isExpanded: true,
                    items: widget.activities
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                        .toList(),
                    onChanged: widget.onSelectActivity,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: widget.selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      widget.onSelectDate(pickedDate);
                    }
                  },
                  child: Text(
                    '${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.selectedActivity is TimedActivity)
              Center(
                child: Text(
                  formatDuration(widget.elapsed),
                  style: const TextStyle(fontSize: 60),
                ),
              )
            else if (widget.selectedActivity is CheckableActivity)
              Center(
                child: Text(
                  '$dateCompletions time(s)',
                  style: const TextStyle(fontSize: 60),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.selectedActivity is TimedActivity) ...[
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        widget.isRunning ||
                        widget.selectedDate.isAfter(DateTime.now()))
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
                    onPressed: (widget.selectedActivity == null ||
                        widget.elapsed == Duration.zero ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : widget.onResetTimer,
                    child: const Text('Finish'),
                  ),
                ] else if (widget.selectedActivity is CheckableActivity)
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : widget.onCheckActivity,
                    child: const Text('Check', style: TextStyle(fontSize: 20)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.selectedActivity != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        widget.isRunning ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : () {
                      showInputDialog(
                        widget.selectedActivity is TimedActivity
                            ? 'Add Time'
                            : 'Add Completions',
                        widget.selectedActivity is TimedActivity
                            ? 'Enter minutes'
                            : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (value) {
                          final intVal = int.parse(value);
                          if (widget.selectedActivity is TimedActivity) {
                            widget
                                .onAddManualTime(Duration(minutes: intVal));
                          } else {
                            widget.onAddManualCompletion(intVal);
                          }
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('+', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: (widget.selectedActivity == null ||
                        (widget.selectedActivity is TimedActivity &&
                            !canSubtractTime) ||
                        (widget.selectedActivity is CheckableActivity &&
                            !canSubtractCompletion) ||
                        widget.selectedDate.isAfter(DateTime.now()))
                        ? null
                        : () {
                      showInputDialog(
                        widget.selectedActivity is TimedActivity
                            ? 'Subtract Time'
                            : 'Subtract Completions',
                        widget.selectedActivity is TimedActivity
                            ? 'Enter minutes'
                            : 'Enter number of completions',
                        widget.selectedActivity is TimedActivity,
                            (value) {
                          final intVal = int.parse(value);
                          if (widget.selectedActivity is TimedActivity) {
                            widget.onSubtractManualTime(
                                Duration(minutes: intVal));
                          } else {
                            widget.onSubtractManualCompletion(intVal);
                          }
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('-', style: TextStyle(fontSize: 30)),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            Text(
              isToday
                  ? 'Today'
                  : 'Selected Date (${widget.selectedDate.day.toString().padLeft(2, '0')}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.year})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            filteredDateActivities.isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No activities logged for this date.'),
            )
                : Column(
              children: filteredDateActivities.map((entry) {
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
            widget.activities.where((a) {
              final goal = widget.goals.firstWhere(
                    (g) => g.activityName == a.name,
                orElse: () => Goal(activityName: a.name, goalDuration: Duration.zero),
              );
              return goal.goalDuration > Duration.zero;
            }).isEmpty
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No goals set. Add goals in the Goals tab.'),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.activities.where((a) {
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == a.name,
                  orElse: () =>
                      Goal(activityName: a.name, goalDuration: Duration.zero),
                );
                return goal.goalDuration > Duration.zero;
              }).length,
              itemBuilder: (context, index) {
                final filteredActivities = widget.activities.where((a) {
                  final goal = widget.goals.firstWhere(
                        (g) => g.activityName == a.name,
                    orElse: () =>
                        Goal(activityName: a.name, goalDuration: Duration.zero),
                  );
                  return goal.goalDuration > Duration.zero;
                }).toList();

                final a = filteredActivities[index];
                final goal = widget.goals.firstWhere(
                      (g) => g.activityName == a.name,
                  orElse: () =>
                      Goal(activityName: a.name, goalDuration: Duration.zero),
                );

                final dateStart = DateTime(
                    widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
                final dateEnd = DateTime(widget.selectedDate.year,
                    widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59, 999);
                final dateTime = widget.activityLogs
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(dateStart) &&
                    log.date.isBefore(dateEnd))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (widget.isRunning &&
                        widget.selectedActivity?.name == a.name &&
                        widget.selectedDate.day == DateTime.now().day
                        ? widget.elapsed
                        : Duration.zero);

                final dateCompletions = widget.activityLogs
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(dateStart) &&
                    log.date.isBefore(dateEnd) &&
                    log.isCheckable)
                    .length;

                final percent = a is TimedActivity
                    ? goal.goalDuration.inSeconds == 0
                    ? 0.0
                    : (dateTime.inSeconds / goal.goalDuration.inSeconds)
                    .clamp(0.0, 1.0)
                    : goal.goalDuration.inMinutes == 0
                    ? 0.0
                    : (dateCompletions / goal.goalDuration.inMinutes)
                    .clamp(0.0, 1.0);

                final remainingText = a is TimedActivity
                    ? (goal.goalDuration - dateTime).isNegative
                    ? 'Goal completed!'
                    : 'Remaining: ${formatDuration(goal.goalDuration - dateTime)}'
                    : dateCompletions >= goal.goalDuration.inMinutes
                    ? 'Goal completed!'
                    : 'Remaining: ${goal.goalDuration.inMinutes - dateCompletions} completion(s)';

                return ListTile(
                  title: Text(a.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: percent),
                      const SizedBox(height: 4),
                      Text(remainingText),
                      Text(
                          goal.goalType == GoalType.daily ? 'Daily' : 'Weekly'),
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
  String? selectedActivity;

  List<BarChartGroupData> getTimedChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars;
    DateTime startDate;

    switch (selectedPeriod) {
      case StatsPeriod.day:
        numBars = 1;
        startDate = today;
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    for (var log in widget.activityLogs.where((log) => !log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if (logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.day) {
          if (logDay.isAtSameMomentAs(today)) {
            index = 0;
          } else {
            continue;
          }
        } else if (selectedPeriod == StatsPeriod.week) {
          index = logDay.difference(startDate).inDays;
        } else if (selectedPeriod == StatsPeriod.month) {
          index = ((logDay.difference(startDate).inDays) / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += log.duration.inMinutes.toDouble();
        }
      }
    }


    return totals.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Theme.of(context).colorScheme.primary,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  List<BarChartGroupData> getCheckableChartData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    List<double> totals = [];
    int numBars;
    DateTime startDate;

    switch (selectedPeriod) {
      case StatsPeriod.day:
        numBars = 1;
        startDate = today;
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.week:
        numBars = 7;
        startDate = today.subtract(Duration(days: now.weekday - 1));
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.month:
        numBars = 4;
        startDate = DateTime(now.year, now.month, 1);
        totals = List.filled(numBars, 0.0);
        break;
      case StatsPeriod.total:
        numBars = 12;
        startDate = DateTime(now.year, now.month - 11, 1);
        totals = List.filled(numBars, 0.0);
        break;
    }

    for (var log in widget.activityLogs.where((log) => log.isCheckable && (selectedActivity == null || log.activityName == selectedActivity))) {
      final logDay = DateTime(log.date.year, log.date.month, log.date.day);
      if (logDay.isAtSameMomentAs(startDate) || logDay.isAfter(startDate)) {
        int index;
        if (selectedPeriod == StatsPeriod.day) {
          if (logDay.isAtSameMomentAs(today)) {
            index = 0;
          } else {
            continue;
          }
        } else if (selectedPeriod == StatsPeriod.week) {
          index = logDay.difference(startDate).inDays;
        } else if (selectedPeriod == StatsPeriod.month) {
          index = ((logDay.difference(startDate).inDays) / 7).floor();
        } else {
          index = (logDay.year - startDate.year) * 12 + logDay.month - startDate.month;
        }
        if (index >= 0 && index < numBars) {
          totals[index] += 1.0;
        }
      }
    }


    return totals.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Theme.of(context).colorScheme.secondary,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();
  }

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
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
        from = widget.activityLogs.isNotEmpty
            ? widget.activityLogs
            .map((log) => DateTime(log.date.year, log.date.month, log.date.day))
            .reduce((a, b) => a.isBefore(b) ? a : b)
            : DateTime(2000);
        break;
    }

    Map<String, Duration> timeTotals = {};
    Map<String, int> completionTotals = {};

    for (var activity in widget.activities) {
      timeTotals[activity.name] = Duration.zero;
      completionTotals[activity.name] = 0;
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(from) || log.date.isAtSameMomentAs(from)) {
        if (log.isCheckable) {
          completionTotals[log.activityName] = (completionTotals[log.activityName] ?? 0) + 1;
        } else {
          timeTotals[log.activityName] = (timeTotals[log.activityName] ?? Duration.zero) + log.duration;
        }
      }
    }

    final totalTimedDuration = selectedActivity == null
        ? widget.activities
        .where((a) => a is TimedActivity)
        .fold<Duration>(Duration.zero, (sum, a) => sum + (timeTotals[a.name] ?? Duration.zero))
        : timeTotals[selectedActivity] ?? Duration.zero;

    final totalCheckableInstances = selectedActivity == null
        ? widget.activities
        .where((a) => a is CheckableActivity)
        .fold<int>(0, (sum, a) => sum + (completionTotals[a.name] ?? 0))
        : completionTotals[selectedActivity] ?? 0;

    return {
      'timeTotals': timeTotals,
      'completionTotals': completionTotals,
      'totalTimedDuration': totalTimedDuration,
      'totalCheckableInstances': totalCheckableInstances,
    };
  }

  double getMaxY(List<BarChartGroupData> barGroups) {
    if (barGroups.isEmpty) return 10.0;
    final maxValue = barGroups
        .map((group) => group.barRods.first.toY)
        .reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue * 1.2 : 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final stats = filteredActivities();
    final timeTotals = stats['timeTotals'] as Map<String, Duration>;
    final completionTotals = stats['completionTotals'] as Map<String, int>;
    final totalTime = stats['totalTimedDuration'] as Duration;
    final totalCheckable = stats['totalCheckableInstances'] as int;
    final isCheckableSelected = selectedActivity != null &&
        widget.activities
            .firstWhere((a) => a.name == selectedActivity, orElse: () => widget.activities.first)
        is CheckableActivity;

    final timedChartData = getTimedChartData();
    final checkableChartData = getCheckableChartData();

    const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<StatsPeriod>(
              value: selectedPeriod,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: StatsPeriod.day, child: Text('Last Day')),
                DropdownMenuItem(value: StatsPeriod.week, child: Text('Last Week')),
                DropdownMenuItem(value: StatsPeriod.month, child: Text('Last Month')),
                DropdownMenuItem(value: StatsPeriod.total, child: Text('Total')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedPeriod = val);
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<String?>(
              value: selectedActivity,
              isExpanded: true,
              hint: const Text('Choose activity for stats and charts'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Activities')),
                ...widget.activities
                    .map((a) => DropdownMenuItem<String?>(value: a.name, child: Text(a.name)))
                    .toList(),
              ],
              onChanged: (val) {
                setState(() => selectedActivity = val);
              },
            ),
            const SizedBox(height: 20),
            if (!isCheckableSelected) ...[
              Text(
                selectedActivity == null
                    ? 'Total timed activity: ${formatDuration(totalTime)}'
                    : 'Total time for $selectedActivity: ${formatDuration(totalTime)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
            if (selectedActivity == null || isCheckableSelected) ...[
              const SizedBox(height: 10),
              Text(
                selectedActivity == null
                    ? 'Total checkable completions: $totalCheckable'
                    : 'Total completions for $selectedActivity: $totalCheckable',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            Column(
              children: (selectedActivity == null
                  ? widget.activities
                  : widget.activities.where((a) => a.name == selectedActivity))
                  .map((a) {
                final percent = a is TimedActivity
                    ? (stats['totalTimedDuration'] as Duration).inSeconds == 0
                    ? 0.0
                    : ((timeTotals[a.name]?.inSeconds ?? 0) /
                    (stats['totalTimedDuration'] as Duration).inSeconds)
                    .clamp(0.0, 1.0)
                    : (stats['totalCheckableInstances'] as int) == 0
                    ? 0.0
                    : ((completionTotals[a.name] ?? 0) /
                    (stats['totalCheckableInstances'] as int))
                    .clamp(0.0, 1.0);
                return ListTile(
                  key: ValueKey(a.name),
                  title: Text(a.name),
                  subtitle: LinearProgressIndicator(value: percent),
                  trailing: Text(
                    a is TimedActivity
                        ? formatDuration(timeTotals[a.name] ?? Duration.zero)
                        : '${completionTotals[a.name] ?? 0} times',
                    style: const TextStyle(fontSize: 20),
                  ),
                  leading: const Icon(Icons.drag_handle),
                  onTap: () {
                    setState(() {
                      final oldIndex = widget.activities.indexOf(a);
                      final newIndex = oldIndex == 0 ? widget.activities.length - 1 : oldIndex - 1;
                      final activity = widget.activities.removeAt(oldIndex);
                      widget.activities.insert(newIndex, activity);
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString(
                            'activities', jsonEncode(widget.activities.map((a) => a.toJson()).toList()));
                      });
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              selectedPeriod == StatsPeriod.week ? 'Time Spent per Day' : 'Time Spent per Week',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            timedChartData.isEmpty || timedChartData.every((group) => group.barRods.first.toY == 0)
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No timed activity data available for this period.'),
            )
                : SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (selectedPeriod == StatsPeriod.day) {
                            return const Text('');
                          } else if (selectedPeriod == StatsPeriod.week) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                selectedPeriod == StatsPeriod.month
                                    ? 'W${value.toInt() + 1}'
                                    : monthLabels[value.toInt() % 12],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                  barGroups: timedChartData,
                  maxY: getMaxY(timedChartData),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${rod.toY.toInt()} min',
                        const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              selectedPeriod == StatsPeriod.week ? 'Completions per Day' : 'Completions per Week',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            checkableChartData.isEmpty || checkableChartData.every((group) => group.barRods.first.toY == 0)
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No checkable activity data available for this period.'),
            )
                : SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (selectedPeriod == StatsPeriod.day) {
                            return const Text('');
                          } else if (selectedPeriod == StatsPeriod.week) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                days[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                selectedPeriod == StatsPeriod.month
                                    ? 'W${value.toInt() + 1}'
                                    : monthLabels[value.toInt() % 12],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                  barGroups: checkableChartData,
                  maxY: getMaxY(checkableChartData),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                        '${rod.toY.toInt()} completions',
                        const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
static const int maxActivities = 10;
static const int maxNameLength = 50;

void addActivity() {
if (widget.activities.length >= maxActivities) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Maximum 10 activities allowed.')),
);
return;
}

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
decoration:
const InputDecoration(hintText: 'Activity name (max 50 chars)'),
maxLength: maxNameLength,
inputFormatters: [
LengthLimitingTextInputFormatter(maxNameLength),
],
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
if (name.isNotEmpty &&
name.length <= maxNameLength &&
!widget.activities.any((a) => a.name == name)) {
setState(() {
widget.activities.add(_isTimedActivity
? TimedActivity(name: name)
    : CheckableActivity(name: name));
});
print('Added activity: $name (${_isTimedActivity ? 'Timed' : 'Checkable'})');
widget.onUpdate();
Navigator.pop(context);
} else if (name.length > maxNameLength) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Activity name must be 50 characters or less.')),
);
} else if (widget.activities.any((a) => a.name == name)) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Activity name already exists.')),
);
} else {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Enter a valid activity name.')),
);
}
},
child: const Text('Save'),
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
decoration: const InputDecoration(hintText: 'New name (max 50 chars)'),
maxLength: maxNameLength,
inputFormatters: [
LengthLimitingTextInputFormatter(maxNameLength),
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
if (name.isNotEmpty &&
name.length <= maxNameLength &&
!widget.activities.any((a) => a.name == name)) {
setState(() {
widget.activities[index].name = name;
});
print('Renamed activity to: $name');
widget.onUpdate();
Navigator.pop(context);
} else if (name.length > maxNameLength) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Activity name must be 50 characters or less.')),
);
} else if (widget.activities.any((a) => a.name == name)) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Activity name already exists.')),
);
} else {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Enter a valid activity name.')),
);
}
},
child: const Text('Save'),
),
],
),
);
}

void deleteActivity(int index) {
final name = widget.activities[index].name;
setState(() {
widget.activities.removeAt(index);
});
print('Deleted activity: $name');
widget.onUpdate();
}

void _onReorder(int oldIndex, int newIndex) {
setState(() {
if (newIndex > oldIndex) {
newIndex -= 1;
}
final activity = widget.activities.removeAt(oldIndex);
widget.activities.insert(newIndex, activity);
});
print('Reordered activities');
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
child: ReorderableListView(
onReorder: _onReorder,
children: widget.activities.asMap().entries.map((entry) {
final index = entry.key;
final a = entry.value;
return ListTile(
key: ValueKey(a.name),
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
leading: const Icon(Icons.drag_handle),
);
}).toList(),
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

int completedDailyGoals = 0;
int totalDailyGoals = widget.goals
    .where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.daily)
    .length;

int completedWeeklyGoals = 0;
int totalWeeklyGoals = widget.goals
    .where((g) => g.goalDuration > Duration.zero && g.goalType == GoalType.weekly)
    .length;

final weekStart = day.subtract(Duration(days: day.weekday - 1));
final weekEnd =
weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

for (var goal in widget.goals.where((g) => g.goalDuration > Duration.zero)) {
final activity = widget.activityLogs
    .where((log) =>
log.activityName == goal.activityName &&
log.date.isAfter(
goal.goalType == GoalType.daily ? dayStart : weekStart) &&
log.date.isBefore(goal.goalType == GoalType.daily ? dayEnd : weekEnd))
    .toList();

bool isCompleted = false;
if (activity.isNotEmpty) {
if (activity.any((log) => log.isCheckable)) {
final completions = activity.where((log) => log.isCheckable).length;
if (completions >= goal.goalDuration.inMinutes) {
isCompleted = true;
}
} else {
final totalTime = activity.fold<Duration>(
Duration.zero, (sum, log) => sum + log.duration);
if (totalTime >= goal.goalDuration) {
isCompleted = true;
}
}
}

if (isCompleted) {
if (goal.goalType == GoalType.daily) {
completedDailyGoals++;
} else {
completedWeeklyGoals++;
}
}
}

Color dailyColor;
if (totalDailyGoals == 0) {
dailyColor = Colors.grey;
} else if (completedDailyGoals == totalDailyGoals) {
dailyColor = Colors.green;
} else if (completedDailyGoals > 0) {
dailyColor = Colors.yellow;
} else {
dailyColor = Colors.red;
}

Color weeklyColor;
if (totalWeeklyGoals == 0) {
weeklyColor = Colors.grey;
} else if (completedWeeklyGoals == totalWeeklyGoals) {
weeklyColor = Colors.green;
} else if (completedWeeklyGoals > 0) {
weeklyColor = Colors.yellow;
} else {
weeklyColor = Colors.red;
}

progress[day] = {
'completedDailyGoals': completedDailyGoals,
'totalDailyGoals': totalDailyGoals,
'dailyColor': dailyColor,
'completedWeeklyGoals': completedWeeklyGoals,
'totalWeeklyGoals': totalWeeklyGoals,
'weeklyColor': weeklyColor,
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
DropdownMenuItem(
value: CalendarPeriod.threeMonths, child: Text('Last 3 Months')),
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
              final completedDailyGoals = dayData['completedDailyGoals'] as int;
              final totalDailyGoals = dayData['totalDailyGoals'] as int;
              final dailyColor = dayData['dailyColor'] as Color;
              final completedWeeklyGoals = dayData['completedWeeklyGoals'] as int;
              final totalWeeklyGoals = dayData['totalWeeklyGoals'] as int;
              final weeklyColor = dayData['weeklyColor'] as Color;

              return ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dailyColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: weeklyColor,
                      ),
                    ),
                  ],
                ),
                title: Text(
                  '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}',
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Completed daily goals: $completedDailyGoals/$totalDailyGoals'),
                    Text(
                        'Completed weekly goals: $completedWeeklyGoals/$totalWeeklyGoals'),
                  ],
                ),
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
  final VoidCallback onResetData;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onResetData,
  });

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text('Are you sure you want to reset all activities, logs, and goals? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Confirm Reset'),
                  content: const Text('Please confirm again to reset all data.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        onResetData();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Confirm Reset'),
                    ),
                  ],
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context, String toEmail, String subject, String body) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: toEmail,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email client found. Please install an email app or contact support manually.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open email client: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: isDarkMode,
            onChanged: onThemeChanged,
          ),
          ListTile(
            title: const Text('Report a Bug'),
            subtitle: const Text('Send us details about any issues you encounter'),
            onTap: () => _launchEmail(
              context,
              'lockintrackerapp@gmail.com',
              'Bug Report - LockIn Tracker',
              'Please describe the bug you encountered:\n\nApp Version: 1.0.0\nDevice: [Your Device]\nOS: [Your OS]\nSteps to Reproduce:\n1. \n2. \n3. \n\nAdditional Details:',
            ),
          ),
          ListTile(
            title: const Text('Contact Us'),
            subtitle: const Text('Reach out with questions or feedback'),
            onTap: () => _launchEmail(
              context,
              'lockintrackerapp@gmail.com',
              'Contact - LockIn Tracker',
              'Please share your questions or feedback:\n\n',
            ),
          ),
          ListTile(
            title: const Text('Reset All Data'),
            subtitle: const Text('Clear all activities, logs, and goals'),
            onTap: () => _confirmReset(context),
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }
}