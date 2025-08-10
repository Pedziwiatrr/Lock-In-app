import 'package:flutter/material.dart';
import 'dart:math';
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
  final num Function(List<Activity>, List<ActivityLog>, List<Goal>) getProgress;

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

  ProgressService({
    required this.activities,
    required this.activityLogs,
    required this.goals,
  });

  static const List<Rank> ranks = [
    Rank(name: 'Rookie', xpRequired: 0, icon: Icons.child_care),
    Rank(name: 'Intermediate', xpRequired: 100, icon: Icons.school),
    Rank(name: 'Expert', xpRequired: 400, icon: Icons.construction),
    Rank(name: 'Master', xpRequired: 1200, icon: Icons.military_tech),
    Rank(name: 'Champion', xpRequired: 2700, icon: Icons.star),
    Rank(name: 'Legend', xpRequired: 6000, icon: Icons.emoji_events),
    Rank(name: 'Truly Locked In', xpRequired: 15000, icon: Icons.auto_awesome),
  ];

  static final List<Quest> _quests = [
    Quest(
        id: 'q1',
        title: 'First Step',
        icon: Icons.add_circle_outline,
        levels: [QuestLevel(description: 'Create your own custom activity.', xpReward: 20, target: 1)],
        getProgress: (a, l, g) => (a.length > 2) ? 1 : 0),
    Quest(
        id: 'q2',
        title: 'Ambitious',
        icon: Icons.flag_outlined,
        levels: [QuestLevel(description: 'Create your first goal.', xpReward: 30, target: 1)],
        getProgress: (a, l, g) => g.isNotEmpty ? 1 : 0),
    Quest(
        id: 'q3',
        title: 'Taking Action',
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
        getProgress: (a, l, g) => l.fold<Duration>(Duration.zero, (p, e) => p + e.duration).inHours),
    Quest(
        id: 'q4_new',
        title: 'Habit Builder',
        icon: Icons.check_circle_outline,
        levels: [
          QuestLevel(description: 'Log a total of 10 completions.', xpReward: 50, target: 10),
          QuestLevel(description: 'Log a total of 25 completions.', xpReward: 100, target: 25),
          QuestLevel(description: 'Log a total of 100 completions.', xpReward: 200, target: 100),
          QuestLevel(description: 'Log a total of 500 completions.', xpReward: 500, target: 500),
          QuestLevel(description: 'Log a total of 1000 completions.', xpReward: 800, target: 1000),
          QuestLevel(description: 'Log a total of 3000 completions.', xpReward: 1600, target: 3000),
          QuestLevel(description: 'Log a total of 10000 completions.', xpReward: 10000, target: 10000),
        ],
        getProgress: (a, l, g) => l.where((log) => log.isCheckable).length),
    Quest(
      id: 'q_repeat_timed',
      title: 'Extra Effort',
      icon: Icons.repeat,
      isRepeatable: true,
      levels: [QuestLevel(description: 'Log 2 hours in any timed activity. (Repeatable)', xpReward: 50, target: 2)],
      getProgress: (a, l, g) => l.fold<Duration>(Duration.zero, (p, e) => p + e.duration).inHours,
    ),
    Quest(
      id: 'q_repeat_checkable',
      title: 'Consistency Check',
      icon: Icons.repeat_one,
      isRepeatable: true,
      levels: [QuestLevel(description: 'Log 5 completions in any checkable activity. (Repeatable)', xpReward: 30, target: 5)],
      getProgress: (a, l, g) => l.where((log) => log.isCheckable).length,
    ),
  ];

  int get totalXp {
    int xp = 0;
    for (var quest in _quests) {
      final progress = quest.getProgress(activities, activityLogs, goals);
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
      final progress = quest.getProgress(activities, activityLogs, goals);
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

  const ProgressPage({
    super.key,
    required this.activities,
    required this.activityLogs,
    required this.goals,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  late ProgressService _progressService;

  @override
  void initState() {
    super.initState();
    _progressService = ProgressService(
      activities: widget.activities,
      activityLogs: widget.activityLogs,
      goals: widget.goals,
    );
  }

  @override
  void didUpdateWidget(covariant ProgressPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activities != oldWidget.activities ||
        widget.activityLogs != oldWidget.activityLogs ||
        widget.goals != oldWidget.goals) {
      setState(() {
        _progressService = ProgressService(
          activities: widget.activities,
          activityLogs: widget.activityLogs,
          goals: widget.goals,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRank = _progressService.currentRank;
    final nextRank = _progressService.nextRank;
    final totalXp = _progressService.totalXp;
    final activeQuests = _progressService.activeQuests;

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

                num progressBaseline, progressValue, progressTotal;
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
                  progressBaseline = activeQuest.currentLevel?.target ?? 0;
                  progressValue = activeQuest.currentProgress - progressBaseline;
                  progressTotal = nextLevel.target - progressBaseline;
                  progressPercent = max(0.0, progressValue / (progressTotal > 0 ? progressTotal : 1));
                }

                return Card(
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
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}