import 'package:flutter/material.dart';

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

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
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

class HomePage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkMode;

  const HomePage({super.key, required this.onThemeChanged, required this.isDarkMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class Goal {
  String activityName;
  Duration dailyGoal;
  Goal({required this.activityName, required this.dailyGoal});
}

abstract class Activity {
  String name;
  Activity({required this.name});
}

class TimedActivity extends Activity {
  Duration totalTime;
  TimedActivity({required super.name, this.totalTime = Duration.zero});
}

class CheckableActivity extends Activity {
  int completionCount;
  CheckableActivity({required super.name, this.completionCount = 0});
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
}

class _HomePageState extends State<HomePage> {
  final List<Activity> activities = [
    TimedActivity(name: 'Studying'),
    TimedActivity(name: 'Workout'),
    TimedActivity(name: 'Reading'),
    TimedActivity(name: 'Cleaning'),
    CheckableActivity(name: 'Pójście na trening'),
  ];
  final List<ActivityLog> activityLogs = [];
  List<Goal> goals = [];

  void updateActivities() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    activityLogs.addAll([
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
        activityName: 'Pójście na trening',
        date: DateTime.now(),
        duration: Duration.zero,
        isCheckable: true,
      ),
      ActivityLog(
        activityName: 'Pójście na trening',
        date: DateTime.now(),
        duration: Duration.zero,
        isCheckable: true,
      ),
    ]);
    goals = [
      Goal(activityName: 'Studying', dailyGoal: const Duration(hours: 1, minutes: 30)),
      Goal(activityName: 'Workout', dailyGoal: const Duration(hours: 1)),
      Goal(activityName: 'Pójście na trening', dailyGoal: const Duration(minutes: 1)),
    ];
    for (var log in activityLogs) {
      final activity = activities.firstWhere(
            (a) => a.name == log.activityName,
        orElse: () {
          print('Warning: No activity found for ${log.activityName}');
          return TimedActivity(name: log.activityName);
        },
      );
      if (activity is TimedActivity && !log.isCheckable) {
        activity.totalTime += log.duration;
      } else if (activity is CheckableActivity && log.isCheckable) {
        activity.completionCount += 1;
      }
    }
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
              onAddLog: (log) {
                setState(() {
                  activityLogs.add(log);
                  final activity = activities.firstWhere((a) => a.name == log.activityName);
                  if (activity is TimedActivity) {
                    activity.totalTime += log.duration;
                  } else if (activity is CheckableActivity) {
                    activity.completionCount += 1;
                  }
                });
              },
            ),
            GoalsPage(
              goals: goals,
              activities: activities,
              onGoalChanged: (newGoals) {
                setState(() {
                  goals = newGoals;
                });
              },
            ),
            ActivitiesPage(activities: activities, onUpdate: updateActivities),
            StatsPage(
              activityLogs: activityLogs,
              activities: activities,
              goals: goals,
            ),
            CalendarPage(activityLogs: activityLogs),
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
  final void Function(ActivityLog) onAddLog;
  final List<Activity> activities;
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;

  const TrackerPage({
    super.key,
    required this.onAddLog,
    required this.activities,
    required this.goals,
    required this.activityLogs,
  });

  @override
  State<TrackerPage> createState() => _TrackerPageState();
}

class _TrackerPageState extends State<TrackerPage> {
  Activity? selectedActivity;
  Stopwatch stopwatch = Stopwatch();
  Duration elapsed = Duration.zero;

  void startTimer() {
    if (selectedActivity == null || stopwatch.isRunning) return;
    stopwatch.start();
    _tick();
  }

