import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
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
  Duration elapsed = Duration.zero;
  bool isRunning = false;
  DateTime selectedDate = DateTime.now();
  StreamSubscription<Map<String, dynamic>?>? _streamSubscription;

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

    final service = FlutterBackgroundService();
    service.isRunning().then((value) {
      if (mounted) setState(() => isRunning = value);
    });

    _streamSubscription = service.on('update').listen((event) {
      if (mounted) {
        setState(() {
          elapsed = Duration(seconds: event?['elapsed'] ?? 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _hasRatedApp = prefs.getBool('hasRatedApp') ?? false;

    final result = await _loadDataFromPrefs(widget.launchCount == 1 ? 1 : 0);
    setState(() {
      activities = result['activities'] as List<Activity>;
      activityLogs = result['logs'] as List<ActivityLog>;
      goals = result['goals'] as List<Goal>;
      if (activities.isNotEmpty) {
        selectedActivity = activities.first;
      }
    });
    _updatePreviousQuestsState();
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
    final prefs = await SharedPreferences.getInstance();
    List<Activity> activities = [];
    List<ActivityLog> logs = [];
    List<Goal> goals = [];

    final activitiesJson = prefs.getString('activities');
    if (activitiesJson == null || activitiesJson.isEmpty || activitiesJson == '[]' || shouldLoadDefaultData == 1) {
      activities = [
        TimedActivity(name: 'Focus'),
        CheckableActivity(name: 'Drink water'),
      ];
      await prefs.setString('activities', jsonEncode(activities.map((a) => a.toJson()).toList()));
    } else {
      try {
        final decoded = jsonDecode(activitiesJson);
        if (decoded is! List) {
          activities = [];
        } else {
          final List<dynamic> activitiesList = decoded;
          activities = activitiesList.where((json) {
            if (json is! Map<String, dynamic>) return false;
            if (!json.containsKey('type') || !json.containsKey('name')) return false;
            return true;
          }).map((json) {
            try {
              return json['type'] == 'TimedActivity'
                  ? TimedActivity.fromJson(json)
                  : CheckableActivity.fromJson(json);
            } catch (e) {
              return null;
            }
          }).whereType<Activity>().take(maxActivities).toList();
        }
      } catch (e) {
        activities = [];
        await prefs.setString('activities', jsonEncode([]));
      }
    }

    final logsJson = prefs.getString('activityLogs');
    if (logsJson != null && logsJson.isNotEmpty) {
      try {
        final List<dynamic> logsList = jsonDecode(logsJson);
        logs = logsList.map((json) => ActivityLog.fromJson(json)).take(maxLogs).toList();
      } catch (e) {
        logs = [];
      }
    }

    final goalsJson = prefs.getString('goals');
    if (goalsJson != null && goalsJson.isNotEmpty) {
      try {
        final List<dynamic> goalsList = jsonDecode(goalsJson);
        goals = goalsList.map((json) => Goal.fromJson(json)).take(maxGoals).toList();
      } catch (e) {
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
    await prefs.clear();
    setState(() {
      activities = [];
      activityLogs = [];
      goals = [];
      selectedActivity = null;
      elapsed = Duration.zero;
      isRunning = false;
    });
    await _loadData();
  }

  void _startTimer() {
    if (selectedActivity == null || selectedActivity is! TimedActivity || isRunning) return;
    FlutterBackgroundService().startService();
    setState(() {
      isRunning = true;
    });
  }

  void _stopAndSaveTimer() {
    FlutterBackgroundService().invoke('stopService');
    if (selectedActivity == null || elapsed == Duration.zero) {
      _resetTimerState();
      return;
    };
    if (activityLogs.length >= maxLogs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
      );
      _resetTimerState();
      return;
    }
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime.now(),
      duration: elapsed,
      isCheckable: false,
    );
    setState(() {
      activityLogs.add(log);
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += elapsed;
      }
    });
    _resetTimerState();
    _saveData();
  }

  void _resetTimerState() {
    setState(() {
      elapsed = Duration.zero;
      isRunning = false;
    });
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
    if (selectedActivity == null || selectedActivity is! TimedActivity || duration <= Duration.zero) return;

    final relevantLogs = activityLogs
        .where((log) =>
    log.activityName == selectedActivity!.name && !log.isCheckable)
        .toList();

    if (relevantLogs.isEmpty) return;

    relevantLogs.sort((a, b) => b.date.compareTo(a.date));
    Duration remainingDurationToSubtract = duration;

    setState(() {
      for (final log in relevantLogs) {
        if (remainingDurationToSubtract <= Duration.zero) break;

        final durationToSubtract = log.duration > remainingDurationToSubtract ? remainingDurationToSubtract : log.duration;
        final activity = activities.firstWhere((a) => a.name == selectedActivity!.name) as TimedActivity;

        activity.totalTime -= durationToSubtract;
        log.duration -= durationToSubtract;
        remainingDurationToSubtract -= durationToSubtract;

        if (log.duration <= Duration.zero) {
          activityLogs.remove(log);
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
    if (selectedActivity == null || selectedActivity is! CheckableActivity || count <= 0) return;

    final relevantLogs = activityLogs
        .where((log) =>
    log.activityName == selectedActivity!.name && log.isCheckable)
        .toList();
    if (relevantLogs.isEmpty) return;

    setState(() {
      relevantLogs.sort((a, b) => b.date.compareTo(a.date));
      for (int i = 0; i < min(count, relevantLogs.length); i++) {
        activityLogs.remove(relevantLogs[i]);
        final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
        if (activity is CheckableActivity) {
          activity.completionCount = max(0, activity.completionCount - 1);
        }
      }
    });
    _saveData();
  }

  void updateActivities() {
    _saveData();
  }

  void selectActivity(Activity? activity) {
    if (isRunning) return;
    setState(() {
      selectedActivity = activity;
      elapsed = Duration.zero;
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
              isRunning: isRunning,
              onSelectActivity: selectActivity,
              onSelectDate: selectDate,
              onStartTimer: _startTimer,
              onStopTimer: _stopAndSaveTimer,
              onResetTimer: _resetTimerState,
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