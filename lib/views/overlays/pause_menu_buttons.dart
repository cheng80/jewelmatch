import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';

class PauseMenuActionButton extends StatelessWidget {
  const PauseMenuActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.panelColor,
    required this.onPressed,
  });

  static const double _height = 53;
  static const double _iconSize = 36;
  static const double _iconSlotWidth = 44;
  static const double _labelSlotWidth = 118;

  final String label;
  final IconData icon;
  final Color panelColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.8,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(panelColor, BlendMode.modulate),
                  child: Image.asset(
                    AssetPaths.normalButtonTintBg,
                    height: _height,
                    width: double.infinity,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Image.asset(
                  AssetPaths.normalButtonFrontFrame,
                  height: _height,
                  width: double.infinity,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _iconSlotWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          icon,
                          color: JewelCandyLuminaTheme.tertiaryGold,
                          size: _iconSize,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.92),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: _labelSlotWidth,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: JewelCandyLuminaTheme.tertiaryGold,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.95),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PauseMenuSettingsButton extends StatelessWidget {
  const PauseMenuSettingsButton({super.key, required this.onPressed});

  static const String _iconFrameAsset =
      'assets/images/${AssetPaths.obsidianIconButtonFrame}';

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                _iconFrameAsset,
                width: 74,
                height: 74,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              Image.asset(
                AssetPaths.modeIconSettings,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PauseMenuDivider extends StatelessWidget {
  const PauseMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 13,
      child: CustomPaint(painter: _PauseDividerPainter()),
    );
  }
}

class _PauseDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.72)
      ..isAntiAlias = true;
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(center.dx - 18, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 18, center.dy),
      Offset(size.width, center.dy),
      paint,
    );
    final diamond = Path()
      ..moveTo(center.dx, 0)
      ..lineTo(center.dx + 8, center.dy)
      ..lineTo(center.dx, size.height)
      ..lineTo(center.dx - 8, center.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = JewelCandyLuminaTheme.goldStrong,
    );
    canvas.drawCircle(
      center,
      2.2,
      Paint()..color = JewelCandyLuminaTheme.goldStrong,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
