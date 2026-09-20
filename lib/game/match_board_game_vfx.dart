part of 'match_board_game.dart';

extension MatchBoardGameVfx on MatchBoardGame {
  bool get hasActiveVisualEffects =>
      _effectPoolsReady &&
      (_juiceLayer.busy || _specialEffectPool.activeCount > 0);

  void _spawnSpecialEffectEvents() {
    if (!_effectPoolsReady) return;
    final events = board.consumeSpecialEffectEvents();
    if (events.isEmpty || board.tileSize <= 0) return;

    for (final event in events) {
      _boardShake.queue(event.shake);
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
    }
  }

  void _updateBoardShake(double dt) {
    _boardShake.updateInto(dt, _boardShakeOffset);
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

  /// 매치 제거 시 스파크, 점수 팝업, 콤보 콜아웃, 콤보 셰이크 + SFX.
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

    if (!_effectPoolsReady) return;
    _juiceLayer.onGemsRemoved(
      cells,
      bigMatch: bigMatch,
      hasSpecial: hasSpecial,
      combo: combo,
      gained: board.lastRemovalScore,
    );
    // 특수 발동은 자체 셰이크가 있다. 일반 매치는 큰 매치와 연쇄에서만 살짝 흔든다.
    if (!hasSpecial && (bigMatch || combo >= 3)) {
      _boardShake.queue(
        SpecialEffectShake(
          intensity: min(1.6 + combo * 0.7, 5.0),
          duration: 0.2,
        ),
      );
    }
  }
}
