import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/home_page.dart';
import 'utils/ad_manager.dart';
import 'dart:convert';

void main() async {
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

  bool consentAsked = prefs.getBool('consentAsked') ?? false;

  try {
    await MobileAds.instance.initialize();
    print('[DEBUG] Mobile Ads initialized');

    if (!consentAsked) {
      await prefs.setBool('personalizedAdsConsent', false);
      await prefs.setBool('consentAsked', true);
      print('[DEBUG] Consent initialized: personalizedAdsConsent=false');
      await AdManager.initialize();
    } else {
      bool personalizedAds = prefs.getBool('personalizedAdsConsent') ?? false;
      print('[DEBUG] Loaded consent: personalizedAdsConsent=$personalizedAds');
      await AdManager.initialize();
    }
  } catch (e) {
    print('[DEBUG] AdMob init error: $e');
    await AdManager.initialize();
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
  }

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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