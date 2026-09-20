part of 'special_effect_burst.dart';

extension _SpecialEffectBurstLightDrawing on SpecialEffectBurst {
  void _drawRadialGlow(
    Canvas canvas,
    Offset center,
    double radius,
    GlowRadial profile,
    Color c0,
    Color c1,
    Color c2, [
    Color c3 = Colors.transparent,
  ]) {
    if (_glowScale <= 0) return;
    _bakedGlow.radial(
      canvas,
      profile,
      center,
      radius,
      c0.withValues(alpha: c0.a * _glowScale),
      c1.withValues(alpha: c1.a * _glowScale),
      c2.withValues(alpha: c2.a * _glowScale),
      c3.withValues(alpha: c3.a * _glowScale),
    );
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
    final path = _lightningPath
      ..reset()
      ..moveTo(start.dx, start.dy);
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    var previous = start;
    for (var i = 1; i <= segments; i++) {
      final f = i / segments;
      final jitter =
          sin(seed * 12.989 + i * 4.21 + t * pi * 5) * tileSize * 0.12;
      final p = i == segments ? end : start + delta * f + normal * jitter;
      path.lineTo(p.dx, p.dy);
      if (glow && _glowScale > 0) {
        _bakedGlow.line(
          canvas,
          previous,
          p,
          tileSize * 0.20,
          SpecialEffectBurst._hotYellow.withValues(
            alpha: 0.26 * fade * _glowScale,
          ),
        );
        _bakedGlow.line(
          canvas,
          previous,
          p,
          tileSize * 0.14,
          SpecialEffectBurst._electricBlue.withValues(
            alpha: 0.30 * fade * _glowScale,
          ),
        );
      }
      previous = p;
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
    final path = _starPath..reset();
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
      _bakedGlow.draw(
        canvas,
        GlowShape.star,
        center,
        radius / 32,
        radius / 32,
        SpecialEffectBurst._hotYellow.withValues(
          alpha: 0.42 * fade * _glowScale,
        ),
      );
      _bakedGlow.draw(
        canvas,
        GlowShape.star,
        center,
        radius / 32,
        radius / 32,
        SpecialEffectBurst._electricBlue.withValues(
          alpha: 0.62 * fade * _glowScale,
        ),
      );
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
        GlowRadial.cell,
        Colors.white.withValues(alpha: 0.22 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.20 * fade),
        color.withValues(alpha: 0.18 * fade),
      );
    }
  }
}
