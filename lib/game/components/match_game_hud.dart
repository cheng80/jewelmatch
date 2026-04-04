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

/// 상단: 일시정지·힌트 + 최고 기록 → 큰 점수 → 콤보(현재·최대) / 보드 아래: 타임바.
///
/// 상단 한 줄(일시정지·힌트·베스트·우측 튜토리얼) 배치는 형제 프로젝트
/// `flame_tab_order/lib/game/components/game_hud.dart`(1~50)와 같은 패턴을 참고한다.
class MatchGameHud extends PositionComponent
    with HasGameReference<MatchBoardGame>, TapCallbacks {
  MatchGameHud({
    required this.onPausePressed,
    required this.onHintPressed,
    required this.onTutorialPressed,
  });

  final VoidCallback onPausePressed;
  final VoidCallback onHintPressed;
  final VoidCallback onTutorialPressed;

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
  late Rect _tutorialRect;
  late TextPainter _tutorialGlyph;
  late Rect _timeBarRect;
  late Rect _comboRect;

  double _scoreBlockTop = 0;
  int? _cachedBest;

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
  }) =>
      TextStyle(
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

  void _rebuildStaticPainters() {
    final t = game.hudTextScale;
    _scoreLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('score', 'Score'),
        style: _ts(size: 14 * t, color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.92)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final best = _cachedBest;
    _bestLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('bestScore', 'Best'),
        style: _ts(size: 12 * t, color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.95)),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _bestValue = TextPainter(
      text: TextSpan(
        text: best != null ? _fmt.format(best) : '—',
        style: _ts(
          size: 17 * t,
          color: JewelCandyLuminaTheme.goldStrong,
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _rebuildTimeBarText();
    _rebuildComboPainters();

    _scoreValue = TextPainter(
      text: TextSpan(
        text: _fmt.format(game.board.score),
        style: _ts(
          size: 40 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _tutorialGlyph = TextPainter(
      text: TextSpan(
        text: '?',
        style: _ts(
          size: 20 * t,
          color: JewelCandyLuminaTheme.primaryPink,
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  void _rebuildTimeBarText() {
    final t = game.hudTextScale;
    if (game.isTimedMode) {
      final s = game.timeRemaining.ceil().clamp(0, 99999);
      final m = s ~/ 60;
      final r = s % 60;
      final txt = '$m:${r.toString().padLeft(2, '0')}';
      // 밝은 그라데이션 위에서도 읽히도록: 밝은 글자 + 짙은 외곽 그림자(시안 단색은 대비 부족)
      final critical = s <= 10;
      final baseSh = _hudLegibilityShadows();
      _timeInBar = TextPainter(
        text: TextSpan(
          text: txt,
          style: _ts(
            size: 19 * t,
            color: critical
                ? const Color(0xFFFFEB3B)
                : const Color(0xFFFFFDE7),
            weight: FontWeight.w800,
            shadows: critical
                ? [
                    Shadow(
                      color: Colors.red.shade900.withValues(alpha: 0.9),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                    ...baseSh,
                  ]
                : baseSh,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    } else {
      _timeInBar = TextPainter(
        text: TextSpan(
          text: game.localeString('unlimitedMode', 'Untimed'),
          style: _ts(
            size: 15 * t,
            color: JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.95),
            weight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
    }
  }

  int _displayCurrentCombo() {
    final s = game.board.state;
    if (s != 'idle' && s != 'gameover') {
      return game.board.combo;
    }
    return game.board.lastCombo;
  }

  void _rebuildComboPainters() {
    final t = game.hudTextScale;
    final cur = _displayCurrentCombo();
    final mx = game.board.maxCombo;
    final sh = _hudLegibilityShadows();

    _comboLeftLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('combo', 'Combo'),
        style: _ts(
          size: 16 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.w600,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboLeftValue = TextPainter(
      text: TextSpan(
        text: '×$cur',
        style: _ts(
          size: 30 * t,
          color: JewelCandyLuminaTheme.secondaryCyan,
          weight: FontWeight.w800,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboRightLabel = TextPainter(
      text: TextSpan(
        text: game.localeString('maxComboLabel', 'Max'),
        style: _ts(
          size: 16 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.w600,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _comboRightValue = TextPainter(
      text: TextSpan(
        text: '×$mx',
        style: _ts(
          size: 30 * t,
          color: JewelCandyLuminaTheme.goldStrong,
          weight: FontWeight.w800,
          shadows: sh,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final t = game.hudTextScale;

    _scoreValue = TextPainter(
      text: TextSpan(
        text: _fmt.format(game.board.score),
        style: _ts(
          size: 40 * t,
          color: const Color(0xFFFFFDE7),
          weight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final latestBest = GameSettings.getBestMatchScore(game.gameMode);
    if (latestBest != _cachedBest) {
      _cachedBest = latestBest;
      _rebuildStaticPainters();
    }

    _rebuildTimeBarText();
    _rebuildComboPainters();
  }

  double _timeRatio() {
    if (!game.isTimedMode) return 1;
    final initial = MatchBoardGame.timedRoundSeconds;
    if (initial <= 0) return 0;
    final t = game.timeRemaining;
    // 보너스로 시작 분(120초)을 넘기면 바는 가득 찬 상태로 유지
    if (t >= initial) {
      return 1.0;
    }
    return (t / initial).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    if (!g.hasLayout || g.size.x <= 0 || g.size.y <= 0) {
      return;
    }

    final layout = g.hudScale;
    final top = g.safeAreaPadding.top + 10;
    final row1H = g.hudTopBarHeight;
    final cx = g.safeContentCenterX;

    final bestBlockW = math.max(_bestLabel.width, _bestValue.width);
    final gapBestTutorial = layout * 0.1;
    final bestRight = _tutorialRect.left - gapBestTutorial;
    final bestLeft = bestRight - bestBlockW;
    final bestTop = top + (row1H - (_bestLabel.height + 4 + _bestValue.height)) / 2;
    _bestLabel.paint(canvas, Offset(bestLeft + (bestBlockW - _bestLabel.width) / 2, bestTop));
    _bestValue.paint(
      canvas,
      Offset(bestLeft + (bestBlockW - _bestValue.width) / 2, bestTop + _bestLabel.height + 4),
    );

    _drawTutorialButton(canvas);

    final scoreY = _scoreBlockTop + 4;
    _scoreLabel.paint(canvas, Offset(cx - _scoreLabel.width / 2, scoreY));
    _scoreValue.paint(
      canvas,
      Offset(cx - _scoreValue.width / 2, scoreY + _scoreLabel.height + 4),
    );

    if (_comboRect.width > 0 && _comboRect.height > 0) {
      final comboR = math.min(14.0, _comboRect.height / 2);
      final comboBg = RRect.fromRectAndRadius(
        _comboRect,
        Radius.circular(comboR),
      );
      canvas.drawRRect(
        comboBg,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: JewelCandyLuminaTheme.comboStripGradient,
          ).createShader(_comboRect),
      );
      canvas.drawRRect(
        comboBg,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      final halfW = _comboRect.width / 2;
      final leftCol = Rect.fromLTWH(
        _comboRect.left,
        _comboRect.top,
        halfW,
        _comboRect.height,
      );
      final rightCol = Rect.fromLTWH(
        _comboRect.left + halfW,
        _comboRect.top,
        halfW,
        _comboRect.height,
      );

      final gapLabelValue = math.max(9.0, layout * 0.11);
      final lh = _comboLeftLabel.height + gapLabelValue + _comboLeftValue.height;
      final rh = _comboRightLabel.height + gapLabelValue + _comboRightValue.height;
      final blockH = math.max(lh, rh);
      final minPad = layout * 0.14;
      var padTop = (_comboRect.height - blockH) / 2;
      if (padTop < minPad) {
        padTop = minPad;
      }
      if (padTop + blockH > _comboRect.height - minPad * 0.75) {
        // blockH > 높이 이면 상한이 음수가 되어 clamp(0, 음수) 가 ArgumentError — 라벨 키운 뒤 발생
        final maxPadTop = math.max(0.0, _comboRect.height - blockH);
        padTop =
            ((_comboRect.height - blockH) / 2).clamp(0.0, maxPadTop);
      }
      final ly0 = _comboRect.top + padTop + (blockH - lh) / 2;
      final ry0 = _comboRect.top + padTop + (blockH - rh) / 2;
      _comboLeftLabel.paint(
        canvas,
        Offset(leftCol.center.dx - _comboLeftLabel.width / 2, ly0),
      );
      _comboLeftValue.paint(
        canvas,
        Offset(
          leftCol.center.dx - _comboLeftValue.width / 2,
          ly0 + _comboLeftLabel.height + gapLabelValue,
        ),
      );

      _comboRightLabel.paint(
        canvas,
        Offset(rightCol.center.dx - _comboRightLabel.width / 2, ry0),
      );
      _comboRightValue.paint(
        canvas,
        Offset(
          rightCol.center.dx - _comboRightValue.width / 2,
          ry0 + _comboRightLabel.height + gapLabelValue,
        ),
      );
    }

    if (_timeBarRect.width > 0 && _timeBarRect.height > 0) {
      final barBg = RRect.fromRectAndRadius(
        _timeBarRect,
        Radius.circular(_timeBarRect.height / 2),
      );
      canvas.drawRRect(
        barBg,
        Paint()..color = JewelCandyLuminaTheme.surfaceContainer,
      );
      canvas.drawRRect(
        barBg,
        Paint()
          ..color = JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      // 고정 inset(3)은 타임바가 낮을 때 inner 높이가 음수가 되어 셰이더/ RRect 가 실패할 수 있음
      final inset = math.min(3.0, _timeBarRect.height / 3);
      final inner = Rect.fromLTWH(
        _timeBarRect.left + inset,
        _timeBarRect.top + inset,
        _timeBarRect.width - inset * 2,
        _timeBarRect.height - inset * 2,
      );

      if (inner.width > 0 && inner.height > 0) {
        final innerR = RRect.fromRectAndRadius(
          inner,
          Radius.circular(inner.height / 2),
        );

        if (g.isTimedMode) {
          final r = _timeRatio();
          final fillW = inner.width * r;
          if (fillW > 0.5) {
            final fillRect =
                Rect.fromLTWH(inner.left, inner.top, fillW, inner.height);
            final fillR = RRect.fromRectAndRadius(
              fillRect,
              Radius.circular(inner.height / 2),
            );
            final low = r < 0.2;
            canvas.drawRRect(
              fillR,
              Paint()
                ..shader = LinearGradient(
                  colors: low
                      ? JewelCandyLuminaTheme.timeBarFillCritical
                      : JewelCandyLuminaTheme.timeBarFillVibrant,
                ).createShader(fillRect),
            );
          }
        } else {
          canvas.drawRRect(
            innerR,
            Paint()
              ..color =
                  JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.14),
          );
        }

        if (_timeInBar != null) {
          final tp = _timeInBar!;
          tp.paint(
            canvas,
            Offset(
              inner.center.dx - tp.width / 2,
              inner.center.dy - tp.height / 2,
            ),
          );
        }
      }
    }

    _drawHintButton(canvas);
    _drawPause(canvas);
  }

  void _drawTutorialButton(Canvas canvas) {
    final r = _tutorialRect;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    canvas.drawRRect(
      rr,
      Paint()..color = JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _tutorialGlyph.paint(
      canvas,
      Offset(
        r.center.dx - _tutorialGlyph.width / 2,
        r.center.dy - _tutorialGlyph.height / 2,
      ),
    );
  }

  /// 힌트 — 전구 형태 (튜토리얼용 ? 버튼과 구분).
  void _drawHintButton(Canvas canvas) {
    final r = _hintRect;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    canvas.drawRRect(
      rr,
      Paint()..color = JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final c = r.center;
    final w = r.width;
    final bulbPaint = Paint()..color = JewelCandyLuminaTheme.goldStrong;
    canvas.drawCircle(Offset(c.dx, c.dy - w * 0.06), w * 0.17, bulbPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + w * 0.18),
          width: w * 0.26,
          height: w * 0.14,
        ),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(c.dx - w * 0.05, c.dy - w * 0.1), w * 0.04, glint);
  }

  void _drawPause(Canvas canvas) {
    final r = _pauseRect;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    canvas.drawRRect(
      rr,
      Paint()..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final barW = r.width * 0.14;
    final barH = r.width * 0.45;
    final gap = r.width * 0.12;
    final cx = r.center.dx;
    final cy = r.center.dy;
    final paint = Paint()..color = const Color(0xFFFFFDE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - gap, cy),
          width: barW,
          height: barH,
        ),
        Radius.circular(barW * 0.3),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx + gap, cy),
          width: barW,
          height: barH,
        ),
        Radius.circular(barW * 0.3),
      ),
      paint,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition;
    if (_pauseRect.contains(Offset(p.x, p.y))) {
      game.dismissHint();
      onPausePressed();
      return;
    }
    if (_hintRect.contains(Offset(p.x, p.y))) {
      onHintPressed();
      return;
    }
    if (_tutorialRect.contains(Offset(p.x, p.y))) {
      game.dismissHint();
      onTutorialPressed();
      return;
    }
    final bt = game.board.boardY;
    final bb = game.boardPixelBottom;
    final py = p.y;
    if (py < bt || py > bb) {
      game.dismissHint();
      return;
    }
    game.handleBoardTap(event.canvasPosition.x, event.canvasPosition.y);
  }
}
