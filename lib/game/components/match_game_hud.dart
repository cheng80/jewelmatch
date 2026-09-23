import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../services/game_settings.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../item_kind.dart';
import '../match_board_game.dart';
import '../match_board_logic.dart';
import 'baked_hud_glow_atlas.dart';

part 'match_game_hud_buttons.dart';
part 'match_game_hud_input.dart';
part 'match_game_hud_interactions.dart';
part 'match_game_hud_painters.dart';
part 'match_game_hud_sections.dart';

const bool _qaSpecialEffectsChainEnabled = bool.fromEnvironment(
  'QA_SPECIAL_EFFECTS_CHAIN',
);

/// 값이 바뀌는 순간 1로 튀었다가 [decayPerSecond] 속도로 0까지 돌아오는 연출 값.
///
/// 매 프레임 객체를 만들지 않고 기존 값을 감쇠한다.
class HudPunch {
  HudPunch(this.decayPerSecond);

  final double decayPerSecond;
  double value = 0;

  void trigger() => value = 1;

  void tick(double dt) {
    if (value > 0) {
      value = math.max(0, value - dt * decayPerSecond);
    }
  }

  /// 시작이 세고 끝이 부드러운 감쇠 곡선.
  double get eased => value * value;

  bool get isActive => value > 0;
}

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

  /// 타임바 채움 영역과 그 위에 고정으로 쓰는 그라데이션. 레이아웃 때만 만든다.
  Rect _timeBarInner = Rect.zero;
  ui.Shader? _timeFillShader;
  ui.Shader? _timeFillCriticalShader;
  late Rect _comboRect;
  Rect _itemTrayRect = Rect.zero;
  Rect _prismColorPickerRect = Rect.zero;
  Rect _itemConfirmRect = Rect.zero;
  Rect _itemConfirmCancelRect = Rect.zero;
  Rect _itemConfirmUseRect = Rect.zero;
  final Map<ItemKind, Rect> _itemRects = {};
  final Map<int, Rect> _loadoutSlotRects = {};
  final Map<GemKind, Rect> _debugEffectPreviewRects = {};
  final Map<int, Rect> _prismColorRects = {};

  double _scoreBlockTop = 0;
  int? _cachedBest;
  int? _cachedBestProgressionLevel;
  String? _cachedRankingTop1Name;
  int? _cachedRankingTop1Score;
  double? _cachedHudTextScale;

  /// 화면에 표시 중인 점수. 실제 점수까지 짧게 굴러 올라간다.
  int? _cachedScore;
  int _scoreRollTarget = 0;
  double _scoreRollTimer = 0;

  /// 점수와 콤보 값이 오를 때 1에서 0으로 감쇠하는 확대 펀치.
  final HudPunch _scorePunch = HudPunch(3.6);
  final HudPunch _comboPunch = HudPunch(3.2);

  /// 레벨 모드 목표 점수 달성 순간의 한 번 강조.
  final HudPunch _goalPunch = HudPunch(1.7);

  /// 힌트 배지 숫자가 바뀐 순간의 튐.
  final HudPunch _hintBadgePunch = HudPunch(3.0);

  /// 버튼과 아이템 슬롯 누름. 한 번에 하나만 눌린다.
  final HudPunch _pressPunch = HudPunch(6.5);
  Rect? _pressedRect;
  Ticker? _pressTicker;

  /// 보드 칸을 누른 포인터. 하이퍼 대기는 이 포인터를 뗄 때만 확정한다.
  int? _boardTapPointerId;

  // 타겟 선택 때와 실제 인벤토리 소모 때의 반응을 분리한다.
  final HudPunch _itemUsePunch = HudPunch(3.5);
  ItemKind? _usedItem;
  final List<int> _itemQuantities = List<int>.filled(
    ItemKind.values.length,
    -1,
  );
  Object? _feedbackBoard;
  int? _feedbackLevel;
  int? _lastHintCount;
  double? _lastTimeRatio;

  /// 시간 보너스로 늘어난 구간의 반짝임.
  final HudPunch _timeBonusPunch = HudPunch(1.6);
  double _timeBonusFrom = 0;
  double _timeBonusTo = 0;

  /// 목표 점수 근접(80% 이상) 맥동에 쓰는 누적 시간.
  double _hudClock = 0;
  bool _goalNear = false;
  bool _goalReached = false;

  /// 화면에 그리는 타임바 채움 비율. 실제 비율을 짧게 따라간다.
  double? _timeFillRatio;

  /// 콤보 3 이상에서 콤보 줄이 달아오르는 정도(0~1).
  double _comboHeat = 0;
  Color _comboHeatColor = const Color(0xFFFFC14D);
  int? _cachedTimedSeconds;
  int? _cachedProgressionXp;
  int? _cachedDisplayedCombo;
  int? _cachedMaxCombo;
  int? _cachedHintBadgeCount;
  bool? _cachedTimedModeForText;
  TextPainter? _hintBadgePainter;
  Offset _hintBadgeCenter = Offset.zero;
  double _hintBadgeDiameter = 0;
  final Paint _hudImagePaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final Paint _hintBadgePaint = Paint()..isAntiAlias = true;

  /// 남은 힌트가 0일 때의 가라앉은 배지 색.
  final Paint _hintBadgeZeroPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF6E6357);
  final Paint _hintBadgeStrokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF2A1606);
  final Paint _comboGradientPaint = Paint();
  final BakedHudGlowAtlas _hudGlows = BakedHudGlowAtlas();
  final Paint _comboStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.78);
  final Paint _comboInnerStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.28);
  final Paint _timeBarBgPaint = Paint();

  final Paint _timeBarStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.82);
  final Paint _timeBarInnerStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..color = JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.28);
  final Paint _timeFillPaint = Paint();

  /// 저시간 틱 박자로 타임바 테두리가 붉게 맥동한다.
  final Paint _timeBarPulsePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;

  /// 시간 보너스로 늘어난 구간의 밝은 띠.
  final Paint _timeBonusFlashPaint = Paint()..isAntiAlias = true;

  /// 콤보 단계에 따라 덧그리는 뜨거운 테두리.
  final Paint _comboHeatPaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  final Paint _untimedFillPaint = Paint()
    ..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.14);
  final Paint _itemTrayPaint = Paint()..isAntiAlias = true;
  final Paint _itemTrayStrokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  final Paint _itemTrayGroovePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..color = const Color(0xB87F5A2A);
  final Paint _itemUsePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke;
  final Paint _lockShacklePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xC77F5A2A);
  final Map<Rect, Paint> _lockBodyPaints = {};
  final Paint _lockedItemPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0x8F0B0908);
  final Map<ItemKind, TextPainter> _itemLabelPainters = {};
  final Map<ItemKind, int> _itemLabelStates = {};
  final Paint _itemIconPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high;
  final Paint _itemIconDimPaint = Paint()
    ..isAntiAlias = true
    ..filterQuality = FilterQuality.high
    ..colorFilter = ColorFilter.mode(
      Colors.white.withValues(alpha: 0.30),
      BlendMode.modulate,
    );
  final Paint _qtyBadgeStrokePaint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = const Color(0xFF2A1606);
  final Paint _qtyBadgeZeroPaint = Paint()
    ..isAntiAlias = true
    ..color = const Color(0xFF6E6357);

  /// 수량 배지는 슬롯마다 매 프레임 그려진다. 레이아웃이 바뀔 때만 다시 만든다.
  final Map<ItemKind, Paint> _qtyBadgeFillPaints = {};
  final Map<int, TextPainter> _qtyBadgePainters = {};
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
    _hudGlows.mount();
  }

  @override
  void onMount() {
    super.onMount();
    _hudGlows.mount();
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
    _cachedHintBadgeCount = null;
    _hintBadgePainter = null;
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

    _comboGradientPaint.shader = _comboRect.isEmpty
        ? null
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: JewelCandyLuminaTheme.comboStripGradient,
          ).createShader(_comboRect);
    _layoutTimeBarFill();
    _timeBarBgPaint.shader = _timeBarRect.isEmpty
        ? null
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A2419),
              JewelCandyLuminaTheme.surfaceStoneDark,
              Color(0xFF241D12),
            ],
          ).createShader(_timeBarRect);

    _hintBadgeDiameter = _hintRect.width * 0.36;
    _hintBadgeCenter = Offset(
      _hintRect.right - _hintBadgeDiameter * 0.18 - 5,
      _hintRect.bottom - _hintBadgeDiameter * 0.18 - 5,
    );
    _hintBadgePaint.shader = _hintBadgeDiameter <= 0
        ? null
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0A8), Color(0xFFC58A22)],
          ).createShader(
            Rect.fromCircle(
              center: _hintBadgeCenter,
              radius: _hintBadgeDiameter / 2,
            ),
          );
    _hintBadgeStrokePaint.strokeWidth = math.max(1.2, _hintRect.width * 0.04);

    _layoutItemSlots();
    _itemTrayPaint.shader = _itemTrayRect.isEmpty
        ? null
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF392D20), Color(0xFF17120E), Color(0xFF08090B)],
            stops: [0.0, 0.44, 1.0],
          ).createShader(_itemTrayRect);
    _layoutPrismColorPicker();
    _layoutItemConfirmPopup();
    _layoutGlowMasks();

    _rebuildStaticPainters();
  }

  void _layoutGlowMasks() {
    final item = _itemRects.values.firstOrNull ?? Rect.zero;
    final prism = _prismColorRects.values.firstOrNull ?? Rect.zero;
    final preview = _debugEffectPreviewRects.values.firstOrNull ?? Rect.zero;
    final previewInset = math.max(4.0, preview.width * 0.11);
    final previewInner = preview.deflate(previewInset);
    RRect shape(double width, double height, double radius) =>
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, math.max(0, width), math.max(0, height)),
          Radius.circular(math.max(0, radius)),
        );
    _hudGlows.configure([
      HudGlowMask(
        shape(
          _comboRect.width,
          _comboRect.height,
          math.min(14, _comboRect.height / 2),
        ),
        8,
      ),
      HudGlowMask(
        shape(_timeBarRect.width, _timeBarRect.height, _timeBarRect.height / 2),
        8,
      ),
      HudGlowMask(shape(item.width - 3.6, item.height - 3.6, 9), 5, 2.2),
      HudGlowMask(
        shape(
          prism.width - 2.4,
          prism.height - 2.4,
          math.min(7, prism.height * 0.18) - 1.2,
        ),
        5,
        2,
      ),
      HudGlowMask(
        shape(
          previewInner.width,
          previewInner.height,
          math.min(8, previewInner.width * 0.20),
        ),
        4,
        1.4,
      ),
    ]);
  }

  @visibleForTesting
  bool get debugGlowReady => _hudGlows.isReady;

  @visibleForTesting
  int get debugGlowGeneration => _hudGlows.generation;

  /// 타임바 채움 사각형과 그라데이션을 미리 만든다(매 프레임 `createShader` 금지).
  void _layoutTimeBarFill() {
    // 고정 inset(3)은 타임바가 낮을 때 inner 높이가 음수가 되어 셰이더/RRect 가 실패할 수 있음
    final inset = math.min(5.0, _timeBarRect.height / 3);
    _timeBarInner = Rect.fromLTWH(
      _timeBarRect.left + inset,
      _timeBarRect.top + inset,
      _timeBarRect.width - inset * 2,
      _timeBarRect.height - inset * 2,
    );
    if (_timeBarInner.width <= 0 || _timeBarInner.height <= 0) {
      _timeFillShader = null;
      _timeFillCriticalShader = null;
      return;
    }
    _timeFillShader = const LinearGradient(
      colors: JewelCandyLuminaTheme.timeBarFillVibrant,
    ).createShader(_timeBarInner);
    _timeFillCriticalShader = const LinearGradient(
      colors: JewelCandyLuminaTheme.timeBarFillCritical,
    ).createShader(_timeBarInner);
  }

  void _layoutItemSlots() {
    _lockBodyPaints.clear();
    _itemLabelPainters.clear();
    _itemLabelStates.clear();
    _qtyBadgeFillPaints.clear();
    _qtyBadgePainters.clear();
    _itemRects.clear();
    _loadoutSlotRects.clear();
    _debugEffectPreviewRects.clear();
    _itemTrayRect = Rect.zero;
    final g = game;
    final left = g.safeContentLeft;
    final right = g.safeContentRight;
    final boardRect = g.boardFrameRect;
    final alignLeft = boardRect.width > 0 ? boardRect.left : left;
    final width = boardRect.width > 0 ? boardRect.width : right - left;
    if (width <= 0) return;

    final qaEffects = g.hudBottomPanel == MatchGameHudBottomPanel.qaEffects;
    final slots = g.hudLoadoutSlots;
    final qaKinds = g.hudQaSpecialEffectKinds;
    final slotCount = qaEffects ? qaKinds.length : slots.length;
    if (slotCount == 0) return;

    final phase2 = g.hudBottomPanel == MatchGameHudBottomPanel.inventory;
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
    final rowCount = phase2 ? 1 : (slotCount + 3) ~/ 4;
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

    for (var i = 0; i < slotCount; i++) {
      final row = phase2 ? 0 : i ~/ 4;
      final col = i % 4;
      final rect = Rect.fromLTWH(
        gridLeft + col * (slotSide + gap),
        slotTop + row * (slotSide + rowGap),
        slotSide,
        slotSide,
      );
      if (qaEffects) {
        _debugEffectPreviewRects[qaKinds[i]] = rect;
      } else {
        _loadoutSlotRects[slots[i].index] = rect;
        final item = slots[i].item;
        if (item != null) {
          _itemRects[item] = rect;
        }
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

  bool get _isQaEffectPanel =>
      game.hudBottomPanel == MatchGameHudBottomPanel.qaEffects;

  Map<int, Rect> debugReadPrismColorRects() =>
      Map<int, Rect>.unmodifiable(_prismColorRects);

  Map<String, Rect> debugReadAlignedHudRects() => {
    'combo': _comboRect,
    'timeBar': _timeBarRect,
    'itemTray': _itemTrayRect,
  };

  /// 테스트에서 실제 HUD 입력 경로와 렌더 상태를 읽는다. 게임 규칙은 변경하지 않는다.
  @visibleForTesting
  bool debugTapButton(Offset point) =>
      _handleUiButtonTap(Vector2(point.dx, point.dy));

  @visibleForTesting
  Map<String, Rect> debugReadButtonRects() => {
    'pause': _pauseRect,
    'hint': _hintRect,
    'ranking': _rankingRect,
    'tutorial': _tutorialRect,
  };

  @visibleForTesting
  Map<String, Object?> debugReadFeedback() => {
    'score': _cachedScore,
    'scorePunch': _scorePunch.value,
    'goalNear': _goalNear,
    'goalReached': _goalReached,
    'goalPunch': _goalPunch.value,
    'hintPunch': _hintBadgePunch.value,
    'pressPunch': _pressPunch.value,
    'pressedRect': _pressedRect,
    'timeFill': _timeFillRatio,
    'timeBonus': _timeBonusPunch.value,
    'timeBonusFrom': _timeBonusFrom,
    'timeBonusTo': _timeBonusTo,
    'comboHeat': _comboHeat,
    'timeShader': _timeFillShader,
    'itemUsePunch': _itemUsePunch.value,
    'usedItem': _usedItem,
  };

  @override
  void update(double dt) {
    super.update(dt);
    _updateHudState(dt);
  }

  @override
  void onRemove() {
    _pressTicker?.dispose();
    _pressTicker = null;
    _hudGlows.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) => _renderHud(canvas);

  @override
  void onTapDown(TapDownEvent event) => _handleTapDown(event);

  @override
  void onTapUp(TapUpEvent event) {
    if (event.pointerId != _boardTapPointerId) return;
    _boardTapPointerId = null;
    game.handleBoardTapUp();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (event.pointerId != _boardTapPointerId) return;
    _boardTapPointerId = null;
    game.board.cancelPendingHyperTap();
  }

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
    game.board.cancelPendingHyperTap();
  }
}
