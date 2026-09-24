import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart' show RoutePaths;
import '../game/daily_seed.dart';
import '../game/jewel_game_mode.dart';
import '../resources/asset_paths.dart';
import '../resources/texture_atlas.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../widgets/overlay_motion.dart';
import '../widgets/ranking_list_popup.dart';
import '../services/in_app_review_service.dart';
import 'overlays/game_loading_overlay.dart';
import 'overlays/how_to_play_overlay.dart';
import 'title/title_icon_button.dart';
import 'title/player_name_dialog.dart';
import 'title/title_round_button.dart';
import 'title/title_version_footer.dart';
import '../utils/web_loading.dart';

String _gameRoute(String mode) {
  final params = <String>[
    if (Uri.base.queryParameters['qaVfx'] == '1') 'qaVfx=1',
    if (Uri.base.queryParameters['qaLevelUp'] == '1') 'qaLevelUp=1',
    if (Uri.base.queryParameters['qaNoMoves'] == '1') 'qaNoMoves=1',
    if (Uri.base.queryParameters['qaPerf'] == '1') 'qaPerf=1',
  ];
  final qa = params.isEmpty ? '' : '&${params.join('&')}';
  return '${RoutePaths.game}?mode=$mode$qa';
}

/// 타이틀 화면. 심플/타임 모드 선택 후 게임 진입, 설정.
class TitleView extends StatefulWidget {
  const TitleView({super.key});

  @override
  State<TitleView> createState() => _TitleViewState();
}

class _TitleViewState extends State<TitleView> with WidgetsBindingObserver {
  bool _ready = false;
  bool _prepareStarted = false;

  /// PackageInfo는 변하지 않으므로 앱 전역 캐싱.
  static PackageInfo? _cachedPackageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SoundManager.playBgm(AssetPaths.bgmMenu);
    _cachePackageInfo();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !kIsWeb) {
        InAppReviewService.maybeRequestReviewOnTitleIfEligible();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepareStarted) return;
    _prepareStarted = true;
    unawaited(_prepareTitleSurface());
  }

  Future<void> _prepareTitleSurface() async {
    WebLoadingScreen.hold();
    _webLoadingHeld = WebLoadingScreen.replacesFlutterOverlay;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return _releaseWebLoading();
    await Future.wait([
      precacheImage(const AssetImage(AssetPaths.stoneMatchTitle), context),
      TextureAtlas.precacheUi(),
    ]);
    if (!mounted) return _releaseWebLoading();
    setState(() => _ready = true);
    // 타이틀이 한 프레임 그려진 뒤 HTML 로딩 화면을 걷어 빈 화면이 비치지 않게 한다.
    await WidgetsBinding.instance.endOfFrame;
    _releaseWebLoading();
  }

  bool _webLoadingHeld = false;

  void _releaseWebLoading() {
    if (!_webLoadingHeld) return;
    _webLoadingHeld = false;
    WebLoadingScreen.release();
  }

  Future<void> _cachePackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    if (!mounted) return;
    if (_ready) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _releaseWebLoading();
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

  Future<void> _showNameDialog(BuildContext context, String mode) async {
    final name = await showPlayerNameDialog(context);
    if (name == null || !context.mounted) return;
    GameSettings.playerName = name;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    context.go(_gameRoute(mode));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const PhoneFrameScaffold(
        child: GameLoadingOverlay(gameMode: JewelGameMode.simple),
      );
    }
    final content = _TitleContent(
      onShowNameDialog: (mode) => _showNameDialog(context, mode),
      packageInfo: _cachedPackageInfo,
    );

    return PhoneFrameScaffold(child: content);
  }
}

class _TitleContent extends StatelessWidget {
  const _TitleContent({required this.onShowNameDialog, this.packageInfo});

  final ValueChanged<String> onShowNameDialog;
  final PackageInfo? packageInfo;

  void _showHowToPlayDialog(BuildContext context) {
    showMotionDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: PhoneFrame(
          child: HowToPlayOverlay(
            onClose: () {
              Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        StaggerReveal(
          index: 0,
          child: Image.asset(
            AssetPaths.stoneMatchTitle,
            width: 338,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 338,
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TitleIconButton(
                  iconFrame: UiFrames.modeIconSettings,
                  semanticLabel: context.tr('settings'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    context.push(RoutePaths.setting);
                  },
                ),
                const SizedBox(width: 8),
                TitleIconButton(
                  iconFrame: UiFrames.rankingCrownIcon,
                  semanticLabel: context.tr('recordsTitle'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    context.push(RoutePaths.records);
                  },
                ),
                const SizedBox(width: 8),
                TitleIconButton(
                  iconFrame: UiFrames.tutorialIcon,
                  semanticLabel: context.tr('howToPlayTitle'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    _showHowToPlayDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 1),
        StaggerReveal(
          index: 1,
          child: TitleRoundButton(
            label: context.tr('modeSimple'),
            panelColor: TitleButtonPalette.teal,
            iconFrame: UiFrames.modeIconSimple,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              context.go(_gameRoute('simple'));
            },
          ),
        ),
        const SizedBox(height: 6),
        StaggerReveal(
          index: 2,
          child: TitleRoundButton(
            label: context.tr('modeProgression'),
            panelColor: TitleButtonPalette.purple,
            iconFrame: UiFrames.modeIconProgression,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              onShowNameDialog('progression');
            },
          ),
        ),
        const SizedBox(height: 6),
        StaggerReveal(
          index: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TitleRoundButton(
                label: context.tr('modeTimed'),
                panelColor: TitleButtonPalette.brown,
                iconFrame: UiFrames.modeIconTimed,
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  onShowNameDialog('timed');
                },
              ),
              const SizedBox(height: 2),
              const _DailyBoardCaption(),
            ],
          ),
        ),
        const SizedBox(height: 6),
        StaggerReveal(
          index: 4,
          child: TitleRoundButton(
            label: context.tr('rankingTitle'),
            panelColor: TitleButtonPalette.charcoal,
            iconFrame: UiFrames.modeIconRanking,
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              showMotionDialog<void>(
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
        ),
        const Spacer(flex: 1),
        TitleVersionFooter(packageInfo: packageInfo),
        const Spacer(flex: 2),
      ],
    );
  }
}

/// 타임 모드는 모두가 같은 날 같은 보드를 받는다. 날짜는 KST 기준이다.
// ponytail: 타이틀을 다시 그릴 때만 날짜가 바뀐다. 자정에 켜 둔 화면은 다음 빌드에서 갱신.
class _DailyBoardCaption extends StatelessWidget {
  const _DailyBoardCaption();

  @override
  Widget build(BuildContext context) {
    final key = DailySeed.keyFor(DateTime.now());
    return Text(
      context.tr(
        'dailyBoardToday',
        namedArgs: {
          'month': int.parse(key.substring(5, 7)).toString(),
          'day': int.parse(key.substring(8, 10)).toString(),
        },
      ),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.82),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
