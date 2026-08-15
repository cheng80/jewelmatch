import '../app_config.dart';
import 'intoss_leaderboard_stub.dart'
    if (dart.library.js_interop) 'intoss_leaderboard_web.dart'
    as bridge;
import 'ranking_service.dart';

class IntossLeaderboardService {
  IntossLeaderboardService._();

  static bool shouldSubmit(StoreChannel channel, RankingMode mode) =>
      channel == StoreChannel.intoss && mode == RankingMode.level;

  static Future<bool> submitLevelScore(int score) async {
    if (!shouldSubmit(AppConfig.storeChannel, RankingMode.level) ||
        score <= 0) {
      return false;
    }
    return bridge.submitLevelScore(score);
  }

  static Future<bool> openLevelLeaderboard() async {
    if (AppConfig.storeChannel != StoreChannel.intoss) return false;
    return bridge.openLevelLeaderboard();
  }
}
