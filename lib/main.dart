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

String getNotificationContent(int minutes) {
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
  String? _activityName;
  DateTime? _startTime;
  int _baseElapsedSeconds = 0;
  int _lastNotifMinute = -1;

  NotificationService().showOrUpdateServiceNotification(
    title: 'Working in the background',
    content: "Don't get distracted!",
  );

  service.on('getServiceState').listen((event) {
    if (_isRunning && _startTime != null) {
      _elapsed = DateTime.now().difference(_startTime!) + Duration(seconds: _baseElapsedSeconds);
    }

    service.invoke('serviceState', {
      'elapsedTime': _elapsed.inSeconds,
      'isRunning': _isRunning,
      'activityName': _activityName,
    });
  });

  service.on('startTimer').listen((event) {
    if (timer?.isActive ?? false) return;

    _baseElapsedSeconds = (event?['previousElapsed'] as int?) ?? 0;
    _activityName = event?['activityName'] as String?;
    _elapsed = Duration(seconds: _baseElapsedSeconds);
    _startTime = DateTime.now();
    _isRunning = true;
    _lastNotifMinute = _elapsed.inMinutes;

    NotificationService().showOrUpdateServiceNotification(
      title: 'Locked In',
      content: getNotificationContent(_elapsed.inMinutes),
    );

    timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_startTime == null) return;

      _elapsed = DateTime.now().difference(_startTime!) + Duration(seconds: _baseElapsedSeconds);

      final currentMinute = _elapsed.inMinutes;
      if (currentMinute > _lastNotifMinute) {
        _lastNotifMinute = currentMinute;
        NotificationService().showOrUpdateServiceNotification(
          title: 'Locked In',
          content: getNotificationContent(currentMinute),
        );
      }

      service.invoke('tick', {'elapsedTime': _elapsed.inSeconds});
    });
  });

  service.on('stopTimer').listen((event) {
    timer?.cancel();
    timer = null;
    _isRunning = false;
    _activityName = null;
    _startTime = null;
    _baseElapsedSeconds = 0;
    _lastNotifMinute = -1;
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
        launchCount: widget.launchCount,
      ),
    );
  }
}