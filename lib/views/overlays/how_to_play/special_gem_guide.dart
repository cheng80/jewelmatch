import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../game/match_board_logic.dart';
import 'special_gem_card.dart';

class HowToPlaySpecialGemGuide extends StatelessWidget {
  const HowToPlaySpecialGemGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        HowToPlaySpecialGemCard(
          kind: GemKind.bomb,
          gemSheetCol: 0,
          title: context.tr('howToPlaySpecialFlameTitle'),
          desc: context.tr('howToPlaySpecialFlameDesc'),
        ),
        HowToPlaySpecialGemCard(
          kind: GemKind.star,
          gemSheetCol: 3,
          title: context.tr('howToPlaySpecialStarTitle'),
          desc: context.tr('howToPlaySpecialStarDesc'),
        ),
        HowToPlaySpecialGemCard(
          kind: GemKind.hyper,
          gemSheetCol: 1,
          title: context.tr('howToPlaySpecialHyperTitle'),
          desc: context.tr('howToPlaySpecialHyperDesc'),
        ),
        HowToPlaySpecialGemCard(
          kind: GemKind.supernova,
          gemSheetCol: 5,
          title: context.tr('howToPlaySpecialSupernovaTitle'),
          desc: context.tr('howToPlaySpecialSupernovaDesc'),
        ),
      ],
    );
  }
}
