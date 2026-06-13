part of 'match_board_game.dart';

extension MatchBoardGameVfx on MatchBoardGame {
  void _spawnSpecialEffectEvents() {
    final events = board.consumeSpecialEffectEvents();
    if (events.isEmpty || board.tileSize <= 0) return;

    for (final event in events) {
      final color =
          event.triggerColor != null &&
              event.triggerColor! >= 1 &&
              event.triggerColor! <= MatchBoardLogic.palette.length
          ? MatchBoardLogic.palette[event.triggerColor! - 1]
          : _colorAt(event.origin.x, event.origin.y);
      _specialEffectPool.spawn(
        effectKind: event.effectKind,
        origin: _cellCenter(event.origin.x, event.origin.y),
        affectedCenters: event.affectedCells
            .map((cell) => _cellCenter(cell.x, cell.y))
            .toList(growable: false),
        tileSize: board.tileSize,
        baseColor: color,
      );
      _queueCameraShake(event.shake);
    }
  }

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
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: -3,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 2,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.col,
        rowOffset: 0,
        colOffset: 2,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.row,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 2.6, duration: 0.22),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.bomb,
        rowOffset: -1,
        colOffset: -1,
        colorIndex: 0,
        shake: SpecialEffectShake(intensity: 4.8, duration: 0.30),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.star,
        rowOffset: -1,
        colOffset: 0,
        colorIndex: 1,
        shake: SpecialEffectShake(intensity: 4.2, duration: 0.26),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.hyper,
        rowOffset: 0,
        colOffset: -1,
        colorIndex: 2,
        shake: SpecialEffectShake(intensity: 5.4, duration: 0.36),
      ),
      const _DebugSpecialEffect(
        kind: GemKind.supernova,
        rowOffset: 0,
        colOffset: 0,
        colorIndex: 3,
        shake: SpecialEffectShake(intensity: 7.2, duration: 0.46),
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
      _queueCameraShake(effect.shake);
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

  Vector2 _cellCenter(int row, int col) {
    final half = board.tileSize / 2;
    return Vector2(
      board.boardX + col * board.tileSize + half,
      board.boardY + row * board.tileSize + half,
    );
  }

  Color _colorAt(int row, int col) {
    final gem = board.getGem(row, col);
    final color = gem?.color ?? 0;
    if (color >= 1 && color <= MatchBoardLogic.palette.length) {
      return MatchBoardLogic.palette[color - 1];
    }
    return Colors.white;
  }

  void _queueCameraShake(SpecialEffectShake shake) {
    _cameraShake.queue(shake);
  }

  void _updateCameraShake(double dt) {
    camera.viewfinder.position = _cameraShake.update(dt);
  }

  /// 매치 제거 시 파티클 스폰 + 추가 SFX.
  void _spawnParticles(
    List<({int row, int col, int color})> cells,
    bool bigMatch,
    bool hasSpecial,
    int combo,
  ) {
    // SFX: 특수 보석 > 4+매치 > 콤보 > 일반 매치 순으로 1개만 재생.
    if (hasSpecial) {
      SoundManager.playSfx(AssetPaths.sfxSpecialGem);
    } else if (bigMatch) {
      SoundManager.playSfx(AssetPaths.sfxBigMatch);
    } else if (combo >= 2) {
      SoundManager.playComboSfxDelayed(AssetPaths.sfxComboHit);
    } else {
      SoundManager.playSfx(AssetPaths.sfxCollect);
    }

    final ts = board.tileSize;
    final half = ts / 2;

    final bool intense = combo >= 3 || (bigMatch && combo >= 2);
    final bool medium = !intense && (bigMatch || combo >= 2);

    final int count;
    final double speed;
    final double size;
    final double life;
    final bool glow;
    if (intense) {
      count = 28;
      speed = 1.38;
      size = 1.38;
      life = 0.62;
      glow = true;
    } else if (medium) {
      count = 18;
      speed = 1.1;
      size = 1.14;
      life = 0.52;
      glow = true;
    } else {
      count = 12;
      speed = 0.9;
      size = 0.9;
      life = 0.46;
      glow = false;
    }

    for (final c in cells) {
      final px = board.boardX + c.col * ts + half;
      final py = board.boardY + c.row * ts + half;
      final color = c.color >= 1 && c.color <= MatchBoardLogic.palette.length
          ? MatchBoardLogic.palette[c.color - 1]
          : Colors.white;
      _particlePool.spawn(
        center: Vector2(px, py),
        baseColor: color,
        count: count,
        lifetime: life,
        speedScale: speed,
        sizeScale: size,
        withGlow: glow,
      );
    }
  }
}

class _DebugSpecialEffect {
  const _DebugSpecialEffect({
    required this.kind,
    required this.rowOffset,
    required this.colOffset,
    required this.colorIndex,
    required this.shake,
  });

  final GemKind kind;
  final int rowOffset;
  final int colOffset;
  final int colorIndex;
  final SpecialEffectShake shake;
}
