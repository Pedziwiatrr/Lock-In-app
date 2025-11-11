import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/activity_log.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/tracker_page.dart';


void main() {

  final List<Activity> testActivities = [
    TimedActivity(name: 'Focus'),
    CheckableActivity(name: 'Workout'),
  ];
  final List<Goal> testGoals = [];
  final List<ActivityLog> testLogs = [];

  Future<void> pumpPage(WidgetTester tester, {
    Activity? selectedActivity,
    Duration elapsed = Duration.zero,
    bool isRunning = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerPage(
            activities: testActivities,
            goals: testGoals,
            activityLogs: testLogs,
            selectedActivity: selectedActivity,
            selectedDate: DateTime.now(),
            elapsed: elapsed,
            isRunning: isRunning,
            onSelectActivity: (_) {},
            onSelectDate: (_) {},
            onStartTimer: () {},
            onStopTimer: () {},
            onFinishTimer: () {},
            onCheckActivity: () {},
            onAddManualTime: (_) {},
            onSubtractManualTime: (_) {},
            onAddManualCompletion: (_) {},
            onSubtractManualCompletion: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('TrackerPage renders initial state', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.byType(DropdownButtonFormField<Activity>), findsOneWidget);
    expect(find.text('Select activity'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
    expect(find.text('CURRENT STREAK'), findsOneWidget);
  });

  testWidgets('TrackerPage displays timer for TimedActivity', (WidgetTester tester) async {
    await pumpPage(
      tester,
      selectedActivity: testActivities.first,
      elapsed: const Duration(hours: 1, minutes: 2, seconds: 3),
    );

    expect(find.text('01:02:03').first, findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('TrackerPage displays completions for CheckableActivity', (WidgetTester tester) async {
    await pumpPage(
      tester,
      selectedActivity: testActivities.last,
    );

    expect(find.text('0 x'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
  });

  testWidgets('TrackerPage displays manual add/subtract buttons', (WidgetTester tester) async {
    await pumpPage(
      tester,
      selectedActivity: testActivities.first,
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });
}