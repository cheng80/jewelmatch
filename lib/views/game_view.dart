import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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

/// 매치-3 게임 화면. [gameMode]는 타이틀에서 Simple / Timed 로 전달한다.
class GameView extends StatefulWidget {
  const GameView({super.key, this.gameMode = JewelGameMode.simple});

  final JewelGameMode gameMode;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  /// Flame GameWidget — initState가 아닌 didChangeDependencies에서 1회만 생성.
  /// build()에서 매번 생성하면 rebuild마다 엔진이 재초기화된다.
  Widget? _gameWidget;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = true;
      SfxPlayLog.clear();
    }
    SoundManager.playBgm(AssetPaths.bgmMain);
    _scheduleGameMount();
  }

  @override
  void dispose() {
    if (widget.gameMode == JewelGameMode.simple) {
      SfxPlayLog.enabled = false;
    }
    super.dispose();
  }

  /// 페이드 전환(500ms)과 Flame 초기화가 같은 프레임에 겹치지 않도록
  /// 첫 프레임 렌더 후 GameWidget을 마운트한다.
  Future<void> _scheduleGameMount() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _ready = true);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _ready ? _gameWidget! : const SizedBox.shrink();
    final showSfxLog =
        widget.gameMode == JewelGameMode.simple && _ready;

    final mq = MediaQuery.of(context);
    final logHeight = min(148.0, mq.size.height * 0.2);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenRatio = constraints.maxWidth / constraints.maxHeight;
                final refRatio = kPhoneFrameRefW / kPhoneFrameRefH;
                final needsFrame = screenRatio > refRatio + 0.05;

                if (!needsFrame) {
                  return SizedBox.expand(child: content);
                }

                final fittedScale = min(
                  constraints.maxWidth / kPhoneFrameRefW,
                  constraints.maxHeight / kPhoneFrameRefH,
                );
                final w = kPhoneFrameRefW * fittedScale;
                final h = kPhoneFrameRefH * fittedScale;
                return SizedBox(
                  width: w,
                  height: h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(kIsWeb ? 28 : 0),
                    child: content,
                  ),
                );
              },
            ),
          ),
          // Positioned는 Stack의 직접 자식이어야 한다. LayoutBuilder 안에 두면
          // 전체 화면을 덮어 게임 입력을 막고, 하단 정렬도 깨진다.
          if (showSfxLog)
            Positioned(
              left: 10,
              right: 10,
              bottom: mq.padding.bottom + 6,
              height: logHeight,
              child: const SfxPlayLogPanel(),
            ),
        ],
      ),
    );
  }
}
