import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../game/match_board_logic.dart';
import '../../../theme/jewel_candy_lumina_theme.dart';
import 'gem_examples.dart';
import 'special_gem_card.dart';

class HowToPlaySpecialCreationGuide extends StatelessWidget {
  const HowToPlaySpecialCreationGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SpecialCreationRow(
          before: const _CreationMatchRow([0, 0, 0, 0]),
          afterKind: GemKind.bomb,
          afterSheetCol: 0,
          label: context.tr('howToPlaySpecialMakeFlame'),
        ),
        const SizedBox(height: 10),
        _SpecialCreationRow(
          before: const _CreationCrossMatch(),
          afterKind: GemKind.star,
          afterSheetCol: 3,
          label: context.tr('howToPlaySpecialMakeStar'),
        ),
        const SizedBox(height: 10),
        _SpecialCreationRow(
          before: const _CreationMatchRow([3, 3, 3, 3, 3]),
          afterKind: GemKind.hyper,
          afterSheetCol: 1,
          label: context.tr('howToPlaySpecialMakeHyper'),
        ),
        const SizedBox(height: 10),
        _SpecialCreationRow(
          before: const _CreationMatchRow([5, 5, 5, 5, 5, 5]),
          afterKind: GemKind.supernova,
          afterSheetCol: 5,
          label: context.tr('howToPlaySpecialMakeSupernova'),
        ),
      ],
    );
  }
}

class _SpecialCreationRow extends StatelessWidget {
  const _SpecialCreationRow({
    required this.before,
    required this.afterKind,
    required this.afterSheetCol,
    required this.label,
  });

  final Widget before;
  final GemKind afterKind;
  final int afterSheetCol;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.22),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300;
          final beforeWidget = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: before,
          );

          final labelText = Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: beforeWidget),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: JewelCandyLuminaTheme.secondaryCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    HowToPlaySpecialGemPreview(
                      kind: afterKind,
                      gemSheetCol: afterSheetCol,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: labelText),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: beforeWidget),
              Icon(
                Icons.arrow_forward_rounded,
                color: JewelCandyLuminaTheme.secondaryCyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              HowToPlaySpecialGemPreview(
                kind: afterKind,
                gemSheetCol: afterSheetCol,
              ),
              const SizedBox(width: 12),
              Expanded(child: labelText),
            ],
          );
        },
      ),
    );
  }
}

class _CreationMatchRow extends StatelessWidget {
  const _CreationMatchRow(this.cols);

  final List<int> cols;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            decoration: howToPlayGemHighlightDecoration(),
            child: HowToPlayGemClip(cols[i]),
          ),
        ],
      ],
    );
  }
}

class _CreationCrossMatch extends StatelessWidget {
  const _CreationCrossMatch();

  @override
  Widget build(BuildContext context) {
    const c = 2;
    const cell = 42.0;
    return SizedBox(
      width: cell * 3,
      height: cell * 3,
      child: Stack(
        children: const [
          Positioned(left: cell, top: 0, child: _HighlightedGem(c)),
          Positioned(left: 0, top: cell, child: _HighlightedGem(c)),
          Positioned(left: cell, top: cell, child: _HighlightedGem(c)),
          Positioned(left: cell * 2, top: cell, child: _HighlightedGem(c)),
          Positioned(left: cell, top: cell * 2, child: _HighlightedGem(c)),
        ],
      ),
    );
  }
}

class _HighlightedGem extends StatelessWidget {
  const _HighlightedGem(this.sheetCol);

  final int sheetCol;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: howToPlayGemHighlightDecoration(),
      child: HowToPlayGemClip(sheetCol),
    );
  }
}
