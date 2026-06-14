import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/in_app_review_service.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../vm/settings_notifier.dart';

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: JewelCandyLuminaTheme.outlineBright.withValues(
                alpha: 0.85,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeepScreenOnTile extends ConsumerWidget {
  const KeepScreenOnTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.keepScreenOn));
    final notifier = ref.read(settingsProvider.notifier);
    return _MuteSwitch(
      label: context.tr('keepScreenOn'),
      value: value,
      onChanged: notifier.setKeepScreenOn,
    );
  }
}

class BgmVolumeTile extends ConsumerWidget {
  const BgmVolumeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.bgmVolume));
    final enabled = !ref.watch(settingsProvider.select((s) => s.bgmMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return _VolumeSlider(
      label: context.tr('bgmVolume'),
      value: value,
      enabled: enabled,
      onChanged: notifier.setBgmVolumeDraft,
      onChangeEnd: (_) => notifier.commitBgmVolume(),
    );
  }
}

class BgmMuteTile extends ConsumerWidget {
  const BgmMuteTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.bgmMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return _MuteSwitch(
      label: context.tr('bgm'),
      value: value,
      onChanged: notifier.setBgmMuted,
    );
  }
}

class SfxVolumeTile extends ConsumerWidget {
  const SfxVolumeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.sfxVolume));
    final enabled = !ref.watch(settingsProvider.select((s) => s.sfxMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return _VolumeSlider(
      label: context.tr('sfxVolume'),
      value: value,
      enabled: enabled,
      onChanged: notifier.setSfxVolumeDraft,
      onChangeEnd: (_) => notifier.commitSfxVolume(),
    );
  }
}

class SfxMuteTile extends ConsumerWidget {
  const SfxMuteTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.sfxMuted));
    final notifier = ref.read(settingsProvider.notifier);
    return _MuteSwitch(
      label: context.tr('sfx'),
      value: value,
      onChanged: notifier.setSfxMuted,
    );
  }
}

class RateAppTile extends StatelessWidget {
  const RateAppTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.star_border,
        color: JewelCandyLuminaTheme.goldStrong,
      ),
      title: Text(context.tr('rateApp')),
      onTap: () async {
        final result = await InAppReviewService.openStoreListing();
        if (!context.mounted) return;
        if (result == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('rateAppAfterRelease'))),
          );
        }
      },
    );
  }
}

class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  static const _options = [
    (locale: Locale('ko'), labelKey: 'langKo'),
    (locale: Locale('en'), labelKey: 'langEn'),
    (locale: Locale('ja'), labelKey: 'langJa'),
    (locale: Locale('zh', 'CN'), labelKey: 'langZhCN'),
    (locale: Locale('zh', 'TW'), labelKey: 'langZhTW'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in _options)
          ListTile(
            title: Text(context.tr(option.labelKey)),
            trailing: context.locale == option.locale
                ? const Icon(
                    Icons.check,
                    color: JewelCandyLuminaTheme.borderNoMoves,
                  )
                : null,
            onTap: () => context.setLocale(option.locale),
          ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: SliderTheme(
        data: JewelCandyLuminaTheme.obsidianSliderTheme(
          SliderTheme.of(context),
        ),
        child: Slider(
          value: value,
          onChanged: enabled ? onChanged : null,
          onChangeEnd: enabled ? onChangeEnd : null,
        ),
      ),
    );
  }
}

class _MuteSwitch extends StatelessWidget {
  const _MuteSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(
        value ? Icons.volume_off : Icons.volume_up,
        color: value ? Colors.grey : null,
      ),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
