import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../resources/asset_paths.dart';
import '../../services/game_settings.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../match_board_game.dart';

part 'match_game_hud_buttons.dart';
part 'match_game_hud_input.dart';
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
  late TextPainter _tutorialGlyph;
  late Rect _timeBarRect;
  late Rect _comboRect;

  double _scoreBlockTop = 0;
  int? _cachedBest;
  double? _cachedHudTextScale;
  int? _cachedScore;
  int? _cachedTimedSeconds;
  int? _cachedDisplayedCombo;
  int? _cachedMaxCombo;
  bool? _cachedTimedModeForText;
  final Paint _comboGradientPaint = Paint();
  final Paint _comboStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _timeBarBgPaint = Paint();
  final Paint _timeBarStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _timeFillPaint = Paint();
  final Paint _untimedFillPaint = Paint();
  final Paint _tutorialFillPaint = Paint();
  final Paint _tutorialStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final Paint _hintFillPaint = Paint();
  final Paint _hintStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _hintBulbPaint = Paint();
  final Paint _hintBasePaint = Paint();
  final Paint _hintGlintPaint = Paint();
  final Paint _rankingFillPaint = Paint();
  final Paint _rankingStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _rankingCupPaint = Paint();
  final Paint _rankingBasePaint = Paint();
  final Paint _pauseFillPaint = Paint();
  final Paint _pauseStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _pauseBarPaint = Paint();

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
    fontFamily: AssetPaths.fontAngduIpsul140,
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
    _cachedHudTextScale = g.hudTextScale;
    _cachedScore = null;
    _cachedTimedSeconds = null;
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
    final currentHudTextScale = game.hudTextScale;
    if (_cachedHudTextScale != currentHudTextScale) {
      _layout();
      return;
    }

    if (_cachedScore != game.board.score) {
      _rebuildScoreValue();
    }

    final latestBest = GameSettings.getBestMatchScore(game.gameMode);
    if (latestBest != _cachedBest) {
      _cachedBest = latestBest;
      _rebuildStaticPainters();
      return;
    }

    final timedModeChanged = _cachedTimedModeForText != game.isTimedMode;
    final currentTimedSeconds = game.isTimedMode
        ? game.timeRemaining.ceil().clamp(0, 99999)
        : null;
    if (timedModeChanged || _cachedTimedSeconds != currentTimedSeconds) {
      _rebuildTimeBarText();
    }

    final displayedCombo = _displayCurrentCombo();
    final maxCombo = game.board.maxCombo;
    if (_cachedDisplayedCombo != displayedCombo ||
        _cachedMaxCombo != maxCombo) {
      _rebuildComboPainters();
    }
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    if (!g.hasLayout || g.size.x <= 0 || g.size.y <= 0) {
      return;
    }

    _renderBestBlock(canvas);
    _drawTutorialButton(canvas);
    _renderScoreBlock(canvas);
    _renderComboStrip(canvas);
    _renderTimeBar(canvas);
    _drawHintButton(canvas);
    if (onRankingPressed != null && _rankingRect.width > 0) {
      _drawRankingButton(canvas);
    }
    _drawPause(canvas);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;
    if (_handleUiButtonTap(p)) return;
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    if (p.y < bt || p.y > bb) {
      game.dismissHint();
      return;
    }
    game.handleBoardTap(event.canvasPosition.x, event.canvasPosition.y);
  }

  // ── 스와이프(드래그) ──

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _resetDrag();
    final p = event.localPosition;
    if (_isUiButton(p)) return;
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    if (p.y < bt || p.y > bb) return;
    _drag.start(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final swipe = _drag.consumeSwipe(event.localDelta, _swipeThreshold);
    if (swipe == null) return;
    game.handleBoardSwipe(swipe.start.x, swipe.start.y, swipe.dr, swipe.dc);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final fallbackTap = _drag.fallbackTap;
    if (fallbackTap != null) {
      game.handleBoardTap(fallbackTap.x, fallbackTap.y);
    }
    _resetDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _resetDrag();
  }

  void _resetDrag() {
    _drag.reset();
  }

  bool _isUiButton(Vector2 p) {
    final o = Offset(p.x, p.y);
    return _pauseRect.contains(o) ||
        _hintRect.contains(o) ||
        (onRankingPressed != null &&
            _rankingRect.width > 0 &&
            _rankingRect.contains(o)) ||
        _tutorialRect.contains(o);
  }

  bool _handleUiButtonTap(Vector2 p) {
    final o = Offset(p.x, p.y);
    if (_pauseRect.contains(o)) {
      game.dismissHint();
      onPausePressed();
      return true;
    }
    if (_hintRect.contains(o)) {
      onHintPressed();
      return true;
    }
    if (onRankingPressed != null &&
        _rankingRect.width > 0 &&
        _rankingRect.contains(o)) {
      game.dismissHint();
      onRankingPressed!();
      return true;
    }
    if (_tutorialRect.contains(o)) {
      game.dismissHint();
      onTutorialPressed();
      return true;
    }
    return false;
  }
}
