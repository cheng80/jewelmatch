import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';

void main() {
  test('MatchBoardGame simple / timed', () {
    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final progression = MatchBoardGame(gameMode: JewelGameMode.progression);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    expect(simple.isTimedMode, false);
    expect(progression.isProgressionMode, true);
    expect(progression.isTimedMode, false);
    expect(timed.isTimedMode, true);
    expect(JewelGameMode.fromQuery('progression'), JewelGameMode.progression);
    expect(MatchBoardGame.rows, 8);
    expect(MatchBoardGame.cols, 8);
  });
}
