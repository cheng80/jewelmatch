import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart';
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/starry_background.dart';
import '../services/in_app_review_service.dart';

/// 타이틀 화면. 심플/타임 모드 선택 후 게임 진입, 설정.
class TitleView extends StatefulWidget {
  const TitleView({super.key});

  @override
  State<TitleView> createState() => _TitleViewState();
}

class _TitleViewState extends State<TitleView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SoundManager.playBgm(AssetPaths.bgmMenu);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !kIsWeb) {
        InAppReviewService.maybeRequestReviewOnTitleIfEligible();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        SoundManager.pauseBgm(onlyIfCurrent: AssetPaths.bgmMenu);
        break;
      case AppLifecycleState.resumed:
        SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMenu);
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _showNameDialog(BuildContext context) async {
    final controller = TextEditingController(text: GameSettings.playerName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.97),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: JewelCandyLuminaTheme.borderPause,
            width: 2,
          ),
        ),
        title: Text(
          context.tr('enterName'),
          style: TextStyle(
            color: JewelCandyLuminaTheme.secondaryCyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 20,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: InputDecoration(
            hintText: 'GUEST',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: JewelCandyLuminaTheme.tertiaryGold),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                  color: JewelCandyLuminaTheme.secondaryCyan, width: 2),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(
              context.tr('startGame'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.tertiaryGold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final name = result.trim().isEmpty ? 'GUEST' : result.trim();
    GameSettings.playerName = name;
    if (!mounted) return;
    context.go('${RoutePaths.game}?mode=timed');
  }

  /// 우주 배경 위에 제목·버튼을 배치한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        Text(
                          context.tr('gameTitle'),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 8,
                          ),
                        ),
                        Text(
                          AppConfig.gameTitleSub,
                          style: TextStyle(
                            fontSize: 88,
                            fontWeight: FontWeight.bold,
                            color: JewelCandyLuminaTheme.goldStrong,
                            letterSpacing: 6,
                            shadows: [
                              Shadow(
                                color: JewelCandyLuminaTheme.primaryPink
                                    .withValues(alpha: 0.55),
                                blurRadius: 24,
                              ),
                              Shadow(
                                color: JewelCandyLuminaTheme.primaryDeep,
                                offset: const Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('gameSubtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            color: JewelCandyLuminaTheme.tertiaryGold
                                .withValues(alpha: 0.75),
                          ),
                        ),
                        const Spacer(flex: 3),
                        _RoundButton(
                          label: context.tr('modeSimple'),
                          gradientColors: JewelCandyLuminaTheme.buttonPrimaryPink,
                          onPressed: () {
                            SoundManager.unlockForWeb();
                            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                            context.go('${RoutePaths.game}?mode=simple');
                          },
                        ),
                        const SizedBox(height: 16),
                        _RoundButton(
                          label: context.tr('modeTimed'),
                          gradientColors: JewelCandyLuminaTheme.buttonRetryMagOr,
                          onPressed: () {
                            SoundManager.unlockForWeb();
                            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                            _showNameDialog(context);
                          },
                        ),
                        const SizedBox(height: 20),
                        _RoundButton(
                          label: context.tr('settings'),
                          gradientColors:
                              JewelCandyLuminaTheme.buttonShuffleCyanLime,
                          onPressed: () {
                            SoundManager.unlockForWeb();
                            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                            context.push(RoutePaths.setting);
                          },
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final v = snapshot.data;
                          final text = v != null
                              ? 'Ver ${v.version}+${v.buildNumber}'
                              : 'Ver';
                          return Center(
                            child: Text(
                              text,
                              style: TextStyle(
                                color: JewelCandyLuminaTheme.outlineBright
                                    .withValues(alpha: 0.65),
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 참조 이미지 스타일의 둥글고 큼지막한 버튼.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.gradientColors,
    required this.onPressed,
  });

  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;

  /// 게임 화면과 동일한 Lumina 그라데이션·테두리·그림자 둥근 버튼.
  @override
  Widget build(BuildContext context) {
    const width = 260.0;
    const height = 68.0;
    const fontSize = 32.0;
    final base = gradientColors.first;
    final darkerColor = HSLColor.fromColor(gradientColors.last)
        .withLightness(
          (HSLColor.fromColor(gradientColors.last).lightness - 0.14)
              .clamp(0.0, 1.0),
        )
        .toColor();

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: darkerColor.withValues(alpha: 0.65),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: darkerColor.withValues(alpha: 0.5),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
            BoxShadow(
              color: base.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
            BoxShadow(
              color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 6,
              shadows: [
                Shadow(
                  color: darkerColor.withValues(alpha: 0.85),
                  offset: const Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
