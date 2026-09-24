import 'package:flutter/material.dart';

import '../../../theme/jewel_candy_lumina_theme.dart';
import '../../../widgets/sprite_sheet_frame.dart';

const double howToPlayGemSize = 36;

class HowToPlayMatchExample extends StatelessWidget {
  const HowToPlayMatchExample(this.cols, {super.key});

  final List<int> cols;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            decoration: i < 3 ? howToPlayGemHighlightDecoration() : null,
            child: HowToPlayGemClip(cols[i]),
          ),
        ],
      ],
    );
  }
}

class HowToPlaySwapExample extends StatelessWidget {
  const HowToPlaySwapExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const HowToPlayGemClip(0),
        const SizedBox(width: 2),
        const HowToPlayGemClip(6),
        const SizedBox(width: 8),
        Icon(
          Icons.swap_horiz_rounded,
          color: JewelCandyLuminaTheme.secondaryCyan,
          size: 28,
        ),
        const SizedBox(width: 8),
        const HowToPlayGemClip(6),
        const SizedBox(width: 2),
        const HowToPlayGemClip(0),
      ],
    );
  }
}

/// 보석 칸. [sheetCol]은 `Jewel_Arcane` 열 번호이고 board_atlas의 `gem_<열>` 칸이다.
class HowToPlayGemClip extends StatelessWidget {
  const HowToPlayGemClip(this.sheetCol, {super.key});

  final int sheetCol;

  @override
  Widget build(BuildContext context) {
    return BoardAtlasFrame('gem_$sheetCol', size: howToPlayGemSize);
  }
}

/// 액션 특수 보석 칸(0 bomb, 1 star, 2 hyper, 3 supernova).
class HowToPlayActionSpecialGemClip extends StatelessWidget {
  const HowToPlayActionSpecialGemClip(this.sheetCol, {super.key});

  final int sheetCol;

  @override
  Widget build(BuildContext context) {
    return BoardAtlasFrame('action_$sheetCol', size: howToPlayGemSize);
  }
}

BoxDecoration howToPlayGemHighlightDecoration() {
  return BoxDecoration(
    border: Border.all(
      color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.8),
      width: 2,
    ),
    borderRadius: BorderRadius.circular(6),
  );
}
