import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 스프라이트 시트에서 고정 프레임 크기 기준으로 한 칸만 정확히 잘라 그린다.
class SpriteSheetFrame extends StatelessWidget {
  const SpriteSheetFrame({
    super.key,
    required this.assetPath,
    required this.frameIndex,
    required this.frameSize,
    required this.size,
  });

  final String assetPath;
  final int frameIndex;
  final int frameSize;
  final double size;

  static final Map<String, Future<ui.Image>> _imageCache =
      <String, Future<ui.Image>>{};

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
          return CustomPaint(
            painter: _SpriteSheetFramePainter(
              image: snapshot.data!,
              frameIndex: frameIndex,
              frameSize: frameSize.toDouble(),
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
    required this.frameIndex,
    required this.frameSize,
  });

  final ui.Image image;
  final int frameIndex;
  final double frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final maxFrameIndex = (image.width / frameSize).floor() - 1;
    final safeIndex = frameIndex.clamp(0, maxFrameIndex);
    final srcRect = Rect.fromLTWH(
      safeIndex * frameSize,
      0,
      frameSize,
      frameSize,
    );
    canvas.drawImageRect(
      image,
      srcRect,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _SpriteSheetFramePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.frameIndex != frameIndex ||
        oldDelegate.frameSize != frameSize;
  }
}
