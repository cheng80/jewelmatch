part of 'special_effect_burst.dart';

extension _SpecialEffectBurstLightDrawing on SpecialEffectBurst {
  void _drawRadialGlow(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    List<double> stops,
  ) {
    if (_glowScale <= 0) return;
    final glowColors = _glowScale >= 1
        ? colors
        : [
            for (final color in colors)
              color.withValues(alpha: color.a * _glowScale),
          ];
    _fillPaint
      ..maskFilter = null
      ..shader = ui.Gradient.radial(center, radius, glowColors, stops);
    canvas.drawCircle(center, radius, _fillPaint);
    _fillPaint
      ..shader = null
      ..maskFilter = null;
  }

  void _drawLightning(
    Canvas canvas,
    Offset start,
    Offset end,
    double t,
    double fade, {
    required int seed,
    bool glow = true,
    int segments = 9,
  }) {
    if ((start - end).distance < 1) return;
    final path = Path()..moveTo(start.dx, start.dy);
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    for (var i = 1; i < segments; i++) {
      final f = i / segments;
      final jitter =
          sin(seed * 12.989 + i * 4.21 + t * pi * 5) * tileSize * 0.12;
      final p = start + delta * f + normal * jitter;
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(end.dx, end.dy);

    if (glow && _glowScale > 0) {
      _paint
        ..maskFilter = SpecialEffectBurst._glow
        ..strokeWidth = tileSize * 0.14
        ..color = SpecialEffectBurst._electricBlue.withValues(
          alpha: 0.30 * fade * _glowScale,
        );
      canvas.drawPath(path, _paint);
    }
    _paint
      ..maskFilter = null
      ..strokeWidth = tileSize * (glow ? 0.052 : 0.044)
      ..color = SpecialEffectBurst._electricBlue.withValues(alpha: 0.88 * fade);
    canvas.drawPath(path, _paint);
    _paint
      ..strokeWidth = tileSize * 0.018
      ..color = Colors.white.withValues(alpha: fade);
    canvas.drawPath(path, _paint);
  }

  void _drawStarCore(Canvas canvas, Offset center, double radius, double fade) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius * 1.45 : radius * 0.48;
      final angle = -pi / 2 + i * pi / 8;
      final p = center + Offset(cos(angle), sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (_glowScale > 0) {
      _fillPaint
        ..maskFilter = SpecialEffectBurst._glow
        ..color = SpecialEffectBurst._electricBlue.withValues(
          alpha: 0.62 * fade * _glowScale,
        );
      canvas.drawPath(path, _fillPaint);
    }
    _fillPaint
      ..maskFilter = null
      ..color = Colors.white.withValues(alpha: 0.92 * fade);
    canvas.drawPath(path, _fillPaint);
  }

  void _drawCellFlash(
    Canvas canvas,
    double t,
    double fade, {
    required int maxCells,
    required Color color,
  }) {
    if (affectedCenters.isEmpty) return;
    final scaledMaxCells = _scaledMaxCells(maxCells);
    final step = max(1, (affectedCenters.length / scaledMaxCells).ceil());
    final radius = tileSize * (0.34 + 0.30 * sin(t * pi).abs());
    for (var i = 0; i < affectedCenters.length; i += step) {
      final center = affectedCenters[i].toOffset();
      _drawRadialGlow(
        canvas,
        center,
        radius,
        [
          Colors.white.withValues(alpha: 0.20 * fade),
          color.withValues(alpha: 0.24 * fade),
          Colors.transparent,
        ],
        const [0.0, 0.42, 1.0],
      );
    }
  }
}
