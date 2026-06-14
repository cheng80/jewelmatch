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
