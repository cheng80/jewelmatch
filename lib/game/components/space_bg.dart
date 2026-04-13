import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 우주 배경 컴포넌트.
///
/// - 그라데이션 배경을 [ui.Picture]로 캐싱 → 매 프레임 drawPicture 1회.
/// - 별 120개를 3 그룹으로 나눠 각 그룹을 [ui.Picture]로 캐싱.
/// - 깜빡임은 그룹 단위 sin alpha로만 처리 → drawPicture 3회 + saveLayer 3회.
/// - 총 draw 호출: 4회/프레임 (기존 ~240회 → 4회).
class SpaceBg extends PositionComponent with HasGameReference {
  static const int _starCount = 120;
  static const int _groupCount = 3;

  ui.Picture? _bgPicture;
  final List<ui.Picture> _starPictures = [];
  final List<double> _groupPhases = [];
  final List<double> _groupSpeeds = [];

  double _time = 0;
  Vector2 _lastSize = Vector2.zero();

  @override
  Future<void> onLoad() async {
    _rebuild();
    priority = -1;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size != _lastSize) _rebuild();
  }

  void _rebuild() {
    size = game.size;
    _lastSize = size.clone();
    _buildBgPicture();
    _buildStarPictures();
  }

  void _buildBgPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    final paint = Paint()
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
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    _bgPicture = recorder.endRecording();
  }

  void _buildStarPictures() {
    _starPictures.clear();
    _groupPhases.clear();
    _groupSpeeds.clear();

    final rng = Random(42);
    final groups = List.generate(_groupCount, (_) => <_Star>[]);

    for (var i = 0; i < _starCount; i++) {
      groups[i % _groupCount].add(_Star(
        x: rng.nextDouble() * size.x,
        y: rng.nextDouble() * size.y,
        radius: rng.nextDouble() * 1.8 + 0.3,
        alpha: rng.nextDouble() * 0.5 + 0.3,
        color: _starColor(rng),
      ));
    }

    for (var g = 0; g < _groupCount; g++) {
      _groupPhases.add(rng.nextDouble() * 2 * pi);
      _groupSpeeds.add(rng.nextDouble() * 0.4 + 0.3);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      for (final star in groups[g]) {
        final paint = Paint()..color = star.color.withValues(alpha: star.alpha);
        canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);

        if (star.radius > 1.2) {
          final glowPaint = Paint()
            ..color = star.color.withValues(alpha: star.alpha * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(
              Offset(star.x, star.y), star.radius * 2.5, glowPaint);
        }
      }

      _starPictures.add(recorder.endRecording());
    }
  }

  Color _starColor(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.55) return Colors.white;
    if (roll < 0.7) return const Color(0xFF00FBFB);
    if (roll < 0.82) return const Color(0xFFFF86C1);
    if (roll < 0.92) return const Color(0xFFFFEA00);
    return const Color(0xFFE1BEE7);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_bgPicture == null) return;

    canvas.drawPicture(_bgPicture!);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    for (var g = 0; g < _groupCount; g++) {
      final alpha =
          (0.7 + 0.3 * sin(_time * _groupSpeeds[g] + _groupPhases[g]))
              .clamp(0.4, 1.0);
      canvas.saveLayer(
        rect,
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha),
      );
      canvas.drawPicture(_starPictures[g]);
      canvas.restore();
    }
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.color,
  });

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final Color color;
}
