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
import '../widgets/sprite_sheet_frame.dart';
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import 'overlays/time_up_overlay.dart';
import 'overlays/pause_menu_overlay.dart';
import 'overlays/no_moves_overlay.dart';
import 'overlays/how_to_play_overlay.dart';
import 'overlays/ranking_overlay.dart';

/// 매치-3 게임 화면. [gameMode]는 타이틀에서 Simple / Timed 로 전달한다.
class GameView extends StatefulWidget {
  const GameView({super.key, this.gameMode = JewelGameMode.simple});

  final JewelGameMode gameMode;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  static const Duration _minLoadingOverlay = Duration(milliseconds: 350);

  /// Flame GameWidget — initState가 아닌 didChangeDependencies에서 1회만 생성.
  /// build()에서 매번 생성하면 rebuild마다 엔진이 재초기화된다.
  Widget? _gameWidget;
  bool _gameMounted = false;
  bool _loadingVisible = true;

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

    final remain = _minLoadingOverlay - DateTime.now().difference(startedAt);
    if (remain > Duration.zero) {
      await Future<void>.delayed(remain);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _loadingVisible = false);
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
          'bestScore': context.tr('bestScore'),
          'combo': context.tr('combo'),
          'timeLeft': context.tr('timeLeft'),
          'unlimitedMode': context.tr('unlimitedMode'),
          'maxComboLabel': context.tr('maxComboLabel'),
        });
        return g;
      },
      overlayBuilderMap: {
        'IntroBlock': (_, MatchBoardGame g) => const AbsorbPointer(
              child: ColoredBox(color: Colors.transparent, child: SizedBox.expand()),
            ),
        'PauseMenu': (_, MatchBoardGame g) => PauseMenuOverlay(game: g),
        'NoMoves': (_, MatchBoardGame g) => NoMovesOverlay(game: g),
        'TimeUp': (_, MatchBoardGame g) => TimeUpOverlay(game: g),
        'HowToPlay': (_, MatchBoardGame g) => HowToPlayOverlay(game: g),
        'RankingList': (_, MatchBoardGame g) => RankingOverlay(game: g),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _gameMounted ? _gameWidget! : const SizedBox.shrink();
    final showSfxLog =
        AppConfig.debugLog && widget.gameMode == JewelGameMode.simple && _gameMounted;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: PhoneFrame(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kIsWeb ? 28 : 0),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                content,
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _loadingVisible
                      ? GameLoadingOverlay(gameMode: widget.gameMode)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameLoadingOverlay extends StatefulWidget {
  const GameLoadingOverlay({super.key, required this.gameMode});

  final JewelGameMode gameMode;

  @override
  State<GameLoadingOverlay> createState() => _GameLoadingOverlayState();
}

class _GameLoadingOverlayState extends State<GameLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.gameMode == JewelGameMode.timed
        ? const Color(0xFFFFD54F)
        : const Color(0xFF22E6FF);

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC2A0A4D),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: accent.withValues(alpha: 0.8), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _loadingGem(0, 0.0),
                        const SizedBox(width: 10),
                        _loadingGem(3, 0.33),
                        const SizedBox(width: 10),
                        _loadingGem(6, 0.66),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3.2),
                ),
                const SizedBox(height: 16),
                Text(
                  '불러오는 중...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingGem(int frameIndex, double phaseOffset) {
    final t = (_controller.value + phaseOffset) % 1.0;
    final pulse = 0.35 + 0.65 * (0.5 + 0.5 * (1 - (t * 2 - 1).abs()));
    final scale = 0.9 + pulse * 0.18;
    return Opacity(
      opacity: pulse.clamp(0.45, 1.0),
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12 * pulse),
                blurRadius: 10 + pulse * 10,
              ),
            ],
          ),
          child: SpriteSheetFrame(
            assetPath: 'assets/images/${AssetPaths.jewelSpriteSheet}',
            frameIndex: frameIndex,
            frameSize: 128,
            size: 46,
          ),
        ),
      ),
    );
  }
}
