import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 우주 배경 컴포넌트.
/// 그라데이션 배경 위에 크기와 밝기가 다른 별들을 그린다.
class SpaceBg extends PositionComponent with HasGameReference {
  static const int _starCount = 120;
  final Random _rng = Random();

  late List<_Star> _stars;
  late Paint _bgPaint;

  /// 배경 그라데이션과 별 목록 초기화.
  @override
  Future<void> onLoad() async {
    _initSizeAndStars();
    priority = -1;
  }

  /// 창 크기 변경 시 배경 크기·별 위치 재계산.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _initSizeAndStars();
  }

  void _initSizeAndStars() {
    size = game.size;
    // Jewel Candy Lumina: 보라–마젠타–딥블루, 칙칙한 회색 톤 제거
    _bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3D0A6B),
          Color(0xFF6A148C),
          Color(0xFF12085C),
          Color(0xFF4A148C),
          Color(0xFF190033),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    _stars = List.generate(_starCount, (_) => _createStar());
  }

  /// 랜덤 위치·크기·속도·색상의 별 하나를 생성한다.
  _Star _createStar() {
    // 반지름 0.3~2.1, 위치 랜덤.
    final radius = _rng.nextDouble() * 1.8 + 0.3;
    return _Star(
      x: _rng.nextDouble() * size.x,
      y: _rng.nextDouble() * size.y,
      radius: radius,
      baseAlpha: _rng.nextDouble() * 0.5 + 0.3,
      twinkleSpeed: _rng.nextDouble() * 2.0 + 0.5,
      twinkleOffset: _rng.nextDouble() * 2 * pi,
      color: _starColor(),
    );
  }

  /// 확률에 따라 별 색상을 반환한다. 70% 흰색, 15% 하늘색, 10% 노랑, 5% 분홍.
  Color _starColor() {
    final roll = _rng.nextDouble();
    if (roll < 0.55) return Colors.white;
    if (roll < 0.7) return const Color(0xFF00FBFB);
    if (roll < 0.82) return const Color(0xFFFF86C1);
    if (roll < 0.92) return const Color(0xFFFFEA00);
    return const Color(0xFFE1BEE7);
  }

  /// 각 별의 time을 누적하여 깜박임 주기에 사용.
  @override
  void update(double dt) {
    super.update(dt);
    for (final star in _stars) {
      star.time += dt;
    }
  }

  /// 그라데이션 배경 위에 크기·밝기가 다른 별들을 그린다. 큰 별은 글로우 효과.
  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _bgPaint);

    for (final star in _stars) {
      // sin으로 별마다 다른 속도/오프셋의 깜박임.
      final twinkle = sin(star.time * star.twinkleSpeed + star.twinkleOffset);
      final alpha = (star.baseAlpha + twinkle * 0.3).clamp(0.05, 1.0);
      final paint = Paint()..color = star.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);

      // 큰 별은 블러로 글로우 효과.
      if (star.radius > 1.2) {
        final glowPaint = Paint()
          ..color = star.color.withValues(alpha: alpha * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(star.x, star.y), star.radius * 2.5, glowPaint);
      }
    }
  }
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double baseAlpha;
  final double twinkleSpeed;
  final double twinkleOffset;
  final Color color;
  double time = 0;

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
