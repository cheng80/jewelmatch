part of 'special_effect_burst.dart';

extension _SpecialEffectBurstParticleDrawing on SpecialEffectBurst {
  void _drawSparks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
    Color? color,
  }) {
    final sparkColor = color ?? baseColor;
    final step = max(1, (count / 56).ceil());
    for (var i = 0; i < count; i += step) {
      final angle = i * 2.399963 + sin(i * 7.13) * 0.2;
      final velocity = (0.22 + _hash(i) * 0.78) * spread;
      final travel = Curves.easeOut.transform(t) * velocity;
      final p = center + Offset(cos(angle), sin(angle)) * travel;
      final size = tileSize * (0.025 + _hash(i + 17) * 0.045) * fade;
      _fillPaint
        ..maskFilter = null
        ..color = Color.lerp(
          Colors.white,
          sparkColor,
          _hash(i + 23),
        )!.withValues(alpha: (0.45 + _hash(i + 9) * 0.45) * fade);
      canvas.drawCircle(p, size, _fillPaint);
    }
    _fillPaint.maskFilter = null;
  }

  void _drawEmbers(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + 0.45;
      final travel = spread * (0.18 + _hash(i + 120) * 0.72) * t;
      final p = center + Offset(cos(angle), sin(angle)) * travel;
      final h = tileSize * (0.08 + _hash(i + 121) * 0.10) * fade;
      final w = h * (0.35 + _hash(i + 122) * 0.18);
      final dir = Offset(cos(angle), sin(angle));
      final side = Offset(-dir.dy, dir.dx);
      final path = Path()
        ..moveTo((p + dir * h).dx, (p + dir * h).dy)
        ..quadraticBezierTo(
          (p + side * w).dx,
          (p + side * w).dy,
          (p - dir * h * 0.55).dx,
          (p - dir * h * 0.55).dy,
        )
        ..quadraticBezierTo(
          (p - side * w * 0.75).dx,
          (p - side * w * 0.75).dy,
          (p + dir * h).dx,
          (p + dir * h).dy,
        )
        ..close();
      _fillPaint.color = Color.lerp(
        SpecialEffectBurst._hotYellow,
        SpecialEffectBurst._hotOrange,
        _hash(i + 123),
      )!.withValues(alpha: 0.42 * fade);
      canvas.drawPath(path, _fillPaint);
    }
  }
}
