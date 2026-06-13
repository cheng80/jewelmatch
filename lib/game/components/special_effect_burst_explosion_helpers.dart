part of 'special_effect_burst.dart';

extension _SpecialEffectBurstExplosionDrawing on SpecialEffectBurst {
  void _drawFlameTongues(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    for (var i = 0; i < 9; i++) {
      final angle = i * 2 * pi / 9 + sin(t * pi * 2 + i) * 0.13;
      final dir = Offset(cos(angle), sin(angle));
      final side = Offset(-dir.dy, dir.dx);
      final tip = center + dir * radius * (0.48 + (i % 3) * 0.13);
      final root = center + dir * tileSize * 0.14;
      final path = Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(
          (center + side * tileSize * 0.28 + dir * radius * 0.28).dx,
          (center + side * tileSize * 0.28 + dir * radius * 0.28).dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (center - side * tileSize * 0.20 + dir * radius * 0.22).dx,
          (center - side * tileSize * 0.20 + dir * radius * 0.22).dy,
          root.dx,
          root.dy,
        )
        ..close();
      _fillPaint.color = Color.lerp(
        SpecialEffectBurst._hotYellow,
        SpecialEffectBurst._hotOrange,
        i / 8,
      )!.withValues(alpha: 0.42 * fade);
      canvas.drawPath(path, _fillPaint);
    }
  }

  void _drawExplosionCloud(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    final bloom = Curves.easeOutCubic.transform(t);
    final heatFade = fade * (1.0 - t * 0.26);
    for (var i = 0; i < 13; i++) {
      final angle = i * 2 * pi / 13 + sin(t * pi * 2 + i) * 0.18;
      final drift = radius * (0.12 + _hash(i + 3) * 0.38) * bloom;
      final lobeCenter = center + Offset(cos(angle), sin(angle)) * drift;
      final lobeRadius = radius * (0.20 + _hash(i + 11) * 0.22);
      final mix = i / 12;
      final color = Color.lerp(
        i.isEven
            ? SpecialEffectBurst._hotYellow
            : SpecialEffectBurst._hotOrange,
        baseColor,
        mix * 0.32,
      )!;
      _drawOrganicBlob(
        canvas,
        lobeCenter,
        lobeRadius,
        seed: i * 19 + 7,
        t: t,
        color: color.withValues(alpha: (0.18 + _hash(i) * 0.18) * heatFade),
      );
    }

    for (var i = 0; i < 8; i++) {
      final angle = i * 2 * pi / 8 + 0.35;
      final drift = radius * (0.36 + _hash(i + 40) * 0.30) * bloom;
      final smokeCenter = center + Offset(cos(angle), sin(angle)) * drift;
      _drawOrganicBlob(
        canvas,
        smokeCenter,
        radius * (0.18 + _hash(i + 50) * 0.18),
        seed: i * 31 + 5,
        t: t + 0.2,
        color: const Color(
          0xFF9CB5A8,
        ).withValues(alpha: (0.13 + _hash(i + 70) * 0.12) * fade),
      );
    }

    _drawFlameTongues(canvas, center, radius * 0.92, t, fade * 0.54);
  }

  void _drawOrganicBlob(
    Canvas canvas,
    Offset center,
    double radius, {
    required int seed,
    required double t,
    required Color color,
  }) {
    final path = Path();
    const points = 9;
    for (var i = 0; i <= points; i++) {
      final angle = i * 2 * pi / points;
      final wobble =
          0.74 +
          _hash(seed + i * 13) * 0.38 +
          sin(t * pi * 2 + seed + i) * 0.08;
      final p = center + Offset(cos(angle), sin(angle)) * radius * wobble;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prevAngle = (i - 0.5) * 2 * pi / points;
        final control =
            center +
            Offset(cos(prevAngle), sin(prevAngle)) *
                radius *
                (0.92 + _hash(seed + i * 7) * 0.18);
        path.quadraticBezierTo(control.dx, control.dy, p.dx, p.dy);
      }
    }
    path.close();
    _fillPaint
      ..shader = null
      ..maskFilter = null
      ..blendMode = BlendMode.srcOver
      ..color = color;
    canvas.drawPath(path, _fillPaint);
    _fillPaint.blendMode = BlendMode.plus;
  }

  void _drawFlashStreaks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double length,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * pi / count + _hash(i + 90) * 0.28;
      final dir = Offset(cos(angle), sin(angle));
      final reach =
          length * (0.42 + _hash(i + 91) * 0.58) * Curves.easeOut.transform(t);
      final start = center + dir * tileSize * 0.08;
      final tip = center + dir * reach * 0.78;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.012 + _hash(i + 92) * 0.018)
        ..color = Color.lerp(
          Colors.white,
          SpecialEffectBurst._hotYellow,
          _hash(i + 93) * 0.55,
        )!.withValues(alpha: 0.24 * fade);
      canvas.drawLine(start, tip, _paint);
    }
  }

  void _drawPlasmaArcs(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    _paint
      ..maskFilter = null
      ..strokeWidth = tileSize * 0.045
      ..color = SpecialEffectBurst._hotYellow.withValues(alpha: 0.42 * fade);
    for (var i = 0; i < 7; i++) {
      final start = i * 2 * pi / 7 + t * 1.6;
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius * (0.54 + _hash(i) * 0.24),
        ),
        start,
        pi * (0.16 + _hash(i + 12) * 0.18),
        false,
        _paint,
      );
    }
  }

  void _drawBurstStreaks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
  }) {
    final progress = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + _hash(i + 150) * 0.35;
      final dir = Offset(cos(angle), sin(angle));
      final distance = spread * (0.22 + _hash(i + 151) * 0.78) * progress;
      final start = center + dir * max(0, distance - tileSize * 0.42);
      final end = center + dir * distance;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.014 + _hash(i + 152) * 0.020)
        ..color = Color.lerp(
          SpecialEffectBurst._hotYellow,
          baseColor,
          _hash(i + 153) * 0.35,
        )!.withValues(alpha: 0.34 * fade);
      canvas.drawLine(start, end, _paint);

      if (i.isEven) {
        _fillPaint.color = SpecialEffectBurst._hotOrange.withValues(
          alpha: 0.28 * fade,
        );
        canvas.drawCircle(
          end,
          tileSize * (0.018 + _hash(i + 154) * 0.018),
          _fillPaint,
        );
      }
    }
  }
}
