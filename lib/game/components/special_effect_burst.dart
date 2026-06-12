import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../match_board_logic.dart';

class SpecialEffectBurst extends PositionComponent {
  SpecialEffectBurst() {
    priority = 120;
  }

  void Function(SpecialEffectBurst)? _onExpired;

  void activate({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
  }) {
    this.effectKind = effectKind;
    this.origin = origin;
    this.affectedCenters = affectedCenters;
    this.tileSize = tileSize;
    this.baseColor = baseColor;
    _lifetime = _lifetimeFor(effectKind);
    _elapsed = 0;
    _active = true;
  }

  GemKind effectKind = GemKind.normal;
  Vector2 origin = Vector2.zero();
  List<Vector2> affectedCenters = const [];
  double tileSize = 0;
  Color baseColor = Colors.white;
  double _lifetime = 0;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.plus;
  final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..blendMode = BlendMode.plus;
  double _elapsed = 0;
  bool _active = false;

  static const _glow = MaskFilter.blur(BlurStyle.normal, 6);
  static const _hotYellow = Color(0xFFFFF3A4);
  static const _hotOrange = Color(0xFFFF8C36);
  static const _electricBlue = Color(0xFF74F6FF);
  static const _electricViolet = Color(0xFFC88DFF);

  static double _lifetimeFor(GemKind kind) {
    switch (kind) {
      case GemKind.row:
      case GemKind.col:
        return 0.34;
      case GemKind.bomb:
        return 0.52;
      case GemKind.star:
        return 0.44;
      case GemKind.hyper:
        return 0.60;
      case GemKind.supernova:
        return 0.72;
      case GemKind.normal:
        return 0.20;
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
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    final t = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final fade = _easeOut(1 - t);
    if (fade <= 0) return;

    switch (effectKind) {
      case GemKind.row:
        _renderLightningSweep(canvas, t, fade, horizontal: true);
        break;
      case GemKind.col:
        _renderLightningSweep(canvas, t, fade, horizontal: false);
        break;
      case GemKind.bomb:
        _renderFlame(canvas, t, fade);
        break;
      case GemKind.star:
        _renderStarLightning(canvas, t, fade);
        break;
      case GemKind.hyper:
        _renderHypercube(canvas, t, fade);
        break;
      case GemKind.supernova:
        _renderSupernova(canvas, t, fade);
        break;
      case GemKind.normal:
        break;
    }
  }

  void _renderFlame(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final heat = Curves.easeOutBack.transform(min(t * 1.15, 1));
    final radius = tileSize * (0.45 + heat * 2.35);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.88,
      [
        Colors.white.withValues(alpha: 0.18 * fade),
        _hotYellow.withValues(alpha: 0.24 * fade),
        _hotOrange.withValues(alpha: 0.13 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.16, 0.48, 1.0],
    );

    _drawExplosionCloud(canvas, center, radius, t, fade);
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: 10,
      length: radius * 0.95,
    );
    _drawSparks(canvas, center, t, fade, count: 42, spread: radius * 1.18);
    _drawEmbers(canvas, center, t, fade, count: 14, spread: radius * 1.05);
    _drawCellFlash(canvas, t, fade, maxCells: 9, color: _hotOrange);
  }

  void _renderStarLightning(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    _drawRadialGlow(
      canvas,
      center,
      tileSize * (1.4 + t * 0.8),
      [
        Colors.white.withValues(alpha: 0.56 * fade),
        _electricBlue.withValues(alpha: 0.34 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.36, 1.0],
    );

    final left = _axisExtreme(horizontal: true, first: true);
    final right = _axisExtreme(horizontal: true, first: false);
    final top = _axisExtreme(horizontal: false, first: true);
    final bottom = _axisExtreme(horizontal: false, first: false);
    _drawLightning(canvas, center, left, t, fade, seed: 1);
    _drawLightning(canvas, center, right, t, fade, seed: 2);
    _drawLightning(canvas, center, top, t, fade, seed: 3);
    _drawLightning(canvas, center, bottom, t, fade, seed: 4);

    for (var i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4 + sin(t * pi * 2) * 0.08;
      final end =
          center + Offset(cos(a), sin(a)) * tileSize * (0.9 + 0.65 * fade);
      _drawLightning(canvas, center, end, t, fade * 0.72, seed: 10 + i);
    }

    _drawStarCore(canvas, center, tileSize * (0.34 + 0.12 * fade), fade);
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 28,
      spread: tileSize * 2.4,
      color: _electricBlue,
    );
    _drawCellFlash(canvas, t, fade, maxCells: 16, color: _electricBlue);
  }

