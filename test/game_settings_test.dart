import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/vm/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
  });

  test('FPS panel is off by default and persists the selected value', () {
    expect(GameSettings.showFps, isFalse);

    GameSettings.showFps = true;

    expect(GameSettings.showFps, isTrue);
  });

  test('settings notifier updates the FPS panel state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).showFps, isFalse);

    container.read(settingsProvider.notifier).setShowFps(true);

    expect(container.read(settingsProvider).showFps, isTrue);
    expect(GameSettings.showFps, isTrue);
  });

  test('progression best record prefers level, then score', () {
    GameSettings.saveBestProgressionRecordIfBetter(level: 3, score: 23200);

    expect(GameSettings.getBestMatchProgressionLevel(), 3);
    expect(GameSettings.getBestMatchScore(JewelGameMode.progression), 23200);

    GameSettings.saveBestProgressionRecordIfBetter(level: 3, score: 20000);
    expect(GameSettings.getBestMatchProgressionLevel(), 3);
    expect(GameSettings.getBestMatchScore(JewelGameMode.progression), 23200);

    GameSettings.saveBestProgressionRecordIfBetter(level: 3, score: 24000);
    expect(GameSettings.getBestMatchProgressionLevel(), 3);
    expect(GameSettings.getBestMatchScore(JewelGameMode.progression), 24000);

    GameSettings.saveBestProgressionRecordIfBetter(level: 4, score: 21000);
    expect(GameSettings.getBestMatchProgressionLevel(), 4);
    expect(GameSettings.getBestMatchScore(JewelGameMode.progression), 21000);
  });
}
