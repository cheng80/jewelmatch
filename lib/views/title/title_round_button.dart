import 'package:flutter/material.dart';

import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/obsidian_frame.dart';

/// 참조 이미지 스타일의 둥글고 큼지막한 버튼.
class TitleRoundButton extends StatelessWidget {
  const TitleRoundButton({
    required this.label,
    required this.gradientColors,
    required this.onPressed,
    super.key,
  });

  static const double _width = 276;
  static const double _height = 58;
  static const double _fontSize = 23;
  static const double _letterSpacing = 2;

  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;

  /// 게임 화면과 동일한 Lumina 그라데이션·테두리·그림자 둥근 버튼.
  @override
  Widget build(BuildContext context) {
    return ObsidianTitleButtonFrame(
      width: _width,
      height: _height,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 46),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          color: JewelCandyLuminaTheme.tertiaryGold,
          letterSpacing: _letterSpacing,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.9),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
            Shadow(
              color: JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.4),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
