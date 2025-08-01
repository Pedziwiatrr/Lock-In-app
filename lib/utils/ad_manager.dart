import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;

  static bool _isInitialized = false;
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _stoperUsageCount = 0;
  bool _lastAdShown = false;
  int _checkUsageCount = 0;
  bool _lastCheckAdShown = false;
  int _goalAddCount = 0;
  int _activityChangeCount = 0;
  SharedPreferences? _prefs;

  AdManager._internal();

  static Future<void> init() async {
    if (!_isInitialized) {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          tagForChildDirectedTreatment: null,
          tagForUnderAgeOfConsent: null,
          maxAdContentRating: MaxAdContentRating.g,
        ),
      );
      _isInitialized = true;
    }
  }

  static Future<void> initialize() async {
    await init();
    await _instance._initPrefs();
    _instance.loadRewardedAd();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _stoperUsageCount = _prefs!.getInt('stoperUsageCount') ?? 0;
    _checkUsageCount = _prefs!.getInt('checkUsageCount') ?? 0;
    _goalAddCount = _prefs!.getInt('goalAddCount') ?? 0;
    _activityChangeCount = _prefs!.getInt('activityChangeCount') ?? 0;
  }

  Future<bool> _canRequestPersonalizedAds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool personalizedAds = prefs.getBool('personalizedAdsConsent') ?? false;
      print('[DEBUG] Personalized ads consent from SharedPreferences: $personalizedAds');
      return personalizedAds;
    } catch (e) {
      print('[DEBUG] Consent error: $e');
      return false;
    }
  }

  void loadRewardedAd() {
    _canRequestPersonalizedAds().then((canRequestPersonalizedAds) {
      print('[DEBUG] Requesting rewarded ad: personalized=$canRequestPersonalizedAds');
      RewardedAd.load(
        adUnitId: Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/5224354917'
            : 'ca-app-pub-3940256099942544/1712485313',
        request: AdRequest(
          nonPersonalizedAds: !canRequestPersonalizedAds,
        ),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            print('[DEBUG] Rewarded ad loaded: personalized=$canRequestPersonalizedAds');
            _rewardedAd = ad;
          },
          onAdFailedToLoad: (error) {
            print('[DEBUG] Rewarded ad loading error: $error');
            _rewardedAd = null;
            Future.delayed(const Duration(seconds: 5), loadRewardedAd);
          },
        ),
      );
    });
  }

  void loadBannerAd({required Function(bool) onAdLoaded}) {
    _canRequestPersonalizedAds().then((canRequestPersonalizedAds) {
      print('[DEBUG] Requesting banner ad: personalized=$canRequestPersonalizedAds');
      _bannerAd = BannerAd(
        adUnitId: Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/6300978111'
            : 'ca-app-pub-3940256099942544/2934735716',
        size: AdSize.banner,
        request: AdRequest(
          nonPersonalizedAds: !canRequestPersonalizedAds,
        ),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('[DEBUG] Banner ad loaded: personalized=$canRequestPersonalizedAds');
            _isAdLoaded = true;
            onAdLoaded(true);
          },
          onAdFailedToLoad: (ad, error) {
            print('[DEBUG] Banner ad loading error: $error');
            ad.dispose();
            _isAdLoaded = false;
            onAdLoaded(false);
            Future.delayed(const Duration(seconds: 5), () => loadBannerAd(onAdLoaded: onAdLoaded));
          },
          onAdOpened: (ad) => print('[DEBUG] Banner ad opened'),
          onAdClosed: (ad) => print('[DEBUG] Banner ad closed'),
        ),
      );
      _bannerAd!.load();
    });
  }

  Widget? getBannerAdWidget() {
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }

  Future<void> incrementStoperUsage() async {
    _stoperUsageCount++;
    await _prefs?.setInt('stoperUsageCount', _stoperUsageCount);
  }

  Future<void> incrementCheckUsage() async {
    _checkUsageCount++;
    await _prefs?.setInt('checkUsageCount', _checkUsageCount);
  }

  Future<void> incrementGoalAddCount() async {
    _goalAddCount++;
    await _prefs?.setInt('goalAddCount', _goalAddCount);
  }

  Future<void> incrementActivityChangeCount() async {
    _activityChangeCount++;
    await _prefs?.setInt('activityChangeCount', _activityChangeCount);
  }

  bool shouldShowAd(Duration duration) {
    if (duration.inSeconds <= 5) {
      print('[DEBUG] Ad not shown: duration too short');
      return false;
    }
    if (_stoperUsageCount < 3) {
      print('[DEBUG] Ad not shown: grace time');
      return false;
    }
    if (_lastAdShown) {
      print('[DEBUG] Ad not shown: ad shown last time');
      _lastAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    _lastAdShown = random;
    if (random) {
      print('[DEBUG] Ad shown');
    } else {
      print('[DEBUG] Ad not shown: random');
    }
    return random;
  }

  bool shouldShowCheckAd() {
    if (_checkUsageCount < 5) {
      print('[DEBUG] Ad not shown: check usage');
      return false;
    }
    if (_lastCheckAdShown) {
      print('[DEBUG] Ad not shown: ad shown last time');
      _lastCheckAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.25;
    _lastCheckAdShown = random;
    if (random) {
      print('[DEBUG] Ad shown');
    } else {
      print('[DEBUG] Ad not shown: random');
    }
    return random;
  }

  bool shouldShowGoalAd() {
    if (_goalAddCount <= 1) {
      print('[DEBUG] Ad not shown: first goal');
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    if (random) {
      print('[DEBUG] Ad shown for goal add');
    } else {
      print('[DEBUG] Ad not shown for goal add: random');
    }
    return random;
  }

  bool shouldShowActivityChangeAd() {
    if (_activityChangeCount <= 2) {
      print('[DEBUG] Ad not shown: first two activity changes');
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    if (random) {
      print('[DEBUG] Ad shown for activity change');
    } else {
      print('[DEBUG] Ad not shown for activity change: random');
    }
    return random;
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailedToShow,
  }) {
    _canRequestPersonalizedAds().then((canRequestPersonalizedAds) {
      print('[DEBUG] showRewardedAd: Attempting to show rewarded ad, personalized=$canRequestPersonalizedAds');
      if (_rewardedAd == null) {
        print('[DEBUG] showRewardedAd: Ad load fail, personalized=$canRequestPersonalizedAds');
        onAdFailedToShow();
        loadRewardedAd();
        return;
      }
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          print('[DEBUG] showRewardedAd: Rewarded ad shown, personalized=$canRequestPersonalizedAds');
        },
        onAdDismissedFullScreenContent: (ad) {
          print('[DEBUG] showRewardedAd: Rewarded ad dismissed, personalized=$canRequestPersonalizedAds');
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('[DEBUG] showRewardedAd: Rewarded ad failed to show, error=$error, personalized=$canRequestPersonalizedAds');
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          onAdFailedToShow();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          print('[DEBUG] showRewardedAd: User earned reward, amount=${reward.amount}, type=${reward.type}, personalized=$canRequestPersonalizedAds');
          onUserEarnedReward();
        },
      );
    });
  }

  Future<void> dispose() async {
    print('[DEBUG] Disposing AdManager');
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    await _prefs?.setInt('stoperUsageCount', _stoperUsageCount);
    await _prefs?.setInt('checkUsageCount', _checkUsageCount);
    await _prefs?.setInt('goalAddCount', _goalAddCount);
    await _prefs?.setInt('activityChangeCount', _activityChangeCount);
  }
}