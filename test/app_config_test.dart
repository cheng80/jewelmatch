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
}
