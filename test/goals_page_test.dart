import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/models/goal.dart';
import 'package:lockin/pages/goals_page.dart';
import 'package:lockin/utils/ad_manager.dart';

import 'mock_ad_manager.dart';

class TestGoalsPageWrapper extends StatefulWidget {
  final List<Activity> activities;
  final List<Goal> initialGoals;

  const TestGoalsPageWrapper({
    super.key,
    required this.activities,
    required this.initialGoals,
  });

  @override
  State<TestGoalsPageWrapper> createState() => _TestGoalsPageWrapperState();
}

class _TestGoalsPageWrapperState extends State<TestGoalsPageWrapper> {
  late List<Goal> goals;
  late List<Activity> activities;

  @override
  void initState() {
    super.initState();
    goals = widget.initialGoals;
    activities = widget.activities;
  }

  void updateActivities(List<Activity> newActivities) {
    setState(() {
      activities = newActivities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GoalsPage(
      goals: goals,
      activities: activities,
      onGoalChanged: (newGoals) {
        setState(() {
          goals = newGoals;
        });
      },
      launchCount: 2,
    );
  }
}

void main() {
  final mockActivities = [
    TimedActivity(name: 'Reading'),
    CheckableActivity(name: 'Workout'),
  ];
  final realAdManager = AdManager.instance;

  setUp(() {
    AdManager.instance = MockAdManager();
  });

  tearDown(() {
    AdManager.instance = realAdManager;
  });

  testWidgets('Can set a new goal', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          initialGoals: const [],
          activities: mockActivities,
        ),
      ),
    ));

    final goalTextFields = find.widgetWithText(TextField, 'Goal');
    await tester.enterText(goalTextFields.first, '60');
    await tester.tap(find.text('Set').first);
    await tester.pumpAndSettle();

    final state = tester.state<State<TestGoalsPageWrapper>>(find.byType(TestGoalsPageWrapper)) as _TestGoalsPageWrapperState;
    expect(state.goals.length, 1);
    expect(state.goals.first.activityName, 'Reading');
    expect(state.goals.first.goalDuration, const Duration(minutes: 60));
  });

  testWidgets('Can update an existing goal', (tester) async {
    final initialGoals = [
      Goal(
        activityName: 'Reading',
        goalDuration: const Duration(minutes: 30),
        goalType: GoalType.daily,
        startDate: DateTime.now(),
      )
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          initialGoals: initialGoals,
          activities: mockActivities,
        ),
      ),
    ));

    final goalTextFields = find.widgetWithText(TextField, 'Goal');
    expect(find.text('30'), findsOneWidget);

    await tester.enterText(goalTextFields.first, '90');
    await tester.tap(find.text('Set').first);
    await tester.pumpAndSettle();

    final state = tester.state<State<TestGoalsPageWrapper>>(find.byType(TestGoalsPageWrapper)) as _TestGoalsPageWrapperState;
    expect(state.goals.length, 1);
    expect(state.goals.first.goalDuration, const Duration(minutes: 90));
  });

  testWidgets('Changes input field when goal type dropdown is changed', (tester) async {
    final initialGoals = [
      Goal(
        activityName: 'Reading',
        goalDuration: const Duration(minutes: 30),
        goalType: GoalType.daily,
        startDate: DateTime.now(),
      ),
      Goal(
        activityName: 'Reading',
        goalDuration: const Duration(minutes: 200),
        goalType: GoalType.weekly,
        startDate: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          initialGoals: initialGoals,
          activities: mockActivities,
        ),
      ),
    ));

    expect(find.text('30'), findsOneWidget);

    await tester.tap(find.text('Daily').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly').last);
    await tester.pumpAndSettle();

    expect(find.text('30'), findsNothing);
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('Shows SnackBar when goal exceeds max value', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          initialGoals: const [],
          activities: mockActivities,
        ),
      ),
    ));

    final goalTextFields = find.widgetWithText(TextField, 'Goal');
    await tester.enterText(goalTextFields.first, '10001');
    await tester.tap(find.text('Set').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot exceed'), findsOneWidget);
  });

  testWidgets('Removes goal widget when an activity is removed', (tester) async {
    final GlobalKey<_TestGoalsPageWrapperState> wrapperKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          key: wrapperKey,
          initialGoals: const [],
          activities: mockActivities,
        ),
      ),
    ));

    expect(find.textContaining('Reading'), findsOneWidget);
    expect(find.textContaining('Workout'), findsOneWidget);

    wrapperKey.currentState?.updateActivities([TimedActivity(name: 'Reading')]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Reading'), findsOneWidget);
    expect(find.textContaining('Workout'), findsNothing);
  });

  testWidgets('Can view and delete goals', (tester) async {
    final goalId = 'test-id-123';
    final initialGoals = [
      Goal(
        id: goalId,
        activityName: 'Reading',
        goalDuration: const Duration(minutes: 30),
        goalType: GoalType.daily,
        startDate: DateTime(2025, 8, 14),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TestGoalsPageWrapper(
          initialGoals: initialGoals,
          activities: mockActivities,
        ),
      ),
    ));

    await tester.tap(find.text('View Goals'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Goal: 00:30:00'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    final state = tester.state<State<TestGoalsPageWrapper>>(find.byType(TestGoalsPageWrapper)) as _TestGoalsPageWrapperState;
    expect(state.goals.isEmpty, isTrue);
    expect(find.textContaining('Goal: 00:30:00'), findsNothing);
  });
}