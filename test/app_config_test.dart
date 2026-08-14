import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/app_config.dart';

void main() {
  test('STORE_CHANNEL selects a supported store channel', () {
    const configuredChannel = String.fromEnvironment(
      'STORE_CHANNEL',
      defaultValue: 'play',
    );

    expect(AppConfig.storeChannel.name, configuredChannel);
  });

  test('INTOSS_AD_MODE selects configured test environment', () {
    const configuredMode = String.fromEnvironment(
      'INTOSS_AD_MODE',
      defaultValue: 'disabled',
    );

    expect(AppConfig.intossAdMode.name, configuredMode);
    if (AppConfig.intossAdMode == IntossAdMode.test) {
      expect(AppConfig.intossRewardedAdGroupId, 'ait-ad-test-rewarded-id');
      expect(AppConfig.intossBannerAdGroupId, 'ait-ad-test-banner-id');
    }
  });
}
