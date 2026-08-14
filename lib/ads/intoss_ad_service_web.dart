import 'dart:js_interop';

import '../app_config.dart';
import 'ad_service.dart';

AdService createIntossAdService() => IntossAdService();

class IntossAdService extends AdService {
  RewardedAdState _state = RewardedAdState.idle;
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
    try {
      if (!_isRewardedSupported()) {
        _setState(RewardedAdState.unavailable);
        return;
      }
      _setState(RewardedAdState.loading);
      final result = (await _loadRewarded(
        AppConfig.intossRewardedAdGroupId.toJS,
      ).toDart).toDart;
      if (_disposed) return;
      _setState(
        result == 'loaded' ? RewardedAdState.ready : RewardedAdState.idle,
      );
    } catch (_) {
      _setState(RewardedAdState.idle);
    }
  }

  @override
  Future<RewardedAdResult> showRewarded(AdPlacement placement) async {
    if (_state != RewardedAdState.ready) {
      return RewardedAdResult.unavailable;
    }
    _setState(RewardedAdState.showing);
    try {
      final result = (await _showRewarded(
        AppConfig.intossRewardedAdGroupId.toJS,
      ).toDart).toDart;
      if (_disposed) return RewardedAdResult.unavailable;
      _setState(RewardedAdState.idle);
      return switch (result) {
        'rewarded' => RewardedAdResult.rewarded,
        'dismissed' => RewardedAdResult.dismissed,
        _ => RewardedAdResult.failed,
      };
    } catch (_) {
      _setState(RewardedAdState.idle);
      return RewardedAdResult.failed;
    }
  }

  @override
  Future<bool> initializeBanner() async {
    try {
      return (await _initializeBanner().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  void showBanner() {
    if (_disposed) return;
    try {
      _showBanner(AppConfig.intossBannerAdGroupId.toJS);
    } catch (_) {}
  }

  @override
  void hideBanner() {
    if (_disposed) return;
    try {
      _hideBanner();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      _disposeBridge();
    } catch (_) {}
    super.dispose();
  }

  void _setState(RewardedAdState state) {
    if (_disposed || _state == state) return;
    _state = state;
    notifyListeners();
  }
}

@JS('stoneMatchAds.isRewardedSupported')
external bool _isRewardedSupported();

@JS('stoneMatchAds.loadRewarded')
external JSPromise<JSString> _loadRewarded(JSString adGroupId);

@JS('stoneMatchAds.showRewarded')
external JSPromise<JSString> _showRewarded(JSString adGroupId);

@JS('stoneMatchAds.initializeBanner')
external JSPromise<JSBoolean> _initializeBanner();

@JS('stoneMatchAds.showBanner')
external void _showBanner(JSString adGroupId);

@JS('stoneMatchAds.hideBanner')
external void _hideBanner();

@JS('stoneMatchAds.dispose')
external void _disposeBridge();
