import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/jewel_candy_lumina_theme.dart';

class TitleMysticSmokeEffect extends StatefulWidget {
  const TitleMysticSmokeEffect({super.key});

  @override
  State<TitleMysticSmokeEffect> createState() => _TitleMysticSmokeEffectState();
}

class _TitleMysticSmokeEffectState extends State<TitleMysticSmokeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MysticSmokePainter(animation: _controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MysticSmokePainter extends CustomPainter {
  _MysticSmokePainter({required Animation<double> animation})
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;

  static const _cycleSeconds = 3600.0;
  static const _fogCool = Color(0xFFD7DEDD);
  static const _fogBlue = Color(0xFF78989D);
  static final _layers = <_FogLayerSpec>[
    _FogLayerSpec(
      texture: _FogTexture.generate(seed: 41, count: 42),
      speed: 15,
      alpha: 0.34,
      y: 0.48,
      height: 0.28,
      blur: 18,
    ),
    _FogLayerSpec(
      texture: _FogTexture.generate(seed: 73, count: 52),
      speed: 10,
      alpha: 0.27,
      y: 0.56,
      height: 0.30,
      blur: 24,
    ),
    _FogLayerSpec(
      texture: _FogTexture.generate(seed: 109, count: 62),
      speed: 5,
      alpha: 0.20,
      y: 0.64,
      height: 0.28,
      blur: 30,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final elapsed = _animation.value * _cycleSeconds;
    final sceneSize = size.height;
    final scene = Rect.fromLTWH(
      (size.width - sceneSize) / 2,
      0,
      sceneSize,
      sceneSize,
    );
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    _paintAtmosphericVeil(canvas, scene, _animation.value);
    for (final layer in _layers.reversed) {
      _paintFogLayer(canvas, scene, layer, elapsed);
    }
    _applySceneMask(canvas, scene);
    canvas.restore();
    _paintDimmingVeil(canvas, scene, _animation.value);
  }

  void _paintAtmosphericVeil(Canvas canvas, Rect scene, double t) {
    final pulse = 0.5 + math.sin(t * math.pi * 2) * 0.5;
    final rect = Rect.fromLTWH(
      scene.left + scene.width * 0.03,
      scene.top + scene.height * 0.42,
      scene.width * 0.94,
      scene.height * 0.52,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.25),
        radius: 0.86,
        colors: [
          _fogCool.withValues(alpha: 0.145 + pulse * 0.025),
          _fogBlue.withValues(alpha: 0.095 + pulse * 0.018),
          Colors.transparent,
        ],
        stops: const [0, 0.58, 1],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    canvas.drawOval(rect, paint);
  }

  void _paintFogLayer(
    Canvas canvas,
    Rect scene,
    _FogLayerSpec layer,
    double elapsed,
  ) {
    final tileWidth = scene.width;
    final offset = (elapsed * layer.speed) % tileWidth;
    final layerTop = scene.top + scene.height * layer.y;
    final layerHeight = scene.height * layer.height;
    final shortSide = scene.shortestSide;
    for (var repeat = -1; repeat <= 2; repeat++) {
      final baseX = scene.left + repeat * tileWidth - offset;
      for (final dot in layer.texture.dots) {
        final center = Offset(
          baseX + dot.x * tileWidth,
          layerTop + dot.y * layerHeight,
        );
        final sceneX = ((center.dx - scene.left) / scene.width).clamp(0.0, 1.0);
        final edgeFade = _backgroundEdgeFade(sceneX) * _verticalFade(dot.y);
        if (edgeFade <= 0) continue;
        final radius = dot.radius * shortSide;
        final color = Color.lerp(_fogBlue, _fogCool, dot.warmth * 0.68)!;
        final paint = Paint()
          ..color = color.withValues(alpha: dot.alpha * layer.alpha * edgeFade)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(layer.blur, radius * 0.72),
          );
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  double _backgroundEdgeFade(double x) {
    if (x <= 0.08 || x >= 0.92) return 0;
    if (x < 0.26) {
      return Curves.easeInOut.transform((x - 0.08) / 0.18);
    }
    if (x > 0.74) {
      return Curves.easeInOut.transform((0.92 - x) / 0.18);
    }
    return 1;
  }

  double _verticalFade(double y) {
    final top = (y / 0.22).clamp(0.0, 1.0);
    final bottom = ((1 - y) / 0.16).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(math.min(top, bottom));
  }

  void _paintDimmingVeil(Canvas canvas, Rect scene, double t) {
    final pulse = 0.5 + math.sin(t * math.pi * 2) * 0.5;
    final rect = Rect.fromLTWH(
      scene.left + scene.width * 0.08,
      scene.top + scene.height * 0.44,
      scene.width * 0.84,
      scene.height * 0.58,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.42),
        radius: 0.86,
        colors: [
          JewelCandyLuminaTheme.surface.withValues(alpha: 0),
          JewelCandyLuminaTheme.surface.withValues(
            alpha: 0.012 + pulse * 0.006,
          ),
          JewelCandyLuminaTheme.surface.withValues(alpha: 0.04),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(rect)
      ..blendMode = BlendMode.multiply;
    canvas.drawOval(rect, paint);
  }

  void _applySceneMask(Canvas canvas, Rect scene) {
    final paint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          Color(0x99FFFFFF),
          Colors.white,
          Colors.white,
          Color(0x99FFFFFF),
          Colors.transparent,
        ],
        stops: [0, 0.08, 0.26, 0.74, 0.92, 1],
      ).createShader(scene);
    canvas.drawRect(scene, paint);
  }

  @override
  bool shouldRepaint(covariant _MysticSmokePainter oldDelegate) =>
      oldDelegate._animation != _animation;
}

class _FogLayerSpec {
  const _FogLayerSpec({
    required this.texture,
    required this.speed,
    required this.alpha,
    required this.y,
    required this.height,
    required this.blur,
  });

  final _FogTexture texture;
  final double speed;
  final double alpha;
  final double y;
  final double height;
  final double blur;
}

class _FogTexture {
  const _FogTexture({required this.dots});

  factory _FogTexture.generate({required int seed, required int count}) {
    final rng = math.Random(seed);
    final dots = <_NoiseDot>[];
    for (var i = 0; i < count; i++) {
      dots.add(
        _NoiseDot(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          radius: 0.020 + rng.nextDouble() * 0.050,
          alpha: 0.32 + rng.nextDouble() * 0.34,
          warmth: rng.nextDouble(),
        ),
      );
    }
    return _FogTexture(dots: dots);
  }

  final List<_NoiseDot> dots;
}

class _NoiseDot {
  const _NoiseDot({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.warmth,
  });

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double warmth;
}
