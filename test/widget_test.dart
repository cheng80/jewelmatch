import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/game/jewel_game_mode.dart';
import 'package:jewelmatch/game/match_board_game.dart';

void main() {
  test('MatchBoardGame simple / timed', () {
    final simple = MatchBoardGame(gameMode: JewelGameMode.simple);
    final timed = MatchBoardGame(gameMode: JewelGameMode.timed);
    expect(simple.isTimedMode, false);
    expect(timed.isTimedMode, true);
    expect(MatchBoardGame.rows, 8);
    expect(MatchBoardGame.cols, 8);
  });
}
