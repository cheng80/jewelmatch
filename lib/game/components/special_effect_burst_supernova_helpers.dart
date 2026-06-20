part of 'special_effect_burst.dart';

extension _SpecialEffectBurstSupernovaDrawing on SpecialEffectBurst {
  void _renderSupernova(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final blast = Curves.easeOutCubic.transform(t);
    final radius = tileSize * (0.85 + blast * 4.2);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.86,
      [
        Colors.white.withValues(alpha: 0.34 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.34 * fade),
        baseColor.withValues(alpha: 0.10 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.20, 0.56, 1.0],
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
