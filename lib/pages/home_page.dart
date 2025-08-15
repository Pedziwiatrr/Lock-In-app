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
import '../utils/format_utils.dart';
import '../utils/notification_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

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
  StreamSubscription? _tickSubscription;
  DateTime? _timerStartDate;

  final NotificationService _notificationService = NotificationService();

  static const int maxLogs = 3000;
  static const int maxManualTimeMinutes = 10000;
  static const int maxManualCompletions = 10000;
  static const int maxActivities = 10;
  static const int maxGoals = 10;

  Set<String> _previousCompletedQuestIds = {};
  bool _hasRatedApp = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _configureTimerListener();
  }

  void _configureTimerListener() {
    final service = FlutterBackgroundService();
    _tickSubscription = service.on('tick').listen((event) {
      if (!mounted || !isRunning) return;

      final now = DateTime.now();
      final timerStart = _timerStartDate;

      if (timerStart != null && (now.day != timerStart.day || now.month != timerStart.month || now.year != timerStart.year)) {
        final timeToLog = elapsed;
        final activityToLog = selectedActivity;

        _stopTimer();

        if (activityToLog != null && timeToLog > Duration.zero) {
          final log = ActivityLog(
            activityName: activityToLog.name,
            date: timerStart,
            duration: timeToLog,
            isCheckable: false,
          );

          setState(() {
            activityLogs = [...activityLogs, log];
            final activityIndex = activities.indexWhere((a) => a.name == activityToLog.name);
            if (activityIndex != -1) {
              final activity = activities[activityIndex];
              if (activity is TimedActivity) {
                activity.totalTime += timeToLog;
              }
            }
          });
          _saveData();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Timer session saved automatically at midnight.')),
              );
            }
          });
        }

        setState(() {
          selectedDate = now;
        });
        return;
      }

      setState(() {
        elapsed += const Duration(seconds: 1);
      });
      _notificationService.showTimerNotification(formatDuration(elapsed));
    });

    service.on('clearNotification').listen((event) {
      _notificationService.cancelTimerNotification();
    });
  }

  @override
  void dispose() {
    _tickSubscription?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (selectedActivity == null || selectedActivity is! TimedActivity || isRunning) return;
    FlutterBackgroundService().invoke('startTimer');
    setState(() {
      isRunning = true;
      _timerStartDate = selectedDate;
    });
  }

  void _stopTimer() {
    FlutterBackgroundService().invoke('stopTimer');
    setState(() {
      isRunning = false;
      _timerStartDate = null;
    });
  }

  void _finishTimerAndSave() {
    FlutterBackgroundService().invoke('stopTimer');
    if (selectedActivity == null || elapsed == Duration.zero) {
      _resetTimerState();
      return;
    }
    if (activityLogs.length >= maxLogs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max log limit reached. Cannot add more.')),
      );
      _resetTimerState();
      return;
    }
    final now = DateTime.now();
    final logDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: logDate,
      duration: elapsed,
      isCheckable: false,
    );
    setState(() {
      activityLogs = [...activityLogs, log];
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += elapsed;
      }
    });
    _resetTimerState();
    _saveData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _hasRatedApp = prefs.getBool('hasRatedApp') ?? false;

    final result = await _loadDataFromPrefs(widget.launchCount == 1 ? 1 : 0);
    setState(() {
      activities = result['activities'] as List<Activity>;
      activityLogs = result['logs'] as List<ActivityLog>;
      goals = result['goals'] as List<Goal>;
      if (activities.isNotEmpty && selectedActivity == null) {
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
        CheckableActivity(name: 'Workout'),
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

    for (var activity in activities) {
      if (activity is TimedActivity) {
        activity.totalTime = logs
            .where((log) => log.activityName == activity.name && !log.isCheckable)
            .fold(Duration.zero, (prev, log) => prev + log.duration);
      } else if (activity is CheckableActivity) {
        activity.completionCount = logs.where((log) => log.activityName == activity.name && log.isCheckable).length;
      }
    }

    return {'activities': activities, 'logs': logs, 'goals': goals};
  }

  Future<void> _saveData() async {
    final logs = activityLogs.length > maxLogs
        ? activityLogs.sublist(activityLogs.length - maxLogs)
        : activityLogs;

    await _saveDataToPrefs({
      'activities': activities.take(maxActivities).toList(),
      'logs': logs,
      'goals': goals.take(maxGoals).toList(),
    });

    _checkQuestCompletions();
    _checkGoalCompletions();
  }

  void _checkGoalCompletions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final goal in goals) {
      if (goal.goalDuration > Duration.zero &&
          goal.startDate.isBefore(tomorrow) &&
          (goal.endDate == null || goal.endDate!.isAfter(today))) {

        final activity = activities.firstWhere((a) => a.name == goal.activityName, orElse: () => CheckableActivity(name: ''));
        if (activity.name.isEmpty) continue;

        bool isCompletedNow = false;
        if (activity is TimedActivity) {
          final totalTime = activityLogs
              .where((log) => log.activityName == goal.activityName && !log.isCheckable)
              .fold(Duration.zero, (sum, log) => sum + log.duration);
          if (totalTime >= goal.goalDuration) {
            isCompletedNow = true;
          }
        } else if (activity is CheckableActivity) {
          final completions = activityLogs
              .where((log) => log.activityName == goal.activityName && log.isCheckable)
              .length;
          if (completions >= goal.goalDuration.inMinutes) {
            isCompletedNow = true;
          }
        }

        if (isCompletedNow && !_previousCompletedQuestIds.contains(goal.id)) {
          _notificationService.scheduleGoalReminder(goal);
          _previousCompletedQuestIds.add(goal.id);
        } else if (!isCompletedNow) {
          _previousCompletedQuestIds.remove(goal.id);
        }
      }
    }
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
    FlutterBackgroundService().invoke('stopTimer');
    setState(() {
      activities = [];
      activityLogs = [];
      goals = [];
      selectedActivity = null;
      elapsed = Duration.zero;
      isRunning = false;
    });
    await _loadData();
    await _saveData();
  }

  void _resetTimerState() {
    setState(() {
      elapsed = Duration.zero;
      isRunning = false;
      _timerStartDate = null;
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
    final now = DateTime.now();
    final logDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: logDate,
      duration: Duration.zero,
      isCheckable: true,
    );
    setState(() {
      activityLogs = [...activityLogs, log];
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is CheckableActivity) {
        activity.completionCount += 1;
      }
    });
    _saveData();
  }

  void addManualTime(Duration duration) {
    final bool cheatsEnabled = activities.any((a) => a.name == 'sv_cheats 1');
    final int limit = cheatsEnabled ? maxManualTimeMinutes : 300;

    if (selectedActivity == null ||
        selectedActivity is! TimedActivity ||
        duration <= Duration.zero ||
        duration > Duration(minutes: limit) ||
        activityLogs.length >= maxLogs) {
      return;
    }
    final now = DateTime.now();
    final logDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);
    final log = ActivityLog(
      activityName: selectedActivity!.name,
      date: logDate,
      duration: duration,
      isCheckable: false,
    );
    setState(() {
      activityLogs = [...activityLogs, log];
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is TimedActivity) {
        activity.totalTime += duration;
      }
    });
    _saveData();
  }

  void subtractManualTime(Duration duration) {
    if (selectedActivity == null || selectedActivity is! TimedActivity || duration <= Duration.zero) return;

    final dateStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = dateStart.add(const Duration(days: 1));
    List<ActivityLog> logsCopy = List.from(activityLogs);

    final relevantLogs = logsCopy
        .where((log) =>
    log.activityName == selectedActivity!.name &&
        !log.isCheckable &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd))
        .toList();

    if (relevantLogs.isEmpty) return;

    relevantLogs.sort((a, b) => b.date.compareTo(a.date));
    Duration remainingDurationToSubtract = duration;

    for (final log in relevantLogs) {
      if (remainingDurationToSubtract <= Duration.zero) break;

      final durationToSubtract = log.duration > remainingDurationToSubtract ? remainingDurationToSubtract : log.duration;
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if(activity is TimedActivity) {
        activity.totalTime -= durationToSubtract;
      }
      log.duration -= durationToSubtract;
      remainingDurationToSubtract -= durationToSubtract;
    }

    logsCopy.removeWhere((log) => log.duration <= Duration.zero);

    setState(() {
      activityLogs = logsCopy;
    });
    _saveData();
  }

  void addManualCompletion(int count) {
    final bool cheatsEnabled = activities.any((a) => a.name == 'sv_cheats 1');
    final int limit = cheatsEnabled ? maxManualCompletions : 30;

    if (selectedActivity == null ||
        selectedActivity is! CheckableActivity ||
        count <= 0 ||
        count > limit ||
        activityLogs.length + count > maxLogs) {
      return;
    }
    final now = DateTime.now();
    final logDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, now.hour, now.minute, now.second);

    List<ActivityLog> newLogs = [];
    for (int i = 0; i < count; i++) {
      newLogs.add(ActivityLog(
        activityName: selectedActivity!.name,
        date: logDate,
        duration: Duration.zero,
        isCheckable: true,
      ));
    }

    setState(() {
      activityLogs = [...activityLogs, ...newLogs];
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is CheckableActivity) {
        activity.completionCount += count;
      }
    });
    _saveData();
  }

  void subtractManualCompletion(int count) {
    if (selectedActivity == null || selectedActivity is! CheckableActivity || count <= 0) return;

    final dateStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    List<ActivityLog> logsToRemove = activityLogs
        .where((log) =>
    log.activityName == selectedActivity!.name &&
        log.isCheckable &&
        log.date.isAfter(dateStart) &&
        log.date.isBefore(dateEnd))
        .toList();

    if (logsToRemove.isEmpty) return;

    logsToRemove.sort((a, b) => b.date.compareTo(a.date));

    final logsToActuallyRemove = logsToRemove.take(count).toSet();

    setState(() {
      activityLogs = activityLogs.where((log) => !logsToActuallyRemove.contains(log)).toList();
      final activity = activities.firstWhere((a) => a.name == selectedActivity!.name);
      if (activity is CheckableActivity) {
        activity.completionCount = max(0, activity.completionCount - logsToActuallyRemove.length);
      }
    });
    _saveData();
  }

  void handleGoalChanged(List<Goal> newGoals) {
    setState(() {
      goals = newGoals.take(maxGoals).toList();
    });
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
    if(isRunning) return;
    setState(() {
      selectedDate = date;
      elapsed = Duration.zero;
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
              onStopTimer: _stopTimer,
              onFinishTimer: _finishTimerAndSave,
              onCheckActivity: checkActivity,
              onAddManualTime: addManualTime,
              onSubtractManualTime: subtractManualTime,
              onAddManualCompletion: addManualCompletion,
              onSubtractManualCompletion: subtractManualCompletion,
            ),
            GoalsPage(
              goals: goals,
              activities: activities,
              onGoalChanged: handleGoalChanged,
              launchCount: widget.launchCount,
            ),
            ActivitiesPage(
              activities: activities,
              onUpdate: () {
                setState(() {});
                _saveData();
              },
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
              activities: activities,
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