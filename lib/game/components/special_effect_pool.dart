import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../match_board_logic.dart';
import 'special_effect_burst.dart';

class SpecialEffectPool {
  SpecialEffectPool(this._parent);

  final Component _parent;
  final List<SpecialEffectBurst> _pool = [];
  int _activeLineSweeps = 0;

  int get cachedCount => _pool.length;
  int get activeLineSweepCount => _activeLineSweeps;

  void spawn({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
  }) {
    final burst = _pool.isNotEmpty ? _pool.removeLast() : _createBurst();
    final isLineSweep = effectKind == GemKind.row || effectKind == GemKind.col;
    final performanceTier = isLineSweep
        ? (_activeLineSweeps >= 4 ? 2 : (_activeLineSweeps >= 2 ? 1 : 0))
        : 0;
    if (isLineSweep) {
      _activeLineSweeps++;
    }
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
    if (burst.effectKind == GemKind.row || burst.effectKind == GemKind.col) {
      _activeLineSweeps = max(0, _activeLineSweeps - 1);
    }
    _pool.add(burst);
  }
}
