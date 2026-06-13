import 'package:flutter/material.dart';

import '../../../game/match_board_logic.dart';
import '../../../theme/jewel_candy_lumina_theme.dart';

class HowToPlaySpecialGemPainter extends CustomPainter {
  HowToPlaySpecialGemPainter(this.kind);

  final GemKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.35;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final core = Paint()..color = Colors.white.withValues(alpha: 0.9);

    if (kind == GemKind.supernova) {
      glow
        ..color = JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.55)
        ..strokeWidth = size.shortestSide * 0.12;
      canvas.drawCircle(center, radius, glow);

      line
        ..color = JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.9)
        ..strokeWidth = size.shortestSide * 0.04;
      canvas.drawCircle(center, radius, line);
      canvas.drawCircle(center, radius * 0.72, line);
    }

    final long = size.shortestSide * 0.32;
    final short = size.shortestSide * 0.16;
    glow
      ..color = JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.44)
      ..strokeWidth = size.shortestSide * 0.09;
    canvas.drawLine(
      Offset(center.dx - long, center.dy),
      Offset(center.dx + long, center.dy),
      glow,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - long),
      Offset(center.dx, center.dy + long),
      glow,
    );

    line
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = size.shortestSide * 0.035;
    canvas.drawLine(
      Offset(center.dx - long, center.dy),
      Offset(center.dx + long, center.dy),
      line,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - long),
      Offset(center.dx, center.dy + long),
      line,
    );
    canvas.drawLine(
      Offset(center.dx - short, center.dy - short),
      Offset(center.dx + short, center.dy + short),
      line,
    );
    canvas.drawLine(
      Offset(center.dx - short, center.dy + short),
      Offset(center.dx + short, center.dy - short),
      line,
    );

    canvas.drawCircle(
      center,
      kind == GemKind.supernova
          ? size.shortestSide * 0.09
          : size.shortestSide * 0.055,
      core,
    );
  }

  @override
  bool shouldRepaint(HowToPlaySpecialGemPainter oldDelegate) {
    return oldDelegate.kind != kind;
  }
}
