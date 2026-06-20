import 'dart:async';
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
  final Paint _particlePaint = Paint();
  static const MaskFilter _glowBlur = MaskFilter.blur(BlurStyle.normal, 4);

  static final Random _rng = Random();
  static const _matchGold = Color(0xFFFFD052);
  static const _matchHotYellow = Color(0xFFFFF0A6);

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

  void deactivateForPool() {
    _active = false;
    _elapsed = 0;
    _count = 0;
    _withGlow = false;
  }

  void warmForPool({required int particleCapacity}) {
    while (_particles.length < particleCapacity) {
      _particles.add(_Particle());
    }
    deactivateForPool();
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
      final color = Color.lerp(
        _baseColor,
        _rng.nextBool() ? _matchGold : _matchHotYellow,
        0.72 + _rng.nextDouble() * 0.22,
      )!;

      p.reset(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed,
        length: (_rng.nextDouble() * 8.0 + 7.0) * _sizeScale,
        width: (_rng.nextDouble() * 1.6 + 1.2) * _sizeScale,
        color: color,
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
    final showGlow = _withGlow && progress < 0.72;
    for (var i = 0; i < _count; i++) {
      final p = _particles[i];
      final sharpness = 1.0 - progress * 0.24;
      final length = p.length * sharpness;
      final width = p.width * sharpness;
      final velocity = Offset(p.dx, p.dy);
      final speed = velocity.distance;
      if (speed < 0.1) continue;
      final dir = velocity / speed;
      final side = Offset(-dir.dy, dir.dx);
      final center = Offset(p.x, p.y);
      final tip = center + dir * length * 0.62;
      final tail = center - dir * length * 0.46;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((center + side * width).dx, (center + side * width).dy)
        ..lineTo(tail.dx, tail.dy)
        ..lineTo((center - side * width).dx, (center - side * width).dy)
        ..close();
      if (showGlow) {
        _particlePaint
          ..color = _matchGold.withValues(alpha: alpha * 0.26)
          ..maskFilter = _glowBlur
          ..strokeWidth = width * 2.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(tail, tip, _particlePaint);
      }
      _particlePaint
        ..maskFilter = null
        ..style = PaintingStyle.fill
        ..color = p.color.withValues(alpha: alpha * 0.96);
      canvas.drawPath(path, _particlePaint);
      _particlePaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.52
        ..color = Colors.white.withValues(alpha: alpha * 0.72);
      canvas.drawLine(center - dir * length * 0.10, tip, _particlePaint);
    }
    _particlePaint
      ..style = PaintingStyle.fill
      ..maskFilter = null;
  }
}

class _Particle {
  double x = 0;
  double y = 0;
  double dx = 0;
  double dy = 0;
  double length = 1;
  double width = 1;
  Color color = Colors.white;

  void reset({
    required double dx,
    required double dy,
    required double length,
    required double width,
    required Color color,
  }) {
    x = 0;
    y = 0;
    this.dx = dx;
    this.dy = dy;
    this.length = length;
    this.width = width;
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

  static const int _maxCachedBursts = 48;

  final Component _parent;
  final List<ParticleBurst> _pool = [];
  final Set<ParticleBurst> _active = <ParticleBurst>{};

  int get activeCount => _active.length;
  int get cachedCount => _pool.length;

  Future<void> warm({
    required int burstCount,
    required int particleCapacity,
  }) async {
    final pendingLoads = <Future<void>>[];
    while (_pool.length < burstCount) {
      final burst = _createBurst();
      burst.warmForPool(particleCapacity: particleCapacity);
      final added = _parent.add(burst);
      if (added is Future<void>) {
        pendingLoads.add(added);
      }
      _pool.add(burst);
    }
    if (pendingLoads.isNotEmpty) {
      await Future.wait(pendingLoads);
    }
  }

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
    _active.add(burst);
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
    if (!_active.remove(burst)) return;
    burst.deactivateForPool();
    if (_pool.length < _maxCachedBursts && burst.parent != null) {
      _pool.add(burst);
    } else {
      burst.removeFromParent();
    }
  }

  void clear() {
    final bursts = <ParticleBurst>{..._active, ..._pool};
    _active.clear();
    _pool.clear();
    for (final burst in bursts) {
      burst.deactivateForPool();
      burst.removeFromParent();
    }
  }
}
