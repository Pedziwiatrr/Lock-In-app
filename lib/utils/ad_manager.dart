import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdManager {
  static bool _isInitialized = false;
  RewardedAd? _rewardedAd;
  int _stoperUsageCount = 0;
  bool _lastAdShown = false;
  int _checkUsageCount = 0;
  bool _lastCheckAdShown = false;

  static Future<void> init() async {
    if (!_isInitialized) {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
  }

  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void incrementStoperUsage() {
    _stoperUsageCount++;
  }

  void incrementCheckUsage() {
    _checkUsageCount++;
  }

  bool shouldShowAd(Duration duration) {
    if (duration.inSeconds <= 5) {
      print("Ad not shown: duration too short");
      return false;
    }
    if (_stoperUsageCount < 3) {
      print("Ad not shown: grace time");
      return false;
    }
    if (_lastAdShown) {
      print("Ad not shown: ad shown last time");
      _lastAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    _lastAdShown = random;
    if (random) {
      print("Ad shown");
    } else {
      print("Ad not shown: random");
    }
    return random;
  }

  bool shouldShowCheckAd() {
    if (_checkUsageCount < 5) {
      print("Ad not shown: check usage");
      return false;
    }
    if (_lastCheckAdShown) {
      print("Ad not shown: ad shown last time");
      _lastCheckAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.25;
    _lastCheckAdShown = random;
    if (random) {
      print("Ad shown");
    } else {
      print("Ad not shown: random");
    }
    return random;
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailedToShow,
  }) {
    if (_rewardedAd == null) {
      print("Ad load fail");
      onAdFailedToShow();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => print("Ad shown"),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      },
    );
  }

  void dispose() {
    print("Disposing AdManager");
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}