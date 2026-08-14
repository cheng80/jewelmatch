import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/ads/ad_service.dart';
import 'package:stonematch/ads/fake_ad_service.dart';

void main() {
  test('테스트 광고는 사전 로드 후에만 보상 결과를 반환한다', () async {
    final service = FakeAdService();

    expect(
      await service.showRewarded(AdPlacement.continueStage),
      RewardedAdResult.unavailable,
    );
    await service.preloadRewarded();
    expect(service.rewardedState, RewardedAdState.ready);
    expect(
      await service.showRewarded(AdPlacement.continueStage),
      RewardedAdResult.rewarded,
    );
    expect(service.rewardedState, RewardedAdState.idle);
  });

  test('테스트 배너는 표시와 제거 상태를 확인할 수 있다', () async {
    final service = FakeAdService();

    expect(await service.initializeBanner(), isTrue);
    service.showBanner();
    expect(service.bannerVisible, isTrue);
    service.hideBanner();
    expect(service.bannerVisible, isFalse);
  });

  test('광고 로딩 중 화면이 닫혀도 폐기된 서비스를 갱신하지 않는다', () async {
    final service = FakeAdService();

    final loading = service.preloadRewarded();
    service.dispose();

    await loading;
    expect(service.rewardedState, RewardedAdState.loading);
  });
}
