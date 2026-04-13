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
      borderColor: JewelCandyLuminaTheme.borderNoMoves,
      shadowColor: JewelCandyLuminaTheme.secondaryCyan,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('noMovesTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.primaryPink,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          LuminaGradientButton(
            width: 220,
            colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
            label: context.tr('shuffleBoard'),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.shuffleBoard();
            },
          ),
          const SizedBox(height: 12),
          LuminaOutlinedButton(
            width: 220,
            label: context.tr('newBoard'),
            borderColor: JewelCandyLuminaTheme.primaryPink,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.newBoard();
            },
          ),
        ],
      ),
    );
  }
}