  void _renderLightningSweep(
    Canvas canvas,
    double t,
    double fade, {
    required bool horizontal,
  }) {
    final center = origin.toOffset();
    final a = _axisExtreme(horizontal: horizontal, first: true);
    final b = _axisExtreme(horizontal: horizontal, first: false);
    _drawLightning(canvas, a, b, t, fade, seed: horizontal ? 5 : 6);
    _drawRadialGlow(
      canvas,
      center,
      tileSize * 1.2,
      [
        Colors.white.withValues(alpha: 0.45 * fade),
        _electricBlue.withValues(alpha: 0.28 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.4, 1.0],
    );
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 18,
      spread: tileSize * 1.8,
      color: _electricBlue,
    );
    _drawCellFlash(canvas, t, fade, maxCells: 12, color: _electricBlue);
  }

  void _renderHypercube(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final radius = tileSize * (0.72 + t * 2.4);
    _drawRadialGlow(
      canvas,
      center,
      radius * 1.25,
      [
        Colors.white.withValues(alpha: 0.42 * fade),
        _electricViolet.withValues(alpha: 0.36 * fade),
        baseColor.withValues(alpha: 0.20 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.24, 0.55, 1.0],
    );

    for (var i = 0; i < 4; i++) {
      final phase = i * pi / 2 + t * pi * 2.2;
      _paint
        ..maskFilter = i == 0 ? _glow : null
        ..strokeWidth = tileSize * (0.045 + i * 0.006)
        ..color = Color.lerp(
          _electricViolet,
          baseColor,
          i / 3,
        )!.withValues(alpha: (0.52 - i * 0.07) * fade);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * (0.46 + i * 0.18)),
        phase,
        pi * 1.22,
        false,
        _paint,
      );
    }
    _paint.maskFilter = null;

