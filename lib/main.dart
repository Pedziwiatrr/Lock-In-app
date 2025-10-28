import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'pages/home_page.dart';
import 'utils/notification_service.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> initAdsAndConsent() async {
  final params = ConsentRequestParameters();

  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
        () async {
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadConsentForm(
              (ConsentForm consentForm) async {
            var status = await ConsentInformation.instance.getConsentStatus();
            if (status == ConsentStatus.required) {
              consentForm.show((FormError? formError) {
                MobileAds.instance.initialize();
              });
            } else {
              MobileAds.instance.initialize();
            }
          },
              (FormError? error) {
            MobileAds.instance.initialize();
          },
        );
      } else {
        MobileAds.instance.initialize();
      }
    },
        (FormError? error) {
      MobileAds.instance.initialize();
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initAdsAndConsent();

  await NotificationService().init();
  await initializeService();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

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
        'name': 'Workout 💪',
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
      notificationChannelId: 'background_service_notif_channel',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

String _getNotificationContent(int minutes) {
  String minuteString;
  if (minutes == 0) {
    minuteString = "less than 1 minute";
  } else if (minutes == 1) {
    minuteString = "1 minute";
  } else {
    minuteString = "$minutes minutes";
  }
  return 'Locked in for: $minuteString\nKeep up the good work!';
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  Timer? timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  NotificationService().showOrUpdateServiceNotification(
    title: 'Working in the background',
    content: "Don't get distracted!",
  );

  service.on('getServiceState').listen((event) {
    service.invoke('serviceState', {
      'elapsedTime': _elapsed.inSeconds,
      'isRunning': _isRunning,
    });
  });

  service.on('startTimer').listen((event) {
    if (timer?.isActive ?? false) return;

    final int previousElapsedSeconds = (event?['previousElapsed'] as int?) ?? 0;
    _elapsed = Duration(seconds: previousElapsedSeconds);
    _isRunning = true;

    NotificationService().showOrUpdateServiceNotification(
      title: 'Locked In',
      content: _getNotificationContent(_elapsed.inMinutes),
    );

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed += const Duration(seconds: 1);

      if (_elapsed.inSeconds % 60 == 0) {
        NotificationService().showOrUpdateServiceNotification(
          title: 'Locked In',
          content: _getNotificationContent(_elapsed.inMinutes),
        );
      }

      service.invoke('tick', {'elapsedTime': _elapsed.inSeconds});
    });
  });

  service.on('stopTimer').listen((event) {
    timer?.cancel();
    timer = null;
    _isRunning = false;
    service.stopSelf();
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
    await prefs.clear();
    setState(() {});
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
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,

      ),
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