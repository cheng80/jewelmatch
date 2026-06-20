part of 'match_board_game.dart';

extension MatchBoardGameDebugVfx on MatchBoardGame {
  /// Browser QA hook for previewing every high-impact special VFX path.
  void _debugTriggerSpecialEffectsImpl() {
    if (board.tileSize <= 0) return;

    final centerRow = MatchBoardGame.rows ~/ 2;
    final centerCol = MatchBoardGame.cols ~/ 2;
    final effects = <_DebugSpecialEffect>[
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: -3,
        colOffset: 0,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: -3,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 2,
        colOffset: 0,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: 2,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.bomb,
        rowOffset: -1,
        colOffset: -1,
        colorIndex: 0,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.star,
        rowOffset: -1,
        colOffset: 0,
        colorIndex: 1,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.hyper,
        rowOffset: 0,
        colOffset: -1,
        colorIndex: 2,
      ),
      const _DebugSpecialEffect(
        kind: GemKind.supernova,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 3,
      ),
    ];

    for (final effect in effects) {
      final row = (centerRow + effect.rowOffset).clamp(
        0,
        MatchBoardGame.rows - 1,
      );
      final col = (centerCol + effect.colOffset).clamp(
        0,
        MatchBoardGame.cols - 1,
      );
      _specialEffectPool.spawn(
        effectKind: effect.kind,
        origin: _cellCenter(row, col),
        affectedCenters: _debugAffectedCenters(effect.kind, row, col),
        tileSize: board.tileSize,
        baseColor: MatchBoardLogic.palette[effect.colorIndex],
      );
    }
  }

  List<Vector2> _debugAffectedCenters(GemKind kind, int row, int col) {
    final cells = <Vector2>[];

    void addCell(int r, int c) {
      if (board.isInside(r, c)) {
        cells.add(_cellCenter(r, c));
      }
    }

    switch (kind) {
      case GemKind.bomb:
        for (var r = row - 1; r <= row + 1; r++) {
          for (var c = col - 1; c <= col + 1; c++) {
            addCell(r, c);
          }
        }
        break;
      case GemKind.star:
        for (var c = 0; c < MatchBoardGame.cols; c++) {
          addCell(row, c);
        }
        for (var r = 0; r < MatchBoardGame.rows; r++) {
          addCell(r, col);
        }
        break;
      case GemKind.hyper:
        for (var r = row - 2; r <= row + 2; r++) {
          for (var c = col - 2; c <= col + 2; c++) {
            if ((r - row).abs() + (c - col).abs() <= 2) {
              addCell(r, c);
            }
          }
        }
        break;
      case GemKind.supernova:
        for (var r = 0; r < MatchBoardGame.rows; r++) {
          for (var c = 0; c < MatchBoardGame.cols; c++) {
            addCell(r, c);
          }
        }
        break;
      case GemKind.row:
        for (var c = 0; c < MatchBoardGame.cols; c++) {
          addCell(row, c);
        }
        break;
      case GemKind.col:
        for (var r = 0; r < MatchBoardGame.rows; r++) {
          addCell(r, col);
        }
        break;
      case GemKind.normal:
        break;
    }

    return cells;
  }
}

class _DebugSpecialEffect {
  const _DebugSpecialEffect({
    required this.kind,
    required this.rowOffset,
    required this.colOffset,
    required this.colorIndex,
  });

  final GemKind kind;
  final int rowOffset;
  final int colOffset;
  final int colorIndex;
}
