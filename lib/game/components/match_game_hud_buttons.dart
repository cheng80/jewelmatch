part of 'match_game_hud.dart';

extension _MatchGameHudButtonRenderer on MatchGameHud {
  void _drawIconButtonFrame(Canvas canvas, Rect r) {
    final image = _iconButtonFrameImage;
    if (image == null) return;
    final frameRect = r.inflate(r.width * 0.08);
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      frameRect,
      paint,
    );
  }

  void _drawTutorialButton(Canvas canvas) {
    final r = _tutorialRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _tutorialIconImage, sizeFactor: 0.58);
  }

  /// 힌트 — 전구 형태 (튜토리얼용 ? 버튼과 구분).
  void _drawHintButton(Canvas canvas) {
    final r = _hintRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(
      canvas,
      r,
      _hintBulbIconImage,
      sizeFactor: 0.62,
      offsetYFactor: 0.02,
    );
    _drawHintBadge(canvas, r);
  }

  void _drawHintBadge(Canvas canvas, Rect buttonRect) {
    final count = game.hintBadgeCount;
    if (count == null) return;

    final diameter = buttonRect.width * 0.36;
    final center = Offset(
      buttonRect.right - diameter * 0.18,
      buttonRect.bottom - diameter * 0.18,
    ).translate(-5, -5);
    final badgePaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFC58A22)],
      ).createShader(Rect.fromCircle(center: center, radius: diameter / 2));
    final strokePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, buttonRect.width * 0.04)
      ..color = const Color(0xFF2A1606);

    canvas.drawCircle(center, diameter / 2, badgePaint);
    canvas.drawCircle(center, diameter / 2, strokePaint);

    final label = count > 99 ? '99+' : '$count';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _ts(
          size: buttonRect.width * (label.length > 2 ? 0.18 : 0.22),
          color: const Color(0xFF211204),
          weight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.45),
              offset: const Offset(0, 0.5),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: diameter * 0.92);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawButtonIcon(
    Canvas canvas,
    Rect r,
    ui.Image? image, {
    required double sizeFactor,
    double offsetYFactor = 0,
  }) {
    if (image == null) return;
    final iconSize = r.width * sizeFactor;
    final iconRect = Rect.fromCenter(
      center: r.center.translate(0, r.width * offsetYFactor),
      width: iconSize,
      height: iconSize,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      iconRect,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
  }

  /// 랭킹 — 왕관 심볼 (힌트 전구와 구분).
  void _drawRankingButton(Canvas canvas) {
    final r = _rankingRect;
    if (r.isEmpty) return;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _rankingCrownIconImage, sizeFactor: 0.6);
  }

  void _drawPause(Canvas canvas) {
    final r = _pauseRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _pauseIconImage, sizeFactor: 0.70);
  }
}