  void stopTimer() {
    if (!stopwatch.isRunning) return;
    stopwatch.stop();
    widget.onAddLog(ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime.now(),
      duration: stopwatch.elapsed,
      isCheckable: false,
    ));
    setState(() {
      elapsed = Duration.zero;
      stopwatch.reset();
    });
  }

  void checkActivity() {
    if (selectedActivity == null) return;
    widget.onAddLog(ActivityLog(
      activityName: selectedActivity!.name,
      date: DateTime.now(),
      duration: Duration.zero,
      isCheckable: true,
    ));
    setState(() {
      selectedActivity = null;
    });
  }

  void resetTimer() {
    stopwatch.reset();
    setState(() {
      elapsed = Duration.zero;
    });
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (stopwatch.isRunning) {
        setState(() {
          elapsed = stopwatch.elapsed;
        });
        _tick();
      }
    });
  }

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

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(todayStart) && log.date.isBefore(todayEnd)) {
        final activityName = log.activityName;
        final activity = widget.activities.firstWhere(
              (a) => a.name == activityName,
          orElse: () => TimedActivity(name: activityName),
        );

        if (!todayActivities.containsKey(activityName)) {
          todayActivities[activityName] = {
            'isTimed': activity is TimedActivity,
            'totalDuration': Duration.zero,
            'completions': 0,
          };
        }

        if (log.isCheckable) {
          todayActivities[activityName]!['completions'] += 1;
        } else {
          todayActivities[activityName]!['totalDuration'] += log.duration;
        }
      }
    }

    return todayActivities;
  }

  @override
  Widget build(BuildContext context) {
    final todayActivities = getTodayActivities();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButton<Activity>(
            value: selectedActivity,
            hint: const Text('Choose activity'),
            items: widget.activities
                .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                .toList(),
            onChanged: (val) {
              if (stopwatch.isRunning) return;
              setState(() {
                selectedActivity = val;
                elapsed = Duration.zero;
                stopwatch.reset();
              });
            },
          ),
          const SizedBox(height: 20),
          if (selectedActivity is TimedActivity)
            Text(
              formatDuration(elapsed),
              style: const TextStyle(fontSize: 80),
            )
          else if (selectedActivity is CheckableActivity)
            const Text(
              'Mark as completed',
              style: TextStyle(fontSize: 24),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedActivity is TimedActivity) ...[
                ElevatedButton(
                  onPressed: (selectedActivity == null || stopwatch.isRunning)
                      ? null
                      : startTimer,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: stopwatch.isRunning ? stopTimer : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: stopwatch.isRunning ? null : resetTimer,
                  child: const Text('Reset'),
                ),
              ] else if (selectedActivity is CheckableActivity)
                ElevatedButton(
                  onPressed: selectedActivity == null ? null : checkActivity,
                  child: const Text('Check'),
                ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Today',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          todayActivities.isEmpty
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No activities logged today.'),
          )
              : SizedBox(
            height: 150,
            child: ListView.builder(
              itemCount: todayActivities.length,
              itemBuilder: (context, index) {
                final activityName = todayActivities.keys.elementAt(index);
                final activityData = todayActivities[activityName]!;
                final isTimed = activityData['isTimed'] as bool;
                final totalDuration = activityData['totalDuration'] as Duration;
                final completions = activityData['completions'] as int;

                return ListTile(
                  title: Text(activityName),
                  trailing: Text(
                    isTimed
                        ? formatDuration(totalDuration)
                        : '$completions time(s)',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Goals',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
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
                final todayTime = widget.activityLogs
                    .where((log) => log.activityName == a.name && log.date.isAfter(todayStart))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (stopwatch.isRunning && selectedActivity?.name == a.name && a is TimedActivity
                        ? stopwatch.elapsed
                        : Duration.zero);

                final todayCompletions = widget.activityLogs
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(todayStart) &&
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
          ),
        ],
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

class CalendarPage extends StatelessWidget {
  final List<ActivityLog> activityLogs;

  const CalendarPage({super.key, required this.activityLogs});

  Map<DateTime, Duration> _aggregateByDay() {
    Map<DateTime, Duration> result = {};
    for (var log in activityLogs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      result[day] = (result[day] ?? Duration.zero) + log.duration;
    }
    return result;
  }

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final data = _aggregateByDay();
    final sortedDays = data.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final duration = data[day]!;
        return ListTile(
          title: Text(
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'),
          trailing: Text(formatDuration(duration)),
        );
      },
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