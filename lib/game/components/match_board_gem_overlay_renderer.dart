part of 'match_board_renderer.dart';

extension _MatchBoardGemOverlayRenderer on MatchBoardRenderer {
  static const double _overlaySourceRatio = 112 / 128;

  void _updateRemovalVisualState() {
    _showRemovalVisuals = false;
    _removalVisualAlpha = 1;
    _removalVisualScale = 1;
    _removalVisualRotation = 0;
    _removalFlashAlpha = 0;

    final removalSet = logic.pendingRemovalSet;
    if (logic.state != 'removing' || removalSet == null || removalSet.isEmpty) {
      return;
    }

    final rawProgress =
        1 - (logic.stageTimer / MatchBoardLogic.removeDelay).clamp(0.0, 1.0);
    final eased = rawProgress * rawProgress * (3 - 2 * rawProgress);
    _removalVisualAlpha = 1 - (1 - MatchBoardRenderer._removalMinAlpha) * eased;
    _removalVisualScale = 1 - (1 - MatchBoardRenderer._removalMinScale) * eased;
    _removalVisualRotation = MatchBoardRenderer._removalMaxRotation * eased;
    _removalFlashAlpha = MatchBoardRenderer._removalMaxFlashAlpha * (1 - eased);

    _removingNormalSpriteColorMatrix[18] = _removalVisualAlpha;
    _removingNormalSpritePaint.colorFilter = ColorFilter.matrix(
      _removingNormalSpriteColorMatrix,
    );
    _removingCompositedSpritePaint.colorFilter = ColorFilter.mode(
      Colors.white.withValues(alpha: _removalVisualAlpha),
      BlendMode.modulate,
    );
    _showRemovalVisuals = true;
  }

  bool _isRemovalVisualCell(BoardGem gem) {
    if (!_showRemovalVisuals) return false;
    return logic.pendingRemovalSet?.containsKey('${gem.row}:${gem.col}') ??
        false;
  }

  void _drawRemovalCellFlash(Canvas canvas, BoardGem gem, double ts) {
    if (_removalFlashAlpha <= 0) return;
    final radius = Radius.circular(ts * MatchBoardRenderer._cellCornerRatio);
    _removalFlashPaint.color = const Color(
      0xFFFFE2A0,
    ).withValues(alpha: _removalFlashAlpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(gem.x + 4, gem.y + 4, ts - 8, ts - 8),
        radius,
      ),
      _removalFlashPaint,
    );
  }

  void _withRemovalTransform(
    Canvas canvas,
    BoardGem gem,
    double ts,
    bool enabled,
    void Function() draw,
  ) {
    if (!enabled) {
      draw();
      return;
    }
    final scale = _removalVisualScale;
    if (scale >= 0.999) {
      draw();
      return;
    }
    final cx = gem.x + ts / 2;
    final cy = gem.y + ts / 2;
    final rotationDirection = gem.id.isEven ? 1 : -1;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(_removalVisualRotation * rotationDirection);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);
    draw();
    canvas.restore();
  }

  int _spriteColumnFor(BoardGem gem) {
    if (gem.kind == GemKind.hyper) {
      return 1;
    }
    final c = gem.color.clamp(1, 6);
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
    final c = gem.color.clamp(1, 6);
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
    final radius = Radius.circular(ts * MatchBoardRenderer._cellCornerRatio);
    const pad = 3.0;

    void pulseCell(int r, int c) {
      final x = bx + c * ts;
      final y = by + r * ts;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + pad, y + pad, ts - pad * 2, ts - pad * 2),
          radius,
        ),
        _hintPulsePaint,
      );
    }

    pulseCell(ha.x, ha.y);
    pulseCell(hb.x, hb.y);
  }

  void _drawGem(Canvas canvas, BoardGem gem, double ts) {
    final x = gem.x;
    final y = gem.y;
    final drawW = ts * 0.82;
    final drawH = ts * 0.82;
    final ox = x + (ts - drawW) / 2;
    final oy = y + (ts - drawH) / 2;
    final specialSprite = _specialSpriteFor(gem.kind);
    final compositedOverlaySprite = _compositedOverlaySpriteFor(gem);
    final overlaySprite = _overlaySpriteFor(gem.kind);
    final isRemovalVisualCell = _isRemovalVisualCell(gem);
    final normalPaint = isRemovalVisualCell
        ? _removingNormalSpritePaint
        : _normalSpritePaint;
    final compositedPaint = isRemovalVisualCell
        ? _removingCompositedSpritePaint
        : _compositedSpritePaint;

    if (isRemovalVisualCell) {
      _drawRemovalCellFlash(canvas, gem, ts);
    }

    if (compositedOverlaySprite != null && specialSprite == null) {
      _withRemovalTransform(canvas, gem, ts, isRemovalVisualCell, () {
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
      });
      return;
    }

    final sprite = specialSprite ?? _sheetSprites[_spriteColumnFor(gem)];
    if (sprite != null) {
      final spritePaint = specialSprite == null ? normalPaint : compositedPaint;
      _withRemovalTransform(canvas, gem, ts, isRemovalVisualCell, () {
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
      });
    } else {
      _withRemovalTransform(
        canvas,
        gem,
        ts,
        isRemovalVisualCell,
        () => _drawGemProcedural(
          canvas,
          gem,
          ts,
          alpha: isRemovalVisualCell ? _removalVisualAlpha : 1,
        ),
      );
    }
  }
}
