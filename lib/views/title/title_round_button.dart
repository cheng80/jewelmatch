import 'package:flutter/material.dart';

import '../../theme/jewel_candy_lumina_theme.dart';

/// 참조 이미지 스타일의 둥글고 큼지막한 버튼.
class TitleRoundButton extends StatelessWidget {
  const TitleRoundButton({
    required this.label,
    required this.gradientColors,
    required this.onPressed,
    super.key,
  });

  static const double _width = 236;
  static const double _height = 62;
  static const double _fontSize = 28;
  static const double _letterSpacing = 5;

  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;

  /// 게임 화면과 동일한 Lumina 그라데이션·테두리·그림자 둥근 버튼.
  @override
  Widget build(BuildContext context) {
    final base = gradientColors.first;
    final darkerColor = HSLColor.fromColor(gradientColors.last)
        .withLightness(
          (HSLColor.fromColor(gradientColors.last).lightness - 0.14).clamp(
            0.0,
            1.0,
          ),
        )
        .toColor();

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(_height / 2),
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
            BoxShadow(color: base.withValues(alpha: 0.35), blurRadius: 16),
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
              fontSize: _fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: _letterSpacing,
              shadows: [
                Shadow(color: base.withValues(alpha: 0.5), blurRadius: 14),
                Shadow(
                  color: darkerColor.withValues(alpha: 0.85),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
                Shadow(
                  color: JewelCandyLuminaTheme.primaryDeep.withValues(
                    alpha: 0.45,
                  ),
                  offset: const Offset(1.5, 1.5),
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
