import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';

class ObsidianAntiqueButtonSurface extends StatelessWidget {
  const ObsidianAntiqueButtonSurface({
    super.key,
    required this.child,
    required this.height,
    required this.onPressed,
    required this.padding,
  });

  final Widget child;
  final double height;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isCompact = height <= 52;
    final isEnabled = onPressed != null;
    final radius = BorderRadius.circular(isCompact ? 10 : 12);
    final outerGold = JewelCandyLuminaTheme.outlineBright.withValues(
      alpha: isEnabled ? 0.95 : 0.42,
    );
    final midGold = JewelCandyLuminaTheme.goldStrong.withValues(
      alpha: isEnabled ? 0.82 : 0.36,
    );
    final innerGold = JewelCandyLuminaTheme.tertiaryGold.withValues(
      alpha: isEnabled ? 0.26 : 0.10,
    );
    final borderWidth = isCompact ? 2.0 : 2.5;
    final middleWidth = isCompact ? 1.2 : 1.5;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.74),
            blurRadius: isCompact ? 8 : 12,
            offset: isCompact ? const Offset(0, 3) : const Offset(0, 5),
          ),
          BoxShadow(
            color: JewelCandyLuminaTheme.surfaceStoneDark.withValues(
              alpha: 0.62,
            ),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: midGold.withValues(alpha: 0.16),
            blurRadius: isCompact ? 6 : 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                JewelCandyLuminaTheme.surfaceStone.withValues(
                  alpha: isEnabled ? 0.98 : 0.58,
                ),
                JewelCandyLuminaTheme.surfaceContainer.withValues(
                  alpha: isEnabled ? 0.99 : 0.62,
                ),
                JewelCandyLuminaTheme.surfaceStoneDark.withValues(
                  alpha: isEnabled ? 0.98 : 0.58,
                ),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
          child: CustomPaint(
            foregroundPainter: _ObsidianButtonBorderPainter(
              radius: isCompact ? 10 : 12,
              outerColor: outerGold,
              outerWidth: borderWidth,
              middleColor: midGold,
              middleWidth: middleWidth,
              innerColor: innerGold,
              innerWidth: 1,
            ),
            child: Padding(
              padding: EdgeInsets.all(borderWidth + middleWidth + 1),
              child: InkWell(
                borderRadius: radius,
                highlightColor: JewelCandyLuminaTheme.tertiaryGold.withValues(
                  alpha: 0.08,
                ),
                splashColor: JewelCandyLuminaTheme.goldStrong.withValues(
                  alpha: 0.10,
                ),
                onTap: onPressed,
                child: Padding(
                  padding: padding,
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ObsidianButtonBorderPainter extends CustomPainter {
  const _ObsidianButtonBorderPainter({
    required this.radius,
    required this.outerColor,
    required this.outerWidth,
    required this.middleColor,
    required this.middleWidth,
    required this.innerColor,
    required this.innerWidth,
  });

  final double radius;
  final Color outerColor;
  final double outerWidth;
  final Color middleColor;
  final double middleWidth;
  final Color innerColor;
  final double innerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    _drawStroke(canvas, size, 0, outerWidth, outerColor);
    _drawStroke(canvas, size, outerWidth + 1, middleWidth, middleColor);
    _drawStroke(
      canvas,
      size,
      outerWidth + middleWidth + 2.5,
      innerWidth,
      innerColor,
    );
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    double inset,
    double strokeWidth,
    Color color,
  ) {
    final halfStroke = strokeWidth / 2;
    final rect =
        Offset(inset + halfStroke, inset + halfStroke) &
        Size(
          size.width - (inset + halfStroke) * 2,
          size.height - (inset + halfStroke) * 2,
        );
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final adjustedRadius = (radius - inset - halfStroke).clamp(
      0.0,
      rect.shortestSide / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(adjustedRadius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ObsidianButtonBorderPainter oldDelegate) {
    return radius != oldDelegate.radius ||
        outerColor != oldDelegate.outerColor ||
        outerWidth != oldDelegate.outerWidth ||
        middleColor != oldDelegate.middleColor ||
        middleWidth != oldDelegate.middleWidth ||
        innerColor != oldDelegate.innerColor ||
        innerWidth != oldDelegate.innerWidth;
  }
}
