import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';
import 'obsidian_frame.dart';

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
    return ObsidianButtonFrame(
      width: width,
      height: height,
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: JewelCandyLuminaTheme.tertiaryGold,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
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
    return ObsidianButtonFrame(
      width: width,
      height: height,
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: JewelCandyLuminaTheme.secondaryCyan,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
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
    return ObsidianButtonFrame(
      width: width,
      height: height,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: JewelCandyLuminaTheme.tertiaryGold,
            letterSpacing: 4,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.9),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
              Shadow(
                color: JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
