import 'dart:math';

import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';

/// 전체 화면 우주 배경. 앱 전역에서 단일 인스턴스만 사용한다.
///
/// - 그라데이션과 별을 3 그룹으로 나눠 각각 [RepaintBoundary]로 래스터 캐싱.
/// - 정적 배경으로 유지해 WebView에서 화면 전체 합성을 반복하지 않는다.
class StarryBackground extends StatelessWidget {
  const StarryBackground._();

  static const Widget instance = StarryBackground._();
  static const _groupCount = 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final groups = _StarPool.groups(_groupCount);
        final ruinsBackgroundSize = size.height;

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
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _StarGroupPainter(stars: groups[i]),
                    isComplex: true,
                    willChange: false,
                  ),
                ),
              ),
            Positioned.fill(
              child: RepaintBoundary(
                child: Center(
                  child: OverflowBox(
                    minWidth: ruinsBackgroundSize,
                    maxWidth: ruinsBackgroundSize,
                    minHeight: ruinsBackgroundSize,
                    maxHeight: ruinsBackgroundSize,
                    child: SizedBox.square(
                      dimension: ruinsBackgroundSize,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x99FFFFFF),
                            Colors.white,
                            Colors.white,
                            Color(0x99FFFFFF),
                            Colors.transparent,
                          ],
                          stops: [0, 0.08, 0.26, 0.74, 0.92, 1],
                        ).createShader(bounds),
                        child: Image.asset(
                          AssetPaths.ancientRuinsSpaceBackground,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
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
    Color(0xFF090C1B),
    Color(0xFF101A31),
    Color(0xFF1B1238),
    Color(0xFF130824),
    Color(0xFF070813),
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
      groups[i % groupCount].add(
        _Star(
          nx: rng.nextDouble(),
          ny: rng.nextDouble(),
          radius: rng.nextDouble() * 1.8 + 0.3,
          alpha: rng.nextDouble() * 0.5 + 0.3,
          color: _starColor(rng),
        ),
      );
    }

    return groups;
  }

  static Color _starColor(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.7) return const Color(0xFFE9E1D2);
    if (roll < 0.85) return const Color(0xFF9FB7BC);
    if (roll < 0.95) return const Color(0xFFD8BE78);
    return const Color(0xFF9B5A4F);
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
