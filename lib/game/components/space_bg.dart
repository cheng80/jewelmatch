import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 우주 배경 컴포넌트.
///
/// - 그라데이션 배경을 [ui.Picture]로 캐싱 → 매 프레임 drawPicture 1회.
/// - 별 120개를 3 그룹으로 나눠 각 그룹을 [ui.Picture]로 캐싱.
/// - 별 그룹은 정적으로 drawPicture 3회 렌더링해 전체 화면 saveLayer를 피한다.
/// - 총 draw 호출: 4회/프레임 (기존 ~240회 → 4회).
class SpaceBg extends PositionComponent with HasGameReference {
  static const int _starCount = 120;
  static const int _groupCount = 3;

  ui.Picture? _bgPicture;
  final List<ui.Picture> _starPictures = [];
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
          Color(0xFF130824),
          Color(0xFF1B1238),
          Color(0xFF0D1B35),
          Color(0xFF162B48),
          Color(0xFF090C1B),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    _bgPicture = recorder.endRecording();
  }

  void _buildStarPictures() {
    _starPictures.clear();

    final rng = Random(42);
    final groups = List.generate(_groupCount, (_) => <_Star>[]);

    for (var i = 0; i < _starCount; i++) {
      groups[i % _groupCount].add(
        _Star(
          x: rng.nextDouble() * size.x,
          y: rng.nextDouble() * size.y,
          radius: rng.nextDouble() * 1.8 + 0.3,
          alpha: rng.nextDouble() * 0.5 + 0.3,
          color: _starColor(rng),
        ),
      );
    }

    for (var g = 0; g < _groupCount; g++) {
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
            Offset(star.x, star.y),
            star.radius * 2.5,
            glowPaint,
          );
        }
      }

      _starPictures.add(recorder.endRecording());
    }
  }

  Color _starColor(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.55) return Colors.white;
    if (roll < 0.7) return const Color(0xFF9DE7EF);
    if (roll < 0.82) return const Color(0xFFF4A6C5);
    if (roll < 0.92) return const Color(0xFFF3DFA3);
    return const Color(0xFFC8B9E8);
  }

  @override
  void render(Canvas canvas) {
    if (_bgPicture == null) return;

    canvas.drawPicture(_bgPicture!);

    for (var g = 0; g < _groupCount; g++) {
      canvas.drawPicture(_starPictures[g]);
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
