import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_config.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_overlay_card.dart';
import 'pause_menu_buttons.dart';

/// 일시 정지 메뉴. 액션만 남기고 사운드 설정은 설정 화면으로 분리한다.
class PauseMenuOverlay extends StatelessWidget {
  const PauseMenuOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return LuminaOverlayCard(
      maxCardWidth: 390,
      maxHeightFactor: 0.86,
      verticalMargin: 30,
      alignment: Alignment.center,
      horizontalPadding: 24,
      verticalPadding: 24,
      innerPadding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('paused'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.textTitleGold,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.88),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                ),
                Shadow(
                  color: JewelCandyLuminaTheme.goldStrong.withValues(
                    alpha: 0.42,
                  ),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const PauseMenuDivider(),
          const SizedBox(height: 24),
          PauseMenuActionButton(
            label: context.tr('continueGame'),
            icon: Icons.play_arrow_rounded,
            panelColor: const Color(0xFF1F8274),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.resumeGame();
            },
          ),
          const SizedBox(height: 16),
          PauseMenuActionButton(
            label: context.tr('retry'),
            icon: Icons.restart_alt_rounded,
            panelColor: const Color(0xFF68468C),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.restartRound();
            },
          ),
          const SizedBox(height: 16),
          PauseMenuActionButton(
            label: context.tr('exit'),
            icon: Icons.logout_rounded,
            panelColor: const Color(0xFF96522B),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              context.go(RoutePaths.title);
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PauseMenuSettingsButton(
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  context.push(RoutePaths.setting);
                },
              ),
              const SizedBox(width: 16),
              PauseMenuStatsButton(
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  game.showGameStats();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
