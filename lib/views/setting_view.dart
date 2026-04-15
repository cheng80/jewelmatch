import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../services/in_app_review_service.dart';
import '../vm/settings_notifier.dart';

/// 설정 화면. SettingsNotifier를 통해 볼륨·음소거·화면 꺼짐 방지를 관리한다.
class SettingView extends ConsumerWidget {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings')),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(
                icon: Icons.phone_android,
                title: context.tr('sectionScreen'),
              ),
              const _KeepScreenOnTile(),
              const Divider(height: 1),
              _SectionTitle(
                icon: Icons.volume_up,
                title: context.tr('sectionSound'),
              ),
              const _BgmVolumeTile(),
              const _BgmMuteTile(),
              const _SfxVolumeTile(),
              const _SfxMuteTile(),
              if (!kIsWeb) ...[
                const Divider(height: 1),
                _SectionTitle(icon: Icons.star, title: context.tr('rateApp')),
                ListTile(
                  leading: const Icon(Icons.star_border, color: Colors.amber),
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
                ),
              ],
              const Divider(height: 1),
              _SectionTitle(icon: Icons.public, title: context.tr('language')),
              ListTile(
                title: Text(context.tr('langKo')),
                trailing: context.locale == const Locale('ko')
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => context.setLocale(const Locale('ko')),
              ),
              ListTile(
                title: Text(context.tr('langEn')),
                trailing: context.locale == const Locale('en')
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => context.setLocale(const Locale('en')),
              ),
              ListTile(
                title: Text(context.tr('langJa')),
                trailing: context.locale == const Locale('ja')
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => context.setLocale(const Locale('ja')),
              ),
              ListTile(
                title: Text(context.tr('langZhCN')),
                trailing: context.locale == const Locale('zh', 'CN')
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => context.setLocale(const Locale('zh', 'CN')),
              ),
              ListTile(
                title: Text(context.tr('langZhTW')),
                trailing: context.locale == const Locale('zh', 'TW')
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => context.setLocale(const Locale('zh', 'TW')),
              ),
            ],
          ),
        ),
      ),
    );

    return PhoneFrameScaffold(child: scaffold);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.icon});
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
              color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
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
        data: SliderTheme.of(context).copyWith(
          trackHeight: 12,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          trackShape: const RoundedRectSliderTrackShape(),
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

class _KeepScreenOnTile extends ConsumerWidget {
  const _KeepScreenOnTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value =
        ref.watch(settingsProvider.select((s) => s.keepScreenOn));
    final notifier = ref.read(settingsProvider.notifier);
    return _MuteSwitch(
      label: context.tr('keepScreenOn'),
      value: value,
      onChanged: notifier.setKeepScreenOn,
    );
  }
}

class _BgmVolumeTile extends ConsumerWidget {
  const _BgmVolumeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.bgmVolume));
    final enabled =
        !ref.watch(settingsProvider.select((s) => s.bgmMuted));
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

class _BgmMuteTile extends ConsumerWidget {
  const _BgmMuteTile();

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

class _SfxVolumeTile extends ConsumerWidget {
  const _SfxVolumeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.sfxVolume));
    final enabled =
        !ref.watch(settingsProvider.select((s) => s.sfxMuted));
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

class _SfxMuteTile extends ConsumerWidget {
  const _SfxMuteTile();

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
