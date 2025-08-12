import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'pages/home_page.dart';
import 'utils/notification_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
  await NotificationService().init();
  await initializeService();

  final prefs = await SharedPreferences.getInstance();
  int launchCount = (prefs.getInt('launchCount') ?? 0) + 1;
  await prefs.setInt('launchCount', launchCount);

  if (!(prefs.containsKey('activities') &&
      prefs.getString('activities') != null &&
      prefs.getString('activities')!.isNotEmpty)) {
    final defaultActivities = [
      {'type': 'TimedActivity', 'name': 'Focus', 'totalTime': 0},
      {
        'type': 'CheckableActivity',
        'name': 'Drink water',
        'completionCount': 0
      },
    ];
    await prefs.setString('activities', jsonEncode(defaultActivities));
  }

  runApp(LockInTrackerApp(launchCount: launchCount));
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'timer_channel',
      initialNotificationTitle: 'Locked In',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final notificationService = NotificationService();
  Timer? timer;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    timer?.cancel();
    notificationService.cancelTimerNotification();
    service.stopSelf();
  });

  Duration elapsed = Duration.zero;
  timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    elapsed += const Duration(seconds: 1);
    String formattedDuration =
        '${elapsed.inMinutes.remainder(60).toString().padLeft(2, '0')}:${elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}';

    notificationService.showTimerNotification(formattedDuration);

    service.invoke('update', {'elapsed': elapsed.inSeconds});
  });
}

class LockInTrackerApp extends StatefulWidget {
  final int launchCount;
  const LockInTrackerApp({super.key, required this.launchCount});

  @override
  State<LockInTrackerApp> createState() => _LockInTrackerAppState();
}

class _LockInTrackerAppState extends State<LockInTrackerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _saveTheme(isDark);
  }

  Future<void> _resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activities');
    await prefs.remove('activityLogs');
    await prefs.remove('goals');
    await prefs.remove('launchCount');
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'LockIn Tracker',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: HomePage(
        onThemeChanged: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
        onResetData: _resetData,
        launchCount: widget.launchCount,
      ),
    );
  }
}