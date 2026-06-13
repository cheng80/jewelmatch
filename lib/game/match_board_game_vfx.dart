part of 'match_board_game.dart';

extension MatchBoardGameVfx on MatchBoardGame {
  bool get hasActiveVisualEffects =>
      _particlePool.activeCount > 0 ||
      _specialEffectPool.activeCount > 0 ||
      _cameraShake.isActive;

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
