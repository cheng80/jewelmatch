part of 'match_board_renderer.dart';

extension _MatchBoardGemOverlayRenderer on MatchBoardRenderer {
  static const double _overlaySourceRatio = 112 / 128;

  void _updateRemovalVisualState() {
    _showRemovalVisuals = false;
    _removalVisualAlpha = 1;
    _removalVisualScale = 1;
    _removalVisualRotation = 0;

    final removalSet = logic.pendingRemovalSet;
    if (logic.state != 'removing' || removalSet == null || removalSet.isEmpty) {
      return;
    }

    final rawProgress =
        1 - (logic.stageTimer / MatchBoardLogic.removeDelay).clamp(0.0, 1.0);
    final eased = rawProgress * rawProgress * (3 - 2 * rawProgress);
    // 팝: 초반에는 선명한 채로 살짝 부풀고, 이후 빠르게 수축하며 사라진다.
    const popPhase = MatchBoardRenderer._removalPopPhase;
    const popScale = MatchBoardRenderer._removalPopScale;
    if (rawProgress < popPhase) {
      _removalVisualAlpha = 1;
      _removalVisualScale =
          1 + (popScale - 1) * math.sin(rawProgress / popPhase * math.pi / 2);
    } else {
      final q = (rawProgress - popPhase) / (1 - popPhase);
      _removalVisualAlpha =
          1 - (1 - MatchBoardRenderer._removalMinAlpha) * q * q;
      _removalVisualScale =
          popScale - (popScale - MatchBoardRenderer._removalMinScale) * q * q;
    }
    _removalVisualRotation = MatchBoardRenderer._removalMaxRotation * eased;

    _removingNormalSpritePaint
      ..colorFilter = const ColorFilter.matrix(
        MatchBoardRenderer._normalSpriteColorMatrix,
      )
      ..color = Colors.white.withValues(alpha: _removalVisualAlpha);
    _removingCompositedSpritePaint.color = Colors.white.withValues(
      alpha: _removalVisualAlpha,
    );
    _showRemovalVisuals = true;
  }

  bool _isRemovalVisualCell(BoardGem gem) {
    if (!_showRemovalVisuals) return false;
    return logic.isPendingRemovalCell(gem.row, gem.col);
  }

