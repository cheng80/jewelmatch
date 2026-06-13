import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import 'how_to_play/gem_examples.dart';
import 'how_to_play/special_creation_guide.dart';
import 'how_to_play/special_gem_guide.dart';
import 'how_to_play/text_styles.dart';

/// "?" 버튼으로 열리는 게임 설명 오버레이.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({super.key, required this.game});
  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: JewelCandyLuminaTheme.surfaceContainer.withValues(
              alpha: 0.97,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: JewelCandyLuminaTheme.secondaryCyan,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.4),
                blurRadius: 22,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Text(
                  context.tr('howToPlayTitle'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.secondaryCyan,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HowToPlaySectionTitle(context.tr('howToPlayGoal')),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlayGoalDesc')),
                      const SizedBox(height: 16),
                      HowToPlaySectionTitle(context.tr('howToPlayMatch')),
                      const SizedBox(height: 8),
                      const HowToPlayMatchExample([0, 0, 0, 6, 3]),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlayMatchDesc')),
                      const SizedBox(height: 16),
                      HowToPlaySectionTitle(context.tr('howToPlaySwap')),
                      const SizedBox(height: 8),
                      const HowToPlaySwapExample(),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlaySwapDesc')),
                      const SizedBox(height: 16),
                      HowToPlaySectionTitle(context.tr('howToPlayCombo')),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlayComboDesc')),
                      const SizedBox(height: 16),
                      HowToPlaySectionTitle(context.tr('howToPlaySpecial')),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlaySpecialDesc')),
                      const SizedBox(height: 12),
                      const HowToPlaySpecialGemGuide(),
                      const SizedBox(height: 14),
                      HowToPlaySectionTitle(
                        context.tr('howToPlaySpecialMakeTitle'),
                      ),
                      const SizedBox(height: 8),
                      const HowToPlaySpecialCreationGuide(),
                      const SizedBox(height: 16),
                      HowToPlaySectionTitle(context.tr('howToPlayHint')),
                      const SizedBox(height: 6),
                      HowToPlayBodyText(context.tr('howToPlayHintDesc')),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: LuminaGradientButton(
                  colors: JewelCandyLuminaTheme.buttonPrimaryPink,
                  label: context.tr('continueGame'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.closeHowToPlay();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
