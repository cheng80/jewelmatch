part of 'match_board_renderer.dart';

extension _MatchBoardGemOverlayRenderer on MatchBoardRenderer {
  static const double _overlaySourceRatio = 112 / 128;

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
    final radius = Radius.circular(ts * MatchBoardRenderer._slotRadiusRatio);
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
    final overlaySprite = _overlaySpriteFor(gem.kind);
    final sprite = specialSprite ?? _sheetSprites[_spriteColumnFor(gem)];
    if (sprite != null) {
      _spriteRenderPosition.setValues(ox, oy);
      _spriteRenderSize.setValues(drawW, drawH);
      sprite.render(
        canvas,
        position: _spriteRenderPosition,
        size: _spriteRenderSize,
        overridePaint: _normalSpritePaint,
      );
      if (overlaySprite != null) {
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
          overridePaint: _normalSpritePaint,
        );
      }
    } else {
      _drawGemProcedural(canvas, gem, ts);
    }
  }
}
