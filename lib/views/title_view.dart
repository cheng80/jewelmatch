import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart' show AppConfig, RoutePaths;
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../widgets/ranking_list_popup.dart';
import '../services/in_app_review_service.dart';

/// 타이틀 화면. 심플/타임 모드 선택 후 게임 진입, 설정.
class TitleView extends StatefulWidget {
  const TitleView({super.key});

  @override
  State<TitleView> createState() => _TitleViewState();
}

class _TitleViewState extends State<TitleView>
    with WidgetsBindingObserver {
  bool _ready = false;

  /// PackageInfo는 변하지 않으므로 앱 전역 캐싱.
  static PackageInfo? _cachedPackageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SoundManager.playBgm(AssetPaths.bgmMenu);
    _cachePackageInfo();
    _scheduleReady();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !kIsWeb) {
        InAppReviewService.maybeRequestReviewOnTitleIfEligible();
      }
    });
  }

  Future<void> _scheduleReady() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _cachePackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
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
        content: SingleChildScrollView(
          child: TextField(
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
    if (result == null || !context.mounted) return;
    final name = result.trim().isEmpty ? 'GUEST' : result.trim();
    GameSettings.playerName = name;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    context.go('${RoutePaths.game}?mode=timed');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(backgroundColor: Colors.transparent);
    }
    final content = _TitleContent(
      onShowNameDialog: () => _showNameDialog(context),
      packageInfo: _cachedPackageInfo,
    );

    return PhoneFrameScaffold(child: content);
  }
}

class _TitleContent extends StatelessWidget {
  const _TitleContent({required this.onShowNameDialog, this.packageInfo});

  final VoidCallback onShowNameDialog;
  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  context.go('${RoutePaths.game}?mode=simple');
                },
              ),
              const SizedBox(height: 16),
              _RoundButton(
                label: context.tr('modeTimed'),
                gradientColors: JewelCandyLuminaTheme.buttonRetryMagOr,
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  onShowNameDialog();
                },
              ),
              const SizedBox(height: 20),
              _RoundButton(
                label: context.tr('settings'),
                gradientColors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  context.push(RoutePaths.setting);
                },
              ),
              const SizedBox(height: 16),
              _RoundButton(
                label: context.tr('rankingTitle'),
                gradientColors: const [
                  JewelCandyLuminaTheme.tertiaryGold,
                  JewelCandyLuminaTheme.goldStrong,
                ],
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    builder: (ctx) => Material(
                      color: Colors.transparent,
                      child: PhoneFrame(
                        child: RankingListPopup(
                          onClose: () {
                            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  context.push(RoutePaths.sfxTest);
                },
                child: Text(
                  '효과음 단독 검증',
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.outlineBright
                        .withValues(alpha: 0.85),
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: JewelCandyLuminaTheme.outlineBright
                        .withValues(alpha: 0.45),
                  ),
                ),
              ),
              const Spacer(flex: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  packageInfo != null
                      ? 'Ver ${packageInfo!.version}+${packageInfo!.buildNumber}'
                      : 'Ver',
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.outlineBright
                        .withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          );
  }
}

/// 참조 이미지 스타일의 둥글고 큼지막한 버튼.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.gradientColors,
    required this.onPressed,
    this.width = 236,
    this.height = 62,
    this.fontSize = 28,
    this.letterSpacing = 5,
  });

  final String label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final double fontSize;
  final double letterSpacing;

  /// 게임 화면과 동일한 Lumina 그라데이션·테두리·그림자 둥근 버튼.
  @override
  Widget build(BuildContext context) {
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
              letterSpacing: letterSpacing,
              shadows: [
                Shadow(
                  color: base.withValues(alpha: 0.5),
                  blurRadius: 14,
                ),
                Shadow(
                  color: darkerColor.withValues(alpha: 0.85),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
                Shadow(
                  color: JewelCandyLuminaTheme.primaryDeep
                      .withValues(alpha: 0.45),
                  offset: const Offset(1.5, 1.5),
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
