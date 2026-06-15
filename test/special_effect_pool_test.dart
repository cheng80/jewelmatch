import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/components/special_effect_pool.dart';
import 'package:stonematch/game/match_board_logic.dart';

void main() {
  test('special effect pool reuses expired burst instances', () {
    final parent = Component();
    final pool = SpecialEffectPool(parent);

    pool.spawn(
      effectKind: GemKind.bomb,
      origin: Vector2.zero(),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.orange,
    );

    expect(pool.cachedCount, 0);
    final first = parent.children.whereType<SpecialEffectBurst>().single;
    first.update(1);

    expect(pool.cachedCount, 1);

    pool.spawn(
      effectKind: GemKind.star,
      origin: Vector2.all(10),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.blue,
    );

    final second = parent.children.whereType<SpecialEffectBurst>().single;
    expect(identical(first, second), isTrue);
    expect(second.effectKind, GemKind.star);
    expect(pool.cachedCount, 0);
  });

  test('line sweep effects use adaptive performance tiers', () {
    final parent = Component();
    final pool = SpecialEffectPool(parent);

    for (var i = 0; i < 5; i++) {
      pool.spawn(
        effectKind: GemKind.row,
        origin: Vector2.all(i.toDouble()),
        affectedCenters: const [],
        tileSize: 64,
        baseColor: Colors.cyan,
      );
    }

    final tiers = parent.children
        .whereType<SpecialEffectBurst>()
        .map((burst) => burst.performanceTier)
        .toList(growable: false);

    expect(tiers, equals([0, 0, 1, 1, 2]));
    expect(pool.activeLineSweepCount, 5);

    for (final burst in parent.children.whereType<SpecialEffectBurst>()) {
      burst.update(1);
    }

    expect(pool.activeLineSweepCount, 0);
    expect(pool.cachedCount, 5);
  });
}
