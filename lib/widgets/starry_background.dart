import 'dart:math';

import 'package:flutter/material.dart';

/// 전체 화면 우주 배경. 웹에서 게임 영역 밖을 채우기 위해 사용.
/// SpaceBg와 동일한 그라데이션·별 스타일.
class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  List<_Star> _stars = [];
  Size _lastSize = Size.zero;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initStars(Size size) {
    final rng = Random(42);
    _stars = List.generate(120, (_) {
      return _Star(
        x: rng.nextDouble() * size.width,
        y: rng.nextDouble() * size.height,
        radius: rng.nextDouble() * 1.8 + 0.3,
        baseAlpha: rng.nextDouble() * 0.5 + 0.3,
        twinkleSpeed: rng.nextDouble() * 2.0 + 0.5,
        twinkleOffset: rng.nextDouble() * 2 * pi,
        color: _starColor(rng),
      );
    });
  }

  Color _starColor(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.7) return Colors.white;
    if (roll < 0.85) return const Color(0xFFAADDFF);
    if (roll < 0.95) return const Color(0xFFFFEEAA);
    return const Color(0xFFFFAAAA);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_stars.isEmpty || size != _lastSize) {
          _lastSize = size;
          _initStars(size);
        }
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: size,
              painter: _StarryPainter(_stars, _controller.value),
            );
          },
        );
      },
    );
  }
}

class _StarryPainter extends CustomPainter {
  _StarryPainter(this.stars, this.time);
  final List<_Star> stars;
  final double time;

  static const _gradientColors = [
    Color(0xFF05051A),
    Color(0xFF0A0A2E),
    Color(0xFF12123A),
    Color(0xFF0A0A2E),
    Color(0xFF05051A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _gradientColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (final star in stars) {
      final twinkle =
          sin(time * 2 * pi * star.twinkleSpeed + star.twinkleOffset);
      final alpha =
          (star.baseAlpha + twinkle * 0.3).clamp(0.05, 1.0).toDouble();
      final paint = Paint()..color = star.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);

      if (star.radius > 1.2) {
        final glowPaint = Paint()
          ..color = star.color.withValues(alpha: alpha * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(
          Offset(star.x, star.y),
          star.radius * 2.5,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarryPainter oldDelegate) =>
      oldDelegate.time != time;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double baseAlpha;
  final double twinkleSpeed;
  final double twinkleOffset;
  final Color color;

  _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseAlpha,
    required this.twinkleSpeed,
    required this.twinkleOffset,
    required this.color,
  });
}
