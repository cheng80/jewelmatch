import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
  });

  final JewelGameMode gameMode;
  final bool qaVfxEnabled;
  final bool qaLevelUpEnabled;
  final bool qaNoMovesEnabled;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  static const Duration _minLoadingOverlay = Duration(milliseconds: 350);

  /// Flame GameWidget — initState가 아닌 didChangeDependencies에서 1회만 생성.
  /// build()에서 매번 생성하면 rebuild마다 엔진이 재초기화된다.
  Widget? _gameWidget;
  MatchBoardGame? _game;
  bool _gameMounted = false;
  bool _loadingVisible = true;
  bool _qaVfxPreviewScheduled = false;
  bool _qaLevelUpPreviewScheduled = false;
  bool _qaNoMovesPreviewScheduled = false;

  bool get _qaVfxEnabled => kIsWeb && widget.qaVfxEnabled;
  bool get _qaLevelUpEnabled => kIsWeb && widget.qaLevelUpEnabled;
  bool get _qaNoMovesEnabled => kIsWeb && widget.qaNoMovesEnabled;

  @override
  void initState() {
    super.initState();
    if (AppConfig.debugLog && widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = true;
      SfxPlayLog.clear();
    }
    SoundManager.playBgm(AssetPaths.bgmMain);
    _scheduleGameMount();
  }

  @override
  void dispose() {
    if (AppConfig.debugLog && widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = false;
    }
    super.dispose();
  }

  /// 페이드 전환(500ms)과 Flame 초기화가 같은 프레임에 겹치지 않도록
  /// 첫 프레임 렌더 후 GameWidget을 마운트하고, 짧은 로딩 오버레이 뒤에 노출한다.
  Future<void> _scheduleGameMount() async {
    final startedAt = DateTime.now();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _gameMounted = true);
    final game = await _waitForGame();
    if (game != null) {
      await Future.wait([game.loaded, SoundManager.preload()]);
    }
    if (!mounted) return;

    final remain = _minLoadingOverlay - DateTime.now().difference(startedAt);
    if (remain > Duration.zero) {
      await Future<void>.delayed(remain);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _loadingVisible = false);
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
        'PauseMenu': (_, MatchBoardGame g) => PauseMenuOverlay(game: g),
        'NoMoves': (_, MatchBoardGame g) => NoMovesOverlay(game: g),
        'LevelCelebration': (_, MatchBoardGame g) =>
            LevelCelebrationOverlay(game: g),
        'LevelUp': (_, MatchBoardGame g) => LevelUpOverlay(game: g),
        'StageInventory': (_, MatchBoardGame g) =>
            StageInventoryOverlay(game: g),
        'TimeUp': (_, MatchBoardGame g) => TimeUpOverlay(game: g),
        'GameStats': (_, MatchBoardGame g) => GameStatsOverlay(game: g),
        'HowToPlay': (_, MatchBoardGame g) => HowToPlayOverlay(game: g),
        'RankingList': (_, MatchBoardGame g) => RankingOverlay(game: g),
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
          duration: const Duration(milliseconds: 220),
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
      body: Center(
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
    );
  }
}
