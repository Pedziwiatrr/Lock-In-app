import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/goals_page.dart';

void main() {

  final List<Activity> testActivities = [
    TimedActivity(name: 'Focus'),
    CheckableActivity(name: 'Workout'),
  ];

  final List<Goal> testGoals = [
    Goal(
      activityName: 'Focus',
      goalDuration: const Duration(hours: 1),
      startDate: DateTime.now(),
      goalType: GoalType.daily,
    ),
  ];

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsPage(
            goals: testGoals,
            activities: testActivities,
            onGoalChanged: (_) {},
            launchCount: 2,
          ),
        ),
      ),
    );
  }

  testWidgets('GoalsPage renders goal cards for activities', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Focus ⏰'), findsOneWidget);
    expect(find.text('Workout ✅'), findsOneWidget);

    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Goal Name (Optional)'), findsNWidgets(2));

    expect(find.text('Hours'), findsOneWidget);
    expect(find.text('Mins'), findsOneWidget);

    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('times'), findsOneWidget);
  });

  testWidgets('Renders "View Goals" button', (WidgetTester tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('View Goals'), findsOneWidget);
    expect(find.text('Hide Goals'), findsNothing);

    await tester.ensureVisible(find.text('View Goals'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Goals'));
    await tester.pumpAndSettle();

    expect(find.text('Hide Goals'), findsOneWidget);
    expect(find.text('View Goals'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Active Goals'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
  });
}