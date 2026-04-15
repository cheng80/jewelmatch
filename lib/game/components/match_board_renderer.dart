import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';

/// 매치 보드 격자·보석·플래시·선택 표시.
/// `Jewel.png`(896×128, 7프레임×128) + `Special.png`(384×128, 3프레임×128) 사용.
///
/// 힌트: [MatchBoardLogic.showHint]가 고른 **한 쌍**만, 보석 위에 흰색 펄스(느리게 깜박임).
/// 다른 칸에는 오버레이를 그리지 않는다.
class MatchBoardRenderer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  MatchBoardRenderer({required this.logic});

  final MatchBoardLogic logic;

  static const double _slotRadiusRatio = 0.18;

  /// 기본 보석 스프라이트 시트 열 0~6 (각 128×128).
  final List<Sprite?> _sheetSprites = List<Sprite?>.filled(7, null);
  final Map<GemKind, Sprite?> _specialSprites = <GemKind, Sprite?>{};

  static const double _frameW = 128;
  static const double _frameH = 128;
  static const List<GemKind> _specialSheetKinds = <GemKind>[
    GemKind.col,
    GemKind.row,
    GemKind.bomb,
  ];

  /// 힌트 펄스 위상 속도(낮을수록 느리게 한 박자).
  static const double _hintPulseHz = 0.32;

  /// `flame_tab_order` [CubeButton]과 같은 cos 펄스, 다만 [_hintPulseHz]로 속도만 조정.
  double _hintPulseTime = 0;

  /// 게임 색상 1~6 → 시트 열 인덱스 (시트 순서: 빨강, 은백, 초록, 노랑, 보라, 주황, 파랑).
  static const List<int> _sheetColByColor1based = [0, 6, 3, 2, 4, 5];

  ui.Picture? _boardChromePicture;
  double? _cachedTileSize;
  double? _cachedBoardX;
  double? _cachedBoardY;
  final Paint _flashPaint = Paint();
  final Paint _selectionPaint = Paint()
    ..color = JewelCandyLuminaTheme.secondaryCyan
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _hintPulsePaint = Paint();
  final Paint _normalSpritePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _proceduralShadowPaint = Paint();
  final Paint _proceduralGradientPaint = Paint();
  final Paint _proceduralStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _proceduralHighlightPaint = Paint();
  final Vector2 _spriteRenderPosition = Vector2.zero();
  final Vector2 _spriteRenderSize = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final img = await Flame.images.load(AssetPaths.jewelSpriteSheet);
      for (var i = 0; i < 7; i++) {
        _sheetSprites[i] = Sprite(
          img,
          srcPosition: Vector2(i * _frameW, 0),
          srcSize: Vector2(_frameW, _frameH),
        );
      }
    } catch (_) {
      for (var i = 0; i < 7; i++) {
        _sheetSprites[i] = null;
      }
    }
    try {
      final img = await Flame.images.load(AssetPaths.specialSpriteSheet);
      for (var i = 0; i < _specialSheetKinds.length; i++) {
        _specialSprites[_specialSheetKinds[i]] = Sprite(
          img,
          srcPosition: Vector2(i * _frameW, 0),
          srcSize: Vector2(_frameW, _frameH),
        );
      }
    } catch (_) {
      for (final kind in _specialSheetKinds) {
        _specialSprites[kind] = null;
      }
    }
    _rebuildBoardChromePicture();
  }

  @override
  void onRemove() {
    _boardChromePicture?.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ha = logic.hintCellA;
    final hb = logic.hintCellB;
    if (ha != null &&
        hb != null &&
        logic.state == 'idle' &&
        !logic.introFillInProgress) {
      _hintPulseTime += dt;
    } else {
      _hintPulseTime = 0;
    }
  }

  int _spriteColumnFor(BoardGem gem) {
    if (gem.kind == GemKind.hyper) {
      return 1;
    }
    final c = gem.color.clamp(1, 6);
    return _sheetColByColor1based[c - 1];
  }

  Sprite? _specialSpriteFor(GemKind kind) {
    return _specialSprites[kind];
  }

  void _ensureBoardChromePicture() {
    final ts = logic.tileSize;
    final bx = logic.boardX;
    final by = logic.boardY;
    if (_boardChromePicture != null &&
        _cachedTileSize == ts &&
        _cachedBoardX == bx &&
        _cachedBoardY == by) {
      return;
    }
    _rebuildBoardChromePicture();
  }

  void _rebuildBoardChromePicture() {
    _boardChromePicture?.dispose();
    final ts = logic.tileSize;
    final bx = logic.boardX;
    final by = logic.boardY;
    if (ts <= 0) {
      _boardChromePicture = null;
      _cachedTileSize = ts;
      _cachedBoardX = bx;
      _cachedBoardY = by;
      return;
    }

    final bw = logic.cols * ts;
    final bh = logic.rows * ts;
    final outerRect = Rect.fromLTWH(bx - 8, by - 8, bw + 16, bh + 16);
    final outerR = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(14),
    );
    final innerR = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      const Radius.circular(10),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRRect(
      outerR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: JewelCandyLuminaTheme.boardFrameGradient,
        ).createShader(outerRect),
    );
    canvas.drawRRect(
      innerR,
      Paint()..color = JewelCandyLuminaTheme.boardInner,
    );

    const pad = 3.0;
    final fillPaint = Paint()..color = JewelCandyLuminaTheme.boardSlotFill;
    final strokePaint = Paint()
      ..color = JewelCandyLuminaTheme.boardSlotStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final slotRadius = Radius.circular(ts * _slotRadiusRatio);
    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final x = bx + c * ts;
        final y = by + r * ts;
        final sr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + pad, y + pad, ts - pad * 2, ts - pad * 2),
          slotRadius,
        );
        canvas.drawRRect(sr, fillPaint);
        canvas.drawRRect(sr, strokePaint);
      }
    }

    _boardChromePicture = recorder.endRecording();
    _cachedTileSize = ts;
    _cachedBoardX = bx;
    _cachedBoardY = by;
  }

  @override
  void render(Canvas canvas) {
    _ensureBoardChromePicture();
    final ts = logic.tileSize;
    final bw = logic.cols * ts;
    final bh = logic.rows * ts;
    final bx = logic.boardX;
    final by = logic.boardY;

    final innerR = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      const Radius.circular(10),
    );
    if (_boardChromePicture != null) {
      canvas.drawPicture(_boardChromePicture!);
    }

    final needsBoardClip = logic.introFillInProgress ||
        logic.state == 'falling' ||
        logic.state == 'refilling';
    if (needsBoardClip) {
      // 보드 밖에서 내려오는 낙하/리필 연출일 때만 클립한다.
      canvas.save();
      canvas.clipRRect(innerR);
    }

    for (final fx in logic.flashEffects) {
      final a = (fx.timer / MatchBoardLogic.flashDuration).clamp(0.0, 1.0) *
          MatchBoardLogic.flashAlpha;
      final fr = RRect.fromRectAndRadius(
        Rect.fromLTWH(fx.x + 4, fx.y + 4, fx.size - 8, fx.size - 8),
        Radius.circular(ts * 0.12),
      );
      _flashPaint.color = Colors.white.withValues(alpha: a);
      canvas.drawRRect(
        fr,
        _flashPaint,
      );
    }

    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final gem = logic.getGem(r, c);
        if (gem != null) {
          _drawGem(canvas, gem, ts);
        }
      }
    }

    _drawHintWhitePulse(canvas, bx, by, ts);

    final sel = logic.selected;
    if (sel != null && logic.state == 'idle') {
      final x = bx + sel.y * ts;
      final y = by + sel.x * ts;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, y + 2, ts - 4, ts - 4),
          Radius.circular(ts * 0.15),
        ),
        _selectionPaint,
      );
    }

    if (needsBoardClip) {
      canvas.restore();
    }
  }

  /// 힌트로 고른 두 칸만, 보석 **위에** 흰색 펄스(다른 칸은 건드리지 않음).
  void _drawHintWhitePulse(Canvas canvas, double bx, double by, double ts) {
    final ha = logic.hintCellA;
    final hb = logic.hintCellB;
    if (ha == null ||
        hb == null ||
        logic.state != 'idle' ||
        logic.introFillInProgress) {
      return;
    }

    final t = (_hintPulseTime * _hintPulseHz) % 1.0;
    final alpha =
        0.14 + 0.42 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
    _hintPulsePaint.color = Color.lerp(
      JewelCandyLuminaTheme.secondaryCyan,
      JewelCandyLuminaTheme.primaryPink,
      0.35,
    )!
        .withValues(alpha: alpha);
    final radius = Radius.circular(ts * _slotRadiusRatio);
    const pad = 3.0;

    void pulseCell(int r, int c) {
      final x = bx + c * ts;
      final y = by + r * ts;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + pad, y + pad, ts - pad * 2, ts - pad * 2),
          radius,
        ),
        _hintPulsePaint,
      );
    }

    pulseCell(ha.x, ha.y);
    pulseCell(hb.x, hb.y);
  }

  void _drawGem(Canvas canvas, BoardGem gem, double ts) {
    final x = gem.x;
    final y = gem.y;
    final drawW = ts * 0.82;
    final drawH = ts * 0.82;
    final ox = x + (ts - drawW) / 2;
    final oy = y + (ts - drawH) / 2;
    final sprite = _specialSpriteFor(gem.kind) ?? _sheetSprites[_spriteColumnFor(gem)];
    if (sprite != null) {
      _spriteRenderPosition.setValues(ox, oy);
      _spriteRenderSize.setValues(drawW, drawH);
      sprite.render(
        canvas,
        position: _spriteRenderPosition,
        size: _spriteRenderSize,
        overridePaint: _normalSpritePaint,
      );
    } else {
      _drawGemProcedural(canvas, gem, ts);
    }
  }

  void _drawGemProcedural(Canvas canvas, BoardGem gem, double ts) {
    final base = gem.kind == GemKind.hyper
        ? const Color(0xFFE8E8FF)
        : MatchBoardLogic.palette[
            gem.color.clamp(1, MatchBoardLogic.palette.length) - 1];

    final x = gem.x;
    final y = gem.y;
    final size = ts;
    final cx = x + size / 2;
    final cy = y + size / 2;

    final shadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 3),
        width: size * 0.78,
        height: size * 0.78,
      ),
      Radius.circular(size * 0.2),
    );
    canvas.drawRRect(
      shadow,
      _proceduralShadowPaint..color = Colors.black.withValues(alpha: 0.28),
    );

    final outer = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size * 0.72,
        height: size * 0.72,
      ),
      Radius.circular(size * 0.16),
    );
    canvas.drawRRect(
      outer,
      _proceduralGradientPaint
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.22)!,
            Color.lerp(base, Colors.black, 0.15)!,
          ],
        ).createShader(outer.outerRect),
    );

    canvas.drawRRect(
      outer,
      _proceduralStrokePaint..color = Colors.white.withValues(alpha: 0.14),
    );

    final hi = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - size * 0.08, cy - size * 0.1),
        width: size * 0.28,
        height: size * 0.22,
      ),
      Radius.circular(size * 0.1),
    );
    canvas.drawRRect(
      hi,
      _proceduralHighlightPaint..color = Colors.white.withValues(alpha: 0.32),
    );
  }
}
