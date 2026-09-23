import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../match_board_logic.dart';
import 'baked_glow_atlas.dart';
import 'board_atlas.dart';
import 'bomb_layer_timeline.dart';
import 'area_layer_timeline.dart';

part 'special_effect_burst_bomb_layer_helpers.dart';
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
    double durationScale = 1.0,
  }) {
    this.effectKind = effectKind;
    this.origin = origin;
    this.affectedCenters = affectedCenters;
    this.tileSize = tileSize;
    this.baseColor = baseColor;
    this.performanceTier = performanceTier;
    _lifetime = _lifetimeFor(effectKind) * durationScale.clamp(0.1, 8.0);
    _elapsed = 0;
    _active = true;
  }

  void deactivateForPool() {
    _active = false;
    effectKind = GemKind.normal;
    origin = Vector2.zero();
    affectedCenters = const [];
    tileSize = 0;
    baseColor = Colors.white;
    performanceTier = 0;
    _elapsed = 0;
    _lifetime = 0;
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

  final BakedGlowAtlas _bakedGlow = BakedGlowAtlas();
  final _AreaLayerRenderer _areaLayers = _AreaLayerRenderer();

  /// 붙어 있으면 범위 효과 레이어를 여기 모아 한 번에 그린다. [SpecialEffectPool]이 넣는다.
  AreaLayerBatch? layerBatch;
  final Path _lightningPath = Path();
  final Path _starPath = Path();

  @visibleForTesting
  bool get debugGlowReady => _bakedGlow.isReady;

  /// bomb 레이어 아틀라스가 실제로 로드됐는지. 눈검증과 테스트용이다.
  @visibleForTesting
  static bool get debugBombLayerAtlasReady =>
      _layerAtlases.containsKey(GemKind.bomb);

  @visibleForTesting
  static bool debugLayerAtlasReady(GemKind kind) =>
      _layerAtlases.containsKey(kind);

  /// Images remain owned by Flame.images; resetting definitions must not dispose them.
  @visibleForTesting
  static Future<void> debugReloadAreaEffectSprites({
    required AssetBundle bundle,
    required Future<ui.Image> Function(String) loadImage,
  }) {
    _layerAtlases.clear();
    return _areaEffectAtlasLoadFuture = _loadAreaEffectAtlas(
      BoardAtlas.read(bundle, loadImage),
    );
  }

  @override
  void onMount() {
    super.onMount();
    _bakedGlow.mount();
  }

  @override
  void onRemove() {
    _bakedGlow.dispose();
    super.onRemove();
  }

  static const _hotYellow = Color(0xFFFFF3A4);
  static const _hotOrange = Color(0xFFFF8C36);
  static const _electricBlue = Color(0xFF74F6FF);
  static const _electricViolet = Color(0xFFC88DFF);

  static final Map<GemKind, _AreaLayerAtlas> _layerAtlases = {};
  static Future<void>? _areaEffectAtlasLoadFuture;

  /// 범위 효과 기준 크기(칸 배수). 레이어 칸은 [BoardAtlas]의 `<종류>_0`~`_4`다.
  static const Map<GemKind, double> _areaLayerScales = {
    GemKind.bomb: 4.5,
    GemKind.hyper: 4.35,
    GemKind.supernova: 4.65,
  };

  int get _tier => performanceTier.clamp(0, 2);

  static Future<void> preloadAreaEffectSprites() {
    return _ensureAreaEffectAtlasLoaded();
  }

  static Future<void> _ensureAreaEffectAtlasLoaded() {
    return _areaEffectAtlasLoadFuture ??= _loadAreaEffectAtlas(
      BoardAtlas.load(),
    );
  }

  static Future<void> _loadAreaEffectAtlas(Future<BoardAtlas> source) async {
    try {
      final atlas = await source;
      for (final entry in _areaLayerScales.entries) {
        // 칸이 빠지거나 규격이 틀린 종류만 절차 그림으로 떨어진다.
        final layer = _AreaLayerAtlas.validated(
          atlas: atlas,
          name: entry.key.name,
          scale: entry.value,
        );
        if (layer != null) _layerAtlases[entry.key] = layer;
      }
    } catch (_) {
      _layerAtlases.clear();
    }
  }

  double get _alphaScale {
    switch (_tier) {
      case 0:
        return 1.0;
      case 1:
        return 0.72;
      default:
        return 0.52;
    }
  }

  double get _glowScale {
    switch (_tier) {
      case 0:
        return 1.0;
      case 1:
        return 0.48;
      default:
        return 0.0;
    }
  }

  int _scaledCount(int count) {
    final scale = switch (_tier) {
      0 => 1.0,
      1 => 0.62,
      _ => 0.38,
    };
    return max(1, (count * scale).round());
  }

  int _scaledMaxCells(int count) {
    final scale = switch (_tier) {
      0 => 1.0,
      1 => 0.55,
      _ => 0.28,
    };
    return max(1, (count * scale).round());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _ensureAreaEffectAtlasLoaded();
  }

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
    final effectFade = fade * _alphaScale;

    switch (effectKind) {
      case GemKind.row:
        _renderLightningSweep(canvas, t, effectFade, horizontal: true);
        break;
      case GemKind.col:
        _renderLightningSweep(canvas, t, effectFade, horizontal: false);
        break;
      case GemKind.bomb:
        _renderExplosion(canvas, t, effectFade);
        break;
      case GemKind.star:
        _renderStarLightning(canvas, t, effectFade);
        break;
      case GemKind.hyper:
        _renderHypercube(canvas, t, effectFade);
        break;
      case GemKind.supernova:
        _renderSupernova(canvas, t, effectFade);
        break;
      case GemKind.normal:
        break;
    }
  }
}
