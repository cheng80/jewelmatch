import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';

/// 오버레이·메뉴에서 사용하는 Lumina 스타일 그라데이션 CTA.
class LuminaGradientButton extends StatelessWidget {
  const LuminaGradientButton({
    super.key,
    required this.colors,
    required this.label,
    required this.onPressed,
    this.width = 240,
    this.height = 52,
    this.fontSize = 18,
    this.borderRadius = 16,
  });

  final List<Color> colors;
  final String label;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final double fontSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 오버레이에서 CTA 아래 보조로 쓰는 아웃라인 버튼.
class LuminaOutlinedButton extends StatelessWidget {
  const LuminaOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 240,
    this.height = 52,
    this.borderColor,
    this.borderRadius = 16,
  });

  final String label;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final sideColor = borderColor ?? JewelCandyLuminaTheme.secondaryCyan;
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: sideColor, width: 2),
          backgroundColor:
              JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// 타이틀 화면의 큼직한 둥근 그라데이션 버튼.
class LuminaRoundButton extends StatelessWidget {
  const LuminaRoundButton({
    super.key,
    required this.label,
    required this.gradientColors,
    required this.onPressed,
    this.width = 260,
    this.height = 68,
    this.fontSize = 32,
  });

  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = gradientColors.first;
    final darkerColor = HSLColor.fromColor(gradientColors.last)
        .withLightness(
          (HSLColor.fromColor(gradientColors.last).lightness - 0.14)
              .clamp(0.0, 1.0),
        )
        .toColor();

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: darkerColor.withValues(alpha: 0.65),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: darkerColor.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
            BoxShadow(
              color: base.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
            BoxShadow(
              color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 6,
              shadows: [
                Shadow(
                  color: darkerColor.withValues(alpha: 0.85),
                  offset: const Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
