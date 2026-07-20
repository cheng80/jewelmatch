part of 'match_board_game.dart';

extension MatchBoardGameDebugVfx on MatchBoardGame {
  /// Android QA hook that drives the real board special-cell resolution path.
  bool triggerQaSpecialEffect(GemKind kind, {bool chain = false}) {
    if (kind == GemKind.normal ||
        !isPlaying ||
        timeUp ||
        activeTargetItem != null ||
        board.inputLocked ||
        board.introFillInProgress ||
        board.state != 'idle') {
      return false;
    }

    final useChain = chain && kind != GemKind.hyper;

    final row = MatchBoardGame.rows ~/ 2;
    final centerCol = MatchBoardGame.cols ~/ 2;
    final triggerCol = useChain ? centerCol - 3 : centerCol;
    final requestedCells = useChain
        ? <({int row, int col})>[
            (row: row, col: centerCol - 2),
            (row: row, col: centerCol - 1),
            (row: row, col: centerCol),
            (row: row, col: centerCol + 1),
          ]
        : <({int row, int col})>[(row: row, col: centerCol)];
    final cells = <({int row, int col})>[
      if (useChain) (row: row, col: triggerCol),
      ...requestedCells,
    ];
    final previous = <({BoardGem gem, GemKind kind, int color})>[];
    for (final cell in cells) {
      final gem = board.getGem(cell.row, cell.col);
      if (gem == null) return false;
      previous.add((gem: gem, kind: gem.kind, color: gem.color));
    }
    for (var index = 0; index < previous.length; index++) {
      final entry = previous[index];
      final replacementKind = useChain && index == 0 ? GemKind.row : kind;
      entry.gem
        ..kind = replacementKind
        ..color = _qaSpecialEffectColor(replacementKind);
    }
    final triggered = board.triggerSpecialCell(row, triggerCol);
    if (!triggered) {
      for (final entry in previous) {
        entry.gem
          ..kind = entry.kind
          ..color = entry.color;
      }
    }
    return triggered;
  }

  int _qaSpecialEffectColor(GemKind kind) => switch (kind) {
    GemKind.bomb => 1,
    GemKind.row || GemKind.col || GemKind.star => 2,
    GemKind.hyper => 3,
    GemKind.supernova => 4,
    GemKind.normal => 1,
  };

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
      _debugTriggerSpecialEffectAt(centerRow, centerCol, effect);
    }
  }

  /// Browser QA hook for previewing one special VFX path without overlap.
  void _debugTriggerSpecialEffectImpl(
    GemKind kind, {
    double durationScale = 1.0,
  }) {
    if (board.tileSize <= 0 || kind == GemKind.normal) return;

    final colorIndex = switch (kind) {
      GemKind.bomb => 0,
      GemKind.row || GemKind.col || GemKind.star => 1,
      GemKind.hyper => 2,
      GemKind.supernova => 3,
      GemKind.normal => 0,
    };
    _debugTriggerSpecialEffectAt(
      MatchBoardGame.rows ~/ 2,
      MatchBoardGame.cols ~/ 2,
      _DebugSpecialEffect(
        kind: kind,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: colorIndex,
        durationScale: durationScale,
      ),
    );
  }

  void _debugTriggerSpecialEffectAt(
    int centerRow,
    int centerCol,
    _DebugSpecialEffect effect,
  ) {
    _boardShake.queue(specialEffectShakeForKind(effect.kind));
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
      durationScale: effect.durationScale,
    );
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
    this.durationScale = 1.0,
  });

  final GemKind kind;
  final int rowOffset;
  final int colOffset;
  final int colorIndex;
  final double durationScale;
}
