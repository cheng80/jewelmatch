import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/phone_frame_scaffold.dart';

/// **모바일 브라우저(Safari·Chrome 등)에서 효과음이 정상 단독 재생되는지** 검증하기 위한 페이지.
///
/// 게임 내 연속 재생·다른 음과 겹침 없이, 항목마다 한 번씩만 재생해 원인(파일·코덱·플레이어)을 좁힌다.
/// 배포용 기능이 아니라 디버그·QA 용도다.
class SfxTestView extends StatelessWidget {
  const SfxTestView({super.key});

  static const List<({String label, String path})> _sfxEntries = [
    (label: 'BigMatch', path: AssetPaths.sfxBigMatch),
    (label: 'BtnSnd', path: AssetPaths.sfxBtnSnd),
    (label: 'Clear', path: AssetPaths.sfxClear),
    (label: 'Collect', path: AssetPaths.sfxCollect),
    (label: 'ComboHit', path: AssetPaths.sfxComboHit),
    (label: 'Fail', path: AssetPaths.sfxFail),
    (label: 'SpecialGem', path: AssetPaths.sfxSpecialGem),
    (label: 'Start', path: AssetPaths.sfxStart),
    (label: 'TimeTic', path: AssetPaths.sfxTimeTic),
    (label: 'TimeUp', path: AssetPaths.sfxTimeUp),
  ];

  @override
  Widget build(BuildContext context) {
    return PhoneFrameScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: JewelCandyLuminaTheme.surfaceContainer
              .withValues(alpha: 0.92),
          foregroundColor: Colors.white,
          title: const Text('효과음 단독 재생 검증'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  '모바일 브라우저에서 각 효과음이 혼자만 재생되는지 확인합니다. '
                  '재생 버튼을 누른 뒤 소리가 나는지, 특정 파일만 묵음인지 비교하세요.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (var i = 0; i < _sfxEntries.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _SfxTile(entry: _sfxEntries[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SfxTile extends StatelessWidget {
  const _SfxTile({required this.entry});

  final ({String label, String path}) entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        entry.label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        entry.path,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 12,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_arrow, color: Colors.white),
        tooltip: '이 효과음만 재생',
        onPressed: () {
          SoundManager.playSfx(entry.path);
        },
      ),
    );
  }
}
