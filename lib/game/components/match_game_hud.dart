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
  ui.Image? _iconButtonFrameImage;
  ui.Image? _hintBulbIconImage;
  ui.Image? _tutorialIconImage;
  ui.Image? _pauseIconImage;
  ui.Image? _rankingCrownIconImage;

  final _fmt = NumberFormat.decimalPattern();

  static const List<String> _fallbackFonts = [
    'PingFang SC',
    'Apple SD Gothic Neo',
    'sans-serif',
  ];

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

    _comboRect = Rect.fromLTWH(
      left + barPad,
      _scoreBlockTop + g.hudMainScoreBlockHeight + g.hudGapScoreToCombo,
      (right - left) - barPad * 2,
      g.hudComboStripHeight,
    );

    final bb = g.boardPixelBottom;
    _timeBarRect = Rect.fromLTWH(
      left + barPad,
      bb + g.hudGapBelowBoard,
      (right - left) - barPad * 2,
      g.hudBottomTimeBarHeight,
    );

    _rebuildStaticPainters();
  }

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
