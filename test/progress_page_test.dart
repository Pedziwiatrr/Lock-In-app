import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/progress_page.dart';
import 'dart:math';

void main() {
  group('ProgressService Tests', () {
    late List<Activity> activities;
    late List<ActivityLog> activityLogs;
    late List<Goal> goals;
    late int launchCount;
    late bool hasRatedApp;

    setUp(() {
      activities = [
        TimedActivity(name: 'Focus'),
        CheckableActivity(name: 'Workout'),
      ];
      activityLogs = [];
      goals = [];
      launchCount = 0;
      hasRatedApp = false;
    });

    ProgressService createService() {
      return ProgressService(
        activities: activities,
        activityLogs: activityLogs,
        goals: goals,
        launchCount: launchCount,
        hasRatedApp: hasRatedApp,
      );
    }

    group('totalXp Calculation', () {
      test('should be 0 when no progress is made', () {
        final service = createService();
        expect(service.totalXp, 0);
      });

      test('should award xp for creating a custom activity', () {
        activities.add(TimedActivity(name: 'Reading'));
        final service = createService();
        expect(service.totalXp, 30);
      });

      test('should award xp for creating a goal', () {
        goals.add(Goal(
          id: 'g1',
          activityName: 'Focus',
          goalDuration: const Duration(hours: 10),
          startDate: DateTime.now(),
        ));
        final service = createService();
        expect(service.totalXp, 40);
      });

      test('should award xp for total timed log hours across multiple levels',
              () {
            activityLogs.add(ActivityLog(
                activityName: 'Focus',
                duration: const Duration(hours: 1),
                isCheckable: false,
                date: DateTime.now()));
            activityLogs.add(ActivityLog(
                activityName: 'Focus',
                duration: const Duration(hours: 9),
                isCheckable: false,
                date: DateTime.now()));
            final service = createService();
            expect(service.totalXp, 610);
          });

      test(
          'should award xp for total checkable completions across multiple levels',
              () {
            for (int i = 0; i < 10; i++) {
              activityLogs.add(ActivityLog(
                  activityName: 'Workout',
                  isCheckable: true,
                  date: DateTime.now(),
                  duration: Duration.zero));
            }
            final service = createService();
            expect(service.totalXp, 220);
          });

      test('should award xp for hours in a single timed activity', () {
        activities.add(TimedActivity(name: 'Study'));
        for (int i = 0; i < 10; i++) {
          activityLogs.add(ActivityLog(
              activityName: 'Study',
              duration: const Duration(hours: 1),
              isCheckable: false,
              date: DateTime.now()));
        }
        activityLogs.add(ActivityLog(
            activityName: 'Focus',
            duration: const Duration(hours: 5),
            isCheckable: false,
            date: DateTime.now()));
        final service = createService();
        expect(service.totalXp, 740);
      });

      test('should award xp for completions of a single checkable activity',
              () {
            activities.add(CheckableActivity(name: 'Meditate'));
            for (int i = 0; i < 5; i++) {
              activityLogs.add(ActivityLog(
                  activityName: 'Meditate',
                  isCheckable: true,
                  date: DateTime.now(),
                  duration: Duration.zero));
            }
            for (int i = 0; i < 3; i++) {
              activityLogs.add(ActivityLog(
                  activityName: 'Workout',
                  isCheckable: true,
                  date: DateTime.now(),
                  duration: Duration.zero));
            }
            final service = createService();
            expect(service.totalXp, 125);
          });

      test('should award xp for app launches', () {
        launchCount = 7;
        final service = createService();
        expect(service.totalXp, 25 + 50);
      });

      test('should award xp for rating the app', () {
        hasRatedApp = true;
        final service = createService();
        expect(service.totalXp, 150);
      });

      test('should award xp for repeatable timed quest', () {
        activityLogs.add(ActivityLog(
            activityName: 'Focus',
            duration: const Duration(hours: 5),
            isCheckable: false,
            date: DateTime.now()));
        final service = createService();
        expect(service.totalXp, 160);
      });

      test('should award xp for repeatable checkable quest', () {
        for (int i = 0; i < 12; i++) {
          activityLogs.add(ActivityLog(
              activityName: 'Workout',
              isCheckable: true,
              date: DateTime.now(),
              duration: Duration.zero));
        }
        final service = createService();
        expect(service.totalXp, 220);
      });

      test('should correctly sum xp from various completed quests', () {
        activities.add(TimedActivity(name: 'Reading'));
        goals.add(Goal(
          id: 'g1',
          activityName: 'Focus',
          goalDuration: const Duration(hours: 1),
          startDate: DateTime.now(),
        ));
        activityLogs.add(ActivityLog(
            activityName: 'Focus',
            duration: const Duration(hours: 1),
            isCheckable: false,
            date: DateTime.now()));
        for (int i = 0; i < 3; i++) {
          activityLogs.add(ActivityLog(
              activityName: 'Workout',
              isCheckable: true,
              date: DateTime.now(),
              duration: Duration.zero));
        }
        launchCount = 3;
        hasRatedApp = true;

        final service = createService();
        int expectedXp = 30 + 40 + 60 + 20 + 25 + 150;
        expect(service.totalXp, expectedXp);
      });
    });

    group('Rank Calculation', () {
      test('should return Rookie rank for 0 xp', () {
        final service = createService();
        expect(service.currentRank.name, 'Rookie');
        expect(service.nextRank?.name, 'Intermediate');
      });

      test('should return Intermediate rank for 100 xp', () {
        activityLogs.add(ActivityLog(
            activityName: 'Focus',
            duration: const Duration(hours: 2),
            isCheckable: false,
            date: DateTime.now()));
        final service = createService();
        expect(service.currentRank.name, 'Intermediate');
        expect(service.nextRank?.name, 'Grinder');
      });
    });
  });
}