  /// 타임 틱과 같은 박자로 보드 테두리가 붉게 맥동한다.
  void _drawLowTimePulse(
    Canvas canvas,
    double bx,
    double by,
    double bw,
    double bh,
  ) {
    final g = game;
    if (!g.hasTimedClock || !g.isPlaying) return;
    final t = g.timeRemaining;
    if (t <= 0 || t > MatchBoardGame.timedLowTimeTickMaxSeconds) return;
    final beat = t - t.floorToDouble();
    final ts = logic.tileSize;
    _lowTimePulsePaint
      ..strokeWidth = ts * (0.05 + 0.07 * beat)
      ..color = const Color(0xFFFF4D4D).withValues(alpha: 0.75 * beat * beat);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx - 2, by - 2, bw + 4, bh + 4),
        const Radius.circular(12),
      ),
      _lowTimePulsePaint,
    );
  }

  void _updateHintNudge(double ts) {
    if (logic.hintCellA == null ||
        logic.hintCellB == null ||
        logic.state != 'idle' ||
        logic.introFillInProgress) {
      _hintNudge = 0;
      return;
    }
    final t = (_hintPulseTime * MatchBoardRenderer._hintPulseHz * 2) % 1.0;
    _hintNudge = ts * 0.09 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
  }

  void _drawSpawnPopRing(Canvas canvas, BoardGem gem, double ts) {
    final p = gem.popT / MatchBoardLogic.spawnPopDuration;
    _popRingPaint
      ..strokeWidth = 1 + ts * 0.09 * (1 - p)
      ..color = const Color(0xFFFFF0A6).withValues(alpha: 0.9 * (1 - p));
    canvas.drawCircle(
      Offset(gem.x + ts / 2, gem.y + ts / 2),
      ts * (0.35 + 0.75 * p),
      _popRingPaint,
    );
  }

  int _spriteColumnFor(BoardGem gem) {
    if (gem.kind == GemKind.hyper) {
      return 1;
    }
    final c = gem.color.clamp(
      1,
      MatchBoardRenderer._sheetColByColor1based.length,
    );
    return MatchBoardRenderer._sheetColByColor1based[c - 1];
  }

  Sprite? _specialSpriteFor(GemKind kind) {
    return _specialSprites[kind];
  }

  Sprite? _overlaySpriteFor(GemKind kind) {
    return _overlaySprites[kind];
  }

  Sprite? _compositedOverlaySpriteFor(BoardGem gem) {
    final sprites = _compositedOverlaySprites[gem.kind];
    if (sprites == null || sprites.isEmpty) return null;
    final c = gem.color.clamp(1, sprites.length);
    return sprites[c - 1];
  }

  /// 힌트로 고른 두 칸만, 보석 **위에** 흰색 펄스(다른 칸은 건드리지 않음).
  void _drawHintWhitePulse(Canvas canvas, double bx, double by, double ts) {
    final ha = logic.hintCellA;
    final hb = logic.hintCellB;
    if (ha == null ||
        hb == null ||
        logic.state != 'idle' ||
        logic.introFillInProgress) {
      return;
    }

    final t = (_hintPulseTime * MatchBoardRenderer._hintPulseHz) % 1.0;
    final alpha = 0.14 + 0.42 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
    _hintPulsePaint.color = Color.lerp(
      JewelCandyLuminaTheme.secondaryCyan,
      JewelCandyLuminaTheme.primaryPink,
      0.35,
    )!.withValues(alpha: alpha);
    _drawHintCell(canvas, ha.x, ha.y, bx, by, ts);
    _drawHintCell(canvas, hb.x, hb.y, bx, by, ts);
  }

  void _drawHintCell(
    Canvas canvas,
    int r,
    int c,
    double bx,
    double by,
    double ts,
  ) {
    const pad = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bx + c * ts + pad,
          by + r * ts + pad,
          ts - pad * 2,
          ts - pad * 2,
        ),
        Radius.circular(ts * MatchBoardRenderer._cellCornerRatio),
      ),
      _hintPulsePaint,
    );
  }

  void _drawGem(Canvas canvas, BoardGem gem, double ts) {
    final y = gem.y;
    final isRemovalVisualCell = _isRemovalVisualCell(gem);
    var sx = 1.0;
    var sy = 1.0;
    var rotation = 0.0;
    var shiftX = 0.0;
    var shiftY = 0.0;
    var anchorY = y + ts / 2;
    if (isRemovalVisualCell) {
      sx = sy = _removalVisualScale;
      if (gem.kind != GemKind.normal) {
        // 기존 제거 0.18초 안에서 첫 0.07초만 수축한다. 판정/발동은 지연하지 않는다.
        final elapsed = MatchBoardLogic.removeDelay - logic.stageTimer;
        if (elapsed < 0.07) {
          sx = sy =
              1 -
              0.22 * math.sin((elapsed / 0.07).clamp(0.0, 1.0) * math.pi / 2);
        } else {
          final p = ((elapsed - 0.07) / 0.11).clamp(0.0, 1.0);
          sx = sy = p < 0.25
              ? 0.78 + 0.46 * p / 0.25
              : 1.24 - 0.94 * math.pow((p - 0.25) / 0.75, 2);
        }
      }
      rotation = _removalVisualRotation * (gem.id.isEven ? 1 : -1);
    } else {
      if (gem.landT >= 0) {
        // 착지 스쿼시: 바닥 기준으로 눌렸다가 살짝 늘어난 뒤 복원.
        final p = gem.landT / MatchBoardLogic.landSquashDuration;
        final wave = math.sin(p * 2 * math.pi) * (1 - p);
        sy -= 0.20 * wave;
        sx += 0.13 * wave;
        anchorY = y + ts * 0.91;
      }
      if (gem.popT >= 0) {
        _gemBatch.flush(canvas);
        _drawSpawnPopRing(canvas, gem, ts);
        final p = 1 - gem.popT / MatchBoardLogic.spawnPopDuration;
        final s = 1 + 0.5 * p * p;
        sx *= s;
        sy *= s;
      } else if (gem.kind != GemKind.normal) {
        // 특수 보석 호흡. id로 위상을 어긋나게 해 보드가 한꺼번에 뛰지 않는다.
        final s = 1 + 0.04 * math.sin(_animTime * 3.2 + gem.id);
        sx *= s;
        sy *= s;
      }
      if (logic.introFillInProgress && logic.lastActionText == 'shuffled') {
        final travel = ((gem.targetY - gem.y) / ts).clamp(0.0, 1.0);
        sx *= 1 - 0.18 * travel;
        sy *= 1 - 0.18 * travel;
        rotation = (gem.col.isEven ? 1 : -1) * 0.16 * travel;
      } else if (_shuffleVisualTime > 0 && gem.kind == GemKind.normal) {
        final pulse = math.sin(_shuffleVisualTime / 0.45 * math.pi);
        sx *= 1 + 0.12 * pulse;
        sy *= 1 + 0.12 * pulse;
        rotation = (gem.col.isEven ? 1 : -1) * 0.08 * pulse;
      }
      if (logic.state == 'idle') {
        final sel = logic.selected;
        if (sel != null && sel.x == gem.row && sel.y == gem.col) {
          final s = 1 + 0.09 * (0.5 + 0.5 * math.sin(_animTime * 8));
          sx *= s;
          sy *= s;
        }
      }
      if (_hintNudge > 0) {
        final ha = logic.hintCellA!;
        final hb = logic.hintCellB!;
        final isA = ha.x == gem.row && ha.y == gem.col;
        if (isA || (hb.x == gem.row && hb.y == gem.col)) {
          final dir = isA ? 1 : -1;
          shiftX = (hb.y - ha.y) * dir * _hintNudge;
          shiftY = (hb.x - ha.x) * dir * _hintNudge;
        }
      }
    }

    final atlas = _gemBatch.image;
    final slot = _atlasSlot(gem);
    final alpha = isRemovalVisualCell ? _removalVisualAlpha : 1.0;
    if (useGemBatching && atlas != null && (sx - sy).abs() < 0.000001) {
      _gemBatch.add(
        slot: slot,
        x: gem.x + ts / 2 + shiftX,
        y: y + ts / 2 + shiftY,
        size: ts,
        scale: sx,
        rotation: rotation,
        alpha: alpha,
      );
      return;
    }
    _gemBatch.flush(canvas);
    final hasGemTransform =
        sx != 1 || sy != 1 || rotation != 0 || shiftX != 0 || shiftY != 0;
    if (hasGemTransform) {
      final cx = gem.x + ts / 2;
      canvas.save();
      canvas.translate(cx + shiftX, anchorY + shiftY);
      if (rotation != 0) canvas.rotate(rotation);
      canvas.scale(sx, sy);
      canvas.translate(-cx, -anchorY);
    }
    if (atlas != null && useGemBatching) {
      _atlasIndividualPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawImageRect(
        atlas,
        _gemBatch.rects[slot],
        Rect.fromLTWH(gem.x, gem.y, ts, ts),
        _atlasIndividualPaint,
      );
    } else {
      _drawGemAppearance(canvas, gem, ts, removing: isRemovalVisualCell);
    }
    individualGemDrawCalls++;
    if (hasGemTransform) canvas.restore();
  }

  void _drawGemAppearance(
    Canvas canvas,
    BoardGem gem,
    double ts, {
    required bool removing,
  }) {
    final x = gem.x;
    final y = gem.y;
    final drawW = ts * 0.82;
    final drawH = ts * 0.82;
    final ox = x + (ts - drawW) / 2;
    final oy = y + (ts - drawH) / 2;
    final specialSprite = _specialSpriteFor(gem.kind);
    final compositedOverlaySprite = _compositedOverlaySpriteFor(gem);
    final overlaySprite = _overlaySpriteFor(gem.kind);
    final isRemovalVisualCell = removing;
    final normalPaint = isRemovalVisualCell
        ? _removingNormalSpritePaint
        : _normalSpritePaint;
    final compositedPaint = isRemovalVisualCell
        ? _removingCompositedSpritePaint
        : _compositedSpritePaint;

    if (compositedOverlaySprite != null && specialSprite == null) {
      final overlayW = ts * _overlaySourceRatio;
      final overlayH = ts * _overlaySourceRatio;
      _spriteRenderPosition.setValues(
        x + (ts - overlayW) / 2,
        y + (ts - overlayH) / 2,
      );
      _spriteRenderSize.setValues(overlayW, overlayH);
      compositedOverlaySprite.render(
        canvas,
        position: _spriteRenderPosition,
        size: _spriteRenderSize,
        overridePaint: compositedPaint,
      );
      return;
    }

    final sprite = specialSprite ?? _sheetSprites[_spriteColumnFor(gem)];
    if (sprite != null) {
      final spritePaint = specialSprite == null ? normalPaint : compositedPaint;
      _spriteRenderPosition.setValues(ox, oy);
      _spriteRenderSize.setValues(drawW, drawH);
      sprite.render(
        canvas,
        position: _spriteRenderPosition,
        size: _spriteRenderSize,
        overridePaint: spritePaint,
      );
      if (overlaySprite != null && compositedOverlaySprite == null) {
        final overlayW = ts * _overlaySourceRatio;
        final overlayH = ts * _overlaySourceRatio;
        _spriteRenderPosition.setValues(
          x + (ts - overlayW) / 2,
          y + (ts - overlayH) / 2,
        );
        _spriteRenderSize.setValues(overlayW, overlayH);
        overlaySprite.render(
          canvas,
          position: _spriteRenderPosition,
          size: _spriteRenderSize,
          overridePaint: normalPaint,
        );
      }
    } else {
      _drawGemProcedural(
        canvas,
        gem,
        ts,
        alpha: isRemovalVisualCell ? _removalVisualAlpha : 1,
      );
    }
  }
}
