import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 보석 제거 시 방사형 파티클 이펙트.
///
/// [center]에서 [count]개의 입자가 랜덤 방향·속도로 퍼지며,
/// 수명([lifetime])이 다하면 컴포넌트 스스로 제거된다.
/// [speedScale]·[sizeScale]로 화려함 단계 조절.
/// 참조: github.com/VatsalBhesaniya/Flutter-Animations/particle_explosions
class ParticleBurst extends PositionComponent {
  ParticleBurst({
    required Vector2 center,
    required this.baseColor,
    this.count = 8,
    this.lifetime = 0.4,
    this.speedScale = 1.0,
    this.sizeScale = 1.0,
    this.withGlow = false,
  }) {
    position = center;
  }

  final Color baseColor;
  final int count;
  final double lifetime;
  final double speedScale;
  final double sizeScale;
  /// 큰 입자 주변에 블러 글로우를 그릴지 (화려한 연출용).
  final bool withGlow;

  late final List<_Particle> _particles;
  double _elapsed = 0;

  static final Random _rng = Random();

  /// 색상 변주용 밝은 악센트 색상 풀.
  static const _accentColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF176),
    Color(0xFF80DEEA),
    Color(0xFFFF80AB),
    Color(0xFFB388FF),
    Color(0xFF69F0AE),
  ];

  @override
  Future<void> onLoad() async {
    priority = 100;
    _particles = List.generate(count, (_) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = (_rng.nextDouble() * 180 + 60) * speedScale;
      final hsl = HSLColor.fromColor(baseColor);

      // 30% 확률로 악센트 색상 혼합 → 색상 다양성
      Color tweaked;
      if (_rng.nextDouble() < 0.3) {
        final accent = _accentColors[_rng.nextInt(_accentColors.length)];
        tweaked = Color.lerp(baseColor, accent, 0.35 + _rng.nextDouble() * 0.3)!;
      } else {
        tweaked = hsl
            .withLightness((hsl.lightness + _rng.nextDouble() * 0.4).clamp(0, 1))
            .withSaturation((hsl.saturation + _rng.nextDouble() * 0.2 - 0.1).clamp(0, 1))
            .toColor();
      }

      return _Particle(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed,
        radius: (_rng.nextDouble() * 3.5 + 1.2) * sizeScale,
        color: tweaked,
      );
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= lifetime) {
      removeFromParent();
      return;
    }
    for (final p in _particles) {
      p.x += p.dx * dt;
      p.y += p.dy * dt;
      p.dx *= 0.94;
      p.dy *= 0.94;
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / lifetime).clamp(0.0, 1.0);
    // 전반 20%는 불투명 유지, 이후 감쇠 → 시작부터 확 보임
    final alpha = progress < 0.2 ? 1.0 : 1.0 - ((progress - 0.2) / 0.8);
    final paint = Paint();
    for (final p in _particles) {
      final r = p.radius * (1.0 - progress * 0.3);
      paint.color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.x, p.y), r, paint);
      if (withGlow && r > 1.5) {
        paint
          ..color = p.color.withValues(alpha: alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(Offset(p.x, p.y), r * 2.5, paint);
        paint.maskFilter = null;
      }
    }
  }
}

class _Particle {
  double x = 0;
  double y = 0;
  double dx;
  double dy;
  final double radius;
  final Color color;

  _Particle({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.color,
  });
}
