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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            _PauseBgmControls(sliderTheme: sliderTheme),
            Text(
              context.tr('sfx'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.tertiaryGold
                    .withValues(alpha: 0.95),
                fontSize: 20,
              ),
            ),
            _PauseSfxControls(sliderTheme: sliderTheme),
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

class _PauseBgmControls extends ConsumerWidget {
  const _PauseBgmControls({required this.sliderTheme});

  final SliderThemeData sliderTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(settingsProvider.select((s) => s.bgmVolume));
    final muted = ref.watch(settingsProvider.select((s) => s.bgmMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return SliderTheme(
      data: sliderTheme,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: muted ? 0.0 : volume,
              onChanged: muted ? null : notifier.setBgmVolumeDraft,
              onChangeEnd: muted ? null : (_) => notifier.commitBgmVolume(),
            ),
          ),
          Switch(
            value: muted,
            onChanged: notifier.setBgmMuted,
          ),
        ],
      ),
    );
  }
}

class _PauseSfxControls extends ConsumerWidget {
  const _PauseSfxControls({required this.sliderTheme});

  final SliderThemeData sliderTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(settingsProvider.select((s) => s.sfxVolume));
    final muted = ref.watch(settingsProvider.select((s) => s.sfxMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return SliderTheme(
      data: sliderTheme,
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: muted ? 0.0 : volume,
              onChanged: muted ? null : notifier.setSfxVolumeDraft,
              onChangeEnd: muted ? null : (_) => notifier.commitSfxVolume(),
            ),
          ),
          Switch(
            value: muted,
            onChanged: notifier.setSfxMuted,
          ),
        ],
      ),
    );
  }
}
