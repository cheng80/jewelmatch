part of 'match_board_renderer.dart';

extension _MatchBoardProceduralRenderer on MatchBoardRenderer {
  void _drawGemProcedural(
    Canvas canvas,
    BoardGem gem,
    double ts, {
    double alpha = 1,
  }) {
    final base = gem.kind == GemKind.hyper
        ? const Color(0xFFE8E8FF)
        : MatchBoardLogic.palette[gem.color.clamp(
                1,
                MatchBoardLogic.palette.length,
              ) -
              1];

    final x = gem.x;
    final y = gem.y;
    final size = ts;
    final cx = x + size / 2;
    final cy = y + size / 2;

    final shadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 3),
        width: size * 0.78,
        height: size * 0.78,
      ),
      Radius.circular(size * 0.2),
    );
    canvas.drawRRect(
      shadow,
      _proceduralShadowPaint
        ..color = Colors.black.withValues(alpha: 0.28 * alpha),
    );

    final outer = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size * 0.72,
        height: size * 0.72,
      ),
      Radius.circular(size * 0.16),
    );
    canvas.drawRRect(
      outer,
      _proceduralGradientPaint
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.22)!.withValues(alpha: alpha),
            Color.lerp(base, Colors.black, 0.15)!.withValues(alpha: alpha),
          ],
        ).createShader(outer.outerRect),
    );

    canvas.drawRRect(
      outer,
      _proceduralStrokePaint
        ..color = Colors.white.withValues(alpha: 0.14 * alpha),
    );

    final hi = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx - size * 0.08, cy - size * 0.1),
        width: size * 0.28,
        height: size * 0.22,
      ),
      Radius.circular(size * 0.1),
    );
    canvas.drawRRect(
      hi,
      _proceduralHighlightPaint
        ..color = Colors.white.withValues(alpha: 0.32 * alpha),
    );
  }
}
