import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/app_config.dart';
import 'package:stonematch/services/intoss_leaderboard_service.dart';
import 'package:stonematch/services/ranking_service.dart';

void main() {
  test('Apps in Toss submits only level mode to its leaderboard', () {
    expect(
      IntossLeaderboardService.shouldSubmit(
        StoreChannel.intoss,
        RankingMode.level,
      ),
      isTrue,
    );
    expect(
      IntossLeaderboardService.shouldSubmit(
        StoreChannel.intoss,
        RankingMode.time,
      ),
      isFalse,
    );
    for (final channel in StoreChannel.values.where(
      (channel) => channel != StoreChannel.intoss,
    )) {
      expect(
        IntossLeaderboardService.shouldSubmit(channel, RankingMode.level),
        isFalse,
      );
    }
  });
}
