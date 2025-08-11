import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import '../main.dart';
import '../models/activity.dart';
import '../models/goal.dart';
import '../models/activity_log.dart';
import '../pages/tracker_page.dart';
import '../pages/goals_page.dart';
import '../pages/activities_page.dart';
import '../pages/stats_page.dart';
import '../pages/history_page.dart';
import '../pages/settings_page.dart';
import '../pages/progress_page.dart';

class HomePage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkMode;
  final VoidCallback onResetData;
  final int launchCount;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.isDarkMode,
    required this.onResetData,
    required this.launchCount,
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
  static const int maxLogs = 3000;
  static const int maxManualTimeMinutes = 1000;
  static const int maxManualCompletions = 50;
  static const int maxActivities = 10;
  static const int maxGoals = 10;

  Set<String> _previousCompletedQuestIds = {};
  bool _hasRatedApp = false;

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

  Future<void> _loadData() async {
    print('[DEBUG] _loadData start');
    final prefs = await SharedPreferences.getInstance();
    _hasRatedApp = prefs.getBool('hasRatedApp') ?? false;

    final result = await _loadDataFromPrefs(widget.launchCount == 1 ? 1 : 0);
    print('[DEBUG] _loadData result: activities=${result['activities'].length}, logs=${result['logs'].length}, goals=${result['goals'].length}');
    setState(() {
      activities = result['activities'] as List<Activity>;
      activityLogs = result['logs'] as List<ActivityLog>;
      goals = result['goals'] as List<Goal>;
    });
    _updatePreviousQuestsState();
    print('[DEBUG] _loadData setState: activities=${activities.length}');
  }

  Set<String> _getAllCompletedQuestLevelIds() {
    final service = ProgressService(
        activities: activities,
        activityLogs: activityLogs,
        goals: goals,
        launchCount: widget.launchCount,
        hasRatedApp: _hasRatedApp);
    final Set<String> completedIds = {};

    for (var quest in ProgressService.quests) {
      final progress = quest.getProgress(activities, activityLogs, goals, widget.launchCount, _hasRatedApp);
      if (quest.isRepeatable) {
        final level = quest.levels.first;
        if (level.target > 0) {
          final completions = (progress / level.target).floor();
          for (int i = 1; i <= completions; i++) {
            completedIds.add('${quest.id}-$i');
          }
        }
      } else {
        for (var level in quest.levels) {
          if (progress >= level.target) {
            completedIds.add('${quest.id}-${level.target}');
          }
        }
      }
    }
    return completedIds;
  }

  void _updatePreviousQuestsState() {
    _previousCompletedQuestIds = _getAllCompletedQuestLevelIds();
  }

  void _checkQuestCompletions() {
    final currentCompletedIds = _getAllCompletedQuestLevelIds();
    final newlyCompletedIds = currentCompletedIds.difference(_previousCompletedQuestIds);

    if (newlyCompletedIds.isNotEmpty) {
      for (final id in newlyCompletedIds) {
        for (var quest in ProgressService.quests) {
          QuestLevel? completedLevel;
          if (quest.isRepeatable) {
            if (id.startsWith(quest.id)) {
              completedLevel = quest.levels.first;
            }
          } else {
            for (var level in quest.levels) {
              if ('${quest.id}-${level.target}' == id) {
                completedLevel = level;
                break;
              }
            }
          }

          if (completedLevel != null) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Quest Completed!', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('"${quest.title}" (+${completedLevel.xpReward} XP)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
            break;
          }
        }
      }
    }
    _previousCompletedQuestIds = currentCompletedIds;
  }

  static Future<Map<String, dynamic>> _loadDataFromPrefs(int shouldLoadDefaultData) async {
    print('[DEBUG] _loadDataFromPrefs start');
    final prefs = await SharedPreferences.getInstance();
    List<Activity> activities = [];
    List<ActivityLog> logs = [];
    List<Goal> goals = [];

    final activitiesJson = prefs.getString('activities');
    print('[DEBUG] activitiesJson: $activitiesJson');
    if (activitiesJson == null || activitiesJson.isEmpty || activitiesJson == '[]' || shouldLoadDefaultData == 1) {
      activities = [
        TimedActivity(name: 'Focus'),
        CheckableActivity(name: 'Drink water'),
      ];
      print('[DEBUG] Default activities created: ${activities.length}');
      await prefs.setString('activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
    } else {
      try {
        final decoded = jsonDecode(activitiesJson);
        if (decoded is! List) {
          print('[DEBUG] Invalid activities JSON format: not a list');
          activities = [];
        } else {
          final List<dynamic> activitiesList = decoded;
          print('[DEBUG] Decoded activitiesList: ${activitiesList.length}');
          activities = activitiesList.where((json) {
            if (json is! Map<String, dynamic>) {
              print('[DEBUG] Invalid activity JSON: $json');
              return false;
            }
            if (!json.containsKey('type') || !json.containsKey('name')) {
              print('[DEBUG] Missing required fields in activity JSON: $json');
              return false;
            }
            return true;
          }).map((json) {
            try {
              return json['type'] == 'TimedActivity'
                  ? TimedActivity.fromJson(json)
                  : CheckableActivity.fromJson(json);
            } catch (e) {
              print('[DEBUG] Error parsing activity: $e, JSON: $json');
              return null;
            }
          }).whereType<Activity>().take(maxActivities).toList();
          print('[DEBUG] Parsed activities: ${activities.length}');
        }
      } catch (e) {
        print('[DEBUG] Error parsing activities: $e');
        activities = [];
        await prefs.setString('activities', jsonEncode([]));
      }
    }

    final logsJson = prefs.getString('activityLogs');
    print('[DEBUG] logsJson: $logsJson');
    if (logsJson != null && logsJson.isNotEmpty) {
      try {
        final List<dynamic> logsList = jsonDecode(logsJson);
        logs = logsList.map((json) => ActivityLog.fromJson(json)).take(maxLogs).toList();
        print('[DEBUG] Parsed logs: ${logs.length}');
      } catch (e) {
        print('[DEBUG] Error parsing logs: $e');
        logs = [];
      }
    }

    final goalsJson = prefs.getString('goals');
    print('[DEBUG] goalsJson: $goalsJson');
    if (goalsJson != null && goalsJson.isNotEmpty) {
      try {
        final List<dynamic> goalsList = jsonDecode(goalsJson);
        goals = goalsList.map((json) => Goal.fromJson(json)).take(maxGoals).toList();
        print('[DEBUG] Parsed goals: ${goals.length}');
      } catch (e) {
        print('[DEBUG] Error parsing goals: $e');
        goals = [];
      }
    }

    for (var log in logs) {
      if (!activities.any((a) => a.name == log.activityName)) {
        if (activities.length >= maxActivities) continue;
        final newActivity = log.activityName == 'Drink water'
            ? CheckableActivity(name: log.activityName)
            : TimedActivity(name: log.activityName);
        activities.add(newActivity);
      }
      final activity = activities.firstWhere((a) => a.name == log.activityName);
      if (activity is TimedActivity && !log.isCheckable) {
        activity.totalTime += log.duration;
      } else if (activity is CheckableActivity && log.isCheckable) {
        activity.completionCount += 1;
      }
    }

    return {'activities': activities, 'logs': logs, 'goals': goals};
  }

  Future<void> _saveData() async {
    if (activityLogs.length > maxLogs) {
      activityLogs = activityLogs.sublist(activityLogs.length - maxLogs);
    }
    if (activities.length > maxActivities) {
      activities = activities.sublist(0, maxActivities);
    }
    if (goals.length > maxGoals) {
      goals = goals.sublist(0, maxGoals);
    }
    await _saveDataToPrefs({
      'activities': activities,
      'logs': activityLogs,
      'goals': goals,
    });

    _checkQuestCompletions();
  }

  static Future<void> _saveDataToPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = data['activities'] as List<Activity>;
    final logs = data['logs'] as List<ActivityLog>;
    final goals = data['goals'] as List<Goal>;
    await prefs.setString('activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
    await prefs.setString('activityLogs', jsonEncode(logs.map((log) => log.toJson()).toList()));
    await prefs.setString('goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  Future<void> _resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activities');
    await prefs.remove('activityLogs');
    await prefs.remove('goals');
    await prefs.remove('launchCount');
    await prefs.remove('hasRatedApp');

    setState(() {
      activities = [];
      activityLogs = [];
      goals = [];
      selectedActivity = null;
      elapsed = Duration.zero;
      stopwatch.reset();
      _timer?.cancel();
    });

    await _loadData();
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
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += stopwatch.elapsed;
      }
      elapsed = Duration.zero;
      stopwatch.reset();
    });
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
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is CheckableActivity) {
        activity.completionCount += 1;
      }
    });
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
          const SnackBar(content: Text('Manual time cannot exceed 1000 minutes.')),
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
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += duration;
      }
    });
    _saveData();
  }

  void subtractManualTime(Duration duration) {
    if (selectedActivity == null || selectedActivity is! TimedActivity || duration <= Duration.zero) {
      return;
    }
    final dateStart = selectedDate.subtract(const Duration(days: 1));
    final dateEnd = selectedDate.add(const Duration(days: 1));
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
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime -= logToRemove.duration;
        if (activity.totalTime < Duration.zero) {
          activity.totalTime = Duration.zero;
        }
      }
    });
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
          const SnackBar(content: Text('Manual completions cannot exceed 50.')),
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
        final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
        if (activity is CheckableActivity) {
          activity.completionCount += 1;
        }
      }
    });
    _saveData();
  }

  void subtractManualCompletion(int count) {
    if (selectedActivity == null || selectedActivity is! CheckableActivity || count <= 0) {
      return;
    }
    final dateStart = selectedDate.subtract(const Duration(days: 1));
    final dateEnd = selectedDate.add(const Duration(days: 1));
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
        final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
        if (activity is CheckableActivity) {
          activity.completionCount -= 1;
          if (activity.completionCount < 0) {
            activity.completionCount = 0;
          }
        }
      }
    });
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
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
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
              Tab(icon: Icon(Icons.list), text: 'Activities'),
              Tab(icon: Icon(Icons.show_chart), text: 'Progress'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
              Tab(icon: Icon(Icons.calendar_today), text: 'History'),
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
              launchCount: widget.launchCount,
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
              launchCount: widget.launchCount,
            ),
            ActivitiesPage(
              activities: activities,
              onUpdate: updateActivities,
              launchCount: widget.launchCount,
            ),
            ProgressPage(
              activities: activities,
              activityLogs: activityLogs,
              goals: goals,
              launchCount: widget.launchCount,
            ),
            StatsPage(
              activityLogs: activityLogs,
              activities: activities,
              goals: goals,
              launchCount: widget.launchCount,
            ),
            HistoryPage(
              activityLogs: activityLogs,
              goals: goals,
              selectedDate: selectedDate,
              onSelectDate: selectDate,
              launchCount: widget.launchCount,
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