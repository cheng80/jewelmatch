import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/components/board_atlas.dart';

/// 스프라이트 시트에서 고정 프레임 크기 기준으로 한 칸만 정확히 잘라 그린다.
class SpriteSheetFrame extends StatelessWidget {
  const SpriteSheetFrame({
    super.key,
    required this.assetPath,
    required this.frameIndex,
    required this.frameSize,
    required this.size,
    this.opacity = 1.0,
  });

  final String assetPath;
  final int frameIndex;
  final int frameSize;
  final double size;
  final double opacity;

  static final Map<String, Future<ui.Image>> _imageCache =
      <String, Future<ui.Image>>{};

  static Future<ui.Image> precache(String assetPath) => _loadImage(assetPath);

  static Future<ui.Image> _loadImage(String assetPath) {
    return _imageCache.putIfAbsent(assetPath, () async {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<ui.Image>(
        future: _loadImage(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final image = snapshot.data!;
          final frame = frameSize.toDouble();
          final maxFrameIndex = (image.width / frame).floor() - 1;
          final safeIndex = frameIndex.clamp(0, maxFrameIndex);
          return CustomPaint(
            painter: _SpriteSheetFramePainter(
              image: image,
              src: Rect.fromLTWH(safeIndex * frame, 0, frame, frame),
              opacity: opacity,
            ),
          );
        },
      ),
    );
  }
}

/// [BoardAtlas]에서 이름 붙은 칸 하나를 그린다. 불러오기 전이나 실패하면 빈 칸이다.
/// 이미지는 보드와 같은 Flame.images 캐시 한 장을 공유한다.
class BoardAtlasFrame extends StatelessWidget {
  const BoardAtlasFrame(this.frame, {super.key, required this.size});

  final String frame;
  final double size;

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
              opacity: 1,
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
