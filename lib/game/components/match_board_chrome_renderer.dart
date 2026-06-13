part of 'match_board_renderer.dart';

extension _MatchBoardChromeRenderer on MatchBoardRenderer {
  void _rebuildBoardChromePicture() {
    _boardChromePicture?.dispose();
    final ts = logic.tileSize;
    final bx = logic.boardX;
    final by = logic.boardY;
    if (ts <= 0) {
      _boardChromePicture = null;
      _cachedTileSize = ts;
      _cachedBoardX = bx;
      _cachedBoardY = by;
      return;
    }

    final bw = logic.cols * ts;
    final bh = logic.rows * ts;
    final outerRect = Rect.fromLTWH(bx - 8, by - 8, bw + 16, bh + 16);
    final outerR = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(14),
    );
    final innerR = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      const Radius.circular(10),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRRect(
      outerR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: JewelCandyLuminaTheme.boardFrameGradient,
        ).createShader(outerRect),
    );
    canvas.drawRRect(innerR, Paint()..color = JewelCandyLuminaTheme.boardInner);

    const pad = 3.0;
    final fillPaint = Paint()..color = JewelCandyLuminaTheme.boardSlotFill;
    final strokePaint = Paint()
      ..color = JewelCandyLuminaTheme.boardSlotStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final slotRadius = Radius.circular(
      ts * MatchBoardRenderer._slotRadiusRatio,
    );
    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final x = bx + c * ts;
        final y = by + r * ts;
        final sr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + pad, y + pad, ts - pad * 2, ts - pad * 2),
          slotRadius,
        );
        canvas.drawRRect(sr, fillPaint);
        canvas.drawRRect(sr, strokePaint);
      }
    }

    _boardChromePicture = recorder.endRecording();
    _cachedTileSize = ts;
    _cachedBoardX = bx;
    _cachedBoardY = by;
  }
}
