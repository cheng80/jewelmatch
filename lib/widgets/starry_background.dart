import 'dart:math';

import 'package:flutter/material.dart';

/// 전체 화면 우주 배경. 웹에서 게임 영역 밖을 채우기 위해 사용.
///
/// - 그라데이션과 별을 3 그룹으로 나눠 각각 [RepaintBoundary]로 래스터 캐싱.
/// - 깜빡임은 [FadeTransition](GPU 컴포지터 alpha)으로만 처리하므로
///   paint()가 최초 1회 이후 다시 호출되지 않는다.
class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _groupAnimations;

  static const _groupCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _groupAnimations = List.generate(_groupCount, (i) {
      final start = i / (_groupCount * 2);
      final end = start + 0.6;
      return Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final groups = _StarPool.groups(_groupCount);

        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: const _GradientPainter(),
                  isComplex: true,
                  willChange: false,
                ),
              ),
            ),
            for (var i = 0; i < _groupCount; i++)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _groupAnimations[i],
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: _StarGroupPainter(stars: groups[i]),
                      isComplex: true,
                      willChange: false,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _GradientPainter extends CustomPainter {
  const _GradientPainter();

  static const _colors = [
    Color(0xFF05051A),
    Color(0xFF0A0A2E),
    Color(0xFF12123A),
    Color(0xFF0A0A2E),
    Color(0xFF05051A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _colors,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) => false;
}

class _StarGroupPainter extends CustomPainter {
  const _StarGroupPainter({required this.stars});

  final List<_Star> stars;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final x = star.nx * size.width;
      final y = star.ny * size.height;
      final paint = Paint()..color = star.color.withValues(alpha: star.alpha);
      canvas.drawCircle(Offset(x, y), star.radius, paint);

      if (star.radius > 1.2) {
        final glowPaint = Paint()
          ..color = star.color.withValues(alpha: star.alpha * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), star.radius * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarGroupPainter oldDelegate) =>
      !identical(oldDelegate.stars, stars);
}

// ---------------------------------------------------------------------------
// Star data pool — 정규화 좌표(0~1), 1회만 생성
// ---------------------------------------------------------------------------

class _StarPool {
  _StarPool._();

  static List<List<_Star>>? _cached;
  static int _cachedGroupCount = 0;

  static List<List<_Star>> groups(int groupCount) {
    if (_cached != null && _cachedGroupCount == groupCount) return _cached!;
    _cachedGroupCount = groupCount;
    _cached = _generate(groupCount);
    return _cached!;
  }

  static List<List<_Star>> _generate(int groupCount) {
    final rng = Random(42);
    final groups = List.generate(groupCount, (_) => <_Star>[]);

    for (var i = 0; i < 120; i++) {
      groups[i % groupCount].add(_Star(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        radius: rng.nextDouble() * 1.8 + 0.3,
        alpha: rng.nextDouble() * 0.5 + 0.3,
        color: _starColor(rng),
      ));
    }

    return groups;
  }

  static Color _starColor(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.7) return Colors.white;
    if (roll < 0.85) return const Color(0xFFAADDFF);
    if (roll < 0.95) return const Color(0xFFFFEEAA);
    return const Color(0xFFFFAAAA);
  }
}

class _Star {
  const _Star({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.alpha,
    required this.color,
  });

  final double nx;
  final double ny;
  final double radius;
  final double alpha;
  final Color color;
}
