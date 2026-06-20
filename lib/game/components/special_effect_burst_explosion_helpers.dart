part of 'special_effect_burst.dart';

extension _SpecialEffectBurstExplosionDrawing on SpecialEffectBurst {
  void _drawFlameTongues(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    final tongueCount = _scaledCount(9);
    for (var i = 0; i < tongueCount; i++) {
      final angle = i * 2 * pi / tongueCount + sin(t * pi * 2 + i) * 0.13;
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
        i / max(1, tongueCount - 1),
      )!.withValues(alpha: 0.34 * fade);
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
    final heatFade = fade * (1.0 - t * 0.18);
    final lobeCount = _scaledCount(10);
    for (var i = 0; i < lobeCount; i++) {
      final angle = i * 2 * pi / lobeCount + sin(t * pi * 1.7 + i) * 0.10;
      final drift = radius * (0.10 + _hash(i + 3) * 0.28) * bloom;
      final lobeCenter = center + Offset(cos(angle), sin(angle)) * drift;
      final lobeRadius = radius * (0.18 + _hash(i + 11) * 0.24);
      final mix = i / max(1, lobeCount - 1);
      final color = Color.lerp(
        i.isEven
            ? SpecialEffectBurst._hotYellow
            : SpecialEffectBurst._hotOrange,
        baseColor,
        mix * 0.12,
      )!;
      final lobeColor = color.withValues(
        alpha: (0.35 + _hash(i) * 0.22) * heatFade,
      );
      if (_tier >= 2) {
        _fillPaint
          ..shader = null
          ..maskFilter = null
          ..blendMode = BlendMode.srcOver
          ..color = lobeColor;
        canvas.drawCircle(lobeCenter, lobeRadius * 0.86, _fillPaint);
        _fillPaint.blendMode = BlendMode.plus;
      } else {
        _drawOrganicBlob(
          canvas,
          lobeCenter,
          lobeRadius,
          seed: i * 19 + 7,
          t: t,
          color: lobeColor,
        );
      }
    }

    _fillPaint
      ..shader = null
      ..maskFilter = null
      ..blendMode = BlendMode.plus
      ..color = SpecialEffectBurst._hotYellow.withValues(alpha: 0.58 * fade);
    canvas.drawCircle(center, radius * (0.16 + bloom * 0.16), _fillPaint);

    _paint
      ..maskFilter = _glowScale > 0 ? SpecialEffectBurst._glow : null
      ..strokeCap = StrokeCap.round
      ..strokeWidth = tileSize * (0.14 + 0.06 * (1 - t))
      ..color = SpecialEffectBurst._hotYellow.withValues(
        alpha: 0.74 * fade * max(_glowScale, 0.38),
      );
    final arcRect = Rect.fromCenter(
      center: center + Offset(0, radius * 0.07),
      width: radius * (1.62 + bloom * 0.46),
      height: radius * (0.62 + bloom * 0.18),
    );
    canvas.drawArc(arcRect, pi * 0.04, pi * 0.92, false, _paint);

    _paint
      ..maskFilter = null
      ..strokeWidth = tileSize * 0.060
      ..color = SpecialEffectBurst._hotOrange.withValues(alpha: 0.68 * fade);
    canvas.drawArc(
      arcRect.inflate(tileSize * 0.08),
      pi * 0.08,
      pi * 0.82,
      false,
      _paint,
    );

    if (_tier < 2) {
      _drawFlameTongues(canvas, center, radius * 0.92, t, fade * 0.72);
    }
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
    final scaledCount = _scaledCount(count);
    for (var i = 0; i < scaledCount; i++) {
      final angle = i * 2 * pi / scaledCount + _hash(i + 90) * 0.28;
      final dir = Offset(cos(angle), sin(angle));
      final reach =
          length * (0.38 + _hash(i + 91) * 0.62) * Curves.easeOut.transform(t);
      final start = center + dir * tileSize * 0.08;
      final tip = center + dir * reach;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.018 + _hash(i + 92) * 0.026)
        ..color = Color.lerp(
          Colors.white,
          SpecialEffectBurst._hotYellow,
          _hash(i + 93) * 0.55,
        )!.withValues(alpha: 0.38 * fade);
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
      ..strokeWidth = tileSize * 0.065
      ..color = SpecialEffectBurst._hotYellow.withValues(alpha: 0.50 * fade);
    final arcCount = _scaledCount(4);
    for (var i = 0; i < arcCount; i++) {
      final start = i * 2 * pi / arcCount + t * 1.2;
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius * (0.56 + _hash(i) * 0.22),
        ),
        start,
        pi * (0.22 + _hash(i + 12) * 0.26),
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
    final scaledCount = _scaledCount(count);
    for (var i = 0; i < scaledCount; i++) {
      final angle = i * 2.399963 + _hash(i + 150) * 0.35;
      final dir = Offset(cos(angle), sin(angle));
      final distance = spread * (0.22 + _hash(i + 151) * 0.78) * progress;
      final start = center + dir * max(0, distance - tileSize * 0.50);
      final end = center + dir * distance;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.020 + _hash(i + 152) * 0.032)
        ..color = Color.lerp(
          SpecialEffectBurst._hotYellow,
          SpecialEffectBurst._hotOrange,
          _hash(i + 153) * 0.65,
        )!.withValues(alpha: 0.40 * fade);
      canvas.drawLine(start, end, _paint);

      if (i.isEven) {
        _fillPaint.color = SpecialEffectBurst._hotOrange.withValues(
          alpha: 0.22 * fade,
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
