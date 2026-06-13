part of 'special_effect_burst.dart';

extension _SpecialEffectBurstSweepDrawing on SpecialEffectBurst {
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
}
