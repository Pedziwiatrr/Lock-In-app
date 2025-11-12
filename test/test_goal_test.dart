import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/goal.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Goal Serialization', () {
    final testDate = DateTime.now();
    final testEndDate = DateTime.now().add(const Duration(days: 30));

    test('Goal toJson/fromJson - Daily', () {
      final goal = Goal(
        activityName: 'Focus',
        goalDuration: const Duration(hours: 1),
        goalType: GoalType.daily,
        startDate: testDate,
        title: 'My Daily Goal',
      );

      final json = goal.toJson();
      final fromJson = Goal.fromJson(json);

      expect(fromJson.id, goal.id);
      expect(fromJson.title, 'My Daily Goal');
      expect(fromJson.activityName, 'Focus');
      expect(fromJson.goalDuration, const Duration(hours: 1));
      expect(fromJson.goalType, GoalType.daily);
      expect(fromJson.startDate, testDate);
      expect(fromJson.endDate, isNull);
    });

    test('Goal toJson/fromJson - Weekly with End Date', () {
      final goal = Goal(
        activityName: 'Workout',
        goalDuration: const Duration(minutes: 3),
        goalType: GoalType.weekly,
        startDate: testDate,
        endDate: testEndDate,
      );

      final json = goal.toJson();
      final fromJson = Goal.fromJson(json);

      expect(fromJson.activityName, 'Workout');
      expect(fromJson.goalDuration, const Duration(minutes: 3));
      expect(fromJson.goalType, GoalType.weekly);
      expect(fromJson.startDate, testDate);
      expect(fromJson.endDate, testEndDate);
    });

    test('Goal toJson/fromJson - Monthly', () {
      final goal = Goal(
        activityName: 'Read',
        goalDuration: const Duration(minutes: 10),
        goalType: GoalType.monthly,
        startDate: testDate,
      );

      final json = goal.toJson();
      final fromJson = Goal.fromJson(json);

      expect(fromJson.goalType, GoalType.monthly);
    });

    test('Goal generates ID if not provided', () {
      final goal = Goal(
        activityName: 'Test',
        goalDuration: const Duration(minutes: 1),
        startDate: testDate,
      );
      expect(goal.id, isNotNull);
      expect(goal.id, isA<String>());
    });

    test('Goal uses provided ID', () {
      const specificId = 'my-custom-id-123';
      final goal = Goal(
        id: specificId,
        activityName: 'Test',
        goalDuration: const Duration(minutes: 1),
        startDate: testDate,
      );
      expect(goal.id, specificId);
    });

    test('Goal handles legacy GoalType string', () {
      final json = {
        'id': const Uuid().v4(),
        'activityName': 'Legacy',
        'goalDuration': 600,
        'goalType': 'GoalType.weekly',
        'startDate': testDate.toIso8601String(),
      };

      final fromJson = Goal.fromJson(json);
      expect(fromJson.goalType, GoalType.weekly);
    });
  });
}