import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';
  static const int maxFailedLoadAttempts = 3;
  RewardedAd? _rewardedAd;
  int _numRewardedLoadAttempts = 0;
  bool _wasAdShownLastTime = false;
  int _stoperUsageCount = 0;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  Future<void> loadRewardedAd() async {
    if (_numRewardedLoadAttempts >= maxFailedLoadAttempts) {
      print("Max ad load attempts reached");
      return;
    }

    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
          print("Rewarded ad loaded");
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _numRewardedLoadAttempts++;
          print("Failed to load rewarded ad: $error");
          loadRewardedAd();
        },
      ),
    );
  }

  bool shouldShowAd(Duration duration) {
    print("shouldShowAd called with duration: ${duration.inSeconds} seconds");
    if (duration.inSeconds <= 5) {
      print("Duration <= 5 seconds, no ad shown");
      return false;
    }

    if (_stoperUsageCount < 3) {
      print("Stoper usage count: $_stoperUsageCount");
      _stoperUsageCount++;
      return false;
    }

    if (_wasAdShownLastTime) {
      print("Ad was shown last time, skipping");
      _wasAdShownLastTime = false;
      return false;
    }

    final random = DateTime.now().millisecond % 2 == 0;
    print("Random result: $random");
    if (random) {
      _wasAdShownLastTime = true;
    }
    return random;
  }

  Future<void> showRewardedAd({
    required Function onUserEarnedReward,
    required Function onAdDismissed,
    required Function onAdFailedToShow,
  }) async {
    print("Attempting to show rewarded ad");
    if (_rewardedAd == null) {
      print("No ad loaded, trying to load one");
      await loadRewardedAd();
      if (_rewardedAd == null) {
        print("Ad still not loaded, calling onAdFailedToShow");
        onAdFailedToShow();
        return;
      }
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print("Rewarded ad dismissed");
        ad.dispose();
        _rewardedAd = null;
        onAdDismissed();
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print("Failed to show rewarded ad: $error");
        ad.dispose();
        _rewardedAd = null;
        onAdFailedToShow();
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print("User earned reward: ${reward.amount} ${reward.type}");
        onUserEarnedReward();
      },
    );
  }

  void incrementStoperUsage() {
    _stoperUsageCount++;
    print("Incremented stoper usage count: $_stoperUsageCount");
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    print("AdManager disposed");
  }
}