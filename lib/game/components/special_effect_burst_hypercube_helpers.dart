part of 'special_effect_burst.dart';

extension _SpecialEffectBurstHypercubeDrawing on SpecialEffectBurst {
  void _renderHypercube(Canvas canvas, double t, double fade) {
    if (_renderAreaEffectSprite(canvas, t, fade)) return;

    final center = origin.toOffset();
    final radius = tileSize * (0.72 + t * 2.4);
    final visibleFade = min(
      1.0,
      fade *
          switch (_tier) {
            0 => 1.0,
            1 => 1.25,
            _ => 1.65,
          },
    );
    if (_glowScale > 0) {
      _drawRadialGlow(
        canvas,
        center,
        radius * 1.25,
        [
          Colors.white.withValues(alpha: 0.42 * visibleFade),
          SpecialEffectBurst._hotYellow.withValues(alpha: 0.30 * visibleFade),
          SpecialEffectBurst._electricViolet.withValues(
            alpha: 0.26 * visibleFade,
          ),
          baseColor.withValues(alpha: 0.16 * visibleFade),
          Colors.transparent,
        ],
        const [0.0, 0.22, 0.50, 0.72, 1.0],
      );
    } else {
      _drawFlatHypercubeGlow(canvas, center, radius * 1.08, visibleFade);
    }

    final arcCount = _scaledCount(4);
    for (var i = 0; i < arcCount; i++) {
      final phase = i * pi / 2 + t * pi * 2.2;
      _paint
        ..maskFilter = i == 0 && _glowScale > 0
            ? SpecialEffectBurst._glow
            : null
        ..strokeWidth = tileSize * (0.045 + i * 0.006)
        ..color = Color.lerp(
          SpecialEffectBurst._electricViolet,
          baseColor,
          i / max(1, arcCount - 1),
        )!.withValues(alpha: (0.58 - i * 0.07) * visibleFade);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.46 + i * 0.18)),
        phase,
        pi * 1.22,
        false,
        _paint,
      );
      if (i == 0 && _glowScale > 0) {
        _paint
          ..maskFilter = SpecialEffectBurst._glow
          ..strokeWidth = tileSize * 0.095
          ..color = SpecialEffectBurst._hotYellow.withValues(
            alpha: 0.26 * visibleFade * _glowScale,
          );
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.46),
          phase,
          pi * 1.22,
          false,
          _paint,
        );
      }
    }
    _paint.maskFilter = null;

    final orbitCount = _scaledCount(18);
    for (var i = 0; i < orbitCount; i++) {
      final p = _orbitPoint(center, radius * 0.9, t, i);
      _fillPaint.color = Color.lerp(
        Colors.white,
        baseColor,
        (i % 5) / 5,
      )!.withValues(alpha: 0.88 * visibleFade);
      canvas.drawCircle(p, tileSize * (0.035 + (i % 3) * 0.012), _fillPaint);
    }
    _drawSparks(
      canvas,
      center,
      t,
      visibleFade,
      count: 32,
      spread: radius,
      color: SpecialEffectBurst._electricViolet,
    );
    _drawCellFlash(
      canvas,
      t,
      visibleFade,
      maxCells: 24,
      color: SpecialEffectBurst._electricViolet,
    );
  }

  void _drawFlatHypercubeGlow(
    Canvas canvas,
    Offset center,
    double radius,
    double fade,
  ) {
    _fillPaint
      ..maskFilter = null
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.white.withValues(alpha: 0.30 * fade),
          SpecialEffectBurst._electricViolet.withValues(alpha: 0.22 * fade),
          baseColor.withValues(alpha: 0.12 * fade),
          Colors.transparent,
        ],
        const [0.0, 0.38, 0.68, 1.0],
      );
    canvas.drawCircle(center, radius, _fillPaint);
    _fillPaint
      ..shader = null
      ..maskFilter = null;
  }
}
