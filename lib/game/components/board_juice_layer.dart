import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';

/// 매치 파티클(충격파 링, 섬광, 파편, 별), 유휴 반짝임, 점수 팝업, 콤보 콜아웃을
/// 한 컴포넌트에서 그린다.
///
/// 모바일 웹 예산(PLAN-001) 때문에 파티클은 고정 크기 typed 버퍼를 돌려 쓰고
/// 종류가 달라도 아틀라스 한 장에서 프레임당 `drawRawAtlas` 1회로 끝낸다.
/// 광륜은 아틀라스에 미리 구워 두어 런타임 blur, saveLayer, 프레임당 객체 생성이 없다.
/// 텍스트는 이벤트당 [TextPainter] 1개만 만들고 알파 대신 스케일로 사라진다.
class BoardJuiceLayer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  BoardJuiceLayer() : super(priority: 130);

  static const int maxSparks = 192;
  static const int _sparkBudgetPerBurst = 150;
  static const int _textSlots = 6;
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

  // drawRawAtlas 입력 버퍼. 비활성 슬롯은 스케일 0으로 남겨 길이를 고정한다.
  final Float32List _rst = Float32List(maxSparks * 4);
  final Float32List _src = Float32List(maxSparks * 4);
  final Int32List _argb = Int32List(maxSparks);

  final Float32List _x = Float32List(maxSparks);
  final Float32List _y = Float32List(maxSparks);
  final Float32List _vx = Float32List(maxSparks);
  final Float32List _vy = Float32List(maxSparks);
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
  int _nextScoreSlot = 1;

  /// 레벨업 대기 판정용. 유휴 반짝임은 포함하지 않는다.
  double _busyTime = 0;
  bool get busy => _busyTime > 0;
  int get liveSparkCount => _liveSparks;

  @override
  Future<void> onLoad() async {
    _atlas = _buildSparkAtlas();
  }

  @override
  void onRemove() {
    _atlas?.dispose();
    _atlas = null;
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
          const [0, 0.38, 1],
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
          const [0, 0.6, 0.8, 0.92, 1],
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

  /// 제거된 칸마다 보석 색 파편을 터뜨리고, 점수 팝업과 콤보 콜아웃을 띄운다.
  void onGemsRemoved(
    List<({int row, int col, int color})> cells, {
    required bool bigMatch,
    required bool hasSpecial,
    required int combo,
    required int gained,
  }) {
    if (cells.isEmpty) return;
    final board = game.board;
    final ts = board.tileSize;
    if (ts <= 0) return;

    // 칸마다 링 + 섬광은 항상, 파편과 별은 예산 안에서 단계별로.
    final wanted = hasSpecial || combo >= 3
        ? 10
        : (bigMatch || combo >= 2 ? 8 : 6);
    final extras = (_sparkBudgetPerBurst ~/ cells.length - 2).clamp(0, wanted);
    final power = 1 + math.min(combo, 6) * 0.07;
    final unit = ts / _atlasSize;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final cell in cells) {
      final cx = board.boardX + (cell.col + 0.5) * ts;
      final cy = board.boardY + (cell.row + 0.5) * ts;
      sumX += cx;
      sumY += cy;
      final rgb = _sparkRgb(cell.color);
      _emit(_ring, cx, cy, life: 0.4, scale: unit * 1.7 * power, rgb: rgb);
      _emit(_flash, cx, cy, life: 0.2, scale: unit * 1.35, rgb: 0xFFF3D0);
      for (var i = 0; i < extras; i++) {
        final angle = _rng.nextDouble() * 2 * math.pi;
        final speed = ts * (1.8 + _rng.nextDouble() * 3.6) * power;
        final isStar = i % 3 == 2;
        _emit(
          isStar ? _star : _shard,
          cx,
          cy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - ts * 1.4,
          life: 0.45 + _rng.nextDouble() * 0.32,
          scale: unit * (0.34 + _rng.nextDouble() * 0.3) * power,
          rgb: isStar ? 0xFFFFFF : rgb,
        );
      }
    }
    _busyTime = math.max(_busyTime, 0.5);

    final centerX = sumX / cells.length;
    final centerY = sumY / cells.length;
    if (gained > 0) {
      final first = cells.first.color;
      _showText(
        slot: _nextScoreSlot,
        text: '+$gained',
        x: centerX,
        y: centerY,
        fontSize: ts * (0.40 + math.min(combo, 6) * 0.035),
        color: Color.lerp(_paletteColor(first), Colors.white, 0.6)!,
        duration: 0.85,
        rise: ts * 1.1,
      );
      _nextScoreSlot = _nextScoreSlot % (_textSlots - 1) + 1;
    }
    if (combo >= 2) {
      final word = _praise[math.min(combo - 2, _praise.length - 1)];
      _showText(
        slot: 0,
        text: '$word ×$combo',
        x: board.boardX + board.cols * ts / 2,
        y: board.boardY + board.rows * ts * 0.36,
        fontSize: ts * (0.62 + math.min(combo, 6) * 0.05),
        color: _gold,
        duration: 1.0,
        rise: ts * 0.5,
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
    _age[i] = 0;
    _life[i] = life;
    _scale[i] = scale;
    _rot[i] = _rng.nextDouble() * math.pi;
    _spin[i] = (_rng.nextDouble() - 0.5) * (kind == _star ? 14 : 2);
    _rgb[i] = rgb;
    // drawRawAtlas의 원본 사각형은 LTRB다.
    final cell = kind == _twinkleKind ? _star : kind;
    final o = i * 4;
    _src[o] = cell * _atlasSize;
    _src[o + 1] = 0;
    _src[o + 2] = (cell + 1) * _atlasSize;
    _src[o + 3] = _atlasSize;
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
    _busyTime = math.max(_busyTime, duration * 0.6);
  }

  @override
  void update(double dt) {
    if (_busyTime > 0) _busyTime -= dt;
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
    _twinkleTimer = 0.18 + _rng.nextDouble() * 0.35;
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
      scale: ts / _atlasSize * (0.42 + _rng.nextDouble() * 0.22),
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
      final o = i * 4;
      if (age >= life) {
        _life[i] = 0;
        _rst[o] = 0;
        _rst[o + 1] = 0;
        _argb[i] = 0;
        continue;
      }
      live++;
      _age[i] = age;
      final p = age / life;
      final kind = _kind[i];
      double scale;
      double alpha;
      if (kind == _twinkleKind) {
        final bloom = math.sin(p * math.pi);
        scale = _scale[i] * bloom;
        alpha = bloom;
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
        _vy[i] = _vy[i] * drag + _gravity * dt;
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
      _argb[i] = ((alpha * 255).round() << 24) | _rgb[i];
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
        _rst,
        _src,
        _argb,
        BlendMode.modulate,
        null,
        _atlasPaint,
      );
    }
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
