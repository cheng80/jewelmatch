import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 보석 제거 시 방사형 파티클 이펙트 (오브젝트 풀링 지원).
///
/// [activate]로 파라미터를 설정하고 재사용한다.
/// 수명이 다하면 [removeFromParent] 대신 [_onExpired] 콜백으로 풀에 반납된다.
class ParticleBurst extends PositionComponent {
  ParticleBurst();

  /// 풀 매니저가 수명 만료 시 반납받기 위해 설정하는 콜백.
  void Function(ParticleBurst)? _onExpired;

  Color _baseColor = Colors.white;
  int _count = 8;
  double _lifetime = 0.4;
  double _speedScale = 1.0;
  double _sizeScale = 1.0;
  bool _withGlow = false;

  final List<_Particle> _particles = [];
  double _elapsed = 0;
  bool _active = false;

  static final Random _rng = Random();

  static const _accentColors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFF176),
    Color(0xFF80DEEA),
    Color(0xFFFF80AB),
    Color(0xFFB388FF),
    Color(0xFF69F0AE),
  ];

  /// 풀에서 꺼낸 뒤 파라미터를 설정하고 활성화한다.
  void activate({
    required Vector2 center,
    required Color baseColor,
    int count = 8,
    double lifetime = 0.4,
    double speedScale = 1.0,
    double sizeScale = 1.0,
    bool withGlow = false,
  }) {
    position = center;
    _baseColor = baseColor;
    _count = count;
    _lifetime = lifetime;
    _speedScale = speedScale;
    _sizeScale = sizeScale;
    _withGlow = withGlow;
    _elapsed = 0;
    _active = true;
    _initParticles();
  }

  @override
  Future<void> onLoad() async {
    priority = 100;
  }

  void _initParticles() {
    // 기존 파티클 재활용 — 부족하면 추가, 남으면 무시
    while (_particles.length < _count) {
      _particles.add(_Particle());
    }
    for (var i = 0; i < _count; i++) {
      final p = _particles[i];
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = (_rng.nextDouble() * 180 + 60) * _speedScale;
      final hsl = HSLColor.fromColor(_baseColor);

      Color tweaked;
      if (_rng.nextDouble() < 0.3) {
        final accent = _accentColors[_rng.nextInt(_accentColors.length)];
        tweaked =
            Color.lerp(_baseColor, accent, 0.35 + _rng.nextDouble() * 0.3)!;
      } else {
        tweaked = hsl
            .withLightness(
                (hsl.lightness + _rng.nextDouble() * 0.4).clamp(0, 1))
            .withSaturation(
                (hsl.saturation + _rng.nextDouble() * 0.2 - 0.1).clamp(0, 1))
            .toColor();
      }

      p.reset(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed,
        radius: (_rng.nextDouble() * 3.5 + 1.2) * _sizeScale,
        color: tweaked,
      );
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
      return;
    }
    for (var i = 0; i < _count; i++) {
      final p = _particles[i];
      p.x += p.dx * dt;
      p.y += p.dy * dt;
      p.dx *= 0.94;
      p.dy *= 0.94;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    final progress = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final alpha = progress < 0.2 ? 1.0 : 1.0 - ((progress - 0.2) / 0.8);
    final paint = Paint();
    for (var i = 0; i < _count; i++) {
      final p = _particles[i];
      final r = p.radius * (1.0 - progress * 0.3);
      paint.color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(p.x, p.y), r, paint);
      if (_withGlow && r > 1.5) {
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
  double dx = 0;
  double dy = 0;
  double radius = 1;
  Color color = Colors.white;

  void reset({
    required double dx,
    required double dy,
    required double radius,
    required Color color,
  }) {
    x = 0;
    y = 0;
    this.dx = dx;
    this.dy = dy;
    this.radius = radius;
    this.color = color;
  }
}

/// ParticleBurst 오브젝트 풀. Component 트리 add/remove 부하를 줄인다.
///
/// 사용법:
///   1. [MatchBoardGame.onLoad]에서 `_particlePool = ParticlePool(world)` 생성.
///   2. 파티클 스폰 시 `_particlePool.spawn(...)` 호출.
///   3. 수명 만료 시 자동으로 풀에 반납된다.
class ParticlePool {
  ParticlePool(this._parent);

  final Component _parent;
  final List<ParticleBurst> _pool = [];

  /// 풀에서 꺼내거나 새로 만들어 활성화한다.
  void spawn({
    required Vector2 center,
    required Color baseColor,
    int count = 8,
    double lifetime = 0.4,
    double speedScale = 1.0,
    double sizeScale = 1.0,
    bool withGlow = false,
  }) {
    final burst = _pool.isNotEmpty ? _pool.removeLast() : _createBurst();
    burst.activate(
      center: center,
      baseColor: baseColor,
      count: count,
      lifetime: lifetime,
      speedScale: speedScale,
      sizeScale: sizeScale,
      withGlow: withGlow,
    );
    if (!burst.isMounted) {
      _parent.add(burst);
    }
  }

  ParticleBurst _createBurst() {
    final burst = ParticleBurst();
    burst._onExpired = _returnToPool;
    return burst;
  }

  void _returnToPool(ParticleBurst burst) {
    _pool.add(burst);
  }
}
