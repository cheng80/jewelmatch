import 'dart:math' show min;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../services/ranking_service.dart';
import 'components/match_board_renderer.dart';
import 'components/match_game_hud.dart';
import 'components/particle_burst.dart';
import 'components/special_effect_pool.dart';
import 'components/space_bg.dart';
import 'jewel_game_mode.dart';
import 'match_board_camera_shake.dart';
import 'match_board_logic.dart';
import 'match_board_qa_bridge.dart';

part 'match_board_game_vfx.dart';
part 'match_board_game_flow.dart';
part 'match_board_game_layout.dart';
part 'match_board_game_timing.dart';

/// 8×8 매치-3 Flame 게임 (스왑·연쇄·특수 보석).
/// 보드 탭은 전체 화면 [MatchGameHud]가 받아 상단 크롬 외 좌표를 [handleBoardTap]으로 전달한다.
class MatchBoardGame extends FlameGame {
  MatchBoardGame({
    this.safeAreaPadding = EdgeInsets.zero,
    this.gameMode = JewelGameMode.simple,
  }) {
    board = MatchBoardLogic(
      rows: rows,
      cols: cols,
      colorCount: 6,
      onNoMoves: () {
        overlays.add('NoMoves');
      },
      timedModeTimeRewardScale: timedModeTimeRewardScale,
      timedModeBonusBaseUnits: timedModeBonusBaseUnits,
      timedModeBonusPerComboTierUnits: timedModeBonusPerComboTierUnits,
      onTimedModeTimeBonus: isTimedMode ? _applyTimedModeTimeBonus : null,
      onInvalidSwap: _playInvalidSwapSfx,
    );
    board.onIntroFillComplete = (BoardFillIntroKind kind) {
      overlays.remove('IntroBlock');
      if (kind == BoardFillIntroKind.roundStart) {
        SoundManager.playSfx(AssetPaths.sfxStart);
      }
    };
    board.onGemsRemoved = _spawnParticles;
    if (isTimedMode) {
      timeRemaining = timedRoundSeconds;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
  }

  final EdgeInsets safeAreaPadding;
  final JewelGameMode gameMode;

  /// 타임 모드 시작 시 남은 시간(초).
  static const double timedRoundSeconds = 60;

  /// 타임 모드에서 [timeRemaining] 상한(초). 이보다 많이 쌓이는 보상은 버린다.
  static const double timedMaxTimeSeconds = 90;

  /// 레벨/난이도용 **시간 보상 비율**.
  /// 실제 추가 초 = `round((기준합) * 이 값)` — 0.5면 보상이 절반.
  static const double timedModeTimeRewardScale = 0.6;

  /// 매치 1단계 기준 보상(정수 초). 콤보 단계 보상은 [timedModeBonusPerComboTierUnits]와 합산 후 스케일·반올림.
  static const int timedModeBonusBaseUnits = 1;

  /// 콤보 2단계부터 (combo-1)에 곱해 더하는 정수 초 단위.
  static const int timedModeBonusPerComboTierUnits = 1;

  /// 남은 시간이 이 초 이하로 떨어지면 매 정수 초마다 [sfxTimeTic] 재생.
  static const int timedLowTimeTickMaxSeconds = 10;

  late final MatchBoardLogic board;
  late final ParticlePool _particlePool;
  late final SpecialEffectPool _specialEffectPool;
  final MatchBoardCameraShake _cameraShake = MatchBoardCameraShake();
  MatchGameHud? _hud;
  final Map<String, String> _localeStrings = {};

  /// 타임 모드: 서버 1위 이름·점수 (비동기 fetch 완료 후 갱신).
  String? rankingTop1Name;
  int? rankingTop1Score;

  String localeString(String key, String fallback) =>
      _localeStrings[key] ?? fallback;

  void setLocaleStrings(Map<String, String> strings) {
    _localeStrings
      ..clear()
      ..addAll(strings);
    _hud?.onGameResize(size);
  }

  static const int rows = 8;
  static const int cols = 8;
  static const double _hudScaleRatio = 0.2;

  bool isPlaying = true;
  bool timeUp = false;
  int _lastSavedScore = -1;

  /// `true`이면 `onGameResize`에서 기하만 갱신하고, 보석 데이터는 유지한다.
  /// (첫 유효 레이아웃에서 한 번만 `generateFreshBoard` — 문서 5절 `onLoad` 이후 레이아웃 확정 흐름과 동일한 단계)
  bool _boardSeededFromLayout = false;

  double timeRemaining = 0;

  /// [timeRemaining]의 정수 초(내림) — 저시간 틱이 중복되지 않도록 추적.
  int _lastFlooredSecondForTimeTic = -1;

  bool get isTimedMode => gameMode == JewelGameMode.timed;

  /// 상단 1열: 일시정지 + 최고 기록만.
  static const double hudTopBarScale = 0.54;

  /// 큰 점수 블록 (라벨 + 숫자).
  static const double hudMainScoreBlockScale = 1.38;
  double get hudTopBarHeight => hudScale * hudTopBarScale;
  double get hudMainScoreBlockHeight => hudScale * hudMainScoreBlockScale;

  /// 점수 숫자 아래 ~ 콤보 줄까지 간격.
  double get hudGapScoreToCombo => hudScale * 0.1;

  /// 콤보(현재·최대) 고정 줄 높이 — 점수 블록과 보드 사이.
  double get hudComboStripHeight => hudScale * 0.88;

  /// 콤보 줄과 보드 사이 간격.
  double get hudGapBeforeBoard => hudScale * 0.22;

  /// 보드 아래: 타임바만 (여백은 [hudGapBelowBoard]·[hudGapBelowTimeBar]).
  static const double hudBottomTimeBarScale = 0.5;

  double get hudBottomTimeBarHeight => hudScale * hudBottomTimeBarScale;

  /// 보드 하단과 타임바 사이 ([MatchGameHud]와 동일).
  double get hudGapBelowBoard => hudScale * 0.26;

  /// 타임바 아래 여백.
  double get hudGapBelowTimeBar => hudScale * 0.18;

  /// [layoutRef] 계산 시 보드 아래에 확보할 높이 (타임바 + 간격만).
  double get bottomChromeHeight =>
      hudGapBelowBoard + hudBottomTimeBarHeight + hudGapBelowTimeBar;

  /// 상단: 안전영역 + 상단바 + 점수 블록 + 콤보 줄 + 보드 전 간격.
  double get topChromeHeight =>
      safeAreaPadding.top +
      10 +
      hudTopBarHeight +
      hudMainScoreBlockHeight +
      hudGapScoreToCombo +
      hudComboStripHeight +
      hudGapBeforeBoard;

  /// Flame 부트스트랩 (`code-flow-analysis.md` 5절과 같은 단계)
  /// 1) super.onLoad  2) viewfinder  3) backdrop  4) viewport(HUD)  5) world(보드 렌더러)
  /// 실제 보석 채움은 `hasLayout`·`layoutRef`가 확보된 뒤 `onGameResize` → `_syncLayout`에서 수행.
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();
    camera.backdrop.add(SpaceBg());

    _hud = MatchGameHud(
      onPausePressed: pauseGame,
      onHintPressed: requestHint,
      onTutorialPressed: showHowToPlay,
      onRankingPressed: isTimedMode ? pauseForRankingPopup : null,
    );
    camera.viewport.add(_hud!);

    world.add(MatchBoardRenderer(logic: board));

    _particlePool = ParticlePool(world);
    _specialEffectPool = SpecialEffectPool(world);
    installMatchBoardQaBridge(this);

    if (isTimedMode) {
      _fetchTop1();
    }
  }

