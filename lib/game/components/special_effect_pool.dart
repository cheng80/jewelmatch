import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../match_board_logic.dart';
import 'special_effect_burst.dart';

class SpecialEffectPool {
  SpecialEffectPool(this._parent);

  static const int _maxCachedBursts = 24;

  final Component _parent;
  final List<SpecialEffectBurst> _pool = [];
  final Set<SpecialEffectBurst> _active = <SpecialEffectBurst>{};
  int _activeLineSweeps = 0;

  int get cachedCount => _pool.length;
  int get activeLineSweepCount => _activeLineSweeps;
  int get activeCount => _active.length;

  void spawn({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
  }) {
    final burst = _pool.isNotEmpty ? _pool.removeLast() : _createBurst();
    final isLineSweep = effectKind == GemKind.row || effectKind == GemKind.col;
    final lineSweepTier = isLineSweep
        ? (_activeLineSweeps >= 4 ? 2 : (_activeLineSweeps >= 2 ? 1 : 0))
        : 0;
    final concurrentTier = activeCount >= 5 ? 2 : (activeCount >= 2 ? 1 : 0);
    final webTier = kIsWeb ? 1 : 0;
    final performanceTier = max(max(lineSweepTier, concurrentTier), webTier);
    if (isLineSweep) {
      _activeLineSweeps++;
    }
    _active.add(burst);
    burst.activate(
      effectKind: effectKind,
      origin: origin,
      affectedCenters: affectedCenters,
      tileSize: tileSize,
      baseColor: baseColor,
      performanceTier: performanceTier,
    );
    if (!burst.isMounted) {
      _parent.add(burst);
    }
  }

  SpecialEffectBurst _createBurst() {
    final burst = SpecialEffectBurst();
    burst.onExpired = _returnToPool;
    return burst;
  }

  void _returnToPool(SpecialEffectBurst burst) {
    if (!_active.remove(burst)) return;
    if (burst.effectKind == GemKind.row || burst.effectKind == GemKind.col) {
      _activeLineSweeps = max(0, _activeLineSweeps - 1);
    }
    burst.deactivateForPool();
    if (_pool.length < _maxCachedBursts && burst.parent != null) {
      _pool.add(burst);
    } else {
      burst.removeFromParent();
    }
  }

  void clear() {
    final bursts = <SpecialEffectBurst>{..._active, ..._pool};
    _active.clear();
    _pool.clear();
    _activeLineSweeps = 0;
    for (final burst in bursts) {
      burst.deactivateForPool();
      burst.removeFromParent();
    }
  }
}
