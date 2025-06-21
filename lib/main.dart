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
      home: HomePage(onThemeChanged: toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
    );
  }
}


class HomePage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkMode;

  HomePage({super.key, required this.onThemeChanged, required this.isDarkMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class Goal {
  String activityName;
  Duration dailyGoal;
  Goal({required this.activityName, required this.dailyGoal});
}

class Activity {
  String name;
  Duration totalTime;
  bool visible;

  Activity({required this.name, this.totalTime = Duration.zero, this.visible = true});
}

class _HomePageState extends State<HomePage> {
  final List<Activity> activities = [
    Activity(name: 'Studying'),
    Activity(name: 'Workout'),
    Activity(name: 'Reading'),
    Activity(name: 'Cleaning'),
  ];
  final List<ActivityLog> activityLogs = [];
  List<Goal> goals = [];

  void updateActivities() {
    setState(() {});
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
                  activity.totalTime += log.duration;
                });
              },
            ),
            GoalsPage(goals: goals, activities: activities, onGoalChanged: (newGoals) {
              setState(() { goals = newGoals; });
            },),
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

  @override
  void initState() {
    super.initState();
    activityLogs.addAll([
      ActivityLog(activityName: 'Studying', date: DateTime.now().subtract(Duration(days: 0)), duration: Duration(hours: 2)),
      ActivityLog(activityName: 'Studying', date: DateTime.now().subtract(Duration(days: 1)), duration: Duration(hours: 2)),
      ActivityLog(activityName: 'Workout', date: DateTime.now().subtract(Duration(days: 2)), duration: Duration(minutes: 90)),
      ActivityLog(activityName: 'Reading', date: DateTime.now().subtract(Duration(days: 3)), duration: Duration(hours: 1, minutes: 30)),
      ActivityLog(activityName: 'Cleaning', date: DateTime.now(), duration: Duration(hours: 1)),
      ActivityLog(activityName: 'Workout', date: DateTime.now().subtract(Duration(days: 32)), duration: Duration(hours: 1, minutes: 30)),
      ActivityLog(activityName: 'Workout', date: DateTime.now().subtract(Duration(days: 367)), duration: Duration(hours: 1, minutes: 30)),
    ]);
    goals = [
      Goal(activityName: 'Studying', dailyGoal: Duration(hours: 1, minutes: 30)),
      Goal(activityName: 'Workout', dailyGoal: Duration(hours: 1)),
    ];
    for (var log in activityLogs) {
      final activity = activities.firstWhere((a) => a.name == log.activityName);
      activity.totalTime += log.duration;
    }
  }
}


class ActivityLog {
  String activityName;
  DateTime date;
  Duration duration;

  ActivityLog({required this.activityName, required this.date, required this.duration});
}


// ---------------- Tracker Page ----------------

class TrackerPage extends StatefulWidget {
  final void Function(ActivityLog) onAddLog;
  final List<Activity> activities;
  final List<Goal> goals;
  final List<ActivityLog> activityLogs;

