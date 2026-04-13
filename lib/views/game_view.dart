import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_config.dart';
import '../game/jewel_game_mode.dart';
import '../game/match_board_game.dart';
import '../widgets/phone_frame_scaffold.dart';
import '../widgets/starry_background.dart';
import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../services/ranking_service.dart';
import '../theme/jewel_candy_lumina_theme.dart';

/// 오버레이에서 그라데이션 CTA와 아웃라인 보조 버튼 모서리를 맞춘다.
const double _kLuminaOverlayButtonRadius = 16;

/// 매치-3 게임 화면. [gameMode]는 타이틀에서 Simple / Timed 로 전달한다.
///
/// 초기화 순서 (`docs/code-flow-analysis.md` 2절·5절과 동일한 단계):
/// 1. [initState]: 게임 BGM 시작
/// 2. [build]: `GameWidget.controlled` → `gameFactory`로 [MatchBoardGame] 생성·로케일 주입
/// 3. Flame `onLoad`: 카메라 → `SpaceBg` → `MatchGameHud`(viewport) → `MatchBoardRenderer`(world)
/// 4. `onGameResize` / `_syncLayout`: 유효한 `layoutRef` 확보 후 `setGeometry` + 최초 1회 `generateFreshBoard`
class GameView extends StatefulWidget {
  const GameView({super.key, this.gameMode = JewelGameMode.simple});

  final JewelGameMode gameMode;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  @override
  void initState() {
    super.initState();
    SoundManager.playBgm(AssetPaths.bgmMain);
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;
    final gameWidget = GameWidget<MatchBoardGame>.controlled(
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
        'IntroBlock': _buildIntroBlock,
        'PauseMenu': _buildPauseMenu,
        'NoMoves': _buildNoMoves,
        'TimeUp': _buildTimeUp,
        'HowToPlay': _buildHowToPlay,
      },
    );

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: StarryBackground()),
            Positioned.fill(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
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
                        borderRadius: BorderRadius.circular(28),
                        child: gameWidget,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(body: gameWidget);
  }

  /// 인트로(보석이 차오르는 동안) HUD·보드 위에 올려 포인터만 흡수한다.
  Widget _buildIntroBlock(BuildContext context, MatchBoardGame game) {
    return const AbsorbPointer(
      child: ColoredBox(
        color: Colors.transparent,
        child: SizedBox.expand(),
      ),
    );
  }

  Widget _buildPauseMenu(BuildContext context, MatchBoardGame game) {
    return _PauseMenuOverlay(game: game);
  }

  Widget _buildNoMoves(BuildContext context, MatchBoardGame game) {
    return _NoMovesOverlay(game: game);
  }

  Widget _buildTimeUp(BuildContext context, MatchBoardGame game) {
    return _TimeUpOverlay(game: game);
  }

  Widget _buildHowToPlay(BuildContext context, MatchBoardGame game) {
    return _HowToPlayOverlay(game: game);
  }
}

class _TimeUpOverlay extends StatefulWidget {
  const _TimeUpOverlay({required this.game});
  final MatchBoardGame game;

  @override
  State<_TimeUpOverlay> createState() => _TimeUpOverlayState();
}

