import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// White glow masks, baked once for the mounted owners and tinted at draw time.
/// A pooled (still mounted) owner keeps its lease; the last removal frees it.
class BakedGlowAtlas {
  static ui.Image? _sharedImage;
  static int _owners = 0;
  static const double _cell = 192;
  static const int _columns = 8;
  static const double _center = _cell / 2;
  static const double _radius = 64;

  ui.Image? _image;
  final _transforms = Float32List.fromList([1, 0, 0, 0]);
  final _rects = Float32List(4);
  final _colors = Int32List(1);
  final _radialTransforms = Float32List.fromList([
    1,
    0,
    -_center,
    -_center,
    1,
    0,
    -_center,
    -_center,
    1,
    0,
    -_center,
    -_center,
    1,
    0,
    -_center,
    -_center,
  ]);
  final _radialRects = Float32List(16);
  final _radialColors = Int32List(4);
  final _paint = ui.Paint()
    ..blendMode = ui.BlendMode.plus
    ..filterQuality = ui.FilterQuality.low;

  bool get isReady => _image != null;

  void mount() {
    if (_image != null) return;
    _image = _sharedImage ??= _bake();
    _owners++;
  }

  void dispose() {
    if (_image == null) return;
    _image = null;
    if (--_owners == 0) {
      _sharedImage!.dispose();
      _sharedImage = null;
    }
  }

  static ui.Image _bake() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF)
      ..strokeCap = ui.StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    for (final shape in GlowShape.values) {
      canvas.save();
      canvas.translate(
        (shape.index % _columns) * _cell + _center,
        (shape.index ~/ _columns) * _cell + _center,
      );
      switch (shape) {
        case GlowShape.line:
          paint
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 12.8;
          canvas.drawLine(
            const ui.Offset(-32, 0),
            const ui.Offset(32, 0),
            paint,
          );
        case GlowShape.star:
          paint.style = ui.PaintingStyle.fill;
          final path = ui.Path();
          for (var i = 0; i < 16; i++) {
            final r = i.isEven ? 32 * 1.45 : 32 * 0.48;
            final angle = -pi / 2 + i * pi / 8;
            if (i == 0) {
              path.moveTo(cos(angle) * r, sin(angle) * r);
            } else {
              path.lineTo(cos(angle) * r, sin(angle) * r);
            }
          }
          canvas.drawPath(path..close(), paint);
        case GlowShape.hyperArc:
        case GlowShape.explosionArc:
          paint
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = shape == GlowShape.hyperArc ? 6 : 10;
          canvas.drawArc(
            const ui.Rect.fromLTRB(-_radius, -_radius, _radius, _radius),
            shape == GlowShape.hyperArc ? 0 : pi * 0.04,
            shape == GlowShape.hyperArc ? pi * 1.22 : pi * 0.92,
            false,
            paint,
          );
        case GlowShape.radial:
          paint
            ..style = ui.PaintingStyle.fill
            ..maskFilter = null
            ..shader = ui.Gradient.radial(ui.Offset.zero, _radius, const [
              ui.Color(0xFFFFFFFF),
              ui.Color(0x00FFFFFF),
            ]);
          canvas.drawCircle(ui.Offset.zero, _radius, paint);
          paint.shader = null;
      }
      canvas.restore();
    }
    paint
      ..style = ui.PaintingStyle.fill
      ..maskFilter = null;
    for (final profile in GlowRadial.values) {
      final stops = profile.stops;
      for (var channel = 0; channel < 4; channel++) {
        final index = GlowShape.values.length + profile.index * 4 + channel;
        final colors = List<ui.Color>.generate(
          stops.length,
          (i) => ui.Color(
            i == channel && channel < stops.length - 1
                ? 0xFFFFFFFF
                : 0x00FFFFFF,
          ),
        );
        canvas.save();
        canvas.translate(
          (index % _columns) * _cell + _center,
          (index ~/ _columns) * _cell + _center,
        );
        paint.shader = ui.Gradient.radial(
          ui.Offset.zero,
          _radius,
          colors,
          stops,
        );
        canvas.drawCircle(ui.Offset.zero, _radius, paint);
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (_cell * _columns).toInt(),
      (_cell *
              ((GlowShape.values.length +
                      GlowRadial.values.length * 4 +
                      _columns -
                      1) ~/
                  _columns))
          .toInt(),
    );
    picture.dispose();
    return image;
  }

  /// Scaling and tinting only: no filters, paths, shaders or buffer views here.
  void draw(
    ui.Canvas canvas,
    GlowShape shape,
    ui.Offset center,
    double scaleX,
    double scaleY,
    ui.Color color, {
    double angle = 0,
  }) {
    final image = _image;
    if (image == null || scaleX <= 0 || scaleY <= 0 || color.a <= 0) return;
    _rects[0] = (shape.index % _columns) * _cell;
    _rects[1] = (shape.index ~/ _columns) * _cell;
    _rects[2] = _rects[0] + _cell;
    _rects[3] = _rects[1] + _cell;
    _colors[0] = color.toARGB32();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (angle != 0) canvas.rotate(angle);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-_center, -_center);
    canvas.drawRawAtlas(
      image,
      _transforms,
      _rects,
      _colors,
      ui.BlendMode.modulate,
      null,
      _paint,
    );
    canvas.restore();
  }

  /// Gradient basis masks preserve the original stops and independent colors.
  /// Four fixed entries are submitted together, including a transparent spare.
  void radial(
    ui.Canvas canvas,
    GlowRadial profile,
    ui.Offset center,
    double radius,
    ui.Color c0,
    ui.Color c1,
    ui.Color c2, [
    ui.Color c3 = const ui.Color(0x00000000),
  ]) {
    final image = _image;
    if (image == null || radius <= 0) return;
    for (var i = 0; i < 4; i++) {
      final index = GlowShape.values.length + profile.index * 4 + i;
      _radialRects[i * 4] = (index % _columns) * _cell;
      _radialRects[i * 4 + 1] = (index ~/ _columns) * _cell;
      _radialRects[i * 4 + 2] = _radialRects[i * 4] + _cell;
      _radialRects[i * 4 + 3] = _radialRects[i * 4 + 1] + _cell;
    }
    _radialColors[0] = c0.toARGB32();
    _radialColors[1] = c1.toARGB32();
    _radialColors[2] = c2.toARGB32();
    _radialColors[3] = c3.toARGB32();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius / _radius);
    canvas.drawRawAtlas(
      image,
      _radialTransforms,
      _radialRects,
      _radialColors,
      ui.BlendMode.modulate,
      null,
      _paint,
    );
    canvas.restore();
  }

  void line(
    ui.Canvas canvas,
    ui.Offset start,
    ui.Offset end,
    double width,
    ui.Color color,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    if (length < 0.01) return;
    draw(
      canvas,
      GlowShape.line,
      ui.Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
      length / 64,
      width / 12.8,
      color,
      angle: atan2(dy, dx),
    );
  }
}

enum GlowShape { line, star, hyperArc, explosionArc, radial }

enum GlowRadial {
  star([0.0, 0.28, 0.58, 1.0]),
  cell([0.0, 0.34, 0.62, 1.0]),
  bomb([0.0, 0.14, 0.54, 1.0]),
  hyper([0.0, 0.22, 0.50, 0.72, 1.0]),
  flatHyper([0.0, 0.38, 0.68, 1.0]),
  supernova([0.0, 0.20, 0.56, 1.0]);

  const GlowRadial(this.stops);
  final List<double> stops;
}
