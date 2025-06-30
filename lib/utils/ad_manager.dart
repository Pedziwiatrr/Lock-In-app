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
      print("Initializing AdManager");
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
  }

  void loadRewardedAd() {
    print("Loading rewarded ad");
    RewardedAd.load(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print("Rewarded ad loaded successfully");
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          print("Failed to load rewarded ad: $error");
          _rewardedAd = null;
        },
      ),
    );
  }

  void incrementStoperUsage() {
    _stoperUsageCount++;
    print("Incremented stoper usage count: $_stoperUsageCount");
  }

  void incrementCheckUsage() {
    _checkUsageCount++;
    print("Incremented check usage count: $_checkUsageCount");
  }

  bool shouldShowAd(Duration duration) {
    print("shouldShowAd called with duration: ${duration.inSeconds} seconds");
    if (duration.inSeconds <= 5) {
      print("Duration <= 5 seconds, not showing ad");
      return false;
    }
    if (_stoperUsageCount < 3) {
      print("Stoper usage count: $_stoperUsageCount");
      return false;
    }
    if (_lastAdShown) {
      print("Ad was shown last time, not showing now");
      _lastAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.5;
    print("Random result: $random");
    _lastAdShown = random;
    return random;
  }

  bool shouldShowCheckAd() {
    print("shouldShowCheckAd called");
    if (_checkUsageCount < 5) {
      print("Check usage count: $_checkUsageCount");
      return false;
    }
    if (_lastCheckAdShown) {
      print("Ad was shown last time for check, not showing now");
      _lastCheckAdShown = false;
      return false;
    }
    final random = Random().nextDouble() < 0.25;
    print("Random result for check: $random");
    _lastCheckAdShown = random;
    return random;
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdDismissed,
    required VoidCallback onAdFailedToShow,
  }) {
    if (_rewardedAd == null) {
      print("No rewarded ad loaded");
      onAdFailedToShow();
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => print("Rewarded ad shown"),
      onAdDismissedFullScreenContent: (ad) {
        print("Rewarded ad dismissed");
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print("Failed to show rewarded ad: $error");
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print("User earned reward: ${reward.amount} ${reward.type}");
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