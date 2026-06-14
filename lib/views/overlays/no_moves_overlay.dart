import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

/// 교환 가능한 보석이 없을 때 셔플 / 새 판 선택.
class NoMovesOverlay extends StatelessWidget {
  const NoMovesOverlay({super.key, required this.game});
  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return LuminaOverlayCard(
      borderColor: JewelCandyLuminaTheme.goldStrong,
      shadowColor: JewelCandyLuminaTheme.goldStrong,
      maxCardWidth: 360,
      maxHeightFactor: 0.72,
      horizontalPadding: 28,
      verticalPadding: 24,
      innerPadding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      verticalMargin: 86,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('noMovesTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.textTitleGold,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.12,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.85),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('noMovesDesc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.textParchment.withValues(
                alpha: 0.86,
              ),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          LuminaGradientButton(
            width: 246,
            height: 54,
            colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
            label: context.tr('shuffleBoard'),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.shuffleBoard();
            },
          ),
          const SizedBox(height: 14),
          LuminaOutlinedButton(
            width: 246,
            height: 54,
            label: context.tr('newBoard'),
            borderColor: JewelCandyLuminaTheme.outlineBright,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.newBoard();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
