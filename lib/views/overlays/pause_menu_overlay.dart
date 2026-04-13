import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_config.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../vm/settings_notifier.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

/// 일시 정지 메뉴. 볼륨/음소거를 SettingsNotifier로 관리한다.
class PauseMenuOverlay extends ConsumerWidget {
  const PauseMenuOverlay({super.key, required this.game});
  final MatchBoardGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final sliderTheme = SliderThemeData(
      activeTrackColor: JewelCandyLuminaTheme.secondaryCyan,
      inactiveTrackColor: Colors.white24,
      thumbColor: JewelCandyLuminaTheme.primaryPink,
      overlayColor: JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.2),
    );
    final switchTheme = SwitchThemeData(
      thumbColor:
          WidgetStatePropertyAll(JewelCandyLuminaTheme.secondaryCyan),
      trackColor: WidgetStatePropertyAll(
        JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.45),
      ),
    );

    return LuminaOverlayCard(
      scrollable: true,
      child: Theme(
        data: Theme.of(context).copyWith(switchTheme: switchTheme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('paused'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.secondaryCyan,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('bgm'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.tertiaryGold
                    .withValues(alpha: 0.95),
                fontSize: 20,
              ),
            ),
            SliderTheme(
              data: sliderTheme,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: s.bgmMuted ? 0.0 : s.bgmVolume,
                      onChanged: s.bgmMuted
                          ? null
                          : (v) => notifier.setBgmVolume(v),
                    ),
                  ),
                  Switch(
                    value: s.bgmMuted,
                    onChanged: (v) => notifier.setBgmMuted(v),
                  ),
                ],
              ),
            ),
            Text(
              context.tr('sfx'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.tertiaryGold
                    .withValues(alpha: 0.95),
                fontSize: 20,
              ),
            ),
            SliderTheme(
              data: sliderTheme,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: s.sfxMuted ? 0.0 : s.sfxVolume,
                      onChanged: s.sfxMuted
                          ? null
                          : (v) => notifier.setSfxVolume(v),
                    ),
                  ),
                  Switch(
                    value: s.sfxMuted,
                    onChanged: (v) => notifier.setSfxMuted(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LuminaGradientButton(
              colors: JewelCandyLuminaTheme.buttonPrimaryPink,
              label: context.tr('continueGame'),
              onPressed: () {
                SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                game.resumeGame();
              },
            ),
            const SizedBox(height: 12),
            LuminaOutlinedButton(
              label: context.tr('exit'),
              onPressed: () {
                SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                context.go(RoutePaths.title);
              },
            ),
          ],
        ),
      ),
    );
  }
}
