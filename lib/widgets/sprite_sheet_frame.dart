import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/components/board_atlas.dart';

/// [BoardAtlas]에서 이름 붙은 칸 하나를 그린다. 불러오기 전이나 실패하면 빈 칸이다.
/// 이미지는 보드와 같은 Flame.images 캐시 한 장을 공유한다.
class BoardAtlasFrame extends StatelessWidget {
  const BoardAtlasFrame(
    this.frame, {
    super.key,
    required this.size,
    this.opacity = 1.0,
  });

  final String frame;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<BoardAtlas>(
        future: BoardAtlas.load(),
        builder: (context, snapshot) {
          final atlas = snapshot.data;
          final src = atlas?.frames[frame];
          if (atlas == null || src == null) return const SizedBox.shrink();
          return CustomPaint(
            painter: _SpriteSheetFramePainter(
              image: atlas.image,
              src: src,
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

class _SpriteSheetFramePainter extends CustomPainter {
  const _SpriteSheetFramePainter({
    required this.image,
    required this.src,
    required this.opacity,
  });

  final ui.Image image;
  final Rect src;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final alpha = opacity.clamp(0.0, 1.0);
    if (alpha < 1.0) {
      paint.colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: alpha),
        BlendMode.modulate,
      );
    }
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _SpriteSheetFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.src != src ||
        oldDelegate.opacity != opacity;
  }
}
