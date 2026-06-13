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
      width: 132,
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
      GemKind.bomb => 2,
      GemKind.normal ||
      GemKind.star ||
      GemKind.hyper ||
      GemKind.supernova => null,
    };
    final chargedSheetCol = switch (kind) {
      GemKind.star => _chargedStarColFromGemCol(gemSheetCol),
      GemKind.supernova => _chargedSupernovaColFromGemCol(gemSheetCol),
      GemKind.normal ||
      GemKind.row ||
      GemKind.col ||
      GemKind.bomb ||
      GemKind.hyper => null,
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
          else if (chargedSheetCol != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: HowToPlayChargedGemClip(chargedSheetCol),
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

  int? _chargedStarColFromGemCol(int? gemSheetCol) {
    final colorIndex = _colorIndexFromGemSheetCol(gemSheetCol);
    return colorIndex;
  }

  int? _chargedSupernovaColFromGemCol(int? gemSheetCol) {
    final colorIndex = _colorIndexFromGemSheetCol(gemSheetCol);
    return colorIndex == null ? null : 6 + colorIndex;
  }

  int? _colorIndexFromGemSheetCol(int? gemSheetCol) {
    return switch (gemSheetCol) {
      0 => 0,
      6 => 1,
      3 => 2,
      2 => 3,
      4 => 4,
      5 => 5,
      _ => null,
    };
  }
}
