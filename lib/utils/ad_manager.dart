import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;

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

  Future<void> initialize() async {
    await _initPrefs();
    loadRewardedAd();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _stoperUsageCount = _prefs!.getInt('stoperUsageCount') ?? 0;
    _checkUsageCount = _prefs!.getInt('checkUsageCount') ?? 0;
    _goalAddCount = _prefs!.getInt('goalAddCount') ?? 0;
    _activityChangeCount = _prefs!.getInt('activityChangeCount') ?? 0;
  }

  Future<void> _logAdRequestInfo(String adType) async {
    final status = await ConsentInformation.instance.getConsentStatus();
    print('[DEBUG] [AD] Requesting $adType. Current UMP Consent Status: $status. The SDK will automatically handle personalization.');
  }

  void loadRewardedAd() {
    _logAdRequestInfo("rewarded ad");
    RewardedAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('[DEBUG] [AD] Rewarded ad loaded.');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('[DEBUG] [AD] Rewarded ad loading error: $error');
          _rewardedAd = null;
          Future.delayed(const Duration(seconds: 30), loadRewardedAd);
        },
      ),
    );
  }

  void loadBannerAd({required Function(bool) onAdLoaded}) {
    _logAdRequestInfo("banner ad");
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('[DEBUG] [AD] Banner ad loaded.');
          _isAdLoaded = true;
          onAdLoaded(true);
        },
        onAdFailedToLoad: (ad, error) {
          print('[DEBUG] [AD] Banner ad loading error: $error');
          ad.dispose();
          _isAdLoaded = false;
          onAdLoaded(false);
          Future.delayed(const Duration(seconds: 30), () => loadBannerAd(onAdLoaded: onAdLoaded));
        },
        onAdOpened: (ad) => print('[DEBUG] [AD] Banner ad opened'),
        onAdClosed: (ad) => print('[DEBUG] [AD] Banner ad closed'),
      ),
    );
    _bannerAd!.load();
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
      print('[DEBUG] [AD] Ad not shown: duration too short');
      return false;
    }
    if (_stoperUsageCount < 3) {
      print('[DEBUG] [AD] Ad not shown: grace time');
      return false;
    }
    if (_lastAdShown) {
      print('[DEBUG] [AD] Ad not shown: ad shown last time');
      _lastAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    _lastAdShown = random;
    if (random) {
      print('[DEBUG] [AD] Ad shown');
    } else {
      print('[DEBUG] [AD] Ad not shown: random');
    }
    return random;
  }

  bool shouldShowCheckAd() {
    if (_checkUsageCount < 5) {
      print('[DEBUG] [AD] Ad not shown: check usage');
      return false;
    }
    if (_lastCheckAdShown) {
      print('[DEBUG] [AD] Ad not shown: ad shown last time');
      _lastCheckAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.25;
    _lastCheckAdShown = random;
    if (random) {
      print('[DEBUG] [AD] Ad shown');
    } else {
      print('[DEBUG] [AD] Ad not shown: random');
    }
    return random;
  }

  bool shouldShowGoalAd() {
    if (_goalAddCount <= 1) {
      print('[DEBUG] [AD] Ad not shown: first goal');
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    if (random) {
      print('[DEBUG] [AD] Ad shown for goal add');
    } else {
      print('[DEBUG] [AD] Ad not shown for goal add: random');
    }
    return random;
  }

  bool shouldShowActivityChangeAd() {
    if (_activityChangeCount <= 2) {
      print('[DEBUG] [AD] Ad not shown: first two activity changes');
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    if (random) {
      print('[DEBUG] [AD] Ad shown for activity change');
    } else {
      print('[DEBUG] [AD] Ad not shown for activity change: random');
    }
    return random;
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailedToShow,
  }) {
    print('[DEBUG] [AD] Attempting to show rewarded ad.');
    if (_rewardedAd == null) {
      print('[DEBUG] [AD] Rewarded ad is not ready to be shown.');
      onAdFailedToShow();
      loadRewardedAd();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        print('[DEBUG] [AD] Rewarded ad shown.');
      },
      onAdDismissedFullScreenContent: (ad) {
        print('[DEBUG] [AD] Rewarded ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('[DEBUG] [AD] Rewarded ad failed to show, error=$error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print('[DEBUG] [AD] User earned reward, amount=${reward.amount}, type=${reward.type}');
        onUserEarnedReward();
      },
    );
    _rewardedAd = null;
  }

  Future<void> dispose() async {
    print('[DEBUG] [AD] Disposing AdManager');
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