import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/obsidian_frame.dart';
import '../widgets/phone_frame_scaffold.dart';
import 'settings/settings_sections.dart';

/// 설정 화면. SettingsNotifier를 통해 볼륨·음소거·화면 꺼짐 방지를 관리한다.
class SettingView extends StatelessWidget {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const outerPadding = EdgeInsets.fromLTRB(16, 18, 16, 24);
            final frameHeight =
                constraints.maxHeight - outerPadding.top - outerPadding.bottom;

            return Padding(
              padding: outerPadding,
              child: SizedBox(
                height: frameHeight.clamp(0.0, constraints.maxHeight),
                child: ObsidianFrame(
                  padding: const EdgeInsets.fromLTRB(34, 56, 34, 58),
                  backgroundColor: JewelCandyLuminaTheme.surfaceContainer
                      .withValues(alpha: 0.94),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: JewelCandyLuminaTheme.borderPause.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 56),
                      child: Column(
                        spacing: 8,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsSectionTitle(
                            icon: Icons.phone_android,
                            title: context.tr('sectionScreen'),
                          ),
                          const KeepScreenOnTile(),
                          const Divider(height: 1),
                          SettingsSectionTitle(
                            icon: Icons.volume_up,
                            title: context.tr('sectionSound'),
                          ),
                          const BgmVolumeTile(),
                          const BgmMuteTile(),
                          const SfxVolumeTile(),
                          const SfxMuteTile(),
                          if (!kIsWeb) ...[
                            const Divider(height: 1),
                            SettingsSectionTitle(
                              icon: Icons.star,
                              title: context.tr('rateApp'),
                            ),
                            const RateAppTile(),
                          ],
                          const Divider(height: 1),
                          SettingsSectionTitle(
                            icon: Icons.public,
                            title: context.tr('language'),
                          ),
                          const LanguageSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    return PhoneFrameScaffold(child: scaffold);
  }
}
