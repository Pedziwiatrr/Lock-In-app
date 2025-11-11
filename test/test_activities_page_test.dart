import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/pages/activities_page.dart';

void main() {

  final List<Activity> testActivities = [
    TimedActivity(name: 'Focus'),
    CheckableActivity(name: 'Workout'),
  ];

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActivitiesPage(
            activities: testActivities,
            onUpdate: () {},
            launchCount: 2,
          ),
        ),
      ),
    );
  }

  testWidgets('ActivitiesPage renders list of activities', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.text('Focus'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

    expect(find.text('Workout'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    expect(find.byType(ReorderableListView), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Activity'), findsOneWidget);
  });

  testWidgets('FloatingActionButton is present', (WidgetTester tester) async {
    await pumpPage(tester);

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(FloatingActionButton).first, findsOneWidget);
  });
}