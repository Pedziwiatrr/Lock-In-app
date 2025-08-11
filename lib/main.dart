import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/home_page.dart';
import 'dart:convert';
import 'dart:async';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  print('[DEBUG] Starting LockIn Tracker App');
  WidgetsFlutterBinding.ensureInitialized();

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

  final Completer<void> consentCompleter = Completer<void>();

  print('[DEBUG] Starting consent info update');
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
        () async {
      final consentStatus = await ConsentInformation.instance.getConsentStatus();
      print('[DEBUG] Consent status after update: $consentStatus');

      if (consentStatus == ConsentStatus.required) {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          print('[DEBUG] Consent form available and required, loading form');
          ConsentForm.loadConsentForm(
                (ConsentForm consentForm) {
              consentForm.show(
                    (FormError? error) {
                  if (error != null) {
                    print('[DEBUG] Consent form error: ${error.message}');
                  }
                  consentCompleter.complete();
                },
              );
            },
                (FormError error) {
              print('[DEBUG] Load consent form error: ${error.message}');
              consentCompleter.complete();
            },
          );
        } else {
          print('[DEBUG] Consent form not available despite being required');
          consentCompleter.complete();
        }
      } else {
        print('[DEBUG] Consent form not required. Status: $consentStatus');
        consentCompleter.complete();
      }
    },
        (FormError error) {
      print('[DEBUG] Consent info update error: ${error.message}');
      consentCompleter.complete();
    },
  );

  await consentCompleter.future;

  try {
    await MobileAds.instance.initialize();
    print('[DEBUG] Mobile Ads initialized');
  } catch (e) {
    print('[DEBUG] AdMob or UMP init error: $e');
  }

  print('[DEBUG] App started with launchCount=$launchCount');
  runApp(LockInTrackerApp(launchCount: launchCount));
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