part of 'match_board_renderer.dart';

extension _MatchBoardGemOverlayRenderer on MatchBoardRenderer {
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
    final sprite =
        _specialSpriteFor(gem.kind) ?? _sheetSprites[_spriteColumnFor(gem)];
    if (sprite != null) {
      _spriteRenderPosition.setValues(ox, oy);
      _spriteRenderSize.setValues(drawW, drawH);
      sprite.render(
        canvas,
        position: _spriteRenderPosition,
        size: _spriteRenderSize,
        overridePaint: _normalSpritePaint,
      );
    } else {
      _drawGemProcedural(canvas, gem, ts);
    }

    if (gem.kind == GemKind.star) {
      _drawStarOverlay(canvas, ox, oy, drawW, drawH);
    } else if (gem.kind == GemKind.supernova) {
      _drawSupernovaOverlay(canvas, ox, oy, drawW, drawH);
    }
  }

  void _drawStarOverlay(
    Canvas canvas,
    double ox,
    double oy,
    double drawW,
    double drawH,
  ) {
    final center = Offset(ox + drawW / 2, oy + drawH / 2);
    final short = drawW * 0.19;
    final long = drawW * 0.39;

    _specialGlowPaint
      ..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.42)
      ..strokeWidth = drawW * 0.12;
    canvas.drawLine(
      Offset(center.dx - long, center.dy),
      Offset(center.dx + long, center.dy),
      _specialGlowPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - long),
      Offset(center.dx, center.dy + long),
      _specialGlowPaint,
    );

    _specialAuraPaint
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = drawW * 0.045;
    canvas.drawLine(
      Offset(center.dx - long, center.dy),
      Offset(center.dx + long, center.dy),
      _specialAuraPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - long),
      Offset(center.dx, center.dy + long),
      _specialAuraPaint,
    );
    canvas.drawLine(
      Offset(center.dx - short, center.dy - short),
      Offset(center.dx + short, center.dy + short),
      _specialAuraPaint,
    );
    canvas.drawLine(
      Offset(center.dx - short, center.dy + short),
      Offset(center.dx + short, center.dy - short),
      _specialAuraPaint,
    );

    _specialCorePaint.color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(center, drawW * 0.07, _specialCorePaint);
  }

  void _drawSupernovaOverlay(
    Canvas canvas,
    double ox,
    double oy,
    double drawW,
    double drawH,
  ) {
    final center = Offset(ox + drawW / 2, oy + drawH / 2);
    final radius = drawW * 0.38;

    _specialGlowPaint
      ..color = JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.5)
      ..strokeWidth = drawW * 0.14;
    canvas.drawCircle(center, radius, _specialGlowPaint);

    _specialAuraPaint
      ..color = JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.9)
      ..strokeWidth = drawW * 0.055;
    canvas.drawCircle(center, radius, _specialAuraPaint);
    canvas.drawCircle(center, radius * 0.74, _specialAuraPaint);

    _drawStarOverlay(canvas, ox, oy, drawW, drawH);

    _specialCorePaint.color = Colors.white.withValues(alpha: 0.78);
    canvas.drawCircle(center, drawW * 0.12, _specialCorePaint);
  }
}
