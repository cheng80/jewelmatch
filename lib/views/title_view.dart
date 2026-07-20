import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_config.dart' show RoutePaths;
import '../game/jewel_game_mode.dart';
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../widgets/ranking_list_popup.dart';
import '../services/in_app_review_service.dart';
import 'overlays/game_loading_overlay.dart';
import 'overlays/how_to_play_overlay.dart';
import 'title/title_icon_button.dart';
import 'title/player_name_dialog.dart';
import 'title/title_round_button.dart';
import 'title/title_version_footer.dart';

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
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Future.wait([
      for (final path in _titleAssetPaths)
        precacheImage(AssetImage(path), context),
    ]);
    if (!mounted) return;
    setState(() => _ready = true);
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

const List<String> _titleAssetPaths = [
  AssetPaths.stoneMatchTitle,
  AssetPaths.modeButtonPanelBase,
  AssetPaths.modeButtonFrameFront,
  AssetPaths.modeIconSimple,
  AssetPaths.modeIconProgression,
  AssetPaths.modeIconTimed,
  AssetPaths.modeIconRanking,
  AssetPaths.modeIconSettings,
  'assets/images/${AssetPaths.obsidianIconButtonFrame}',
  'assets/images/${AssetPaths.obsidianTutorialIcon}',
];

class _TitleContent extends StatelessWidget {
  const _TitleContent({required this.onShowNameDialog, this.packageInfo});

  final ValueChanged<String> onShowNameDialog;
  final PackageInfo? packageInfo;

  void _showHowToPlayDialog(BuildContext context) {
    showDialog<void>(
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
        Image.asset(
          AssetPaths.stoneMatchTitle,
          width: 338,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
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
                  iconAssetPath: AssetPaths.modeIconSettings,
                  semanticLabel: context.tr('settings'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    context.push(RoutePaths.setting);
                  },
                ),
                const SizedBox(width: 8),
                TitleIconButton(
                  iconAssetPath: AssetPaths.obsidianTutorialIcon,
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
        TitleRoundButton(
          label: context.tr('modeSimple'),
          panelColor: TitleButtonPalette.teal,
          iconAssetPath: AssetPaths.modeIconSimple,
          onPressed: () {
            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
            context.go(_gameRoute('simple'));
          },
        ),
        const SizedBox(height: 6),
        TitleRoundButton(
          label: context.tr('modeProgression'),
          panelColor: TitleButtonPalette.purple,
          iconAssetPath: AssetPaths.modeIconProgression,
          onPressed: () {
            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
            onShowNameDialog('progression');
          },
        ),
        const SizedBox(height: 6),
        TitleRoundButton(
          label: context.tr('modeTimed'),
          panelColor: TitleButtonPalette.brown,
          iconAssetPath: AssetPaths.modeIconTimed,
          onPressed: () {
            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
            onShowNameDialog('timed');
          },
        ),
        const SizedBox(height: 6),
        TitleRoundButton(
          label: context.tr('rankingTitle'),
          panelColor: TitleButtonPalette.charcoal,
          iconAssetPath: AssetPaths.modeIconRanking,
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
        const Spacer(flex: 1),
        TitleVersionFooter(packageInfo: packageInfo),
        const Spacer(flex: 2),
      ],
    );
  }
}
