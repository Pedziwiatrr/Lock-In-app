import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/pages/activities_page.dart';

void main() {
  late List<Activity> testActivities;
  String? renamedActivityOldName;
  String? renamedActivityNewName;

  setUp(() {
    testActivities = [
      TimedActivity(name: 'Focus'),
      CheckableActivity(name: 'Workout'),
    ];
    renamedActivityOldName = null;
    renamedActivityNewName = null;
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              body: ActivitiesPage(
                activities: testActivities,
                onUpdate: () => setState(() {}),
                onRenameActivity: (activity, newName) {
                  setState(() {
                    renamedActivityOldName = activity.name;
                    renamedActivityNewName = newName;
                    activity.name = newName;
                  });
                },
                launchCount: 2,
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('ActivitiesPage renders list of activities',
          (WidgetTester tester) async {
        await pumpPage(tester);

        expect(find.text('Focus'), findsOneWidget);
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);

        expect(find.text('Workout'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        expect(find.byType(ReorderableListView), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Add Activity'), findsOneWidget);
      });

  testWidgets('FloatingActionButton opens add dialog',
          (WidgetTester tester) async {
        await pumpPage(tester);

        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);

        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
        expect(find.byType(FloatingActionButton).first, findsOneWidget);
      });

  testWidgets('Rename activity calls onRenameActivity callback',
          (WidgetTester tester) async {
        await pumpPage(tester);

        final editButton = find.descendant(
          of: find.widgetWithText(ListTile, 'Focus'),
          matching: find.byIcon(Icons.edit_outlined),
        );
        expect(editButton, findsOneWidget);

        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Rename Activity'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Deep Work');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(renamedActivityOldName, 'Focus');
        expect(renamedActivityNewName, 'Deep Work');

        expect(find.text('Deep Work'), findsOneWidget);
        expect(find.text('Focus'), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      });

  testWidgets('Rename activity shows error if name already exists',
          (WidgetTester tester) async {
        await pumpPage(tester);

        await tester.tap(find.descendant(
          of: find.widgetWithText(ListTile, 'Focus'),
          matching: find.byIcon(Icons.edit_outlined),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Workout');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Activity name already exists.'), findsOneWidget);

        expect(renamedActivityOldName, isNull);
        expect(renamedActivityNewName, isNull);

        expect(find.widgetWithText(ListTile, 'Focus'), findsOneWidget);
        expect(find.widgetWithText(ListTile, 'Workout'), findsOneWidget);
      });
}