import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';

part 'match_board_chrome_renderer.dart';
part 'match_board_gem_overlay_renderer.dart';
part 'match_board_procedural_renderer.dart';

/// 매치 보드 격자·보석·플래시·선택 표시.
/// `Jewel_Arcane.png`(896×128, 7프레임×128), row/col legacy 특수 시트,
/// bomb/star/supernova 독립 오버레이 스프라이트 사용.
///
/// 힌트: [MatchBoardLogic.showHint]가 고른 **한 쌍**만, 보석 위에 흰색 펄스(느리게 깜박임).
/// 다른 칸에는 오버레이를 그리지 않는다.
class MatchBoardRenderer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  MatchBoardRenderer({required this.logic});

  final MatchBoardLogic logic;

  static const double _cellCornerRatio = 0.04;

  /// 기본 보석 스프라이트 시트 열 0~6 (각 128×128).
  final List<Sprite?> _sheetSprites = List<Sprite?>.filled(7, null);
  final Map<GemKind, Sprite?> _specialSprites = <GemKind, Sprite?>{};
  final Map<GemKind, Sprite?> _overlaySprites = <GemKind, Sprite?>{};

  static const double _frameW = 128;
  static const double _frameH = 128;
  static const List<GemKind> _specialSheetKinds = <GemKind>[
    GemKind.col,
    GemKind.row,
  ];
  static const Map<GemKind, String> _overlayAssetPaths = <GemKind, String>{
    GemKind.bomb: AssetPaths.flameOverlay,
    GemKind.star: AssetPaths.starOverlay,
    GemKind.supernova: AssetPaths.supernovaOverlay,
  };

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
  final Paint _normalSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.matrix(<double>[
      0.90556,
      0.06296,
      0.01848,
      0,
      0,
      0.02556,
      0.93704,
      0.01848,
      0,
      0,
      0.02556,
      0.06296,
      0.89848,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
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
    for (final entry in _overlayAssetPaths.entries) {
      try {
        final img = await Flame.images.load(entry.value);
        _overlaySprites[entry.key] = Sprite(
          img,
          srcPosition: Vector2.zero(),
          srcSize: Vector2(_frameW, _frameH),
        );
      } catch (_) {
        _overlaySprites[entry.key] = null;
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

    final needsBoardClip =
        logic.introFillInProgress ||
        logic.state == 'falling' ||
        logic.state == 'refilling';
    if (needsBoardClip) {
      // 보드 밖에서 내려오는 낙하/리필 연출일 때만 클립한다.
      canvas.save();
      canvas.clipRRect(innerR);
    }

    for (final fx in logic.flashEffects) {
      final a =
          (fx.timer / MatchBoardLogic.flashDuration).clamp(0.0, 1.0) *
          MatchBoardLogic.flashAlpha;
      final fr = RRect.fromRectAndRadius(
        Rect.fromLTWH(fx.x + 4, fx.y + 4, fx.size - 8, fx.size - 8),
        Radius.circular(ts * MatchBoardRenderer._cellCornerRatio),
      );
      _flashPaint.color = Colors.white.withValues(alpha: a);
      canvas.drawRRect(fr, _flashPaint);
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
          Radius.circular(ts * MatchBoardRenderer._cellCornerRatio),
        ),
        _selectionPaint,
      );
    }

    if (needsBoardClip) {
      canvas.restore();
    }
  }
}
