import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/particle_burst.dart';
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

  test('special effect pool can be warmed before first spawn', () async {
    final parent = Component();
    final pool = SpecialEffectPool(parent);

    await pool.warm(burstCount: 3);

    expect(pool.cachedCount, 3);

    pool.spawn(
      effectKind: GemKind.bomb,
      origin: Vector2.zero(),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.orange,
    );

    expect(pool.cachedCount, 2);
    expect(pool.activeCount, 1);
  });

  test('particle pool can be warmed with particle capacity', () async {
    final parent = Component();
    final pool = ParticlePool(parent);

    await pool.warm(burstCount: 4, particleCapacity: 18);

    expect(pool.cachedCount, 4);

    pool.spawn(center: Vector2.zero(), baseColor: Colors.orange, count: 18);

    expect(pool.cachedCount, 3);
    expect(pool.activeCount, 1);
  });

  test('line sweep effects use adaptive performance tiers', () {
    final parent = Component();
    final pool = SpecialEffectPool(parent, constrainedDevice: false);

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

  test('constrained devices preserve bomb detail and reduce wider effects', () {
    final parent = Component();
    final pool = SpecialEffectPool(parent, constrainedDevice: true);

    pool.spawn(
      effectKind: GemKind.bomb,
      origin: Vector2.zero(),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.orange,
    );
    pool.spawn(
      effectKind: GemKind.hyper,
      origin: Vector2.all(10),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.purple,
    );

    final tiers = parent.children
        .whereType<SpecialEffectBurst>()
        .map((burst) => burst.performanceTier)
        .toList(growable: false);

    expect(tiers, equals([1, 2]));
  });

  test('desktop high impact effects still avoid full cost when overlapping', () {
    final parent = Component();
    final pool = SpecialEffectPool(parent, constrainedDevice: false);

    pool.spawn(
      effectKind: GemKind.bomb,
      origin: Vector2.zero(),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.orange,
    );
    pool.spawn(
      effectKind: GemKind.bomb,
      origin: Vector2.all(10),
      affectedCenters: const [],
      tileSize: 64,
      baseColor: Colors.orange,
    );

    final tiers = parent.children
        .whereType<SpecialEffectBurst>()
        .map((burst) => burst.performanceTier)
        .toList(growable: false);

    expect(tiers, equals([1, 2]));
  });
}
