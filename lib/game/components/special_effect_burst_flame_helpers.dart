part of 'special_effect_burst.dart';

extension _SpecialEffectBurstFlameDrawing on SpecialEffectBurst {
  void _renderExplosion(Canvas canvas, double t, double fade) {
    // 레이어 경로가 먼저다. 글로우를 낱장보다 먼저 깔고 한 동작으로 움직인다.
    final layerAtlas = SpecialEffectBurst._bombLayerAtlas;
    if (layerAtlas != null) {
      final tierScale = switch (_tier) {
        0 => 1.0,
        1 => 0.94,
        _ => 0.86,
      };
      _bombLayers.render(
        canvas,
        layerAtlas,
        _bakedGlow,
        origin.toOffset(),
        tileSize * layerAtlas.scale * tierScale,
        t,
        fade,
        _glowScale,
      );
      return;
    }
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
        GlowRadial.bomb,
        Colors.white.withValues(alpha: 0.34 * fade),
        SpecialEffectBurst._hotYellow.withValues(alpha: 0.48 * fade),
        SpecialEffectBurst._hotOrange.withValues(alpha: 0.23 * fade),
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
