import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../game/match_board_logic.dart';
import 'special_gem_card.dart';

class HowToPlaySpecialGemGuide extends StatelessWidget {
  const HowToPlaySpecialGemGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HowToPlaySpecialGemCard(
          kind: GemKind.bomb,
          gemSheetCol: 0,
          title: context.tr('howToPlaySpecialFlameTitle'),
          desc: context.tr('howToPlaySpecialFlameDesc'),
        ),
        const SizedBox(height: 10),
        HowToPlaySpecialGemCard(
          kind: GemKind.star,
          gemSheetCol: 3,
          title: context.tr('howToPlaySpecialStarTitle'),
          desc: context.tr('howToPlaySpecialStarDesc'),
        ),
        const SizedBox(height: 10),
        HowToPlaySpecialGemCard(
          kind: GemKind.hyper,
          gemSheetCol: 1,
          title: context.tr('howToPlaySpecialHyperTitle'),
          desc: context.tr('howToPlaySpecialHyperDesc'),
        ),
        const SizedBox(height: 10),
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
