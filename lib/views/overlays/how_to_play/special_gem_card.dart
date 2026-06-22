import 'package:flutter/material.dart';

import '../../../game/match_board_logic.dart';
import '../../../theme/jewel_candy_lumina_theme.dart';
import 'gem_examples.dart';

class HowToPlaySpecialGemCard extends StatelessWidget {
  const HowToPlaySpecialGemCard({
    super.key,
    required this.kind,
    required this.gemSheetCol,
    required this.title,
    required this.desc,
  });

  final GemKind kind;
  final int? gemSheetCol;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: HowToPlaySpecialGemPreview(
              kind: kind,
              gemSheetCol: gemSheetCol,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: JewelCandyLuminaTheme.tertiaryGold,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class HowToPlaySpecialGemPreview extends StatelessWidget {
  const HowToPlaySpecialGemPreview({
    super.key,
    required this.kind,
    this.gemSheetCol,
  });

  final GemKind kind;
  final int? gemSheetCol;

  @override
  Widget build(BuildContext context) {
    final specialSheetCol = switch (kind) {
      GemKind.col => 0,
      GemKind.row => 1,
      GemKind.normal ||
      GemKind.bomb ||
      GemKind.star ||
      GemKind.hyper ||
      GemKind.supernova => null,
    };
    final actionSpecialSheetCol = switch (kind) {
      GemKind.bomb => 0,
      GemKind.star => 1,
      GemKind.hyper => 2,
      GemKind.supernova => 3,
      GemKind.normal || GemKind.row || GemKind.col => null,
    };
    final overlayAssetPath = switch (kind) {
      GemKind.normal ||
      GemKind.row ||
      GemKind.col ||
      GemKind.bomb ||
      GemKind.star ||
      GemKind.hyper ||
      GemKind.supernova => null,
    };

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (specialSheetCol != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: HowToPlaySpecialGemClip(specialSheetCol),
            )
          else if (actionSpecialSheetCol != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: HowToPlayActionSpecialGemClip(actionSpecialSheetCol),
            )
          else if (overlayAssetPath != null && gemSheetCol != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: HowToPlayOverlayGemClip(
                sheetCol: gemSheetCol!,
                overlayAssetPath: overlayAssetPath,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(4),
              child: gemSheetCol == null
                  ? const SizedBox.shrink()
                  : HowToPlayGemClip(gemSheetCol!),
            ),
        ],
      ),
    );
  }
}
