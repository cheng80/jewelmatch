import 'package:flutter/material.dart';

import '../../../resources/asset_paths.dart';
import '../../../theme/jewel_candy_lumina_theme.dart';
import '../../../widgets/sprite_sheet_frame.dart';

const double howToPlayGemSize = 36;
const double howToPlayOverlayRatio = 112 / 128;

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

class HowToPlayGemClip extends StatelessWidget {
  const HowToPlayGemClip(this.sheetCol, {super.key});

  final int sheetCol;

  @override
  Widget build(BuildContext context) {
    return SpriteSheetFrame(
      assetPath: 'assets/images/${AssetPaths.jewelSpriteSheet}',
      frameIndex: sheetCol,
      frameSize: 128,
      size: howToPlayGemSize,
    );
  }
}

class HowToPlaySpecialGemClip extends StatelessWidget {
  const HowToPlaySpecialGemClip(this.sheetCol, {super.key});

  final int sheetCol;

  @override
  Widget build(BuildContext context) {
    return SpriteSheetFrame(
      assetPath: 'assets/images/${AssetPaths.specialSpriteSheet}',
      frameIndex: sheetCol,
      frameSize: 128,
      size: howToPlayGemSize,
    );
  }
}

class HowToPlayOverlayGemClip extends StatelessWidget {
  const HowToPlayOverlayGemClip({
    super.key,
    required this.sheetCol,
    required this.overlayAssetPath,
  });

  final int sheetCol;
  final String overlayAssetPath;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: howToPlayGemSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          HowToPlayGemClip(sheetCol),
          Image.asset(
            'assets/images/$overlayAssetPath',
            width: howToPlayGemSize * howToPlayOverlayRatio,
            height: howToPlayGemSize * howToPlayOverlayRatio,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ],
      ),
    );
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
