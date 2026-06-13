import 'match_board_game.dart';

export 'match_board_qa_bridge_stub.dart'
    if (dart.library.js_interop) 'match_board_qa_bridge_web.dart';

typedef SimulationHintMove = Map<String, Object?>;

extension MatchBoardSimulationHints on MatchBoardGame {
  SimulationHintMove? readSimulationHintMove() {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return null;
    }
    if (board.hintCellA == null || board.hintCellB == null) {
      if (!board.showHint()) return null;
    }

    final a = board.hintCellA;
    final b = board.hintCellB;
    if (a == null || b == null) return null;

    final aTopLeft = board.cellToPixel(a.x, a.y);
    final bTopLeft = board.cellToPixel(b.x, b.y);
    final halfTile = board.tileSize / 2;

    return {
      'a': {
        'row': a.x,
        'col': a.y,
        'x': aTopLeft.dx + halfTile,
        'y': aTopLeft.dy + halfTile,
      },
      'b': {
        'row': b.x,
        'col': b.y,
        'x': bTopLeft.dx + halfTile,
        'y': bTopLeft.dy + halfTile,
      },
      'tileSize': board.tileSize,
      'state': board.state,
    };
  }
}