  const TrackerPage({
    Key? key,
    required this.activities,
    required this.goals,
    required this.onAddLog,
    required this.activityLogs,
  }) : super(key: key);

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
    ));
    setState(() {
      elapsed = Duration.zero;
      stopwatch.reset();
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

  @override
  Widget build(BuildContext context) {
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
          Text(
            formatDuration(elapsed),
            style: const TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: (selectedActivity == null || stopwatch.isRunning) ? null : startTimer,
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
            ],
          ),
          const SizedBox(height: 30),
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
                    .where((log) =>
                log.activityName == a.name &&
                    log.date.isAfter(todayStart))
                    .fold(Duration.zero, (sum, log) => sum + log.duration) +
                    (stopwatch.isRunning && selectedActivity?.name == a.name
                        ? stopwatch.elapsed
                        : Duration.zero);

                final percent = goal.dailyGoal.inSeconds == 0
                    ? 0.0
                    : (todayTime.inSeconds / goal.dailyGoal.inSeconds).clamp(0.0, 1.0);

                final remaining = goal.dailyGoal - todayTime;
                final remainingText = remaining.isNegative
                    ? 'Goal completed!'
                    : 'Remaining: ${formatDuration(remaining)}';

                return ListTile(
                  title: Text(a.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: percent),
                      SizedBox(height: 4),
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

// ---------------- Goal Page ----------------

  class GoalsPage extends StatefulWidget {
  final List<Goal> goals;
  final List<Activity> activities;
  final void Function(List<Goal>) onGoalChanged;

  const GoalsPage({super.key, required this.goals, required this.activities, required this.onGoalChanged});

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

  void updateGoal(String activityName, String minutesText) {
    final minutes = int.tryParse(minutesText) ?? 0;
    setState(() {
      final index = editableGoals.indexWhere((g) => g.activityName == activityName);
      if (index != -1) {
        editableGoals[index] = Goal(activityName: activityName, dailyGoal: Duration(minutes: minutes));
      } else {
        editableGoals.add(Goal(activityName: activityName, dailyGoal: Duration(minutes: minutes)));
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
            width: 60,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(suffixText: 'min'),
              onSubmitted: (val) => updateGoal(activity.name, val),
            ),
          ),
        );
      },
    );
  }
}

// ---------------- Stats Page ----------------



enum StatsPeriod { day, week, month, total }

class StatsPage extends StatefulWidget {
  final List<ActivityLog> activityLogs;
  final List<Activity> activities;
  final List<Goal> goals;

  const StatsPage({super.key, required this.activityLogs, required this.activities, required this.goals});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  StatsPeriod selectedPeriod = StatsPeriod.total;

  Duration getGoalForActivity(String name) {
    final goal = widget.goals.firstWhere((g) => g.activityName == name, orElse: () => Goal(activityName: name, dailyGoal: Duration.zero));
    return goal.dailyGoal;
  }

  List<Activity> filteredActivities() {
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

    Map<String, Duration> totals = {};

    for (var activity in widget.activities) {
      totals[activity.name] = Duration.zero;
    }

    for (var log in widget.activityLogs) {
      if (log.date.isAfter(from)) {
        totals[log.activityName] = (totals[log.activityName] ?? Duration.zero) + log.duration;
      }
    }

    return widget.activities.map((a) {
      return Activity(name: a.name, totalTime: totals[a.name] ?? Duration.zero);
    }).toList();
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
    final filtered = filteredActivities();
    final totalTime = filtered.fold<Duration>(
        Duration.zero, (sum, a) => sum + a.totalTime);

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
            'Total activity time: ${formatDuration(totalTime)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: filtered.map((a) {
                final goalDuration = getGoalForActivity(a.name);
                final percent = goalDuration.inSeconds == 0
                    ? 0.0
                    : (a.totalTime.inSeconds / goalDuration.inSeconds).clamp(0.0, 1.0);
                return ListTile(
                  title: Text(a.name),
                  subtitle: LinearProgressIndicator(value: percent),
                  trailing: Text(formatDuration(a.totalTime)),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------- Activities Page ----------------

class ActivitiesPage extends StatefulWidget {
  final List<Activity> activities;
  final VoidCallback onUpdate;

  const ActivitiesPage({super.key, required this.activities, required this.onUpdate});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}


class _ActivitiesPageState extends State<ActivitiesPage> {
  void addActivity() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Activity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Activity name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty &&
                    !widget.activities.any((a) => a.name == name)) {
                  setState(() {
                    widget.activities.add(Activity(name: name));
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  void renameActivity(int index) {
    final controller =
    TextEditingController(text: widget.activities[index].name);

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
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    widget.activities[index].name = name;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Save')),
        ],
      ),
    );
  }

  void deleteActivity(int index) {
    setState(() {
      widget.activities.removeAt(index);
    });
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(a.visible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          a.visible = !a.visible;
                        });
                        widget.onUpdate();
                      },
                    ),

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

// ---------------- Calendar Page ----------------

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
          title: Text('${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'),
          trailing: Text(formatDuration(duration)),
        );
      },
    );
  }
}

// ---------------- Settings Page ----------------

class SettingsPage extends StatelessWidget {
  final bool isDarkMode;
  final void Function(bool) onThemeChanged;

  const SettingsPage({super.key, required this.isDarkMode, required this.onThemeChanged});

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

