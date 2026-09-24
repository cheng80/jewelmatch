import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';
import 'board_atlas.dart';

part 'match_board_chrome_renderer.dart';
part 'match_board_gem_atlas.dart';
part 'match_board_gem_bonus_renderer.dart';
part 'match_board_gem_overlay_renderer.dart';
part 'match_board_procedural_renderer.dart';

/// 매치 보드 격자·보석·플래시·선택 표시.
/// 보석, row/col legacy 특수, bomb/star/hyper/supernova 액션 특수, 배지 칸을
/// 모두 [BoardAtlas] 한 장에서 읽는다.
///
/// 힌트: [MatchBoardLogic.showHint]가 고른 **한 쌍**만, 보석 위에 흰색 펄스(느리게 깜박임).
/// 다른 칸에는 오버레이를 그리지 않는다.
class MatchBoardRenderer extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  MatchBoardRenderer({required this.logic});

  final MatchBoardLogic logic;
  late final _GemAtlasBatch _gemBatch = _GemAtlasBatch(logic.rows * logic.cols);
  final Paint _atlasIndividualPaint = Paint()
    ..filterQuality = FilterQuality.medium;
  final Paint _shufflePaint = Paint()..style = PaintingStyle.stroke;
  double _shuffleVisualTime = 0;
  String _lastVisualAction = '';

  /// 실제 Canvas 제출 횟수. 진단과 회귀 검증용이며 규칙에서 읽지 않는다.
  int get gemAtlasDrawCalls => _gemBatch.drawCalls;
  int get batchedGemCount => _gemBatch.submittedGems;
  int individualGemDrawCalls = 0;
  @visibleForTesting
  bool useGemBatching = true;
  @visibleForTesting
  bool get hasGemAtlas => _gemBatch.image != null;

  /// Time, Multiplier 배지를 그리는 [BoardAtlas] 이미지와 칸. 없으면 배지를 그리지 않는다.
  /// 배지는 drawImageRect로 그린다. drawRawAtlas나 구운 atlas(toImageSync)로 옮기면
  /// 밉맵 없이 샘플링돼 작은 배지 그림이 원본과 달라진다(측정: 최대 채널 차 112).
  ui.Image? _badgeImage;
  final List<Rect> _badgeSources = List<Rect>.filled(2, Rect.zero);
  final Paint _badgePaint = Paint()..filterQuality = FilterQuality.medium;
  final Map<String, TextPainter> _badgeLabels = {};
  double _badgeLabelTileSize = 0;

  static const double _cellCornerRatio = 0.04;
  static const double _removalMinAlpha = 0.08;
  static const double _removalMinScale = 0.3;
  static const double _removalPopScale = 1.2;
  static const double _removalPopPhase = 0.3;
  static const double _removalMaxRotation = math.pi;
  static const List<double> _normalSpriteColorMatrix = <double>[
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
  ];

  /// 기본 보석 스프라이트 시트 열 0~6 (각 128×128).
  final List<Sprite?> _sheetSprites = List<Sprite?>.filled(7, null);
  final Map<GemKind, Sprite?> _specialSprites = <GemKind, Sprite?>{};

  static const List<GemKind> _specialActionSheetKinds = <GemKind>[
    GemKind.bomb,
    GemKind.star,
    GemKind.hyper,
    GemKind.supernova,
  ];

  /// 힌트 펄스 위상 속도(낮을수록 느리게 한 박자).
  static const double _hintPulseHz = 0.32;

  /// `flame_tab_order` [CubeButton]과 같은 cos 펄스, 다만 [_hintPulseHz]로 속도만 조정.
  double _hintPulseTime = 0;

  /// 선택 맥동, 특수 보석 호흡 등 상시 연출의 공용 시계.
  double _animTime = 0;

  /// 힌트 쌍이 서로 쪽으로 끌리는 거리(px). 힌트가 없으면 0.
  double _hintNudge = 0;

  /// 게임 색상 1~6 → 시트 열 인덱스 (시트 순서: 빨강, 은백, 초록, 노랑, 보라, 주황, 파랑).
  /// 색 1~7 → `Jewel_Arcane.png` 열. 7번째 색은 흰 돌(열 1)이다.
  static const List<int> _sheetColByColor1based = [0, 6, 3, 2, 4, 5, 1];

  ui.Picture? _boardChromePicture;
  double? _cachedTileSize;
  double? _cachedBoardX;
  double? _cachedBoardY;
  final Paint _selectionPaint = Paint()
    ..color = JewelCandyLuminaTheme.secondaryCyan
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _hintPulsePaint = Paint();
  final Paint _normalSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.matrix(_normalSpriteColorMatrix);
  final Paint _removingNormalSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium;
  final Paint _removingCompositedSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium;
  final Paint _compositedSpritePaint = Paint()
    ..filterQuality = FilterQuality.medium;
  final Paint _popRingPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _lowTimePulsePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _proceduralShadowPaint = Paint();
  final Paint _proceduralGradientPaint = Paint();
  final Paint _proceduralStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _proceduralHighlightPaint = Paint();
  final Vector2 _spriteRenderPosition = Vector2.zero();
  final Vector2 _spriteRenderSize = Vector2.zero();
  bool _showRemovalVisuals = false;
  double _removalVisualAlpha = 1;
  double _removalVisualScale = 1;
  double _removalVisualRotation = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final atlas = await BoardAtlas.load();
      Sprite? sprite(String name) {
        final rect = atlas.frames[name];
        if (rect == null) return null;
        return Sprite(
          atlas.image,
          srcPosition: Vector2(rect.left, rect.top),
          srcSize: Vector2(rect.width, rect.height),
        );
      }

      for (var i = 0; i < _sheetSprites.length; i++) {
        _sheetSprites[i] = sprite('gem_$i');
      }
      // 행, 열 특수 보석은 게임에서 만들어지지 않아 그림이 없다(QA 훅에서만 생기며 일반 보석 그림으로 대체).
      for (var i = 0; i < _specialActionSheetKinds.length; i++) {
        _specialSprites[_specialActionSheetKinds[i]] = sprite('action_$i');
      }
      final time = atlas.frames['badge_0'];
      final multiplier = atlas.frames['badge_1'];
      if (time != null && multiplier != null) {
        _badgeSources
          ..[0] = time
          ..[1] = multiplier;
        _badgeImage = atlas.image;
      }
    } catch (_) {
      _badgeImage = null;
    }
  }

  @override
  void onMount() {
    super.onMount();
    _buildGemAtlas();
    _rebuildBoardChromePicture();
  }

  @override
  void onRemove() {
    _boardChromePicture?.dispose();
    _boardChromePicture = null;
    _gemBatch.dispose();
    _disposeBadgeLabels();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
    if (_lastVisualAction != logic.lastActionText) {
      _lastVisualAction = logic.lastActionText;
      if (_lastVisualAction == 'fate shuffle') _shuffleVisualTime = 0.45;
    }
    if (_shuffleVisualTime > 0) {
      _shuffleVisualTime = math.max(0, _shuffleVisualTime - dt);
    }
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
    _gemBatch.beginFrame();
    individualGemDrawCalls = 0;
    final shakeOffset = game.boardShakeOffset;
    final hasShakeOffset = shakeOffset.x != 0 || shakeOffset.y != 0;
    if (hasShakeOffset) {
      canvas.save();
      canvas.translate(shakeOffset.x, shakeOffset.y);
    }

    final ts = logic.tileSize;
    final bw = logic.cols * ts;
    final bh = logic.rows * ts;
    final bx = logic.boardX;
    final by = logic.boardY;

    if (_boardChromePicture != null) {
      canvas.drawPicture(_boardChromePicture!);
    }
    _drawLowTimePulse(canvas, bx, by, bw, bh);
    _drawShuffleFeedback(canvas, bx, by, bw, bh);

    _updateRemovalVisualState();
    _updateHintNudge(ts);

    final needsBoardClip =
        logic.introFillInProgress ||
        logic.state == 'falling' ||
        logic.state == 'refilling';
    if (needsBoardClip) {
      // 보드 밖에서 내려오는 낙하/리필 연출일 때만 클립한다.
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, bh),
          const Radius.circular(10),
        ),
      );
    }

    _drawInteractionGlows(canvas, ts);
    final activeDragGem = logic.activeInvalidDragGem;
    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final gem = logic.getGem(r, c);
        if (gem != null) {
          if (identical(gem, activeDragGem)) continue;
          _drawGem(canvas, gem, ts);
        }
      }
    }

    _gemBatch.flush(canvas);
    _drawBonusBadges(canvas, ts, skip: activeDragGem);
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

    if (activeDragGem != null) {
      _drawGem(canvas, activeDragGem, ts);
      _gemBatch.flush(canvas);
      _drawBonusBadge(canvas, activeDragGem, ts);
    }

    if (needsBoardClip) {
      canvas.restore();
    }
    if (hasShakeOffset) {
      canvas.restore();
    }
  }
}
