import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity_log.dart';

void main() {
  group('ActivityLog Serialization', () {
    final testDate = DateTime.now();

    test('ActivityLog toJson/fromJson', () {
      final log = ActivityLog(
        activityName: 'Test Activity',
        date: testDate,
        duration: const Duration(minutes: 30),
        isCheckable: false,
      );

      final json = log.toJson();
      final fromJson = ActivityLog.fromJson(json);

      expect(fromJson.activityName, 'Test Activity');
      expect(fromJson.date, testDate);
      expect(fromJson.duration, const Duration(minutes: 30));
      expect(fromJson.isCheckable, false);
    });

    test('ActivityLog for checkable activity', () {
      final log = ActivityLog(
        activityName: 'Checkable',
        date: testDate,
        duration: Duration.zero,
        isCheckable: true,
      );

      final json = log.toJson();
      final fromJson = ActivityLog.fromJson(json);

      expect(fromJson.activityName, 'Checkable');
      expect(fromJson.date, testDate);
      expect(fromJson.duration, Duration.zero);
      expect(fromJson.isCheckable, true);
    });

    test('Date parsing', () {
      final dateString = "2025-10-20T10:00:00.000Z";
      final json = {
        'activityName': 'Parsed Date',
        'date': dateString,
        'duration': 60,
        'isCheckable': false,
      };

      final fromJson = ActivityLog.fromJson(json);
      expect(fromJson.date, DateTime.parse(dateString));
    });
  });
}