class _TimeUpOverlayState extends State<_TimeUpOverlay>
    with TickerProviderStateMixin {
  static const Duration _titleDuration = Duration(milliseconds: 1500);
  static const Duration _panelDelay = Duration(milliseconds: 1900);

  late final AnimationController _titleCtrl;
  late final Animation<double> _titleScale;
  late final Animation<double> _titleOpacity;

  bool _showPanel = false;
  String? _rankMessage;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = AnimationController(vsync: this, duration: _titleDuration);

    _titleScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutExpo)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.bounceOut)),
        weight: 70,
      ),
    ]).animate(_titleCtrl);

    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleCtrl, curve: const Interval(0, 0.15)),
    );

    _titleCtrl.forward();

    Future.delayed(_panelDelay, () {
      if (!mounted) return;
      setState(() => _showPanel = true);
      _submitIfTimed();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitIfTimed() async {
    if (!widget.game.isTimedMode) return;
    final name = GameSettings.playerName;
    final score = widget.game.board.score;
    if (score <= 0) return;
    final result = await RankingService.submit(name: name, score: score);
    if (!mounted) return;
    setState(() {
      _submitted = true;
      if (result == null) {
        _rankMessage = context.tr('rankSubmitFailed');
      } else if (result.ranked) {
        _rankMessage = context.tr('rankSuccess')
            .replaceAll('{rank}', '${result.rank}')
            .replaceAll('{score}', '${result.score}');
      } else {
        _rankMessage = context.tr('rankNotInTop');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Stack(
        children: [
          if (!_showPanel)
            Center(
              child: AnimatedBuilder(
                animation: _titleCtrl,
                builder: (_, _) => Opacity(
                  opacity: _titleOpacity.value,
                  child: Transform.scale(
                    scale: _titleScale.value,
                    child: Text(
                      context.tr('timeUpTitle'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            color: JewelCandyLuminaTheme.primaryPink,
                            blurRadius: 30,
                          ),
                          Shadow(
                            color: JewelCandyLuminaTheme.primaryPink
                                .withValues(alpha: 0.8),
                            blurRadius: 60,
                          ),
                          Shadow(
                            color: JewelCandyLuminaTheme.primaryDeep,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_showPanel)
            Center(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 36),
                  decoration: BoxDecoration(
                    color: JewelCandyLuminaTheme.surfaceContainer
                        .withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: JewelCandyLuminaTheme.borderTimeUp,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: JewelCandyLuminaTheme.primaryPink
                            .withValues(alpha: 0.35),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('timeUpTitle'),
                        style: TextStyle(
                          color: JewelCandyLuminaTheme.secondaryCyan,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('gameResult'),
                        style: TextStyle(
                          color: JewelCandyLuminaTheme.tertiaryGold
                              .withValues(alpha: 0.95),
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        '${context.tr('score')}: ${widget.game.board.score}',
                        style: TextStyle(
                          color: JewelCandyLuminaTheme.goldStrong,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.game.isTimedMode) ...[
                        const SizedBox(height: 12),
                        if (!_submitted)
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: JewelCandyLuminaTheme.secondaryCyan,
                            ),
                          )
                        else if (_rankMessage != null)
                          Text(
                            _rankMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: JewelCandyLuminaTheme.tertiaryGold,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                      const SizedBox(height: 24),
                      _LuminaGradientButton(
                        colors: JewelCandyLuminaTheme.buttonRetryMagOr,
                        label: context.tr('retry'),
                        onPressed: () {
                          SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                          widget.game.restartRound();
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 240,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: JewelCandyLuminaTheme.secondaryCyan,
                              width: 2,
                            ),
                            backgroundColor: JewelCandyLuminaTheme
                                .surfaceVariant
                                .withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  _kLuminaOverlayButtonRadius),
                            ),
                          ),
                          onPressed: () {
                            SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                            context.go(RoutePaths.title);
                          },
                          child: Text(context.tr('exit')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMovesOverlay extends StatelessWidget {
  const _NoMovesOverlay({required this.game});
  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: JewelCandyLuminaTheme.borderNoMoves,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.25),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('noMovesTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.primaryPink,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _LuminaGradientButton(
                width: 220,
                colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
                label: context.tr('shuffleBoard'),
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  game.shuffleBoard();
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: JewelCandyLuminaTheme.primaryPink,
                      width: 2,
                    ),
                    backgroundColor: JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_kLuminaOverlayButtonRadius),
                    ),
                  ),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.newBoard();
                  },
                  child: Text(context.tr('newBoard')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseMenuOverlay extends StatefulWidget {
  const _PauseMenuOverlay({required this.game});
  final MatchBoardGame game;

  @override
  State<_PauseMenuOverlay> createState() => _PauseMenuOverlayState();
}

class _PauseMenuOverlayState extends State<_PauseMenuOverlay> {
  late double _bgmVolume;
  late double _sfxVolume;
  late bool _bgmMuted;
  late bool _sfxMuted;

  @override
  void initState() {
    super.initState();
    _bgmVolume = GameSettings.bgmVolume;
    _sfxVolume = GameSettings.sfxVolume;
    _bgmMuted = GameSettings.bgmMuted;
    _sfxMuted = GameSettings.sfxMuted;
  }

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderThemeData(
      activeTrackColor: JewelCandyLuminaTheme.secondaryCyan,
      inactiveTrackColor: Colors.white24,
      thumbColor: JewelCandyLuminaTheme.primaryPink,
      overlayColor: JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.2),
    );
    final switchTheme = SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(JewelCandyLuminaTheme.secondaryCyan),
      trackColor: WidgetStatePropertyAll(
        JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.45),
      ),
    );
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: SingleChildScrollView(
          child: Theme(
            data: Theme.of(context).copyWith(switchTheme: switchTheme),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: BoxDecoration(
                color: JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: JewelCandyLuminaTheme.borderPause,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.4),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Text(
                  context.tr('paused'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.secondaryCyan,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('bgm'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
                    fontSize: 20,
                  ),
                ),
                SliderTheme(
                  data: sliderTheme,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _bgmMuted ? 0.0 : _bgmVolume,
                          onChanged: _bgmMuted
                              ? null
                              : (v) {
                                  setState(() {
                                    _bgmVolume = v;
                                    GameSettings.bgmVolume = v;
                                    SoundManager.applyBgmVolume();
                                  });
                                },
                        ),
                      ),
                      Switch(
                        value: _bgmMuted,
                        onChanged: (v) {
                          setState(() {
                            _bgmMuted = v;
                            GameSettings.bgmMuted = v;
                            if (v) {
                              SoundManager.pauseBgm();
                            } else {
                              SoundManager.playBgmIfUnmuted();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Text(
                  context.tr('sfx'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
                    fontSize: 20,
                  ),
                ),
                SliderTheme(
                  data: sliderTheme,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _sfxMuted ? 0.0 : _sfxVolume,
                          onChanged: _sfxMuted
                              ? null
                              : (v) {
                                  setState(() {
                                    _sfxVolume = v;
                                    GameSettings.sfxVolume = v;
                                  });
                                },
                        ),
                      ),
                      Switch(
                        value: _sfxMuted,
                        onChanged: (v) {
                          setState(() {
                            _sfxMuted = v;
                            GameSettings.sfxMuted = v;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _LuminaGradientButton(
                  colors: JewelCandyLuminaTheme.buttonPrimaryPink,
                  label: context.tr('continueGame'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    widget.game.resumeGame();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 240,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: JewelCandyLuminaTheme.secondaryCyan,
                        width: 2,
                      ),
                      backgroundColor:
                          JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _kLuminaOverlayButtonRadius,
                        ),
                      ),
                    ),
                    onPressed: () {
                      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                      context.go(RoutePaths.title);
                    },
                    child: Text(context.tr('exit')),
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stitch **Jewel Candy Lumina** 스타일 그라데이션 CTA.
class _LuminaGradientButton extends StatelessWidget {
  const _LuminaGradientButton({
    required this.colors,
    required this.label,
    required this.onPressed,
    this.width = 240,
  });

  final List<Color> colors;
  final String label;
  final VoidCallback onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius:
              BorderRadius.circular(_kLuminaOverlayButtonRadius),
          boxShadow: [
            BoxShadow(
              color: JewelCandyLuminaTheme.primaryDeep.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                BorderRadius.circular(_kLuminaOverlayButtonRadius),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HowToPlayOverlay extends StatelessWidget {
  const _HowToPlayOverlay({required this.game});
  final MatchBoardGame game;

  static const double _gemSize = 36;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: JewelCandyLuminaTheme.overlayScrim,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: JewelCandyLuminaTheme.surfaceContainer
                .withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: JewelCandyLuminaTheme.secondaryCyan,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: JewelCandyLuminaTheme.primaryDeep
                    .withValues(alpha: 0.4),
                blurRadius: 22,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Text(
                  context.tr('howToPlayTitle'),
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.secondaryCyan,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionTitle(context.tr('howToPlayGoal')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayGoalDesc')),
                      const SizedBox(height: 16),

                      _sectionTitle(context.tr('howToPlayMatch')),
                      const SizedBox(height: 8),
                      _matchExample([0, 0, 0, 6, 3]),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayMatchDesc')),
                      const SizedBox(height: 16),

                      _sectionTitle(context.tr('howToPlaySwap')),
                      const SizedBox(height: 8),
                      _swapExample(),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlaySwapDesc')),
                      const SizedBox(height: 16),

                      _sectionTitle(context.tr('howToPlayCombo')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayComboDesc')),
                      const SizedBox(height: 16),

                      _sectionTitle(context.tr('howToPlayHint')),
                      const SizedBox(height: 6),
                      _bodyText(context.tr('howToPlayHintDesc')),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: _LuminaGradientButton(
                  colors: JewelCandyLuminaTheme.buttonPrimaryPink,
                  label: context.tr('continueGame'),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.closeHowToPlay();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: JewelCandyLuminaTheme.tertiaryGold,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _gemClip(int sheetCol) {
    return SizedBox(
      width: _gemSize,
      height: _gemSize,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: _gemSize * 7,
          maxHeight: _gemSize,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(-_gemSize * sheetCol, 0),
            child: Image.asset(
              'assets/images/sprites/Juwel.png',
              width: _gemSize * 7,
              height: _gemSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchExample(List<int> cols) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Container(
            decoration: i < 3
                ? BoxDecoration(
                    border: Border.all(
                      color: JewelCandyLuminaTheme.tertiaryGold
                          .withValues(alpha: 0.8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: _gemClip(cols[i]),
          ),
        ],
      ],
    );
  }

  Widget _swapExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _gemClip(0),
        const SizedBox(width: 2),
        _gemClip(6),
        const SizedBox(width: 8),
        Icon(Icons.swap_horiz_rounded,
            color: JewelCandyLuminaTheme.secondaryCyan, size: 28),
        const SizedBox(width: 8),
        _gemClip(6),
        const SizedBox(width: 2),
        _gemClip(0),
      ],
    );
  }
}
