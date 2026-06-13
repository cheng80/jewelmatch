part of 'match_game_hud.dart';

extension _MatchGameHudButtonRenderer on MatchGameHud {
  void _drawTutorialButton(Canvas canvas) {
    final r = _tutorialRect;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    _tutorialFillPaint.color = JewelCandyLuminaTheme.primaryPink.withValues(
      alpha: 0.22,
    );
    canvas.drawRRect(rr, _tutorialFillPaint);
    _tutorialStrokePaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
      alpha: 0.75,
    );
    canvas.drawRRect(rr, _tutorialStrokePaint);
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
    _hintFillPaint.color = JewelCandyLuminaTheme.goldStrong.withValues(
      alpha: 0.2,
    );
    canvas.drawRRect(rr, _hintFillPaint);
    _hintStrokePaint.color = JewelCandyLuminaTheme.goldStrong.withValues(
      alpha: 0.85,
    );
    canvas.drawRRect(rr, _hintStrokePaint);
    final c = r.center;
    final w = r.width;
    _hintBulbPaint.color = JewelCandyLuminaTheme.goldStrong;
    canvas.drawCircle(Offset(c.dx, c.dy - w * 0.06), w * 0.17, _hintBulbPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, c.dy + w * 0.18),
          width: w * 0.26,
          height: w * 0.14,
        ),
        Radius.circular(w * 0.04),
      ),
      _hintBasePaint..color = const Color(0xFF8D6E63),
    );
    _hintGlintPaint.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(
      Offset(c.dx - w * 0.05, c.dy - w * 0.1),
      w * 0.04,
      _hintGlintPaint,
    );
  }

  /// 랭킹 — 트로피 실루엣 (힌트 전구와 구분).
  void _drawRankingButton(Canvas canvas) {
    final r = _rankingRect;
    if (r.isEmpty) return;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    _rankingFillPaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
      alpha: 0.18,
    );
    canvas.drawRRect(rr, _rankingFillPaint);
    _rankingStrokePaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
      alpha: 0.88,
    );
    canvas.drawRRect(rr, _rankingStrokePaint);
    final c = r.center;
    final w = r.width;
    _rankingCupPaint.color = JewelCandyLuminaTheme.goldStrong;
    final path = Path()
      ..moveTo(c.dx - w * 0.22, c.dy + w * 0.12)
      ..lineTo(c.dx - w * 0.18, c.dy - w * 0.02)
      ..quadraticBezierTo(c.dx - w * 0.2, c.dy - w * 0.2, c.dx, c.dy - w * 0.22)
      ..quadraticBezierTo(
        c.dx + w * 0.2,
        c.dy - w * 0.2,
        c.dx + w * 0.18,
        c.dy - w * 0.02,
      )
      ..lineTo(c.dx + w * 0.22, c.dy + w * 0.12)
      ..lineTo(c.dx + w * 0.14, c.dy + w * 0.1)
      ..lineTo(c.dx - w * 0.14, c.dy + w * 0.1)
      ..close();
    canvas.drawPath(path, _rankingCupPaint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + w * 0.16),
        width: w * 0.36,
        height: w * 0.08,
      ),
      _rankingBasePaint..color = const Color(0xFF8D6E63),
    );
    canvas.drawCircle(
      Offset(c.dx - w * 0.2, c.dy - w * 0.18),
      w * 0.06,
      _rankingCupPaint,
    );
    canvas.drawCircle(
      Offset(c.dx + w * 0.2, c.dy - w * 0.18),
      w * 0.06,
      _rankingCupPaint,
    );
  }

  void _drawPause(Canvas canvas) {
    final r = _pauseRect;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.25));
    _pauseFillPaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
      alpha: 0.2,
    );
    canvas.drawRRect(rr, _pauseFillPaint);
    _pauseStrokePaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
      alpha: 0.65,
    );
    canvas.drawRRect(rr, _pauseStrokePaint);
    final barW = r.width * 0.14;
    final barH = r.width * 0.45;
    final gap = r.width * 0.12;
    final cx = r.center.dx;
    final cy = r.center.dy;
    _pauseBarPaint.color = const Color(0xFFFFFDE7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - gap, cy),
          width: barW,
          height: barH,
        ),
        Radius.circular(barW * 0.3),
      ),
      _pauseBarPaint,
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
      _pauseBarPaint,
    );
  }
}
