import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';

part 'board_juice_glyphs.dart';
part 'board_juice_events.dart';

/// 매치 파티클(충격파 링, 섬광, 파편, 별), 유휴 반짝임, 점수 팝업, 콤보 콜아웃을
/// 한 컴포넌트에서 그린다.
///
/// 모바일 웹 예산(PLAN-001) 때문에 파티클은 고정 크기 typed 버퍼를 돌려 쓰고
/// 종류가 달라도 아틀라스 한 장에서 프레임당 `drawRawAtlas` 1회로 끝낸다.
/// 광륜은 아틀라스에 미리 구워 두어 런타임 blur, saveLayer, 프레임당 객체 생성이 없다.
/// 숫자는 글리프 아틀라스, 콜아웃만 이벤트당 [TextPainter] 1개를 사용한다.
class BoardJuiceLayer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  BoardJuiceLayer() : super(priority: 130);

  static const int maxSparks = 192;
  static const int _sparkBudgetPerBurst = 150;
  static const int _textSlots = 1;
  static const double _atlasSize = 64;
  static const double _gravity = 620;

  // 파티클 종류. 앞 네 개는 아틀라스 칸 번호와 같다(반짝임은 별 칸을 쓴다).
  static const int _star = 0;
  static const int _flash = 1;
  static const int _ring = 2;
  static const int _shard = 3;
  static const int _twinkleKind = 4;

  static const List<String> _praise = [
    'GOOD!',
    'GREAT!',
    'AWESOME!',
    'AMAZING!',
    'UNBELIEVABLE!',
  ];
  static const Color _gold = Color(0xFFFFD052);

  final math.Random _rng = math.Random();
  ui.Image? _atlas;
  final Paint _atlasPaint = Paint()..blendMode = BlendMode.plus;

  // 살아 있는 슬롯만 압축한다. 길이별 뷰는 생성 시 한 번 캐시한다.
  final Float32List _rst = Float32List(maxSparks * 4);
  final Float32List _src = Float32List(maxSparks * 4);
  final Int32List _argb = Int32List(maxSparks);
  late final List<Float32List> _rstViews = List.generate(
    maxSparks + 1,
    (n) => Float32List.sublistView(_rst, 0, n * 4),
  );
  late final List<Float32List> _srcViews = List.generate(
    maxSparks + 1,
    (n) => Float32List.sublistView(_src, 0, n * 4),
  );
  late final List<Int32List> _argbViews = List.generate(
    maxSparks + 1,
    (n) => Int32List.sublistView(_argb, 0, n),
  );

  final Float32List _x = Float32List(maxSparks);
  final Float32List _y = Float32List(maxSparks);
  final Float32List _vx = Float32List(maxSparks);
  final Float32List _vy = Float32List(maxSparks);
  final Float32List _gravityBySpark = Float32List(maxSparks);
  final Float32List _age = Float32List(maxSparks);
  final Float32List _life = Float32List(maxSparks);
  final Float32List _scale = Float32List(maxSparks);
  final Float32List _rot = Float32List(maxSparks);
  final Float32List _spin = Float32List(maxSparks);
  final Int32List _rgb = Int32List(maxSparks);
  final Uint8List _kind = Uint8List(maxSparks);
  int _nextSpark = 0;
  int _liveSparks = 0;
  double _twinkleTimer = 1;

  final List<_FloatText> _texts = List.generate(
    _textSlots,
    (_) => _FloatText(),
  );
  final _glyphs = _JuiceGlyphs();
  double _calloutHold = 0;

  /// 레벨업 대기 판정용. 유휴 반짝임은 포함하지 않는다.
  double _busyTime = 0;
  bool get busy => _busyTime > 0;
  int get liveSparkCount => _liveSparks;

  @override
  void onMount() {
    super.onMount();
    _atlas ??= _buildSparkAtlas();
    _glyphs.mount();
    // lazy 필드를 여기서 초기화해 첫 render에도 할당하지 않는다.
    _rstViews;
    _srcViews;
    _argbViews;
  }

  @override
  void onRemove() {
    _atlas?.dispose();
    _atlas = null;
    _glyphs.dispose();
    _calloutHold = 0;
    for (final text in _texts) {
      text.painter?.dispose();
      text.painter = null;
    }
    _life.fillRange(0, maxSparks, 0);
    _liveSparks = 0;
    _busyTime = 0;
    super.onRemove();
  }

  /// 별, 섬광, 충격파 링, 파편을 가로로 나란히 한 번만 구워 둔다. 모두 흰색이고
  /// 그릴 때 파티클 색을 곱한다.
  static ui.Image _buildSparkAtlas() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = _atlasSize;
    const half = size / 2;
    const white = Color(0xFFFFFFFF);
    const clear = Color(0x00FFFFFF);
    final fill = Paint()..color = white;

    void glow(double cx, double radius, double alpha) => canvas.drawCircle(
      Offset(cx, half),
      radius,
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, half), radius, [
          white.withValues(alpha: alpha),
          clear,
        ]),
    );

    // 0: 4각 별
    glow(half, half, 0.55);
    final star = Path()..moveTo(half, 1);
    for (var i = 1; i < 8; i++) {
      final r = i.isEven ? half - 1 : size * 0.075;
      final a = -math.pi / 2 + i * math.pi / 4;
      star.lineTo(half + math.cos(a) * r, half + math.sin(a) * r);
    }
    canvas.drawPath(star..close(), fill);

    // 1: 섬광
    const flashX = size + half;
    canvas.drawCircle(
      const Offset(flashX, half),
      half,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(flashX, half),
          half,
          const [white, Color(0x88FFFFFF), clear],
          const [0, 0.12, 1],
        ),
    );

    // 2: 충격파 링
    const ringX = size * 2 + half;
    canvas.drawCircle(
      const Offset(ringX, half),
      half,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(ringX, half),
          half,
          const [clear, clear, Color(0xF2FFFFFF), Color(0x40FFFFFF), clear],
          const [0, 0.76, 0.82, 0.87, 1],
        ),
    );

    // 3: 파편. +x 방향으로 길어서 속도 방향으로 돌려 그린다.
    const shardX = size * 3 + half;
    glow(shardX, half * 0.6, 0.35);
    canvas.drawPath(
      Path()
        ..moveTo(shardX - half + 3, half)
        ..lineTo(shardX + 2, half - 6)
        ..lineTo(shardX + half - 2, half)
        ..lineTo(shardX + 2, half + 6)
        ..close(),
      fill,
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync((size * 4).toInt(), size.toInt());
    picture.dispose();
    return image;
  }

  /// 제거 진입 때 한 번만 빛을 낸다. 사각형 셀 오버레이를 대체한다.
  void onRemovalStarted(Map<String, bool> cells) {
    final board = game.board;
    final ts = board.tileSize;
    for (final key in cells.keys) {
      final split = key.indexOf(':');
      final row = int.parse(key.substring(0, split));
      final col = int.parse(key.substring(split + 1));
      _emit(
        _flash,
        board.boardX + (col + 0.5) * ts,
        board.boardY + (row + 0.5) * ts,
        life: 0.12,
        scale: ts / _atlasSize * 0.65,
        rgb: 0xFFF3D0,
      );
    }
  }

  /// 제거된 칸마다 보석 색 파편을 터뜨리고, 점수 팝업과 콤보 콜아웃을 띄운다.
  void onGemsRemoved(
    List<({int row, int col, int color})> cells, {
    required bool bigMatch,
    required bool hasSpecial,
    required int combo,
    required int gained,
    MatchJuicePattern pattern = MatchJuicePattern.normal,
  }) {
    if (cells.isEmpty) return;
    final board = game.board;
    final ts = board.tileSize;
    if (ts <= 0) return;

    // 칸마다 링 + 섬광은 항상, 파편과 별은 예산 안에서 단계별로.
    final wanted = hasSpecial || combo >= 3
        ? 14
        : (bigMatch || combo >= 2 ? 12 : 10);
    final extras = (_sparkBudgetPerBurst ~/ cells.length - 2).clamp(0, wanted);
    final power = 1 + math.min(combo, 6) * 0.07 + pattern.index * 0.08;
    final unit = ts / _atlasSize;
    // 2026-09-24 사용자 체감(퍼지고 사라지는 속도가 느림)으로 1.4, 0.65에서 올렸다.
    const speedUp = 1.75;
    const lifeScale = 0.5;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final cell in cells) {
      final cx = board.boardX + (cell.col + 0.5) * ts;
      final cy = board.boardY + (cell.row + 0.5) * ts;
      sumX += cx;
      sumY += cy;
      final rgb = _sparkRgb(cell.color);
      _emit(
        _ring,
        cx,
        cy,
        life: 0.32 * lifeScale,
        scale: unit * 1.25 * power,
        rgb: rgb,
      );
      _emit(
        _flash,
        cx,
        cy,
        life: 0.12 * lifeScale,
        scale: unit * 0.75,
        rgb: 0xFFF3D0,
      );
      for (var i = 0; i < extras; i++) {
        final angle = switch (pattern) {
          MatchJuicePattern.four => i * math.pi / 2 + math.pi / 4,
          MatchJuicePattern.five => i * 2 * math.pi / 5,
          MatchJuicePattern.sixPlus => i * 2 * math.pi / math.max(1, extras),
          MatchJuicePattern.cross => i * math.pi / 2,
          MatchJuicePattern.normal => _rng.nextDouble() * 2 * math.pi,
        };
        final speed = ts * (1.8 + _rng.nextDouble() * 3.6) * power * speedUp;
        final isStar = i % 3 == 2;
        _emit(
          isStar ? _star : _shard,
          cx,
          cy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          gravity: 0,
          life: (0.55 + _rng.nextDouble() * 0.25) * lifeScale,
          scale: unit * (0.46 + _rng.nextDouble() * 0.32) * power,
          rgb: pattern == MatchJuicePattern.five
              ? _sparkRgb(i % 6 + 1)
              : isStar
              ? 0xFFFFFF
              : rgb,
        );
      }
    }
    _busyTime = math.max(_busyTime, 0.8);

    final centerX = sumX / cells.length;
    final centerY = sumY / cells.length;
    if (combo >= 2) {
      _emit(
        _ring,
        centerX,
        centerY,
        life: 0.36 * lifeScale,
        scale: unit * (combo == 2 ? 1.6 : 2.0),
        rgb: 0xFFD052,
      );
      final accents = combo == 2 ? 4 : 8;
      for (var i = 0; i < accents; i++) {
        final angle = i * 2 * math.pi / accents;
        _emit(
          _star,
          centerX,
          centerY,
          vx: math.cos(angle) * ts * 2 * speedUp,
          vy: math.sin(angle) * ts * 2 * speedUp,
          gravity: 0,
          life: 0.5 * lifeScale,
          scale: unit * 0.55,
          rgb: 0xFFD052,
        );
      }
    }
    if (gained > 0) {
      final first = cells.first.color;
      final scoreY = math.max(
        math.min(
          centerY - math.min(combo - 1, 4) * ts * 0.32,
          board.boardY + (board.rows - 1.6) * ts,
        ),
        board.boardY + ts * 2,
      );
      _glyphs.show(
        '+$gained',
        x: centerX,
        y: scoreY,
        size: ts * (0.40 + math.min(combo, 6) * 0.035),
        rgb:
            Color.lerp(_paletteColor(first), Colors.white, 0.6)!.toARGB32() &
            0xFFFFFF,
        left: board.boardX,
        right: board.boardX + board.cols * ts,
        rise: math.min(ts * 1.5, scoreY - board.boardY - ts * 1.15),
      );
    }
    if (combo >= 2 && _calloutHold <= 0) {
      final word = _praise[math.min(combo - 2, _praise.length - 1)];
      _showText(
        slot: 0,
        text: '$word ×$combo',
        x: board.boardX + board.cols * ts / 2,
        y: board.boardY + ts * 0.55,
        fontSize: ts * (combo <= 3 ? 0.48 : 0.68),
        color: _gold,
        duration: combo <= 3 ? 0.6 : 0.8,
        rise: ts * 0.22,
      );
    }
  }

  static Color _paletteColor(int color1based) =>
      color1based >= 1 && color1based <= MatchBoardLogic.palette.length
      ? MatchBoardLogic.palette[color1based - 1]
      : Colors.white;

  /// 가산 합성에서 색이 죽지 않도록 팔레트를 흰색 쪽으로 살짝 끌어올린다.
  static int _sparkRgb(int color1based) =>
      Color.lerp(_paletteColor(color1based), Colors.white, 0.25)!.toARGB32() &
      0xFFFFFF;

  void _emit(
    int kind,
    double x,
    double y, {
    double vx = 0,
    double vy = 0,
    double gravity = _gravity,
    required double life,
    required double scale,
    required int rgb,
  }) {
    final i = _nextSpark;
    _nextSpark = (_nextSpark + 1) % maxSparks;
    if (_life[i] <= 0) _liveSparks++;
    _kind[i] = kind;
    _x[i] = x;
    _y[i] = y;
    _vx[i] = vx;
    _vy[i] = vy;
    _gravityBySpark[i] = gravity;
    _age[i] = 0;
    _life[i] = life;
    _scale[i] = scale;
    _rot[i] = _rng.nextDouble() * math.pi;
    _spin[i] = (_rng.nextDouble() - 0.5) * (kind == _star ? 14 : 2);
    _rgb[i] = rgb;
  }

  void _showText({
    required int slot,
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    required double duration,
    required double rise,
  }) {
    final board = game.board;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AssetPaths.fontNexonLv2Gothic,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [
            Shadow(color: Color(0xE6000000), offset: Offset(0, 2)),
            Shadow(color: Color(0xB3000000), offset: Offset(0, -1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final half = painter.width / 2;
    final left = board.boardX + half;
    final right = board.boardX + board.cols * board.tileSize - half;
    _texts[slot]
      ..painter?.dispose()
      ..painter = painter
      ..x = left <= right ? x.clamp(left, right).toDouble() : x
      ..y = y
      ..age = 0
      ..duration = duration
      ..rise = rise;
    _busyTime = math.max(_busyTime, duration);
  }

  @override
  void update(double dt) {
    if (_busyTime > 0) _busyTime -= dt;
    _calloutHold = math.max(0, _calloutHold - dt);
    _observeGemMotion();
    _glyphs.update(dt);
    _updateTwinkle(dt);
    _updateSparks(dt);
    for (final text in _texts) {
      if (text.painter == null) continue;
      text.age += dt;
      if (text.age >= text.duration) {
        text.painter!.dispose();
        text.painter = null;
      }
    }
  }

  /// 보드가 쉬는 동안 임의의 보석 하이라이트 위치에서 별빛이 피었다 진다.
  void _updateTwinkle(double dt) {
    final board = game.board;
    if (!game.isPlaying || board.state != 'idle' || board.introFillInProgress) {
      return;
    }
    _twinkleTimer -= dt;
    if (_twinkleTimer > 0) return;
    _twinkleTimer = 0.22 + _rng.nextDouble() * 0.1;
    final gem = board.getGem(
      _rng.nextInt(board.rows),
      _rng.nextInt(board.cols),
    );
    if (gem == null) return;
    final ts = board.tileSize;
    _emit(
      _twinkleKind,
      gem.targetX + ts * (0.30 + _rng.nextDouble() * 0.12),
      gem.targetY + ts * (0.28 + _rng.nextDouble() * 0.12),
      life: 0.5 + _rng.nextDouble() * 0.25,
      scale: ts / _atlasSize * (0.6 + _rng.nextDouble() * 0.2),
      rgb: 0xFFFFFF,
    );
  }

  void _updateSparks(double dt) {
    if (_liveSparks == 0) return;
    final drag = math.max(0.0, 1 - 2.6 * dt);
    const half = _atlasSize / 2;
    var live = 0;
    for (var i = 0; i < maxSparks; i++) {
      final life = _life[i];
      if (life <= 0) continue;
      final age = _age[i] + dt;
      final o = live * 4;
      if (age >= life) {
        _life[i] = 0;
        continue;
      }
      final cell = _kind[i] == _twinkleKind ? _star : _kind[i];
      _src[o] = cell * _atlasSize;
      _src[o + 1] = 0;
      _src[o + 2] = (cell + 1) * _atlasSize;
      _src[o + 3] = _atlasSize;
      _age[i] = age;
      final p = age / life;
      final kind = _kind[i];
      double scale;
      double alpha;
      if (kind == _twinkleKind) {
        final bloom = math.sin(p * math.pi);
        scale = _scale[i] * bloom;
        alpha = bloom * (2 / 3);
        _rot[i] += _spin[i] * dt;
      } else if (kind == _ring) {
        // 빠르게 퍼지고 천천히 옅어진다.
        scale = _scale[i] * (0.25 + 0.75 * (1 - (1 - p) * (1 - p)));
        alpha = (1 - p) * (1 - p);
      } else if (kind == _flash) {
        scale = _scale[i] * (0.6 + 0.4 * p);
        alpha = 1 - p * p;
      } else {
        _vx[i] *= drag;
        _vy[i] = _vy[i] * drag + _gravityBySpark[i] * dt;
        _x[i] += _vx[i] * dt;
        _y[i] += _vy[i] * dt;
        scale = _scale[i] * (1 - 0.55 * p);
        alpha = p < 0.35 ? 1 : 1 - (p - 0.35) / 0.65;
        if (kind == _shard) {
          _rot[i] = math.atan2(_vy[i], _vx[i]);
        } else {
          _rot[i] += _spin[i] * dt;
        }
      }
      final scos = math.cos(_rot[i]) * scale;
      final ssin = math.sin(_rot[i]) * scale;
      _rst[o] = scos;
      _rst[o + 1] = ssin;
      _rst[o + 2] = _x[i] - scos * half + ssin * half;
      _rst[o + 3] = _y[i] - ssin * half - scos * half;
      _argb[live] = ((alpha * 255).round() << 24) | _rgb[i];
      live++;
    }
    _liveSparks = live;
  }

  @override
  void render(Canvas canvas) {
    final shake = game.boardShakeOffset;
    final shaking = shake.x != 0 || shake.y != 0;
    if (shaking) {
      canvas.save();
      canvas.translate(shake.x, shake.y);
    }
    final atlas = _atlas;
    if (atlas != null && _liveSparks > 0) {
      canvas.drawRawAtlas(
        atlas,
        _rstViews[_liveSparks],
        _srcViews[_liveSparks],
        _argbViews[_liveSparks],
        BlendMode.modulate,
        null,
        _atlasPaint,
      );
    }
    _glyphs.render(canvas);
    for (final text in _texts) {
      final painter = text.painter;
      if (painter == null) continue;
      final p = text.age / text.duration;
      // 튀어나오며 등장하고, 떠오르다가, 끝에서 스케일로 사라진다.
      final double scale;
      if (p < 0.18) {
        final q = p / 0.18;
        scale = 0.4 + 0.75 * q;
      } else if (p < 0.3) {
        scale = 1.15 - 0.15 * (p - 0.18) / 0.12;
      } else if (p > 0.78) {
        scale = 1 - (p - 0.78) / 0.22;
      } else {
        scale = 1;
      }
      final lift = text.rise * (1 - (1 - p) * (1 - p));
      canvas.save();
      canvas.translate(text.x, text.y - lift);
      canvas.scale(scale);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
    if (shaking) canvas.restore();
  }
}

class _FloatText {
  TextPainter? painter;
  double x = 0;
  double y = 0;
  double age = 0;
  double duration = 1;
  double rise = 0;
}
