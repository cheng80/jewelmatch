part of 'special_effect_burst.dart';

extension _SpecialEffectBurstHypercubeDrawing on SpecialEffectBurst {
  void _renderHypercube(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final radius = tileSize * (0.72 + t * 2.4);
    _drawRadialGlow(
      canvas,
      center,
      radius * 1.25,
      [
        Colors.white.withValues(alpha: 0.42 * fade),
        SpecialEffectBurst._electricViolet.withValues(alpha: 0.36 * fade),
        baseColor.withValues(alpha: 0.20 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.24, 0.55, 1.0],
    );

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
        )!.withValues(alpha: (0.52 - i * 0.07) * fade);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.46 + i * 0.18)),
        phase,
        pi * 1.22,
        false,
        _paint,
      );
    }
    _paint.maskFilter = null;

    final orbitCount = _scaledCount(18);
    for (var i = 0; i < orbitCount; i++) {
      final p = _orbitPoint(center, radius * 0.9, t, i);
      _fillPaint.color = Color.lerp(
        Colors.white,
        baseColor,
        (i % 5) / 5,
      )!.withValues(alpha: 0.82 * fade);
      canvas.drawCircle(p, tileSize * (0.035 + (i % 3) * 0.012), _fillPaint);
    }
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 32,
      spread: radius,
      color: SpecialEffectBurst._electricViolet,
    );
    _drawCellFlash(
      canvas,
      t,
      fade,
      maxCells: 24,
      color: SpecialEffectBurst._electricViolet,
    );
  }
}
