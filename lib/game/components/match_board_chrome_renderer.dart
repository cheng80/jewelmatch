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
    final frame = (ts * 0.17).clamp(7.0, 14.0);
    final outerRect = Rect.fromLTWH(
      bx - frame,
      by - frame,
      bw + frame * 2,
      bh + frame * 2,
    );
    final innerRect = Rect.fromLTWH(bx, by, bw, bh);
    final outerR = RRect.fromRectAndRadius(outerRect, Radius.circular(frame));
    final innerR = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(ts * 0.04),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawBoardShadow(canvas, outerR, ts);
    _drawStoneFrame(canvas, outerRect, outerR, innerR, frame, ts);
    _drawUniformCells(canvas, innerRect, ts);
    _drawGridLines(canvas, innerRect, ts);
    _drawBoardRim(canvas, innerRect, outerRect, ts);

    _boardChromePicture = recorder.endRecording();
    _cachedTileSize = ts;
    _cachedBoardX = bx;
    _cachedBoardY = by;
  }

  void _drawBoardShadow(Canvas canvas, RRect outerR, double ts) {
    canvas.drawRRect(
      outerR.shift(Offset(0, ts * 0.06)),
      Paint()
        ..color = const Color(0x99000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ts * 0.12),
    );
  }

  void _drawStoneFrame(
    Canvas canvas,
    Rect outerRect,
    RRect outerR,
    RRect innerR,
    double frame,
    double ts,
  ) {
    final framePath = Path()
      ..addRRect(outerR)
      ..addRRect(innerR)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      framePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFB18143),
            Color(0xFF41321F),
            Color(0xFF151719),
            Color(0xFF7A5A32),
          ],
          stops: <double>[0.0, 0.28, 0.63, 1.0],
        ).createShader(outerRect),
    );
    canvas.drawPath(
      framePath,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.04,
    );
    canvas.drawRRect(
      outerR.deflate(frame * 0.28),
      Paint()
        ..color = const Color(0x99D8B36B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.018,
    );
    _drawFrameSegments(canvas, outerRect, frame, ts);
  }

  void _drawFrameSegments(
    Canvas canvas,
    Rect outerRect,
    double frame,
    double ts,
  ) {
    final segmentPaint = Paint()
      ..color = const Color(0x88302016)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ts * 0.018;
    for (var i = 1; i < logic.cols; i++) {
      final x = outerRect.left + frame + i * ts;
      canvas.drawLine(
        Offset(x, outerRect.top + frame * 0.2),
        Offset(x, outerRect.top + frame * 0.92),
        segmentPaint,
      );
      canvas.drawLine(
        Offset(x, outerRect.bottom - frame * 0.92),
        Offset(x, outerRect.bottom - frame * 0.2),
        segmentPaint,
      );
    }
    for (var i = 1; i < logic.rows; i++) {
      final y = outerRect.top + frame + i * ts;
      canvas.drawLine(
        Offset(outerRect.left + frame * 0.2, y),
        Offset(outerRect.left + frame * 0.92, y),
        segmentPaint,
      );
      canvas.drawLine(
        Offset(outerRect.right - frame * 0.92, y),
        Offset(outerRect.right - frame * 0.2, y),
        segmentPaint,
      );
    }
  }

  void _drawUniformCells(Canvas canvas, Rect innerRect, double ts) {
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(ts * 0.035)),
    );
    final cellPaint = Paint()..color = const Color(0xFF20211E);
    final insetPaint = Paint()..color = const Color(0x1A080908);
    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final cellRect = Rect.fromLTWH(
          innerRect.left + c * ts,
          innerRect.top + r * ts,
          ts,
          ts,
        );
        canvas.drawRect(cellRect, cellPaint);
        canvas.drawRect(cellRect.deflate(ts * 0.08), insetPaint);
      }
    }
    canvas.restore();
  }

  void _drawGridLines(Canvas canvas, Rect innerRect, double ts) {
    final darkLine = Paint()
      ..color = const Color(0xFF3A3A34)
      ..strokeWidth = (ts * 0.035).clamp(1.5, 2.4);
    for (var c = 1; c < logic.cols; c++) {
      final x = innerRect.left + c * ts;
      canvas.drawLine(
        Offset(x, innerRect.top),
        Offset(x, innerRect.bottom),
        darkLine,
      );
    }
    for (var r = 1; r < logic.rows; r++) {
      final y = innerRect.top + r * ts;
      canvas.drawLine(
        Offset(innerRect.left, y),
        Offset(innerRect.right, y),
        darkLine,
      );
    }
  }

  void _drawBoardRim(Canvas canvas, Rect innerRect, Rect outerRect, double ts) {
    final rim = RRect.fromRectAndRadius(innerRect, Radius.circular(ts * 0.035));
    canvas.drawRRect(
      rim,
      Paint()
        ..color = const Color(0xFF070705)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.065,
    );
    canvas.drawRRect(
      rim.inflate(ts * 0.035),
      Paint()
        ..color = const Color(0xFFD8B36B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.02,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(ts * 0.16)),
      Paint()
        ..color = const Color(0xFF080706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ts * 0.035,
    );
  }
}
