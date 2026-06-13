import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/jewel_game_mode.dart';
import 'package:jewelmatch/services/game_settings.dart';
import 'package:jewelmatch/utils/storage_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    await StorageHelper.erase();
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
