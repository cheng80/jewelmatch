part of 'special_effect_burst.dart';

extension _SpecialEffectBurstDrawing on SpecialEffectBurst {
  void _renderFlame(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final heat = Curves.easeOutBack.transform(min(t * 1.15, 1));
    final radius = tileSize * (0.45 + heat * 2.35);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.88,
      [
        Colors.white.withValues(alpha: 0.18 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.24 * fade),
        SpecialEffectBurst._hotOrange.withValues(alpha: 0.13 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.16, 0.48, 1.0],
    );

    _drawExplosionCloud(canvas, center, radius, t, fade);
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: 10,
      length: radius * 0.95,
    );
    _drawSparks(canvas, center, t, fade, count: 42, spread: radius * 1.18);
    _drawEmbers(canvas, center, t, fade, count: 14, spread: radius * 1.05);
    _drawCellFlash(
      canvas,
      t,
      fade,
      maxCells: 9,
      color: SpecialEffectBurst._hotOrange,
    );
  }

  void _renderStarLightning(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    _drawRadialGlow(
      canvas,
      center,
      tileSize * (1.4 + t * 0.8),
      [
        Colors.white.withValues(alpha: 0.56 * fade),
        SpecialEffectBurst._electricBlue.withValues(alpha: 0.34 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.36, 1.0],
    );

    final left = _axisExtreme(horizontal: true, first: true);
    final right = _axisExtreme(horizontal: true, first: false);
    final top = _axisExtreme(horizontal: false, first: true);
    final bottom = _axisExtreme(horizontal: false, first: false);
    _drawLightning(canvas, center, left, t, fade, seed: 1);
    _drawLightning(canvas, center, right, t, fade, seed: 2);
    _drawLightning(canvas, center, top, t, fade, seed: 3);
    _drawLightning(canvas, center, bottom, t, fade, seed: 4);

    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4 + sin(t * pi * 2) * 0.08;
      final end =
          center + Offset(cos(a), sin(a)) * tileSize * (0.9 + 0.65 * fade);
      _drawLightning(canvas, center, end, t, fade * 0.72, seed: 10 + i);
    }

    _drawStarCore(canvas, center, tileSize * (0.34 + 0.12 * fade), fade);
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 28,
      spread: tileSize * 2.4,
      color: SpecialEffectBurst._electricBlue,
    );
    _drawCellFlash(
      canvas,
      t,
      fade,
      maxCells: 16,
      color: SpecialEffectBurst._electricBlue,
    );
  }

  void _renderLightningSweep(
    Canvas canvas,
    double t,
    double fade, {
    required bool horizontal,
  }) {
    final center = origin.toOffset();
    final a = _axisExtreme(horizontal: horizontal, first: true);
    final b = _axisExtreme(horizontal: horizontal, first: false);
    final tier = performanceTier.clamp(0, 2);
    _drawLightning(
      canvas,
      a,
      b,
      t,
      fade,
      seed: horizontal ? 5 : 6,
      glow: tier == 0,
      segments: tier == 0 ? 9 : 6,
    );
    if (tier < 2) {
      _drawRadialGlow(
        canvas,
        center,
        tileSize * (tier == 0 ? 1.2 : 0.86),
        [
          Colors.white.withValues(alpha: (tier == 0 ? 0.45 : 0.24) * fade),
          SpecialEffectBurst._electricBlue.withValues(
            alpha: (tier == 0 ? 0.28 : 0.16) * fade,
          ),
          Colors.transparent,
        ],
        const [0.0, 0.4, 1.0],
      );
    }
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: tier == 0 ? 18 : 8,
      spread: tileSize * (tier == 0 ? 1.8 : 1.25),
      color: SpecialEffectBurst._electricBlue,
    );
    if (tier < 2) {
      _drawCellFlash(
        canvas,
        t,
        fade,
        maxCells: tier == 0 ? 12 : 4,
        color: SpecialEffectBurst._electricBlue,
      );
    }
  }

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

    for (var i = 0; i < 4; i++) {
      final phase = i * pi / 2 + t * pi * 2.2;
      _paint
        ..maskFilter = i == 0 ? SpecialEffectBurst._glow : null
        ..strokeWidth = tileSize * (0.045 + i * 0.006)
        ..color = Color.lerp(
          SpecialEffectBurst._electricViolet,
          baseColor,
          i / 3,
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

    for (var i = 0; i < 18; i++) {
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

  void _renderSupernova(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final blast = Curves.easeOutCubic.transform(t);
    final radius = tileSize * (0.85 + blast * 4.2);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.86,
      [
        Colors.white.withValues(alpha: 0.28 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.24 * fade),
        baseColor.withValues(alpha: 0.12 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.18, 0.52, 1.0],
    );
    _drawExplosionCloud(canvas, center, radius * 0.58, t, fade);
    _drawPlasmaArcs(canvas, center, radius, t, fade);
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: 18,
      length: radius * 0.95,
    );

    _drawBurstStreaks(
      canvas,
      center,
      t,
      fade,
      count: 30,
      spread: radius * 0.92,
    );

    final left = _axisExtreme(horizontal: true, first: true);
    final right = _axisExtreme(horizontal: true, first: false);
    final top = _axisExtreme(horizontal: false, first: true);
    final bottom = _axisExtreme(horizontal: false, first: false);
    _drawLightning(canvas, left, right, t, fade * 0.72, seed: 30);
    _drawLightning(canvas, top, bottom, t, fade * 0.72, seed: 31);

    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 64,
      spread: radius * 1.12,
      color: SpecialEffectBurst._hotYellow,
    );
    _drawEmbers(canvas, center, t, fade, count: 20, spread: radius * 0.95);
    _drawCellFlash(
      canvas,
      t,
      fade,
      maxCells: 32,
      color: SpecialEffectBurst._hotYellow,
    );
  }
}
