import 'ad_service.dart';

class UnsupportedAdService extends AdService {
  @override
  RewardedAdState get rewardedState => RewardedAdState.unavailable;

  @override
  Future<void> preloadRewarded() async {}

  @override
  Future<RewardedAdResult> showRewarded(AdPlacement placement) async =>
      RewardedAdResult.unavailable;

  @override
  Future<bool> initializeBanner() async => false;

  @override
  void showBanner() {}

  @override
  void hideBanner() {}
}
