import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../match_board_logic.dart';
import 'special_effect_burst.dart';

class SpecialEffectPool {
  SpecialEffectPool(this._parent, {bool? constrainedDevice})
    : _constrainedDevice = constrainedDevice ?? _defaultConstrainedDevice;

  static const int _maxCachedBursts = 24;

  final Component _parent;
  final bool _constrainedDevice;
  final List<SpecialEffectBurst> _pool = [];
  final Set<SpecialEffectBurst> _active = <SpecialEffectBurst>{};
  int _activeLineSweeps = 0;

  int get cachedCount => _pool.length;
  int get activeLineSweepCount => _activeLineSweeps;
  int get activeCount => _active.length;

  static bool get _defaultConstrainedDevice {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => false,
    };
  }

  Future<void> warm({required int burstCount}) async {
    final pendingLoads = <Future<void>>[];
    while (_pool.length < burstCount) {
      final burst = _createBurst();
      final added = _parent.add(burst);
      if (added is Future<void>) {
        pendingLoads.add(added);
      }
      _pool.add(burst);
    }
    if (pendingLoads.isNotEmpty) {
      await Future.wait(pendingLoads);
    }
  }

  void spawn({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
    double durationScale = 1.0,
  }) {
    final burst = _pool.isNotEmpty ? _pool.removeLast() : _createBurst();
    final isLineSweep = effectKind == GemKind.row || effectKind == GemKind.col;
    final lineSweepTier = isLineSweep
        ? (_activeLineSweeps >= 4 ? 2 : (_activeLineSweeps >= 2 ? 1 : 0))
        : 0;
    final concurrentTier = _concurrentTierFor(effectKind);
    final deviceTier = _deviceTierFor(effectKind);
    final performanceTier = max(max(lineSweepTier, concurrentTier), deviceTier);
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
      durationScale: durationScale,
    );
    if (!burst.isMounted) {
      _parent.add(burst);
    }
  }

  int _concurrentTierFor(GemKind kind) {
    final highImpact = _isHighImpact(kind);
    if (activeCount >= 5 || (highImpact && activeCount >= 1)) return 2;
    if (activeCount >= 2 || highImpact) return 1;
    return 0;
  }

  int _deviceTierFor(GemKind kind) {
    if (!_constrainedDevice) return 0;
    return switch (kind) {
      GemKind.bomb => 1,
      GemKind.hyper || GemKind.supernova => 2,
      GemKind.row || GemKind.col || GemKind.star => 1,
      GemKind.normal => 0,
    };
  }

  bool _isHighImpact(GemKind kind) {
    return switch (kind) {
      GemKind.bomb || GemKind.hyper || GemKind.supernova => true,
      GemKind.row || GemKind.col || GemKind.star || GemKind.normal => false,
    };
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