  Future<void> _fetchTop1() async {
    final top = await RankingService.fetchTop1();
    if (top != null) {
      rankingTop1Name = top.name;
      rankingTop1Score = top.score;
    }
  }

  double get hudScale => _hudScaleImpl;

  /// 레이아웃용 [hudScale]은 50~100대라 그대로 `fontSize`에 곱하면 글자가 비정상적으로 커진다.
  static const double _hudLayoutRef = 72.0;
  double get hudTextScale => _hudTextScaleImpl;

  double get panelCenterY => _panelCenterYImpl;

  double get safeContentLeft => _safeContentLeftImpl;

  double get safeContentRight => _safeContentRightImpl;

  double get safeContentWidth => _safeContentWidthImpl;

  double get safeContentCenterX => _safeContentCenterXImpl;

  double get gridTopY => _gridTopYImpl;

  double get layoutRef => _layoutRefImpl;

  /// 보드(셀) 영역 하단 Y — HUD에서 하단 패널 배치·히트 테스트에 사용.
  double get boardPixelBottom => _boardPixelBottomImpl;

  /// 인트로 중에는 Flutter [IntroBlock] 오버레이로 전체 입력 차단(투명).
  void _syncIntroInputBlock() => _syncIntroInputBlockImpl();

  void _syncLayout() => _syncLayoutImpl();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncLayout();
  }

  void pauseGame() => _pauseGameImpl();

  void resumeGame() => _resumeGameImpl();

  /// 타임 모드 HUD 랭킹 버튼: 게임 일시정지 + 랭킹 팝업.
  void pauseForRankingPopup() => _pauseForRankingPopupImpl();

  void closeRankingPopup() => _closeRankingPopupImpl();

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        return;
      case AppLifecycleState.detached:
        super.lifecycleStateChange(state);
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        super.lifecycleStateChange(state);
        SoundManager.pauseBgm(onlyIfCurrent: AssetPaths.bgmMain);
        if (isPlaying && !timeUp) {
          isPlaying = false;
          overlays.add('PauseMenu');
        }
        break;
    }
  }

  void _triggerTimeUp() => _triggerTimeUpImpl();

  /// 같은 모드로 점수·타이머·보드 초기화.
  void restartRound() => _restartRoundImpl();

  @override
  void update(double dt) {
    board.update(dt);
    _spawnSpecialEffectEvents();
    _updateCameraShake(dt);

    _updateTimedModeClock(dt);
    _saveBestScoreIfChanged();
    super.update(dt);
  }

  void handleBoardTap(double x, double y) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    board.handleTap(x, y);
  }

  /// 스와이프 입력: 시작 좌표(px)에서 [dr]/[dc] 방향으로 1칸 스왑 시도.
  void handleBoardSwipe(double startX, double startY, int dr, int dc) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    board.clearHint();
    final cell = board.pixelToCell(startX, startY);
    if (cell == null) return;
    final fromRow = cell.x;
    final fromCol = cell.y;
    final toRow = fromRow + dr;
    final toCol = fromCol + dc;
    if (!board.isInside(toRow, toCol)) return;
    board.selected = null;
    board.trySwap(fromRow, fromCol, toRow, toCol);
  }

  void requestHint() => _requestHintImpl();

  /// 힌트 디밍만 해제 (보드 탭 외 UI 탭 등).
  void dismissHint() => _dismissHintImpl();

  void showHowToPlay() => _showHowToPlayImpl();

  void closeHowToPlay() => _closeHowToPlayImpl();

  void shuffleBoard() => _shuffleBoardImpl();

  void debugTriggerSpecialEffects() => _debugTriggerSpecialEffectsImpl();

  void newBoard() => _newBoardImpl();

  /// [seconds]는 정수 초. [timedMaxTimeSeconds]까지 남은 여유(`room`)만큼만 가산하고,
  /// 보상 초 중 **초과분은 제외**(버림)한다.
  void _playInvalidSwapSfx() {
    SoundManager.playSfx(AssetPaths.sfxFail);
  }

  void _applyTimedModeTimeBonus(int seconds) =>
      _applyTimedModeTimeBonusImpl(seconds);
}
