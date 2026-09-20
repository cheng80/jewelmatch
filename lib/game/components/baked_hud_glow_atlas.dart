import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Layout-sized HUD masks. The render path only tints a cached atlas entry.
/// Unlike stretching a blurred rectangle, this preserves corner radii and sigma.
class BakedHudGlowAtlas {
  static const double _padding = 28; // > 3 sigma for the largest shadow (8).
  final _paint = ui.Paint()..filterQuality = ui.FilterQuality.low;
  final _transform = Float32List.fromList([1, 0, 0, 0]);
  final _color = Int32List(1);
  final List<Float32List> _sources = [];
  List<HudGlowMask> _masks = const [];
  ui.Image? _image;
  bool _mounted = false;
  int _generation = 0;

  bool get isReady => _image != null;
  int get generation => _generation;

  void configure(List<HudGlowMask> masks) {
    var same = masks.length == _masks.length;
    if (same) {
      for (var i = 0; i < masks.length; i++) {
        if (masks[i].shape != _masks[i].shape ||
            masks[i].sigma != _masks[i].sigma ||
            masks[i].strokeWidth != _masks[i].strokeWidth) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    _masks = masks;
    if (_mounted) _bake();
  }

  void mount() {
    if (_mounted) return;
    _mounted = true;
    _bake();
  }

  void dispose() {
    _mounted = false;
    _image?.dispose();
    _image = null;
    _sources.clear();
  }

  void _bake() {
    if (_masks.isEmpty) return;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final sources = <Float32List>[];
    var top = 0.0;
    var width = 1.0;
    for (final mask in _masks) {
      final shape = mask.shape;
      final cellWidth = (math.max(0, shape.width) + 2 * _padding)
          .ceilToDouble();
      final cellHeight = (math.max(0, shape.height) + 2 * _padding)
          .ceilToDouble();
      sources.add(Float32List.fromList([0, top, cellWidth, top + cellHeight]));
      width = math.max(width, cellWidth);
      if (shape.width > 0 && shape.height > 0) {
        paint
          ..style = mask.strokeWidth == 0
              ? ui.PaintingStyle.fill
              : ui.PaintingStyle.stroke
          ..strokeWidth = mask.strokeWidth
          ..maskFilter = ui.MaskFilter.blur(
            mask.strokeWidth == 0 ? ui.BlurStyle.normal : ui.BlurStyle.outer,
            mask.sigma,
          );
        canvas.save();
        canvas.translate(_padding - shape.left, top + _padding - shape.top);
        canvas.drawRRect(shape, paint);
        canvas.restore();
      }
      top += cellHeight;
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width.toInt(), top.toInt());
    picture.dispose();
    _image?.dispose();
    _image = image;
    _sources
      ..clear()
      ..addAll(sources);
    _generation++;
  }

  void draw(
    ui.Canvas canvas,
    HudGlowKind kind,
    ui.Offset topLeft,
    ui.Color color,
  ) {
    final image = _image;
    if (image == null || color.a <= 0) return;
    _transform[2] = topLeft.dx - _padding;
    _transform[3] = topLeft.dy - _padding;
    _color[0] = color.toARGB32();
    canvas.drawRawAtlas(
      image,
      _transform,
      _sources[kind.index],
      _color,
      ui.BlendMode.modulate,
      null,
      _paint,
    );
  }
}

enum HudGlowKind {
  comboShadow,
  timeShadow,
  itemTarget,
  prismSelection,
  preview,
}

class HudGlowMask {
  const HudGlowMask(this.shape, this.sigma, [this.strokeWidth = 0]);
  final ui.RRect shape;
  final double sigma;
  final double strokeWidth;
}
