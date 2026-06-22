part of 'special_effect_burst.dart';

extension _SpecialEffectBurstFlameDrawing on SpecialEffectBurst {
  void _renderExplosion(Canvas canvas, double t, double fade) {
    if (_renderAreaEffectSprite(canvas, t, fade)) return;

    final center = origin.toOffset();
    final heat = Curves.easeOutBack.transform(min(t * 1.28, 1));
    final radius = tileSize * (0.46 + heat * 2.28);
    final tier = _tier;

    if (tier == 0) {
      _drawRadialGlow(
        canvas,
        center,
        radius * 0.92,
        [
          Colors.white.withValues(alpha: 0.34 * fade),
          SpecialEffectBurst._hotYellow.withValues(alpha: 0.48 * fade),
          SpecialEffectBurst._hotOrange.withValues(alpha: 0.23 * fade),
          Colors.transparent,
        ],
        const [0.0, 0.14, 0.54, 1.0],
      );
    }

    _drawExplosionCloud(canvas, center, radius, t, fade);
    if (tier == 0) {
      _drawPlasmaArcs(canvas, center, radius * 0.80, t, fade);
    }
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: tier == 0 ? 8 : 4,
      length: radius * 1.18,
    );
    _drawBurstStreaks(
      canvas,
      center,
      t,
      fade,
      count: tier == 0 ? 18 : 8,
      spread: radius * 1.34,
    );
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: tier == 0 ? 28 : 12,
      spread: radius * 1.26,
      color: SpecialEffectBurst._hotOrange,
    );
    if (tier == 0) {
      _drawEmbers(canvas, center, t, fade, count: 10, spread: radius * 1.18);
      _drawCellFlash(
        canvas,
        t,
        fade,
        maxCells: 5,
        color: SpecialEffectBurst._hotOrange,
      );
    }
  }
}
