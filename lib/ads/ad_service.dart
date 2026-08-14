import 'package:flutter/foundation.dart';

enum AdPlacement { continueStage, refillItem, infiniteBanner }

enum RewardedAdState { unavailable, idle, loading, ready, showing }

enum RewardedAdResult { rewarded, dismissed, failed, unavailable }

abstract class AdService extends ChangeNotifier {
  RewardedAdState get rewardedState;

  Future<void> preloadRewarded();

  Future<RewardedAdResult> showRewarded(AdPlacement placement);

  Future<bool> initializeBanner();

  void showBanner();

  void hideBanner();
}
