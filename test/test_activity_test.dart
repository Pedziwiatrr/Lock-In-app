import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';

void main() {
  group('Activity Serialization', () {
    test('TimedActivity toJson/fromJson', () {
      final activity = TimedActivity(
        name: 'Test Focus',
        totalTime: const Duration(seconds: 3600),
      );

      final json = activity.toJson();
      final fromJson = TimedActivity.fromJson(json);

      expect(fromJson.name, 'Test Focus');
      expect(fromJson.totalTime, const Duration(seconds: 3600));
      expect(fromJson.toJson()['type'], 'TimedActivity');
    });

    test('TimedActivity default values', () {
      final activity = TimedActivity(name: 'Default Time');
      final json = activity.toJson();
      final fromJson = TimedActivity.fromJson(json);

      expect(fromJson.name, 'Default Time');
      expect(fromJson.totalTime, Duration.zero);
    });

    test('CheckableActivity toJson/fromJson', () {
      final activity = CheckableActivity(
        name: 'Test Workout',
        completionCount: 10,
      );

      final json = activity.toJson();
      final fromJson = CheckableActivity.fromJson(json);

      expect(fromJson.name, 'Test Workout');
      expect(fromJson.completionCount, 10);
      expect(fromJson.toJson()['type'], 'CheckableActivity');
    });

    test('CheckableActivity default values', () {
      final activity = CheckableActivity(name: 'Default Check');
      final json = activity.toJson();
      final fromJson = CheckableActivity.fromJson(json);

      expect(fromJson.name, 'Default Check');
      expect(fromJson.completionCount, 0);
    });

    test('Activity base class', () {
      final Activity activity = TimedActivity(name: 'Base');
      expect(activity.name, 'Base');
    });
  });
}