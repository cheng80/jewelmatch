import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../match_board_logic.dart';

part 'special_effect_burst_draw_helpers.dart';
part 'special_effect_burst_explosion_helpers.dart';
part 'special_effect_burst_flame_helpers.dart';
part 'special_effect_burst_geometry_helpers.dart';
part 'special_effect_burst_hypercube_helpers.dart';
part 'special_effect_burst_light_helpers.dart';
part 'special_effect_burst_particle_helpers.dart';
part 'special_effect_burst_supernova_helpers.dart';
part 'special_effect_burst_sweep_helpers.dart';

class SpecialEffectBurst extends PositionComponent {
  SpecialEffectBurst() {
    priority = 120;
  }

  void Function(SpecialEffectBurst)? _onExpired;
  set onExpired(void Function(SpecialEffectBurst)? value) {
    _onExpired = value;
  }

  void activate({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
    int performanceTier = 0,
  }) {
    this.effectKind = effectKind;
    this.origin = origin;
    this.affectedCenters = affectedCenters;
    this.tileSize = tileSize;
    this.baseColor = baseColor;
    this.performanceTier = performanceTier;
    _lifetime = _lifetimeFor(effectKind);
    _elapsed = 0;
    _active = true;
  }

  GemKind effectKind = GemKind.normal;
  Vector2 origin = Vector2.zero();
  List<Vector2> affectedCenters = const [];
  double tileSize = 0;
  Color baseColor = Colors.white;
  int performanceTier = 0;
  double _lifetime = 0;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;
  final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  double _elapsed = 0;
  bool _active = false;

  static const _glow = MaskFilter.blur(BlurStyle.normal, 6);
  static const _hotYellow = Color(0xFFFFF3A4);
  static const _hotOrange = Color(0xFFFF8C36);
  static const _electricBlue = Color(0xFF74F6FF);
  static const _electricViolet = Color(0xFFC88DFF);

  static double _lifetimeFor(GemKind kind) {
    switch (kind) {
      case GemKind.row:
      case GemKind.col:
        return 0.34;
      case GemKind.bomb:
        return 0.52;
      case GemKind.star:
        return 0.44;
      case GemKind.hyper:
        return 0.60;
      case GemKind.supernova:
        return 0.72;
      case GemKind.normal:
        return 0.20;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_active) return;
    _elapsed += dt;
    if (_elapsed >= _lifetime) {
      _active = false;
      if (_onExpired != null) {
        _onExpired!(this);
      } else {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    final t = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final fade = _easeOut(1 - t);
    if (fade <= 0) return;

    switch (effectKind) {
      case GemKind.row:
        _renderLightningSweep(canvas, t, fade, horizontal: true);
        break;
      case GemKind.col:
        _renderLightningSweep(canvas, t, fade, horizontal: false);
        break;
      case GemKind.bomb:
        _renderFlame(canvas, t, fade);
        break;
      case GemKind.star:
        _renderStarLightning(canvas, t, fade);
        break;
      case GemKind.hyper:
        _renderHypercube(canvas, t, fade);
        break;
      case GemKind.supernova:
        _renderSupernova(canvas, t, fade);
        break;
      case GemKind.normal:
        break;
    }
  }
}
