import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ads/ad_reward_policy.dart';
import '../ads/ad_service.dart';
import '../ads/ad_service_factory.dart';
import '../ads/fake_ad_service.dart';
import '../app_config.dart';
import '../game/jewel_game_mode.dart';
import '../game/match_board_game.dart';
import '../utils/sfx_play_log.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../widgets/sfx_play_log_panel.dart';
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import 'overlays/time_up_overlay.dart';
import 'overlays/pause_menu_overlay.dart';
import 'overlays/no_moves_overlay.dart';
import 'overlays/how_to_play_overlay.dart';
import 'overlays/level_celebration_overlay.dart';
import 'overlays/level_up_overlay.dart';
import 'overlays/game_loading_overlay.dart';
import 'overlays/game_stats_overlay.dart';
import 'overlays/ranking_overlay.dart';
import 'overlays/stage_inventory_overlay.dart';

/// 매치-3 게임 화면. [gameMode]는 타이틀에서 Simple / Timed 로 전달한다.
class GameView extends StatefulWidget {
  const GameView({
    super.key,
    this.gameMode = JewelGameMode.simple,
    this.qaVfxEnabled = false,
    this.qaLevelUpEnabled = false,
    this.qaNoMovesEnabled = false,
    this.adService,
    this.adRewardPolicy,
  });

  final JewelGameMode gameMode;
  final bool qaVfxEnabled;
  final bool qaLevelUpEnabled;
  final bool qaNoMovesEnabled;
  final AdService? adService;
  final AdRewardPolicy? adRewardPolicy;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  static const Duration _minLoadingOverlay = Duration(milliseconds: 350);
  static const Duration _loadingFadeDuration = Duration(milliseconds: 220);

  /// Flame GameWidget — initState가 아닌 didChangeDependencies에서 1회만 생성.
  /// build()에서 매번 생성하면 rebuild마다 엔진이 재초기화된다.
  Widget? _gameWidget;
  MatchBoardGame? _game;
  bool _gameMounted = false;
  bool _loadingVisible = true;
  bool _qaVfxPreviewScheduled = false;
  bool _qaLevelUpPreviewScheduled = false;
  bool _qaNoMovesPreviewScheduled = false;
  late final AdService _adService;
  late final AdRewardPolicy _adRewardPolicy;
  late final bool _ownsAdService;
  bool _bannerSupported = false;
  int _bannerBlockCount = 0;

  bool get _qaVfxEnabled => kIsWeb && widget.qaVfxEnabled;
  bool get _qaLevelUpEnabled => kIsWeb && widget.qaLevelUpEnabled;
  bool get _qaNoMovesEnabled => kIsWeb && widget.qaNoMovesEnabled;

  @override
  void initState() {
    super.initState();
    _ownsAdService = widget.adService == null;
    _adService = widget.adService ?? createAdService();
    _adRewardPolicy = widget.adRewardPolicy ?? AdRewardPolicy();
    if (widget.gameMode == JewelGameMode.progression) {
      unawaited(_adService.preloadRewarded());
    }
    if (widget.gameMode == JewelGameMode.simple) {
      unawaited(_initializeBanner());
    }
    if (AppConfig.debugLog && widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = true;
      SfxPlayLog.clear();
    }
    SoundManager.playBgm(AssetPaths.bgmMain);
    _scheduleGameMount();
  }

  @override
  void dispose() {
    _adService.hideBanner();
    if (_ownsAdService) _adService.dispose();
    if (AppConfig.debugLog && widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = false;
    }
    super.dispose();
  }

  Future<void> _initializeBanner() async {
    final supported = await _adService.initializeBanner();
    if (!mounted) return;
    setState(() => _bannerSupported = supported);
    _syncBanner();
  }

  void _setBannerBlocked(bool blocked) {
    _bannerBlockCount += blocked ? 1 : -1;
    if (_bannerBlockCount < 0) _bannerBlockCount = 0;
    _syncBanner();
  }

  void _syncBanner() {
    final shouldShow =
        mounted &&
        _bannerSupported &&
        !_loadingVisible &&
        _bannerBlockCount == 0;
    if (shouldShow) {
      _adService.showBanner();
    } else {
      _adService.hideBanner();
    }
  }

  Widget _blocksBanner(Widget child) =>
      _BannerBlocker(onChanged: _setBannerBlocked, child: child);

