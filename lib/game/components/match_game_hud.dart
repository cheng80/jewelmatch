import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../resources/asset_paths.dart';
import '../../services/game_settings.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../item_kind.dart';
import '../match_board_game.dart';

part 'match_game_hud_buttons.dart';
part 'match_game_hud_input.dart';
part 'match_game_hud_interactions.dart';
part 'match_game_hud_painters.dart';
part 'match_game_hud_sections.dart';

/// 상단: 일시정지·힌트 + 최고 기록 → 큰 점수 → 콤보(현재·최대) / 보드 아래: 타임바.
///
/// 상단 한 줄(일시정지·힌트·베스트·우측 튜토리얼) 배치는 형제 프로젝트
/// `flame_tab_order/lib/game/components/game_hud.dart`(1~50)와 같은 패턴을 참고한다.
class MatchGameHud extends PositionComponent
    with HasGameReference<MatchBoardGame>, TapCallbacks, DragCallbacks {
  MatchGameHud({
    required this.onPausePressed,
    required this.onHintPressed,
    required this.onTutorialPressed,
    this.onRankingPressed,
  });

  final VoidCallback onPausePressed;
  final VoidCallback onHintPressed;
  final VoidCallback onTutorialPressed;

  /// 타임 모드 전용: 힌트 오른쪽 랭킹 버튼. `null`이면 그리지 않는다.
  final VoidCallback? onRankingPressed;

  /// 방향 판정 최소 이동 거리(px). 이보다 짧으면 탭으로 폴백.
  static const double _swipeThreshold = 14.0;
  final _drag = _HudDragTracker();

  late TextPainter _scoreLabel;
  late TextPainter _scoreValue;
  late TextPainter _bestLabel;
  late TextPainter _bestValue;
  TextPainter? _timeInBar;

  late TextPainter _comboLeftLabel;
  late TextPainter _comboLeftValue;
  late TextPainter _comboRightLabel;
  late TextPainter _comboRightValue;

  late Rect _pauseRect;
  late Rect _hintRect;
  late Rect _rankingRect;
  late Rect _tutorialRect;
  late Rect _timeBarRect;
  late Rect _comboRect;
  Rect _itemTrayRect = Rect.zero;
  Rect _prismColorPickerRect = Rect.zero;
  Rect _itemConfirmRect = Rect.zero;
  Rect _itemConfirmCancelRect = Rect.zero;
  Rect _itemConfirmUseRect = Rect.zero;
  final Map<ItemKind, Rect> _itemRects = {};
  final Map<int, Rect> _loadoutSlotRects = {};
  final Map<int, Rect> _prismColorRects = {};

  double _scoreBlockTop = 0;
  int? _cachedBest;
  int? _cachedBestProgressionLevel;
  String? _cachedRankingTop1Name;
  int? _cachedRankingTop1Score;
  double? _cachedHudTextScale;
  int? _cachedScore;
  int? _cachedTimedSeconds;
  int? _cachedProgressionXp;
  int? _cachedDisplayedCombo;
  int? _cachedMaxCombo;
  bool? _cachedTimedModeForText;
  final Paint _comboGradientPaint = Paint();
  final Paint _comboStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _comboInnerStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _timeBarBgPaint = Paint();
  final Paint _timeBarStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _timeBarInnerStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _timeFillPaint = Paint();
  final Paint _untimedFillPaint = Paint();
  final Paint _itemTrayPaint = Paint()..isAntiAlias = true;
  final Paint _itemTrayStrokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  ui.Image? _iconButtonFrameImage;
  ui.Image? _hintBulbIconImage;
  ui.Image? _tutorialIconImage;
  ui.Image? _pauseIconImage;
  ui.Image? _rankingCrownIconImage;
  ui.Image? _jewelSpriteSheetImage;
  ui.Image? _obsidianPanelFrameImage;
  final Map<ItemKind, ui.Image> _itemIconImages = {};

  final _fmt = NumberFormat.decimalPattern();
  static const Map<ItemKind, String> _phaseOneItemIconPaths = {
    ItemKind.runeHammer: AssetPaths.itemIconRuneHammer,
    ItemKind.ancientBomb: AssetPaths.itemIconAncientBomb,
    ItemKind.thorHammer: AssetPaths.itemIconThorHammer,
    ItemKind.hyperCube: AssetPaths.itemIconHyperCube,
    ItemKind.prismTransform: AssetPaths.itemIconPrismTransform,
    ItemKind.fateShuffle: AssetPaths.itemIconFateShuffle,
    ItemKind.timeSlip: AssetPaths.itemIconTimeSlip,
    ItemKind.hintPlus: AssetPaths.itemIconHintPlus,
  };

  static const List<String> _fallbackFonts = [
    'PingFang SC',
    'Apple SD Gothic Neo',
    'sans-serif',
  ];

  static const List<int> _gemSheetColByColor1based = [0, 6, 3, 2, 4, 5];
  static const double _gemFrameSize = 128;

  TextStyle _ts({
    required double size,
    Color? color,
    FontWeight? weight,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: AssetPaths.fontNexonLv2Gothic,
    fontFamilyFallback: _fallbackFonts,
    fontSize: size,
    color: color,
    fontWeight: weight,
    shadows: shadows,
  );

  /// 그라데이션·밝은 배경 위 텍스트 가독성 (타임바·콤보 스트립 공통)
  List<Shadow> _hudLegibilityShadows() => [
    Shadow(
      color: Colors.black.withValues(alpha: 0.82),
      offset: const Offset(0, 1.5),
      blurRadius: 3,
    ),
    Shadow(
      color: Colors.black.withValues(alpha: 0.55),
      offset: Offset.zero,
      blurRadius: 7,
    ),
  ];

  @override
  Future<void> onLoad() async {
    priority = 20;
    _iconButtonFrameImage = await Flame.images.load(
      AssetPaths.obsidianIconButtonFrame,
    );
    _hintBulbIconImage = await Flame.images.load(
      AssetPaths.obsidianHintBulbIcon,
    );
    _tutorialIconImage = await Flame.images.load(
      AssetPaths.obsidianTutorialIcon,
    );
    _pauseIconImage = await Flame.images.load(AssetPaths.obsidianPauseIcon);
    _rankingCrownIconImage = await Flame.images.load(
      AssetPaths.obsidianRankingCrownIcon,
    );
    _jewelSpriteSheetImage = await Flame.images.load(
      AssetPaths.jewelSpriteSheet,
    );
    _obsidianPanelFrameImage = await Flame.images.load(
      AssetPaths.obsidianPanelFrameFlame,
    );
    for (final entry in _phaseOneItemIconPaths.entries) {
      _itemIconImages[entry.key] = await Flame.images.load(entry.value);
    }
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    this.size = size.clone();
    position = Vector2.zero();
    super.onGameResize(size);
    _layout();
  }

  void _layout() {
    final g = game;
    final scale = g.hudScale;
    _cachedBest = GameSettings.getBestMatchScore(g.gameMode);
    _cachedBestProgressionLevel = GameSettings.getBestMatchProgressionLevel();
    _cachedHudTextScale = g.hudTextScale;
    _cachedScore = null;
    _cachedTimedSeconds = null;
    _cachedProgressionXp = null;
    _cachedDisplayedCombo = null;
    _cachedMaxCombo = null;
    _cachedTimedModeForText = null;

    final top = g.safeAreaPadding.top + 10;
    final left = g.safeContentLeft;
    final right = g.safeContentRight;
    final barPad = scale * 0.12;

    final row1H = g.hudTopBarHeight;
    final btn = scale * 0.52;
    _pauseRect = Rect.fromLTWH(
      left + barPad,
      top + (row1H - btn) / 2,
      btn,
      btn,
    );

    final gapBtn = scale * 0.1;
    _hintRect = Rect.fromLTWH(
      _pauseRect.right + gapBtn,
      top + (row1H - btn) / 2,
      btn,
      btn,
    );

    if (onRankingPressed != null) {
      _rankingRect = Rect.fromLTWH(
        _hintRect.right + gapBtn,
        top + (row1H - btn) / 2,
        btn,
        btn,
      );
    } else {
      _rankingRect = Rect.zero;
    }

    _tutorialRect = Rect.fromLTWH(
      right - barPad - btn,
      top + (row1H - btn) / 2,
      btn,
      btn,
    );

    _scoreBlockTop = top + row1H;

    final boardRect = g.boardFrameRect;
    final stripLeft = boardRect.width > 0 ? boardRect.left : left + barPad;
    final stripWidth = boardRect.width > 0
        ? boardRect.width
        : (right - left) - barPad * 2;

    _comboRect = Rect.fromLTWH(
      stripLeft,
      _scoreBlockTop + g.hudMainScoreBlockHeight + g.hudGapScoreToCombo,
      stripWidth,
      g.hudComboStripHeight,
    );

    _timeBarRect = Rect.fromLTWH(
      stripLeft,
      _comboRect.bottom + g.hudGapComboToTimeBar,
      stripWidth,
      g.hudBottomTimeBarHeight,
    );

    _layoutItemSlots();
    _layoutPrismColorPicker();
    _layoutItemConfirmPopup();

    _rebuildStaticPainters();
  }

  void _layoutItemSlots() {
    _itemRects.clear();
    _loadoutSlotRects.clear();
    _itemTrayRect = Rect.zero;
    final g = game;
    final left = g.safeContentLeft;
    final right = g.safeContentRight;
    final boardRect = g.boardFrameRect;
    final alignLeft = boardRect.width > 0 ? boardRect.left : left;
    final width = boardRect.width > 0 ? boardRect.width : right - left;
    if (width <= 0) return;

    final slots = g.hudLoadoutSlots;
    if (slots.isEmpty) return;

    final phase2 = g.usesPhase2Inventory;
    final gap = phase2
        ? math.max(13.0, g.hudScale * 0.15)
        : math.max(9.0, g.hudScale * 0.105);
    final rowGap = math.max(7.0, g.hudScale * 0.085);
    final slotSide = phase2
        ? math.min((width - gap * 3) / 4, g.hudScale * 0.74).clamp(52.0, 66.0)
        : math.min((width - gap * 3) / 4, g.hudScale * 0.54).clamp(36.0, 48.0);
    final totalW = slotSide * 4 + gap * 3;
    final gridLeft = alignLeft + (width - totalW) / 2;
    final phaseOneSlotSide = math
        .min(
          (width - math.max(9.0, g.hudScale * 0.105) * 3) / 4,
          g.hudScale * 0.54,
        )
        .clamp(36.0, 48.0);
    final phaseOneTrayH = phaseOneSlotSide * 2 + rowGap;
    final rowCount = phase2 ? 1 : 2;
    final totalH = phase2
        ? math.max(phaseOneTrayH, slotSide)
        : slotSide * rowCount + rowGap;
    final trayPadY = math.max(4.0, g.hudScale * 0.055);
    final frameOverhang = slotSide * 0.08;
    final bottom =
        size.y -
        g.safeAreaPadding.bottom -
        math.max(5.0, gap) -
        math.max(trayPadY, frameOverhang);
    final top = bottom - totalH;
    final slotTop = phase2 ? top + (totalH - slotSide) / 2 : top;
    _itemTrayRect = Rect.fromLTWH(
      alignLeft,
      top - trayPadY,
      width,
      totalH + trayPadY * 2,
    );

    for (var i = 0; i < slots.length; i++) {
      final row = phase2 ? 0 : i ~/ 4;
      final col = i % 4;
      final rect = Rect.fromLTWH(
        gridLeft + col * (slotSide + gap),
        slotTop + row * (slotSide + rowGap),
        slotSide,
        slotSide,
      );
      _loadoutSlotRects[slots[i].index] = rect;
      final item = slots[i].item;
      if (item != null) {
        _itemRects[item] = rect;
      }
    }
  }

  void _layoutPrismColorPicker() {
    _prismColorRects.clear();
    _prismColorPickerRect = Rect.zero;
    final g = game;
    if (_itemTrayRect.isEmpty || g.safeContentWidth <= 0) return;

    final boardRect = g.boardFrameRect;
    if (boardRect.isEmpty) return;

    final colorCount = g.board.colorCount;
    final gap = math.max(8.0, g.hudScale * 0.10);
    final maxSwatch =
        (boardRect.width * 0.76 - gap * (colorCount - 1)) / colorCount;
    final swatch = math
        .min(math.max(g.board.tileSize * 0.92, g.hudScale * 0.42), maxSwatch)
        .clamp(34.0, 52.0);
    final width = swatch * colorCount + gap * (colorCount - 1);
    _prismColorPickerRect = boardRect;

    var left = _prismColorPickerRect.center.dx - width / 2;
    final swatchTop = _prismColorPickerRect.center.dy - swatch * 0.18;
    for (var color = 1; color <= colorCount; color++) {
      _prismColorRects[color] = Rect.fromLTWH(left, swatchTop, swatch, swatch);
      left += swatch + gap;
    }
  }

  void _layoutItemConfirmPopup() {
    _itemConfirmRect = Rect.zero;
    _itemConfirmCancelRect = Rect.zero;
    _itemConfirmUseRect = Rect.zero;
    final g = game;
    if (_itemTrayRect.isEmpty || g.safeContentWidth <= 0) return;

    final boardRect = g.boardFrameRect;
    final center = boardRect.isEmpty
        ? Offset(g.safeContentLeft + g.safeContentWidth / 2, g.size.y / 2)
        : boardRect.center;
    _itemConfirmRect = boardRect.isEmpty
        ? Rect.fromCenter(
            center: center,
            width: g.safeContentWidth,
            height: math.max(220.0, g.hudScale * 2.4),
          )
        : boardRect;

    final buttonGap = math.max(10.0, g.hudScale * 0.12);
    final buttonHeight = math.max(34.0, g.hudScale * 0.38);
    final buttonSidePadding = math.max(
      g.hudScale * 0.44,
      _itemConfirmRect.width * 0.18,
    );
    final buttonWidth = math.min(
      (_itemConfirmRect.width - buttonSidePadding * 2 - buttonGap) / 2,
      g.hudScale * 1.42,
    );
    final groupWidth = buttonWidth * 2 + buttonGap;
    final buttonTop = _itemConfirmRect.center.dy + g.hudScale * 0.17;
    final buttonLeft = _itemConfirmRect.center.dx - groupWidth / 2;
    _itemConfirmCancelRect = Rect.fromLTWH(
      buttonLeft,
      buttonTop,
      buttonWidth,
      buttonHeight,
    );
    _itemConfirmUseRect = Rect.fromLTWH(
      _itemConfirmCancelRect.right + buttonGap,
      buttonTop,
      buttonWidth,
      buttonHeight,
    );
  }

  Map<ItemKind, Rect> debugReadItemSlotRects() =>
      Map<ItemKind, Rect>.unmodifiable(_itemRects);

  Map<int, Rect> debugReadPrismColorRects() =>
      Map<int, Rect>.unmodifiable(_prismColorRects);

  Map<String, Rect> debugReadAlignedHudRects() => {
    'combo': _comboRect,
    'timeBar': _timeBarRect,
    'itemTray': _itemTrayRect,
  };

  @override
  void update(double dt) {
    super.update(dt);
    _updateHudState();
  }

  @override
  void render(Canvas canvas) => _renderHud(canvas);

  @override
  void onTapDown(TapDownEvent event) => _handleTapDown(event);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _handleDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _handleDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _handleDragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _resetDrag();
  }
}
