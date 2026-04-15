import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../widgets/ranking_list_popup.dart';

/// 타임 모드 랭킹 목록. 게임은 [MatchBoardGame.pauseForRankingPopup]으로 멈춘 상태여야 한다.
class RankingOverlay extends StatelessWidget {
  const RankingOverlay({super.key, required this.game});
  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return RankingListPopup(
      onClose: () {
        SoundManager.playSfx(AssetPaths.sfxBtnSnd);
        game.closeRankingPopup();
      },
    );
  }
}
