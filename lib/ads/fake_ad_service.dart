import 'dart:async';

import 'ad_service.dart';

class FakeAdService extends AdService {
  FakeAdService({this.nextResult = RewardedAdResult.rewarded});

  RewardedAdResult nextResult;
  RewardedAdState _state = RewardedAdState.idle;
  bool bannerVisible = false;
  bool _disposed = false;

  @override
  RewardedAdState get rewardedState => _state;

  @override
  Future<void> preloadRewarded() async {
    if (_state == RewardedAdState.loading ||
        _state == RewardedAdState.ready ||
        _state == RewardedAdState.showing) {
      return;
    }
    _state = RewardedAdState.loading;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_disposed) return;
    _state = RewardedAdState.ready;
    notifyListeners();
  }

  @override
  Future<RewardedAdResult> showRewarded(AdPlacement placement) async {
    if (_state != RewardedAdState.ready) {
      return RewardedAdResult.unavailable;
    }
    _state = RewardedAdState.showing;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_disposed) return RewardedAdResult.unavailable;
    final result = nextResult;
    _state = RewardedAdState.idle;
    notifyListeners();
    return result;
  }

  @override
  Future<bool> initializeBanner() async => true;

  @override
  void showBanner() {
    if (_disposed || bannerVisible) return;
    bannerVisible = true;
    _notifyBannerChanged();
  }

  @override
  void hideBanner() {
    if (_disposed || !bannerVisible) return;
    bannerVisible = false;
    _notifyBannerChanged();
  }

  void _notifyBannerChanged() {
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
