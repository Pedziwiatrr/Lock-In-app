import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'pages/home_page.dart';
import 'utils/ad_manager.dart';
import 'dart:convert';

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

  try {
    await MobileAds.instance.initialize();
    print('[DEBUG] Mobile Ads initialized');

    bool consentAsked = prefs.getBool('consentAsked') ?? false;
    print('[DEBUG] Consent asked previously: $consentAsked');

    ConsentStatus consentStatus = await ConsentInformation.instance.getConsentStatus();
    print('[DEBUG] Initial consent status: $consentStatus');

    if (!consentAsked || consentStatus == ConsentStatus.required) {
      print('[DEBUG] Starting consent info update');
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
            () async {
          consentStatus = await ConsentInformation.instance.getConsentStatus();
          print('[DEBUG] Consent status after update: $consentStatus');

          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            print('[DEBUG] Consent form available and required, loading form');
            ConsentForm.loadConsentForm(
                  (ConsentForm consentForm) async {
                consentForm.show(
                      (FormError? error) async {
                    if (error != null) {
                      print('[DEBUG] Consent form error: ${error.message}');
                      await prefs.setBool('personalizedAdsConsent', false);
                      print('[DEBUG] Personalized ads disabled due to form error');
                    } else {
                      print('[DEBUG] Initializing consent form');
                      final status = await ConsentInformation.instance.getConsentStatus();
                      final canRequest = await ConsentInformation.instance.canRequestAds();
                      bool personalizedAds = status == ConsentStatus.obtained && canRequest;

                      if (personalizedAds) {
                        final requestConfig = await MobileAds.instance.getRequestConfiguration();
                        personalizedAds = requestConfig.tagForChildDirectedTreatment == null &&
                            requestConfig.tagForUnderAgeOfConsent == null &&
                            requestConfig.maxAdContentRating == null;
                      }

                      await prefs.setBool('personalizedAdsConsent', personalizedAds);
                      print('[DEBUG] Consent initialized: personalizedAdsConsent=$personalizedAds');
                      print('[DEBUG] Consent status after form: $status, Can request ads: $canRequest');
                    }
                    await prefs.setBool('consentAsked', true);
                    await AdManager.initialize();
                  },
                );
              },
                  (FormError error) async {
                print('[DEBUG] Load consent form error: ${error.message}');
                await prefs.setBool('personalizedAdsConsent', false);
                await prefs.setBool('consentAsked', true);
                print('[DEBUG] Personalized ads disabled due to load error');
                await AdManager.initialize();
              },
            );
          } else {
            print('[DEBUG] Consent form not available or not required');
            bool personalizedAds = consentStatus == ConsentStatus.obtained;
            if (personalizedAds) {
              final requestConfig = await MobileAds.instance.getRequestConfiguration();
              personalizedAds = requestConfig.tagForChildDirectedTreatment == null &&
                  requestConfig.tagForUnderAgeOfConsent == null &&
                  requestConfig.maxAdContentRating == null;
            }
            await prefs.setBool('personalizedAdsConsent', personalizedAds);
            await prefs.setBool('consentAsked', true);
            print('[DEBUG] Personalized ads set to: $personalizedAds');
            await AdManager.initialize();
          }
        },
            (FormError error) async {
          print('[DEBUG] Consent info update error: ${error.message}');
          await prefs.setBool('personalizedAdsConsent', false);
          await prefs.setBool('consentAsked', true);
          print('[DEBUG] Personalized ads disabled due to update error');
          await AdManager.initialize();
        },
      );
    } else {
      print('[DEBUG] Skipping consent flow, using stored consent');
      bool personalizedAds = prefs.getBool('personalizedAdsConsent') ?? false;
      print('[DEBUG] Using stored personalizedAdsConsent=$personalizedAds');
      await AdManager.initialize();
    }
  } catch (e) {
    print('[DEBUG] AdMob or UMP init error: $e');
    await prefs.setBool('personalizedAdsConsent', false);
    await prefs.setBool('consentAsked', true);
    print('[DEBUG] Personalized ads disabled due to init error');
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