  /// 페이드 전환과 Flame 초기화가 같은 프레임에 겹치지 않도록
  /// 첫 보드 프레임까지 준비한 뒤 노출한다. 이후 보석 인트로는 화면에서 재생한다.
  Future<void> _scheduleGameMount() async {
    final startedAt = DateTime.now();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _gameMounted = true);
    final game = await _waitForGame();
    if (game != null) {
      await Future.wait([game.loaded, SoundManager.preload()]);
      await game.firstBoardFrameRendered.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    if (!mounted) return;

    final remain = _minLoadingOverlay - DateTime.now().difference(startedAt);
    if (remain > Duration.zero) {
      await Future<void>.delayed(remain);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _loadingVisible = false);
    _syncBanner();
    await Future<void>.delayed(_loadingFadeDuration);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _game?.releaseRoundStartIntro();
    if (_qaVfxEnabled && !_qaVfxPreviewScheduled) {
      _qaVfxPreviewScheduled = true;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _game?.debugTriggerSpecialEffects();
        }),
      );
    }
    if (_qaLevelUpEnabled && !_qaLevelUpPreviewScheduled) {
      _qaLevelUpPreviewScheduled = true;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) _game?.debugTriggerProgressionLevelUp();
        }),
      );
    }
    if (_qaNoMovesEnabled && !_qaNoMovesPreviewScheduled) {
      _qaNoMovesPreviewScheduled = true;
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (mounted) _game?.debugShowNoMovesOverlay();
        }),
      );
    }
  }

  Future<MatchBoardGame?> _waitForGame() async {
    while (mounted) {
      final game = _game;
      if (game != null) return game;
      await WidgetsBinding.instance.endOfFrame;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gameWidget != null) return;
    final mediaPadding = MediaQuery.of(context).padding;
    _gameWidget = GameWidget<MatchBoardGame>.controlled(
      gameFactory: () {
        final g = MatchBoardGame(
          safeAreaPadding: kIsWeb ? EdgeInsets.zero : mediaPadding,
          gameMode: widget.gameMode,
        );
        g.setLocaleStrings({
          'score': context.tr('score'),
          'targetScore': context.tr('targetScore'),
          'bestScore': context.tr('bestScore'),
          'combo': context.tr('combo'),
          'timeLeft': context.tr('timeLeft'),
          'unlimitedMode': context.tr('unlimitedMode'),
          'levelLabel': context.tr('levelLabel'),
          'xpLabel': context.tr('xpLabel'),
          'maxComboLabel': context.tr('maxComboLabel'),
        });
        _game = g;
        return g;
      },
      overlayBuilderMap: {
        'IntroBlock': (_, MatchBoardGame g) => const AbsorbPointer(
          child: ColoredBox(
            color: Colors.transparent,
            child: SizedBox.expand(),
          ),
        ),
        'PauseMenu': (_, MatchBoardGame g) =>
            _blocksBanner(PauseMenuOverlay(game: g)),
        'NoMoves': (_, MatchBoardGame g) =>
            _blocksBanner(NoMovesOverlay(game: g)),
        'LevelCelebration': (_, MatchBoardGame g) =>
            LevelCelebrationOverlay(game: g),
        'LevelUp': (_, MatchBoardGame g) => LevelUpOverlay(game: g),
        'StageInventory': (_, MatchBoardGame g) => _blocksBanner(
          StageInventoryOverlay(
            game: g,
            adService: _adService,
            adRewardPolicy: _adRewardPolicy,
          ),
        ),
        'TimeUp': (_, MatchBoardGame g) => _blocksBanner(
          TimeUpOverlay(
            game: g,
            adService: _adService,
            adRewardPolicy: _adRewardPolicy,
          ),
        ),
        'GameStats': (_, MatchBoardGame g) =>
            _blocksBanner(GameStatsOverlay(game: g)),
        'HowToPlay': (_, MatchBoardGame g) =>
            _blocksBanner(HowToPlayOverlay(game: g)),
        'RankingList': (_, MatchBoardGame g) =>
            _blocksBanner(RankingOverlay(game: g)),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _gameMounted ? _gameWidget! : const SizedBox.shrink();
    final showSfxLog =
        AppConfig.debugLog &&
        widget.gameMode == JewelGameMode.simple &&
        _gameMounted;
    final gameStack = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        content,
        AnimatedSwitcher(
          duration: _loadingFadeDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _loadingVisible
              ? AbsorbPointer(
                  child: GameLoadingOverlay(gameMode: widget.gameMode),
                )
              : const SizedBox.shrink(),
        ),
        if (showSfxLog)
          const Positioned(
            left: 10,
            right: 10,
            bottom: 6,
            height: 148,
            child: SfxPlayLogPanel(),
          ),
        if (_qaVfxEnabled)
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _game?.debugTriggerSpecialEffects(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: PhoneFrame(
                child: kIsWeb
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        clipBehavior: Clip.hardEdge,
                        child: gameStack,
                      )
                    : gameStack,
              ),
            ),
          ),
          if (_bannerSupported && !_loadingVisible)
            _BannerSafeArea(adService: _adService),
        ],
      ),
    );
  }
}

class _BannerBlocker extends StatefulWidget {
  const _BannerBlocker({required this.onChanged, required this.child});

  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<_BannerBlocker> createState() => _BannerBlockerState();
}

class _BannerBlockerState extends State<_BannerBlocker> {
  @override
  void initState() {
    super.initState();
    widget.onChanged(true);
  }

  @override
  void dispose() {
    widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerSafeArea extends StatelessWidget {
  const _BannerSafeArea({required this.adService});

  final AdService adService;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: adService is! FakeAdService
          ? const SizedBox.shrink()
          : AnimatedBuilder(
              animation: adService,
              builder: (context, _) {
                final visible = (adService as FakeAdService).bannerVisible;
                return ColoredBox(
                  color: visible ? const Color(0xFF151D30) : Colors.transparent,
                  child: visible
                      ? const Center(
                          child: Text(
                            'TEST AD, 무한 모드 하단 배너',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : null,
                );
              },
            ),
    );
  }
}
