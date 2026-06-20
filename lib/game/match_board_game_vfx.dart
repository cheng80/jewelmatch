part of 'match_board_game.dart';

extension MatchBoardGameVfx on MatchBoardGame {
  bool get hasActiveVisualEffects =>
      _effectPoolsReady &&
      (_particlePool.activeCount > 0 || _specialEffectPool.activeCount > 0);

  void _spawnSpecialEffectEvents() {
    if (!_effectPoolsReady) return;
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
    }
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

  }
}
