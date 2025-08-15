import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/activity.dart';
import '../models/activity_log.dart';
import '../models/goal.dart';

class QuestLevel {
  final String description;
  final int xpReward;
  final num target;

  const QuestLevel({
    required this.description,
    required this.xpReward,
    required this.target,
  });
}

class Quest {
  final String id;
  final String title;
  final IconData icon;
  final bool isRepeatable;
  final List<QuestLevel> levels;
  final num Function(List<Activity>, List<ActivityLog>, List<Goal>, int, bool) getProgress;

  const Quest({
    required this.id,
    required this.title,
    required this.icon,
    this.isRepeatable = false,
    required this.levels,
    required this.getProgress,
  });
}

class ActiveQuestInfo {
  final Quest quest;
  final num currentProgress;
  final QuestLevel? currentLevel;
  final QuestLevel nextLevel;
  final int currentLevelNum;

  ActiveQuestInfo({
    required this.quest,
    required this.currentProgress,
    this.currentLevel,
    required this.nextLevel,
    required this.currentLevelNum,
  });
}

class Rank {
  final String name;
  final int xpRequired;
  final IconData icon;

  const Rank({
    required this.name,
    required this.xpRequired,
    required this.icon,
  });
}

class ProgressService {
  final List<Activity> activities;
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;
  final int launchCount;
  final bool hasRatedApp;

  ProgressService({
    required this.activities,
    required this.activityLogs,
    required this.goals,
    required this.launchCount,
    required this.hasRatedApp,
  });

  static const List<Rank> ranks = [
    Rank(name: 'Rookie', xpRequired: 0, icon: Icons.child_care),
    Rank(name: 'Intermediate', xpRequired: 100, icon: Icons.school),
    Rank(name: 'Advanced', xpRequired: 400, icon: Icons.insights),
    Rank(name: 'Expert', xpRequired: 1200, icon: Icons.construction),
    Rank(name: 'Master', xpRequired: 2700, icon: Icons.military_tech),
    Rank(name: 'Champion', xpRequired: 6000, icon: Icons.star),
    Rank(name: 'Legend', xpRequired: 10000, icon: Icons.emoji_events),
    Rank(name: 'Truly Locked In', xpRequired: 20000, icon: Icons.auto_awesome),
  ];

