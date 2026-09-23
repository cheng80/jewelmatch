import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../resources/texture_atlas.dart';

/// UI 아틀라스 칸 하나를 `Image.asset`처럼 그린다.
///
/// 크기 규칙은 `RenderImage`, 그리기는 `paintImage`(가운데 정렬, 안티앨리어스 없음)와 같다.
/// 아틀라스가 아직 없으면 빈 칸으로 두었다가 올라오면 다시 그린다.
class AtlasImage extends StatefulWidget {
  const AtlasImage(
    this.frame, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  /// `UiFrames` 칸 이름.
  final String frame;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<AtlasImage> createState() => _AtlasImageState();
}

class _AtlasImageState extends State<AtlasImage> {
  @override
  void initState() {
    super.initState();
    _whenUiAtlasReady(this, widget.frame, () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final found = TextureAtlas.findUi(widget.frame);
    return _AtlasFrame(
      image: found?.$1,
      src: found?.$2,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}

/// UI 아틀라스 칸을 [child] 뒤에 나인패치로 깐다. `DecorationImage(centerSlice:, fit: fill)` 대체.
class AtlasNineBox extends StatefulWidget {
  const AtlasNineBox({
    super.key,
    required this.frame,
    required this.center,
    required this.child,
  });

  final String frame;

  /// 칸 기준 가운데 영역.
  final Rect center;
  final Widget child;

  @override
  State<AtlasNineBox> createState() => _AtlasNineBoxState();
}

class _AtlasNineBoxState extends State<AtlasNineBox> {
  @override
  void initState() {
    super.initState();
    _whenUiAtlasReady(this, widget.frame, () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final found = TextureAtlas.findUi(widget.frame);
    return CustomPaint(
      painter: found == null
          ? null
          : _NinePainter(found.$1, found.$2, widget.center),
      child: widget.child,
    );
  }
}

void _whenUiAtlasReady(State state, String frame, VoidCallback rebuild) {
  if (TextureAtlas.findUi(frame) != null) return;
  TextureAtlas.precacheUi().then((_) {
    if (state.mounted && TextureAtlas.findUi(frame) != null) rebuild();
  });
}

Paint _imagePaint() => Paint()
  ..isAntiAlias = false
  ..filterQuality = FilterQuality.high;

class _NinePainter extends CustomPainter {
  _NinePainter(this.image, this.src, this.center);

  final ui.Image image;
  final Rect src;
  final Rect center;

  @override
  void paint(Canvas canvas, Size size) => drawAtlasNine(
    canvas,
    image,
    src,
    center,
    Offset.zero & size,
    // `paintImage`의 나인패치(drawImageNine)는 품질과 관계없이 선형 필터다.
    Paint()..filterQuality = FilterQuality.low,
  );

  @override
  bool shouldRepaint(_NinePainter old) =>
      old.image != image || old.src != src || old.center != center;
}

class _AtlasFrame extends LeafRenderObjectWidget {
  const _AtlasFrame({
    required this.image,
    required this.src,
    required this.width,
    required this.height,
    required this.fit,
  });

  final ui.Image? image;
  final Rect? src;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  _RenderAtlasFrame createRenderObject(BuildContext context) =>
      _RenderAtlasFrame()..update(this);

  @override
  void updateRenderObject(BuildContext context, _RenderAtlasFrame r) =>
      r.update(this);
}

class _RenderAtlasFrame extends RenderBox {
  ui.Image? _image;
  Rect? _src;
  double? _width;
  double? _height;
  BoxFit _fit = BoxFit.contain;

  void update(_AtlasFrame w) {
    final relayout =
        w.width != _width || w.height != _height || w.src?.size != _src?.size;
    final repaint = relayout || w.image != _image || w.src != _src;
    _image = w.image;
    _src = w.src;
    _width = w.width;
    _height = w.height;
    _fit = w.fit;
    if (relayout) {
      markNeedsLayout();
    } else if (repaint) {
      markNeedsPaint();
    }
  }

  Size _sizeFor(BoxConstraints constraints) {
    final c = BoxConstraints.tightFor(
      width: _width,
      height: _height,
    ).enforce(constraints);
    final src = _src;
    if (src == null) return c.smallest;
    return c.constrainSizeAndAttemptToPreserveAspectRatio(src.size);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _width == null && _height == null ? 0 : computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _sizeFor(BoxConstraints.tightForFinite(height: height)).width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _width == null && _height == null ? 0 : computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _sizeFor(BoxConstraints.tightForFinite(width: width)).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  @override
  void performLayout() => size = _sizeFor(constraints);

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _image;
    final src = _src;
    if (image == null || src == null || size.isEmpty) return;
    final rect = offset & size;
    final fitted = applyBoxFit(_fit, src.size, rect.size);
    final dst = Alignment.center.inscribe(fitted.destination, rect);
    final source = Alignment.center
        .inscribe(fitted.source, Offset.zero & src.size)
        .shift(src.topLeft);
    context.canvas.drawImageRect(image, source, dst, _imagePaint());
  }
}
