import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../match_board_logic.dart';
import '../../resources/asset_paths.dart';

part 'special_effect_burst_draw_helpers.dart';
part 'special_effect_burst_explosion_helpers.dart';
part 'special_effect_burst_flame_helpers.dart';
part 'special_effect_burst_geometry_helpers.dart';
part 'special_effect_burst_hypercube_helpers.dart';
part 'special_effect_burst_light_helpers.dart';
part 'special_effect_burst_particle_helpers.dart';
part 'special_effect_burst_sprite_helpers.dart';
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

  static const _glow = MaskFilter.blur(BlurStyle.normal, 6);
  static const _hotYellow = Color(0xFFFFF3A4);
  static const _hotOrange = Color(0xFFFF8C36);
  static const _electricBlue = Color(0xFF74F6FF);
  static const _electricViolet = Color(0xFFC88DFF);

  static _SpecialAreaEffectAtlas? _areaEffectAtlas;
  static Future<void>? _areaEffectAtlasLoadFuture;

  int get _tier => performanceTier.clamp(0, 2);

  static Future<void> preloadAreaEffectSprites() {
    return _ensureAreaEffectAtlasLoaded();
  }

  static Future<void> _ensureAreaEffectAtlasLoaded() {
    return _areaEffectAtlasLoadFuture ??= _loadAreaEffectAtlas();
  }

  static Future<void> _loadAreaEffectAtlas() async {
    try {
      final raw =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/images/${AssetPaths.specialAreaEffectManifest}',
                ),
              )
              as Map<String, dynamic>;
      final grid = raw['grid'] as Map<String, dynamic>;
      final columns = (grid['columns'] as num).toInt();
      final rows = (grid['rows'] as num).toInt();
      final frameCount = (grid['frameCount'] as num).toInt();
      final configuredFrameWidth = (grid['frameWidth'] as num?)?.toDouble();
      final configuredFrameHeight = (grid['frameHeight'] as num?)?.toDouble();
      final rawEffects = raw['effects'] as Map<String, dynamic>;
      final effects = <GemKind, _SpecialAreaEffectDefinition>{};

      for (final entry in rawEffects.entries) {
        final kind = _specialAreaEffectKindFromName(entry.key);
        if (kind == null) continue;
        final value = entry.value as Map<String, dynamic>;
        final imagePath = value['image'] as String;
        final image = await Flame.images.load(imagePath);
        final frameWidth = configuredFrameWidth ?? image.width / columns;
        final frameHeight = configuredFrameHeight ?? image.height / rows;
        final frames = <Rect>[];
        for (var i = 0; i < frameCount; i++) {
          final col = i % columns;
          final row = i ~/ columns;
          frames.add(
            Rect.fromLTWH(
              col * frameWidth,
              row * frameHeight,
              frameWidth,
              frameHeight,
            ),
          );
        }
        effects[kind] = _SpecialAreaEffectDefinition(
          image: image,
          frames: frames,
          scale: (value['scale'] as num?)?.toDouble() ?? 4.0,
          centerOffset: Offset(
            (value['centerOffsetX'] as num?)?.toDouble() ?? 0,
            (value['centerOffsetY'] as num?)?.toDouble() ?? 0,
          ),
          blendMode: _specialAreaEffectBlendMode(value['blend'] as String?),
        );
      }
      _areaEffectAtlas = _SpecialAreaEffectAtlas(effects);
    } catch (_) {
      _areaEffectAtlas = const _SpecialAreaEffectAtlas({});
    }
  }

  static GemKind? _specialAreaEffectKindFromName(String name) {
    return switch (name) {
      'bomb' => GemKind.bomb,
      'hyper' => GemKind.hyper,
      'supernova' => GemKind.supernova,
      _ => null,
    };
  }

  static BlendMode _specialAreaEffectBlendMode(String? name) {
    return switch (name) {
      'srcOver' => BlendMode.srcOver,
      _ => BlendMode.plus,
    };
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

class _SpecialAreaEffectAtlas {
  const _SpecialAreaEffectAtlas(this.effects);

  final Map<GemKind, _SpecialAreaEffectDefinition> effects;

  _SpecialAreaEffectDefinition? definitionFor(GemKind kind) => effects[kind];
}

class _SpecialAreaEffectDefinition {
  const _SpecialAreaEffectDefinition({
    required this.image,
    required this.frames,
    required this.scale,
    required this.centerOffset,
    required this.blendMode,
  });

  final ui.Image image;
  final List<Rect> frames;
  final double scale;
  final Offset centerOffset;
  final BlendMode blendMode;

  Rect frameFor(double t) {
    final index = (t.clamp(0.0, 1.0) * frames.length).floor().clamp(
      0,
      frames.length - 1,
    );
    return frames[index];
  }
}
