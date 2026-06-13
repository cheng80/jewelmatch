part of 'special_effect_burst.dart';

extension _SpecialEffectBurstGeometryHelpers on SpecialEffectBurst {
  Offset _axisExtreme({required bool horizontal, required bool first}) {
    if (affectedCenters.isEmpty) return origin.toOffset();
    var chosen = affectedCenters.first;
    for (final center in affectedCenters.skip(1)) {
      if (horizontal) {
        if ((first && center.x < chosen.x) || (!first && center.x > chosen.x)) {
          chosen = center;
        }
      } else {
        if ((first && center.y < chosen.y) || (!first && center.y > chosen.y)) {
          chosen = center;
        }
      }
    }
    return chosen.toOffset();
  }

  Offset _orbitPoint(Offset center, double radius, double t, int i) {
    final angle = i * 2 * pi / 18 + t * pi * (1.6 + (i % 3) * 0.25);
    final wobble = sin(t * pi * 4 + i) * tileSize * 0.12;
    return center + Offset(cos(angle), sin(angle)) * (radius + wobble);
  }

  double _hash(int value) {
    final n = sin(value * 12.9898 + 78.233) * 43758.5453;
    return n - n.floorToDouble();
  }

  double _easeOut(double value) => 1 - pow(1 - value, 3).toDouble();
}
