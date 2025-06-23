import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import '../models/activity.dart';
import '../models/goal.dart';
import '../models/activity_log.dart';
import '../pages/tracker_page.dart';
import '../pages/goals_page.dart';
import '../pages/activities_page.dart';
import '../pages/stats_page.dart';
import '../pages/calendar_page.dart';
import '../pages/settings_page.dart';

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
      activityLogs = logsList.map((json) => ActivityLog.fromJson(json)).take(maxLogs).toList();
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
      goals = goalsList.map((json) => Goal.fromJson(json)).take(maxGoals).toList();
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
      activityLogs = activityLogs.sublist(activityLogs.length - maxLogs, activityLogs.length);
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
      date: DateTime.now(),
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
      date: DateTime.now(),
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
      date: DateTime.now(),
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
    final dateStart = DateTime.now().subtract(const Duration(days: 1));
    final dateEnd = DateTime.now();
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
        'Manual time subtracted: ${selectedActivity!.name} on $dateStart with duration $duration');
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
          date: DateTime.now(),
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
        'Manual completions added: $count for ${selectedActivity!.name} on ${DateTime.now()}');
    _saveData();
  }

  void subtractManualCompletion(int count) {
    if (selectedActivity == null ||
        selectedActivity is! CheckableActivity ||
        count <= 0) return;
    final dateStart = DateTime.now().subtract(const Duration(days: 1));
    final dateEnd = DateTime.now();
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
        'Manual completions subtracted: $count for ${selectedActivity!.name} on $dateStart');
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: EdgeInsets.symmetric(horizontal: 16),
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.timer), text: 'Tracker'),
              Tab(icon: Icon(Icons.flag), text: 'Goals'),
              Tab(icon: Icon(Icons.list), text: 'Activity'),
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
            CalendarPage(
              activityLogs: activityLogs,
              goals: goals,
              selectedDate: selectedDate,
              onSelectDate: selectDate,
            ),
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