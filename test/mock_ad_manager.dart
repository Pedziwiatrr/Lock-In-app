import 'package:flutter/material.dart';
import 'package:lockin/utils/ad_manager.dart';

class MockAdManager implements AdManager {
  bool isBannerAdLoaded = false;
  Widget? bannerAdWidget;
  bool showNextActivityChangeAd = false;
  int activityChangeCount = 0;

  @override
  void loadBannerAd({Function(bool)? onAdLoaded}) {
    if (onAdLoaded != null) {
      onAdLoaded(isBannerAdLoaded);
    }
  }

  @override
  Widget? getBannerAdWidget() {
    return bannerAdWidget;
  }

  @override
  Future<void> incrementActivityChangeCount() async {
    activityChangeCount++;
  }

  @override
  bool shouldShowActivityChangeAd() {
    return showNextActivityChangeAd;
  }

  @override
  void showRewardedAd({
    required Function onUserEarnedReward,
    Function? onAdDismissed,
    Function? onAdFailedToShow,
  }) {
    onUserEarnedReward();
  }

  // --- Puste implementacje wymagane przez interfejs ---
  @override
  Future<void> initialize() async {}

  @override
  Future<void> incrementGoalAddCount() async {}

  @override
  bool shouldShowGoalAd() => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> incrementCheckUsage() async {}

  @override
  Future<void> incrementStoperUsage() async {}

  @override
  void loadRewardedAd() {}

  @override
  bool shouldShowCheckAd() => false;

  @override
  bool shouldShowAd(Duration duration) => false;
}