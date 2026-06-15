import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';
import 'how_to_play/gem_examples.dart';
import 'how_to_play/special_creation_guide.dart';
import 'how_to_play/special_gem_guide.dart';
import 'how_to_play/text_styles.dart';

/// "?" 버튼으로 열리는 게임 설명 오버레이.
class HowToPlayOverlay extends StatelessWidget {
  const HowToPlayOverlay({super.key, this.game, this.onClose})
    : assert(game != null || onClose != null);

  final MatchBoardGame? game;
  final VoidCallback? onClose;

  void _close() {
    final closeHandler = onClose;
    if (closeHandler != null) {
      closeHandler();
      return;
    }
    game?.closeHowToPlay();
  }

  @override
  Widget build(BuildContext context) {
    return LuminaOverlayCard(
      maxCardWidth: 560,
      maxHeightFactor: 0.86,
      verticalMargin: 40,
      alignment: Alignment.topCenter,
      horizontalPadding: 20,
      verticalPadding: 20,
      innerPadding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('howToPlayTitle'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.textTitleGold,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 18),
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
            padding: const EdgeInsets.fromLTRB(30, 18, 30, 4),
            child: LuminaGradientButton(
              width: 260,
              colors: JewelCandyLuminaTheme.buttonPrimaryPink,
              label: context.tr('continueGame'),
              onPressed: () {
                SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                _close();
              },
            ),
          ),
        ],
      ),
    );
  }
}
