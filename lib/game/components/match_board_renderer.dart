import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';

/// 매치 보드 격자·보석·플래시·선택 표시.
/// `Juwel.png`(1792×256, 7프레임×256) 스프라이트 시트 사용.
///
/// 힌트: [MatchBoardLogic.showHint]가 고른 **한 쌍**만, 보석 위에 흰색 펄스(느리게 깜박임).
/// 다른 칸에는 오버레이를 그리지 않는다.
class MatchBoardRenderer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  MatchBoardRenderer({required this.logic});

  final MatchBoardLogic logic;

  static const double _slotRadiusRatio = 0.18;

  /// 스프라이트 시트 열 0~6 (각 256×256).
  final List<Sprite?> _sheetSprites = List<Sprite?>.filled(7, null);

  static const double _frameW = 256;
  static const double _frameH = 256;

  /// 힌트 펄스 위상 속도(낮을수록 느리게 한 박자).
  static const double _hintPulseHz = 0.32;

  /// `flame_tab_order` [CubeButton]과 같은 cos 펄스, 다만 [_hintPulseHz]로 속도만 조정.
  double _hintPulseTime = 0;

  /// 게임 색상 1~6 → 시트 열 인덱스 (시트 순서: 빨강, 은백, 초록, 노랑, 보라, 주황, 파랑).
  static const List<int> _sheetColByColor1based = [0, 6, 3, 2, 4, 5];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final img = await Flame.images.load(AssetPaths.juwelSpriteSheet);
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

  @override
  void render(Canvas canvas) {
    final ts = logic.tileSize;
    final bw = logic.cols * ts;
    final bh = logic.rows * ts;
    final bx = logic.boardX;
    final by = logic.boardY;

    final outerRect = Rect.fromLTWH(bx - 8, by - 8, bw + 16, bh + 16);
    final outerR = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(14),
    );
    canvas.drawRRect(
      outerR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: JewelCandyLuminaTheme.boardFrameGradient,
        ).createShader(outerRect),
    );

    final innerR = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      innerR,
      Paint()..color = JewelCandyLuminaTheme.boardInner,
    );

    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final x = bx + c * ts;
        final y = by + r * ts;
        const pad = 3.0;
        final sr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + pad, y + pad, ts - pad * 2, ts - pad * 2),
          Radius.circular(ts * _slotRadiusRatio),
        );
        canvas.drawRRect(sr, Paint()..color = JewelCandyLuminaTheme.boardSlotFill);
        canvas.drawRRect(
          sr,
          Paint()
            ..color = JewelCandyLuminaTheme.boardSlotStroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    // 보드 안쪽만 보이게 — 인트로 시 보석이 위에서 내려올 때 윗줄 밖은 마스크 처리.
    canvas.save();
    canvas.clipRRect(innerR);

    for (final fx in logic.flashEffects) {
      final a = (fx.timer / MatchBoardLogic.flashDuration).clamp(0.0, 1.0) *
          MatchBoardLogic.flashAlpha;
      final fr = RRect.fromRectAndRadius(
        Rect.fromLTWH(fx.x + 4, fx.y + 4, fx.size - 8, fx.size - 8),
        Radius.circular(ts * 0.12),
      );
      canvas.drawRRect(
        fr,
        Paint()..color = Colors.white.withValues(alpha: a),
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
        Paint()
          ..color = JewelCandyLuminaTheme.secondaryCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    canvas.restore();
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
    final pulse = Paint()
      ..color = Color.lerp(
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
        pulse,
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

    final col = _spriteColumnFor(gem);
    final sprite = _sheetSprites[col];
    if (sprite != null) {
      final hyper = gem.kind == GemKind.hyper;
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (hyper) {
        paint.colorFilter = const ColorFilter.matrix(<double>[
          1.12, 0, 0, 0, 35,
          0, 1.08, 0, 0, 35,
          0, 0, 1.28, 0, 45,
          0, 0, 0, 1, 0,
        ]);
      }
      sprite.render(
        canvas,
        position: Vector2(ox, oy),
        size: Vector2(drawW, drawH),
        overridePaint: paint,
      );
    } else {
      _drawGemProcedural(canvas, gem, ts);
    }

    final cx = x + ts / 2;
    final cy = y + ts / 2;
    _drawSpecialMark(canvas, gem.kind, cx, cy, ts);
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
      Paint()..color = Colors.black.withValues(alpha: 0.28),
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
      Paint()
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
      Paint()
        ..color = Colors.white.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
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
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );
  }

  void _drawSpecialMark(
      Canvas canvas, GemKind kind, double cx, double cy, double ts) {
    switch (kind) {
      case GemKind.normal:
        break;
      case GemKind.row:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - ts * 0.18, cy), Offset(cx + ts * 0.18, cy), p);
        canvas.drawLine(Offset(cx - ts * 0.18, cy - 4), Offset(cx + ts * 0.18, cy - 4), p);
        canvas.drawLine(Offset(cx - ts * 0.18, cy + 4), Offset(cx + ts * 0.18, cy + 4), p);
      case GemKind.col:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx, cy - ts * 0.18), Offset(cx, cy + ts * 0.18), p);
        canvas.drawLine(Offset(cx - 4, cy - ts * 0.18), Offset(cx - 4, cy + ts * 0.18), p);
        canvas.drawLine(Offset(cx + 4, cy - ts * 0.18), Offset(cx + 4, cy + ts * 0.18), p);
      case GemKind.bomb:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(cx, cy), ts * 0.12, p);
        for (final off in [
          Offset(0, -ts * 0.16),
          Offset(ts * 0.12, -ts * 0.08),
          Offset(ts * 0.12, ts * 0.1),
          Offset(-ts * 0.12, ts * 0.1),
          Offset(-ts * 0.12, -ts * 0.08),
        ]) {
          canvas.drawLine(Offset(cx, cy), Offset(cx + off.dx, cy + off.dy), p);
        }
      case GemKind.hyper:
        final p = Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - ts * 0.16, cy), Offset(cx + ts * 0.16, cy), p);
        canvas.drawLine(Offset(cx, cy - ts * 0.16), Offset(cx, cy + ts * 0.16), p);
        canvas.drawLine(Offset(cx - ts * 0.11, cy - ts * 0.11),
            Offset(cx + ts * 0.11, cy + ts * 0.11), p);
        canvas.drawLine(Offset(cx - ts * 0.11, cy + ts * 0.11),
            Offset(cx + ts * 0.11, cy - ts * 0.11), p);
    }
  }
}
