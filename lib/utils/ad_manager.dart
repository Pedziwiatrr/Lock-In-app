import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AdUnitIds {
  static const String rewardedInterstitialAndroid = 'ca-app-pub-3191540141651884/9594852827';
  static const String rewardedAndroid = 'ca-app-pub-3191540141651884/4684314330';
  static const String rewardedIos = 'ca-app-pub-3940256099942544/1712485313';
  static const String bannerAndroid = 'ca-app-pub-3191540141651884/8431987657';
  static const String bannerIos = 'ca-app-pub-3940256099942544/2934735716';
}

class AdManager {
  static AdManager _instance = AdManager._internal();
  static AdManager get instance => _instance;

  static set instance(AdManager value) => _instance = value;

  static const int _maxRetries = 3;

  RewardedAd? _rewardedAd;
  int _rewardedAdRetryAttempt = 0;

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _bannerAdRetryAttempt = 0;

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
    if (!kReleaseMode) {
      final status = await ConsentInformation.instance.getConsentStatus();
      //print('[AD] Requesting $adType. Current UMP Consent Status: $status.');
    }
  }

  void loadRewardedAd() {
    _logAdRequestInfo("rewarded ad");
    RewardedAd.load(
      adUnitId: Platform.isAndroid
          ? _AdUnitIds.rewardedAndroid
          : _AdUnitIds.rewardedIos,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!kReleaseMode) print('[AD] Rewarded ad loaded successfully.');
          _rewardedAd = ad;
          _rewardedAdRetryAttempt = 0;
        },
        onAdFailedToLoad: (error) {
          _rewardedAdRetryAttempt++;
          if (_rewardedAdRetryAttempt > _maxRetries) {
            if (!kReleaseMode) print('[AD] Rewarded ad failed to load after $_maxRetries attempts. Stopping retries. Error: $error');
            return;
          }
          final delay = Duration(seconds: 30 * pow(2, _rewardedAdRetryAttempt - 1).toInt());
          if (!kReleaseMode) print('[AD] Rewarded ad loading error. Attempt $_rewardedAdRetryAttempt. Retrying in ${delay.inSeconds} seconds. Error: $error');
          _rewardedAd = null;
          Future.delayed(delay, loadRewardedAd);
        },
      ),
    );
  }

  void loadBannerAd({required Function(bool) onAdLoaded}) {
    _logAdRequestInfo("banner ad");
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? _AdUnitIds.bannerAndroid
          : _AdUnitIds.bannerIos,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!kReleaseMode) print('[AD] Banner ad loaded successfully.');
          _isAdLoaded = true;
          _bannerAdRetryAttempt = 0;
          onAdLoaded(true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          onAdLoaded(false);

          _bannerAdRetryAttempt++;
          if (_bannerAdRetryAttempt > _maxRetries) {
            if (!kReleaseMode) print('[AD] Banner ad failed to load after $_maxRetries attempts. Stopping retries. Error: $error');
            return;
          }
          final delay = Duration(seconds: 30 * pow(2, _bannerAdRetryAttempt - 1).toInt());
          if (!kReleaseMode) print('[AD] Banner ad loading error. Attempt $_bannerAdRetryAttempt. Retrying in ${delay.inSeconds} seconds. Error: $error');
          Future.delayed(delay, () => loadBannerAd(onAdLoaded: onAdLoaded));
        },
        onAdOpened: (ad) {
          if (!kReleaseMode) print('[AD] Banner ad opened');
        },
        onAdClosed: (ad) {
          if (!kReleaseMode) print('[AD] Banner ad closed');
        },
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
    if (duration.inSeconds <= 10) {
      if (!kReleaseMode) print('[AD] Ad not shown: duration too short');
      return false;
    }
    if (_stoperUsageCount < 5) {
      if (!kReleaseMode) print('[AD] Ad not shown: grace time');
      return false;
    }
    if (_lastAdShown) {
      if (!kReleaseMode) print('[AD] Ad not shown: ad shown last time');
      _lastAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.4;
    _lastAdShown = random;
    if (!kReleaseMode) print('[AD] Ad decision: ${random ? "show" : "skip (random)"}');
    return random;
  }

  bool shouldShowCheckAd() {
    if (_checkUsageCount < 5) {
      if (!kReleaseMode) print('[AD] Ad not shown: check usage');
      return false;
    }
    if (_lastCheckAdShown) {
      if (!kReleaseMode) print('[AD] Ad not shown: ad shown last time');
      _lastCheckAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.2;
    _lastCheckAdShown = random;
    if (!kReleaseMode) print('[AD] Ad check decision: ${random ? "show" : "skip (random)"}');
    return random;
  }

  bool shouldShowGoalAd() {
    if (_goalAddCount <= 2) {
      if (!kReleaseMode) print('[AD] Ad not shown: first goals');
      return false;
    }
    final random = Random().nextDouble() < 0.4;
    if (!kReleaseMode) print('[AD] Ad goal decision: ${random ? "show" : "skip (random)"}');
    return random;
  }

  bool shouldShowActivityChangeAd() {
    if (_activityChangeCount <= 3) {
      if (!kReleaseMode) print('[AD] Ad not shown: first two activity changes');
      return false;
    }
    final random = Random().nextDouble() < 0.4;
    if (!kReleaseMode) print('[AD] Ad activity change decision: ${random ? "show" : "skip (random)"}');
    return random;
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailedToShow,
  }) {
    if (_rewardedAd == null) {
      if (!kReleaseMode) print('[AD] Rewarded ad is not ready. Attempting to load a new one.');
      onAdFailedToShow();
      loadRewardedAd();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (!kReleaseMode) print('[AD] Rewarded ad shown.');
      },
      onAdDismissedFullScreenContent: (ad) {
        if (!kReleaseMode) print('[AD] Rewarded ad dismissed.');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (!kReleaseMode) print('[AD] Rewarded ad failed to show, error=$error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        if (!kReleaseMode) print('[AD] User earned reward, amount=${reward.amount}, type=${reward.type}');
        onUserEarnedReward();
      },
    );
    _rewardedAd = null;
  }

  Future<void> dispose() async {
    if (!kReleaseMode) print('[AD] Disposing AdManager');
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