    for (var i = 0; i < 18; i++) {
      final p = _orbitPoint(center, radius * 0.9, t, i);
      _fillPaint.color = Color.lerp(
        Colors.white,
        baseColor,
        (i % 5) / 5,
      )!.withValues(alpha: 0.82 * fade);
      canvas.drawCircle(p, tileSize * (0.035 + (i % 3) * 0.012), _fillPaint);
    }
    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 32,
      spread: radius,
      color: _electricViolet,
    );
    _drawCellFlash(canvas, t, fade, maxCells: 24, color: _electricViolet);
  }

  void _renderSupernova(Canvas canvas, double t, double fade) {
    final center = origin.toOffset();
    final blast = Curves.easeOutCubic.transform(t);
    final radius = tileSize * (0.85 + blast * 4.2);

    _drawRadialGlow(
      canvas,
      center,
      radius * 0.86,
      [
        Colors.white.withValues(alpha: 0.28 * fade),
        _hotYellow.withValues(alpha: 0.24 * fade),
        baseColor.withValues(alpha: 0.12 * fade),
        Colors.transparent,
      ],
      const [0.0, 0.18, 0.52, 1.0],
    );
    _drawExplosionCloud(canvas, center, radius * 0.58, t, fade);
    _drawPlasmaArcs(canvas, center, radius, t, fade);
    _drawFlashStreaks(
      canvas,
      center,
      t,
      fade,
      count: 18,
      length: radius * 0.95,
    );

    _drawBurstStreaks(
      canvas,
      center,
      t,
      fade,
      count: 30,
      spread: radius * 0.92,
    );

    final left = _axisExtreme(horizontal: true, first: true);
    final right = _axisExtreme(horizontal: true, first: false);
    final top = _axisExtreme(horizontal: false, first: true);
    final bottom = _axisExtreme(horizontal: false, first: false);
    _drawLightning(canvas, left, right, t, fade * 0.72, seed: 30);
    _drawLightning(canvas, top, bottom, t, fade * 0.72, seed: 31);

    _drawSparks(
      canvas,
      center,
      t,
      fade,
      count: 64,
      spread: radius * 1.12,
      color: _hotYellow,
    );
    _drawEmbers(canvas, center, t, fade, count: 20, spread: radius * 0.95);
    _drawCellFlash(canvas, t, fade, maxCells: 32, color: _hotYellow);
  }

  void _drawRadialGlow(
    Canvas canvas,
    Offset center,
    double radius,
    List<Color> colors,
    List<double> stops,
  ) {
    _fillPaint
      ..maskFilter = null
      ..shader = ui.Gradient.radial(center, radius, colors, stops);
    canvas.drawCircle(center, radius, _fillPaint);
    _fillPaint
      ..shader = null
      ..maskFilter = null;
  }

  void _drawLightning(
    Canvas canvas,
    Offset start,
    Offset end,
    double t,
    double fade, {
    required int seed,
  }) {
    if ((start - end).distance < 1) return;
    final path = Path()..moveTo(start.dx, start.dy);
    final delta = end - start;
    final normal = Offset(-delta.dy, delta.dx) / delta.distance;
    const segments = 9;
    for (var i = 1; i < segments; i++) {
      final f = i / segments;
      final jitter =
          sin(seed * 12.989 + i * 4.21 + t * pi * 5) * tileSize * 0.12;
      final p = start + delta * f + normal * jitter;
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(end.dx, end.dy);

    _paint
      ..maskFilter = _glow
      ..strokeWidth = tileSize * 0.14
      ..color = _electricBlue.withValues(alpha: 0.30 * fade);
    canvas.drawPath(path, _paint);
    _paint
      ..maskFilter = null
      ..strokeWidth = tileSize * 0.052
      ..color = _electricBlue.withValues(alpha: 0.88 * fade);
    canvas.drawPath(path, _paint);
    _paint
      ..strokeWidth = tileSize * 0.018
      ..color = Colors.white.withValues(alpha: fade);
    canvas.drawPath(path, _paint);
  }

  void _drawFlameTongues(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    for (var i = 0; i < 9; i++) {
      final angle = i * 2 * pi / 9 + sin(t * pi * 2 + i) * 0.13;
      final dir = Offset(cos(angle), sin(angle));
      final side = Offset(-dir.dy, dir.dx);
      final tip = center + dir * radius * (0.48 + (i % 3) * 0.13);
      final root = center + dir * tileSize * 0.14;
      final path = Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(
          (center + side * tileSize * 0.28 + dir * radius * 0.28).dx,
          (center + side * tileSize * 0.28 + dir * radius * 0.28).dy,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (center - side * tileSize * 0.20 + dir * radius * 0.22).dx,
          (center - side * tileSize * 0.20 + dir * radius * 0.22).dy,
          root.dx,
          root.dy,
        )
        ..close();
      _fillPaint.color = Color.lerp(
        _hotYellow,
        _hotOrange,
        i / 8,
      )!.withValues(alpha: 0.42 * fade);
      canvas.drawPath(path, _fillPaint);
    }
  }

  void _drawExplosionCloud(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    final bloom = Curves.easeOutCubic.transform(t);
    final heatFade = fade * (1.0 - t * 0.26);
    for (var i = 0; i < 13; i++) {
      final angle = i * 2 * pi / 13 + sin(t * pi * 2 + i) * 0.18;
      final drift = radius * (0.12 + _hash(i + 3) * 0.38) * bloom;
      final lobeCenter = center + Offset(cos(angle), sin(angle)) * drift;
      final lobeRadius = radius * (0.20 + _hash(i + 11) * 0.22);
      final mix = i / 12;
      final color = Color.lerp(
        i.isEven ? _hotYellow : _hotOrange,
        baseColor,
        mix * 0.32,
      )!;
      _drawOrganicBlob(
        canvas,
        lobeCenter,
        lobeRadius,
        seed: i * 19 + 7,
        t: t,
        color: color.withValues(alpha: (0.18 + _hash(i) * 0.18) * heatFade),
      );
    }

    for (var i = 0; i < 8; i++) {
      final angle = i * 2 * pi / 8 + 0.35;
      final drift = radius * (0.36 + _hash(i + 40) * 0.30) * bloom;
      final smokeCenter = center + Offset(cos(angle), sin(angle)) * drift;
      _drawOrganicBlob(
        canvas,
        smokeCenter,
        radius * (0.18 + _hash(i + 50) * 0.18),
        seed: i * 31 + 5,
        t: t + 0.2,
        color: const Color(
          0xFF9CB5A8,
        ).withValues(alpha: (0.13 + _hash(i + 70) * 0.12) * fade),
      );
    }

    _drawFlameTongues(canvas, center, radius * 0.92, t, fade * 0.54);
  }

  void _drawOrganicBlob(
    Canvas canvas,
    Offset center,
    double radius, {
    required int seed,
    required double t,
    required Color color,
  }) {
    final path = Path();
    const points = 9;
    for (var i = 0; i <= points; i++) {
      final angle = i * 2 * pi / points;
      final wobble =
          0.74 +
          _hash(seed + i * 13) * 0.38 +
          sin(t * pi * 2 + seed + i) * 0.08;
      final p = center + Offset(cos(angle), sin(angle)) * radius * wobble;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prevAngle = (i - 0.5) * 2 * pi / points;
        final control =
            center +
            Offset(cos(prevAngle), sin(prevAngle)) *
                radius *
                (0.92 + _hash(seed + i * 7) * 0.18);
        path.quadraticBezierTo(control.dx, control.dy, p.dx, p.dy);
      }
    }
    path.close();
    _fillPaint
      ..shader = null
      ..maskFilter = null
      ..blendMode = BlendMode.srcOver
      ..color = color;
    canvas.drawPath(path, _fillPaint);
    _fillPaint.blendMode = BlendMode.plus;
  }

  void _drawFlashStreaks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double length,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2 * pi / count + _hash(i + 90) * 0.28;
      final dir = Offset(cos(angle), sin(angle));
      final reach =
          length * (0.42 + _hash(i + 91) * 0.58) * Curves.easeOut.transform(t);
      final start = center + dir * tileSize * 0.08;
      final tip = center + dir * reach * 0.78;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.012 + _hash(i + 92) * 0.018)
        ..color = Color.lerp(
          Colors.white,
          _hotYellow,
          _hash(i + 93) * 0.55,
        )!.withValues(alpha: 0.24 * fade);
      canvas.drawLine(start, tip, _paint);
    }
  }

  void _drawPlasmaArcs(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double fade,
  ) {
    _paint
      ..maskFilter = null
      ..strokeWidth = tileSize * 0.045
      ..color = _hotYellow.withValues(alpha: 0.42 * fade);
    for (var i = 0; i < 7; i++) {
      final start = i * 2 * pi / 7 + t * 1.6;
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius * (0.54 + _hash(i) * 0.24),
        ),
        start,
        pi * (0.16 + _hash(i + 12) * 0.18),
        false,
        _paint,
      );
    }
  }

  void _drawStarCore(Canvas canvas, Offset center, double radius, double fade) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final r = i.isEven ? radius * 1.45 : radius * 0.48;
      final angle = -pi / 2 + i * pi / 8;
      final p = center + Offset(cos(angle), sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    _fillPaint
      ..maskFilter = _glow
      ..color = _electricBlue.withValues(alpha: 0.62 * fade);
    canvas.drawPath(path, _fillPaint);
    _fillPaint
      ..maskFilter = null
      ..color = Colors.white.withValues(alpha: 0.92 * fade);
    canvas.drawPath(path, _fillPaint);
  }

  void _drawBurstStreaks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
  }) {
    final progress = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + _hash(i + 150) * 0.35;
      final dir = Offset(cos(angle), sin(angle));
      final distance = spread * (0.22 + _hash(i + 151) * 0.78) * progress;
      final start = center + dir * max(0, distance - tileSize * 0.42);
      final end = center + dir * distance;
      _paint
        ..maskFilter = null
        ..strokeWidth = tileSize * (0.014 + _hash(i + 152) * 0.020)
        ..color = Color.lerp(
          _hotYellow,
          baseColor,
          _hash(i + 153) * 0.35,
        )!.withValues(alpha: 0.34 * fade);
      canvas.drawLine(start, end, _paint);

      if (i.isEven) {
        _fillPaint.color = _hotOrange.withValues(alpha: 0.28 * fade);
        canvas.drawCircle(
          end,
          tileSize * (0.018 + _hash(i + 154) * 0.018),
          _fillPaint,
        );
      }
    }
  }

  void _drawSparks(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
    Color? color,
  }) {
    final sparkColor = color ?? baseColor;
    final step = max(1, (count / 56).ceil());
    for (var i = 0; i < count; i += step) {
      final angle = i * 2.399963 + sin(i * 7.13) * 0.2;
      final velocity = (0.22 + _hash(i) * 0.78) * spread;
      final travel = Curves.easeOut.transform(t) * velocity;
      final p = center + Offset(cos(angle), sin(angle)) * travel;
      final size = tileSize * (0.025 + _hash(i + 17) * 0.045) * fade;
      _fillPaint
        ..maskFilter = null
        ..color = Color.lerp(
          Colors.white,
          sparkColor,
          _hash(i + 23),
        )!.withValues(alpha: (0.45 + _hash(i + 9) * 0.45) * fade);
      canvas.drawCircle(p, size, _fillPaint);
    }
    _fillPaint.maskFilter = null;
  }

  void _drawEmbers(
    Canvas canvas,
    Offset center,
    double t,
    double fade, {
    required int count,
    required double spread,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + 0.45;
      final travel = spread * (0.18 + _hash(i + 120) * 0.72) * t;
      final p = center + Offset(cos(angle), sin(angle)) * travel;
      final h = tileSize * (0.08 + _hash(i + 121) * 0.10) * fade;
      final w = h * (0.35 + _hash(i + 122) * 0.18);
      final dir = Offset(cos(angle), sin(angle));
      final side = Offset(-dir.dy, dir.dx);
      final path = Path()
        ..moveTo((p + dir * h).dx, (p + dir * h).dy)
        ..quadraticBezierTo(
          (p + side * w).dx,
          (p + side * w).dy,
          (p - dir * h * 0.55).dx,
          (p - dir * h * 0.55).dy,
        )
        ..quadraticBezierTo(
          (p - side * w * 0.75).dx,
          (p - side * w * 0.75).dy,
          (p + dir * h).dx,
          (p + dir * h).dy,
        )
        ..close();
      _fillPaint.color = Color.lerp(
        _hotYellow,
        _hotOrange,
        _hash(i + 123),
      )!.withValues(alpha: 0.42 * fade);
      canvas.drawPath(path, _fillPaint);
    }
  }

  void _drawCellFlash(
    Canvas canvas,
    double t,
    double fade, {
    required int maxCells,
    required Color color,
  }) {
    if (affectedCenters.isEmpty) return;
    final step = max(1, (affectedCenters.length / maxCells).ceil());
    final radius = tileSize * (0.34 + 0.30 * sin(t * pi).abs());
    for (var i = 0; i < affectedCenters.length; i += step) {
      final center = affectedCenters[i].toOffset();
      _drawRadialGlow(
        canvas,
        center,
        radius,
        [
          Colors.white.withValues(alpha: 0.20 * fade),
          color.withValues(alpha: 0.24 * fade),
          Colors.transparent,
        ],
        const [0.0, 0.42, 1.0],
      );
    }
  }

  Offset _axisExtreme({required bool horizontal, required bool first}) {
    if (affectedCenters.isEmpty) return origin.toOffset();
    var chosen = affectedCenters.first;
    for (final center in affectedCenters.skip(1)) {
      if (horizontal) {
        if ((first && center.x < chosen.x) || (!first && center.x > chosen.x)) {
          chosen = center;
        }
      } else {
        if ((first && center.y < chosen.y) || (!first && center.y > chosen.y)) {
          chosen = center;
        }
      }
    }
    return chosen.toOffset();
  }

  Offset _orbitPoint(Offset center, double radius, double t, int i) {
    final angle = i * 2 * pi / 18 + t * pi * (1.6 + (i % 3) * 0.25);
    final wobble = sin(t * pi * 4 + i) * tileSize * 0.12;
    return center + Offset(cos(angle), sin(angle)) * (radius + wobble);
  }

  double _hash(int value) {
    final n = sin(value * 12.9898 + 78.233) * 43758.5453;
    return n - n.floorToDouble();
  }

  double _easeOut(double value) => 1 - pow(1 - value, 3).toDouble();
}

class SpecialEffectPool {
  SpecialEffectPool(this._parent);

  final Component _parent;
  final List<SpecialEffectBurst> _pool = [];

  int get cachedCount => _pool.length;

  void spawn({
    required GemKind effectKind,
    required Vector2 origin,
    required List<Vector2> affectedCenters,
    required double tileSize,
    required Color baseColor,
  }) {
    final burst = _pool.isNotEmpty ? _pool.removeLast() : _createBurst();
    burst.activate(
      effectKind: effectKind,
      origin: origin,
      affectedCenters: affectedCenters,
      tileSize: tileSize,
      baseColor: baseColor,
    );
    if (!burst.isMounted) {
      _parent.add(burst);
    }
  }

  SpecialEffectBurst _createBurst() {
    final burst = SpecialEffectBurst();
    burst._onExpired = _returnToPool;
    return burst;
  }

  void _returnToPool(SpecialEffectBurst burst) {
    _pool.add(burst);
  }
}
