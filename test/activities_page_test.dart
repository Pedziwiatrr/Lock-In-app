import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockin/models/activity.dart';
import 'package:lockin/pages/activities_page.dart';
import 'package:lockin/utils/ad_manager.dart';
import 'mock_ad_manager.dart';

void main() {
  final realAdManager = AdManager.instance;
  late MockAdManager mockAdManager;

  setUp(() {
    mockAdManager = MockAdManager();
    AdManager.instance = mockAdManager;
  });

  tearDown(() {
    AdManager.instance = realAdManager;
  });

  Future<void> pumpActivitiesPage(WidgetTester tester, {
    required List<Activity> activities,
    VoidCallback? onUpdate,
    int launchCount = 2,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ActivitiesPage(
          activities: activities,
          onUpdate: onUpdate ?? () {},
          launchCount: launchCount,
        ),
      ),
    ));
  }

  testWidgets('ActivitiesPage shows initial activities and banner ad', (tester) async {
    final activities = [
      TimedActivity(name: 'Reading'),
      CheckableActivity(name: 'Workout'),
    ];

    mockAdManager.isBannerAdLoaded = true;
    mockAdManager.bannerAdWidget = const SizedBox(width: 320, height: 50, child: Text('Mock Ad'));

    await pumpActivitiesPage(tester, activities: activities, launchCount: 2);
    await tester.pump();

    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Mock Ad'), findsOneWidget);
  });

  testWidgets('Can add a new timed activity (default)', (tester) async {
    final activities = <Activity>[];
    var updatedCalled = false;

    await pumpActivitiesPage(
      tester,
      activities: activities,
      onUpdate: () => updatedCalled = true,
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Coding');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Coding'), findsOneWidget);
    expect(find.text('Timed'), findsOneWidget);
    expect(activities.length, 1);
    expect(activities.first, isA<TimedActivity>());
    expect(updatedCalled, isTrue);
  });

  testWidgets('Can add a new checkable activity', (tester) async {
    final activities = <Activity>[];
    var updatedCalled = false;

    await pumpActivitiesPage(
        tester,
        activities: activities,
        onUpdate: () => updatedCalled = true
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final checkableRadio = find.byWidgetPredicate(
          (widget) => widget is Radio<bool> && widget.value == false,
    );
    await tester.tap(checkableRadio);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Yoga');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Checkable'), findsOneWidget);
    expect(activities.length, 1);
    expect(activities.first, isA<CheckableActivity>());
    expect(updatedCalled, isTrue);
  });

  testWidgets('Can rename an activity', (tester) async {
    final activities = [TimedActivity(name: 'Old Name')];
    var updatedCalled = false;
    mockAdManager.showNextActivityChangeAd = false;

    await pumpActivitiesPage(
      tester,
      activities: activities,
      onUpdate: () => updatedCalled = true,
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Old Name'), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
    expect(activities.first.name, 'New Name');
    expect(updatedCalled, isTrue);
  });

  testWidgets('Can delete an activity', (tester) async {
    final activities = [TimedActivity(name: 'To Delete')];
    var updatedCalled = false;
    mockAdManager.showNextActivityChangeAd = false;

    await pumpActivitiesPage(
      tester,
      activities: activities,
      onUpdate: () => updatedCalled = true,
    );

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('To Delete'), findsNothing);
    expect(activities.isEmpty, isTrue);
    expect(updatedCalled, isTrue);
  });

  testWidgets('Shows SnackBar when adding a duplicate activity name', (tester) async {
    final activities = [TimedActivity(name: 'Existing')];

    await pumpActivitiesPage(tester, activities: activities);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Existing');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Activity name already exists.'), findsOneWidget);
    expect(activities.length, 1);
  });
}