  static final List<Quest> _quests = [
    Quest(
        id: 'q1',
        title: 'First Step',
        icon: Icons.add_circle_outline,
        levels: [QuestLevel(description: 'Create your own custom activity.', xpReward: 30, target: 1)],
        getProgress: (a, l, g, lc, hr) => (a.length > 2) ? 1 : 0),
    Quest(
        id: 'q2',
        title: 'Ambitious',
        icon: Icons.flag_outlined,
        levels: [QuestLevel(description: 'Create your first goal.', xpReward: 40, target: 1)],
        getProgress: (a, l, g, lc, hr) => g.isNotEmpty ? 1 : 0),
    Quest(
        id: 'q3',
        title: 'Locking in',
        icon: Icons.hourglass_top_outlined,
        levels: [
          QuestLevel(description: 'Log a total of 1 hour in any timed activity.', xpReward: 60, target: 1),
          QuestLevel(description: 'Log a total of 10 hours in any timed activity.', xpReward: 150, target: 10),
          QuestLevel(description: 'Log a total of 25 hours in the "Focus" activity.', xpReward: 250, target: 25),
          QuestLevel(description: 'Log a total of 100 hours.', xpReward: 500, target: 100),
          QuestLevel(description: 'Log a total of 500 hours.', xpReward: 1200, target: 500),
          QuestLevel(description: 'Log a total of 2000 hours.', xpReward: 3000, target: 2000),
          QuestLevel(description: 'Log a total of 10000 hours.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g, lc, hr) => l.fold<Duration>(Duration.zero, (p, e) => p + e.duration).inHours),
    Quest(
        id: 'q4',
        title: 'Habit Builder',
        icon: Icons.check_circle_outline,
        levels: [
          QuestLevel(description: 'Log 3 total completions.', xpReward: 20, target: 3),
          QuestLevel(description: 'Log 10 total completions.', xpReward: 75, target: 10),
          QuestLevel(description: 'Log 25 total completions.', xpReward: 50, target: 25),
          QuestLevel(description: 'Log 100 total completions.', xpReward: 100, target: 100),
          QuestLevel(description: 'Log 500 total completions.', xpReward: 250, target: 500),
          QuestLevel(description: 'Log 1000 total completions.', xpReward: 500, target: 1000),
          QuestLevel(description: 'Log 2500 total completions.', xpReward: 3000, target: 2500),
          QuestLevel(description: 'Log 5000 total completions.', xpReward: 6000, target: 5000),
          QuestLevel(description: 'Log 10000 total completions.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g, lc, hr) => l.where((log) => log.isCheckable).length),
    Quest(
        id: 'q5',
        title: 'Activity Specialist',
        icon: Icons.psychology_outlined,
        levels: [
          QuestLevel(description: 'Log 10 hours in a single timed activity.', xpReward: 150, target: 10),
          QuestLevel(description: 'Log 25 hours in a single timed activity.', xpReward: 250, target: 25),
          QuestLevel(description: 'Log 100 hours in a single timed activity.', xpReward: 500, target: 100),
          QuestLevel(description: 'Log 500 hours in a single timed activity.', xpReward: 1000, target: 1000),
          QuestLevel(description: 'Log 1500 hours in a single timed activity.', xpReward: 2000, target: 1500),
          QuestLevel(description: 'Log 4000 hours in a single timed activity.', xpReward: 5000, target: 4000),
          QuestLevel(description: 'Log 10000 hours in a single timed activity.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g, lc, hr) {
          final timedActivities = a.whereType<TimedActivity>();
          if (timedActivities.isEmpty) return 0;
          return timedActivities.map((activity) {
            return l.where((log) => log.activityName == activity.name && !log.isCheckable)
                .fold<Duration>(Duration.zero, (p, e) => p + e.duration).inHours;
          }).reduce(max);
        }),
    Quest(
        id: 'q6',
        title: 'Routine Master',
        icon: Icons.checklist_rtl_outlined,
        levels: [
          QuestLevel(description: 'Log 5 completions for a single checkable activity.', xpReward: 25, target: 5),
          QuestLevel(description: 'Log 20 completions for a single checkable activity.', xpReward: 100, target: 20),
          QuestLevel(description: 'Log 150 completions for a single checkable activity.', xpReward: 250, target: 150),
          QuestLevel(description: 'Log 500 completions for a single checkable activity.', xpReward: 500, target: 500),
          QuestLevel(description: 'Log 1500 completions for a single checkable activity.', xpReward: 1000, target: 1500),
          QuestLevel(description: 'Log 4000 completions for a single checkable activity.', xpReward: 3000, target: 4000),
          QuestLevel(description: 'Log 10000 completions for a single checkable activity.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g, lc, hr) {
          final checkableActivities = a.whereType<CheckableActivity>();
          if (checkableActivities.isEmpty) return 0;
          return checkableActivities.map((activity) {
            return l.where((log) => log.activityName == activity.name && log.isCheckable).length;
          }).reduce((v, e) => max(v,e));
        }),
    Quest(
        id: 'q7_logins',
        title: 'Regular Visitor',
        icon: Icons.login,
        levels: [
          QuestLevel(description: 'Launch the app 3 times.', xpReward: 25, target: 3),
          QuestLevel(description: 'Launch the app 7 times.', xpReward: 50, target: 7),
          QuestLevel(description: 'Launch the app 30 times.', xpReward: 100, target: 30),
          QuestLevel(description: 'Launch the app 100 times.', xpReward: 250, target: 100),
          QuestLevel(description: 'Launch the app 365 times.', xpReward: 1000, target: 365),
          QuestLevel(description: 'Launch the app 1000 times.', xpReward: 2000, target: 10000),
          QuestLevel(description: 'Launch the app 3000 times.', xpReward: 4000, target: 3000),
          QuestLevel(description: 'Launch the app 10000 times.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g, launchCount, hr) => launchCount),
    Quest(
        id: 'q8_rate',
        title: 'Supporter',
        icon: Icons.rate_review_outlined,
        levels: [QuestLevel(description: 'Rate the app on the Google Play store. To do so just click on this text :)', xpReward: 150, target: 1)],
        getProgress: (a, l, g, lc, hasRated) => hasRated ? 1 : 0),
    Quest(
      id: 'q_repeat_1',
      title: 'Extra Effort',
      icon: Icons.repeat,
      isRepeatable: true,
      levels: [QuestLevel(description: 'Log 2 hours in any timed activity. (Repeatable)', xpReward: 50, target: 2)],
      getProgress: (a, l, g, lc, hr) => l.fold<Duration>(Duration.zero, (p, e) => p + e.duration).inHours,
    ),
    Quest(
      id: 'q_repeat_checkable',
      title: 'Consistency Check',
      icon: Icons.repeat_one,
      isRepeatable: true,
      levels: [QuestLevel(description: 'Log 5 completions in any checkable activity. (Repeatable)', xpReward: 50, target: 5)],
      getProgress: (a, l, g, lc, hr) => l.where((log) => log.isCheckable).length,
    ),
  ];

  static List<Quest> get quests => _quests;

  int get totalXp {
    int xp = 0;
    for (var quest in _quests) {
      final progress = quest.getProgress(activities, activityLogs, goals, launchCount, hasRatedApp);
      if (quest.isRepeatable) {
        final level = quest.levels.first;
        if (level.target > 0) {
          final completions = (progress / level.target).floor();
          xp += completions * level.xpReward;
        }
      } else {
        for (var level in quest.levels) {
          if (progress >= level.target) {
            xp += level.xpReward;
          }
        }
      }
    }
    return xp;
  }

  Rank get currentRank {
    return ranks.lastWhere((r) => totalXp >= r.xpRequired, orElse: () => ranks.first);
  }

  Rank? get nextRank {
    final currentRankIndex = ranks.indexOf(currentRank);
    if (currentRankIndex < ranks.length - 1) {
      return ranks[currentRankIndex + 1];
    }
    return null;
  }

  List<ActiveQuestInfo> get activeQuests {
    final List<ActiveQuestInfo> active = [];
    for (var quest in _quests) {
      final progress = quest.getProgress(activities, activityLogs, goals, launchCount, hasRatedApp);
      if (quest.isRepeatable) {
        active.add(ActiveQuestInfo(
          quest: quest,
          currentProgress: progress,
          nextLevel: quest.levels.first,
          currentLevelNum: 0,
        ));
        continue;
      }

      QuestLevel? currentLevel;
      QuestLevel? nextLevel;
      int currentLevelIndex = -1;

      for (int i = 0; i < quest.levels.length; i++) {
        if (progress < quest.levels[i].target) {
          nextLevel = quest.levels[i];
          break;
        }
        currentLevel = quest.levels[i];
        currentLevelIndex = i;
      }

      if (nextLevel != null) {
        active.add(ActiveQuestInfo(
          quest: quest,
          currentProgress: progress,
          currentLevel: currentLevel,
          nextLevel: nextLevel,
          currentLevelNum: currentLevelIndex + 1,
        ));
      }
    }
    return active;
  }
}

class ProgressPage extends StatefulWidget {
  final List<Activity> activities;
  final List<ActivityLog> activityLogs;
  final List<Goal> goals;
  final int launchCount;

  const ProgressPage({
    super.key,
    required this.activities,
    required this.activityLogs,
    required this.goals,
    required this.launchCount,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  ProgressService? _progressService;
  bool _hasRatedApp = false;

  @override
  void initState() {
    super.initState();
    _loadDataAndInitService();
  }

  Future<void> _loadDataAndInitService() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasRatedApp = prefs.getBool('hasRatedApp') ?? false;
        _progressService = ProgressService(
          activities: widget.activities,
          activityLogs: widget.activityLogs,
          goals: widget.goals,
          launchCount: widget.launchCount,
          hasRatedApp: _hasRatedApp,
        );
      });
    }
  }

  Future<void> _handleRateApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasRatedApp', true);

    const url = 'https://play.google.com/store/apps/details?id=com.example.lockin';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      setState(() {
        _hasRatedApp = true;
        _progressService = ProgressService(
          activities: widget.activities,
          activityLogs: widget.activityLogs,
          goals: widget.goals,
          launchCount: widget.launchCount,
          hasRatedApp: _hasRatedApp,
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activities != oldWidget.activities ||
        widget.activityLogs != oldWidget.activityLogs ||
        widget.goals != oldWidget.goals ||
        widget.launchCount != oldWidget.launchCount) {
      setState(() {
        _progressService = ProgressService(
          activities: widget.activities,
          activityLogs: widget.activityLogs,
          goals: widget.goals,
          launchCount: widget.launchCount,
          hasRatedApp: _hasRatedApp,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_progressService == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentRank = _progressService!.currentRank;
    final nextRank = _progressService!.nextRank;
    final totalXp = _progressService!.totalXp;
    final activeQuests = _progressService!.activeQuests;

    double progressToNextRank = 0.0;
    int xpForNextRank = 0;
    int xpProgressInRank = 0;

    if (nextRank != null) {
      xpForNextRank = nextRank.xpRequired - currentRank.xpRequired;
      xpProgressInRank = totalXp - currentRank.xpRequired;
      progressToNextRank = max(0.0, xpProgressInRank / (xpForNextRank > 0 ? xpForNextRank : 1));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(currentRank.icon, size: 50, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Rank', style: TextStyle(color: Colors.grey)),
                      Text(currentRank.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Total XP: $totalXp', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (nextRank != null) ...[
            Text('Progress to ${nextRank.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressToNextRank,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$xpProgressInRank XP', style: const TextStyle(color: Colors.grey)),
                Text('$xpForNextRank XP', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ] else ...[
            Text('Congratulations!', style: Theme.of(context).textTheme.titleLarge),
            const Text('You have achieved the highest rank!'),
          ],
          const SizedBox(height: 24),
          Text('Available Quests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (activeQuests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No more quests available. You are truly locked in!')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeQuests.length,
              itemBuilder: (context, index) {
                final activeQuest = activeQuests[index];
                final quest = activeQuest.quest;
                final nextLevel = activeQuest.nextLevel;

                num progressValue, progressTotal;
                double progressPercent;
                String title;

                if (quest.isRepeatable) {
                  title = quest.title;
                  progressTotal = nextLevel.target;
                  if (progressTotal > 0) {
                    progressValue = activeQuest.currentProgress % progressTotal;
                  } else {
                    progressValue = 0;
                  }
                  progressPercent = max(0.0, progressValue / (progressTotal > 0 ? progressTotal : 1));
                } else {
                  title = '${quest.title} ${activeQuest.currentLevelNum + 1}';
                  progressValue = activeQuest.currentProgress;
                  progressTotal = nextLevel.target;
                  progressPercent = max(0.0, progressValue / (progressTotal > 0 ? progressTotal : 1));
                }

                final questCard = Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                          leading: Icon(quest.icon, color: Theme.of(context).colorScheme.secondary),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(nextLevel.description),
                          trailing: Text('+${nextLevel.xpReward} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                        ),
                        if (quest.id != 'q8_rate')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Column(
                              children: [
                                LinearProgressIndicator(
                                  value: progressPercent,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${progressValue.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text('${progressTotal.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );

                if (quest.id == 'q8_rate' && !_hasRatedApp) {
                  return InkWell(
                    onTap: _handleRateApp,
                    child: questCard,
                  );
                }
                return questCard;
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}