import 'dart:async';
import 'dart:math' show Random, min;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/event_logger.dart';
import '../services/game_settings.dart';
import '../services/play_event_context.dart';
import '../services/ranking_service.dart';
import '../services/records/player_records.dart';
import '../services/records/records_store.dart';
import 'components/board_juice_layer.dart';
import 'components/last_hurrah_badge.dart';
import 'components/match_board_renderer.dart';
import 'components/match_game_hud.dart';
import 'components/special_effect_pool.dart';
import 'components/speed_bonus_badge.dart';
import 'daily_seed.dart' show DailyRandom;
import 'item_inventory.dart';
import 'item_kind.dart';
import 'jewel_game_mode.dart';
import 'jewel_rank_progression.dart';
import 'last_hurrah.dart';
import 'match_board_camera_shake.dart';
import 'match_board_logic.dart';
import 'match_board_qa_bridge.dart';
import 'match_board_specials.dart';
import 'round_summary.dart';
import 'round_timing.dart';
import 'speed_bonus.dart';
import 'stage_challenge.dart';
import 'stage_reward.dart';

part 'match_board_game_vfx.dart';
part 'match_board_game_debug_vfx.dart';
part 'match_board_game_flow.dart';
part 'match_board_game_layout.dart';
part 'match_board_game_mode_rules.dart';
part 'match_board_game_progression.dart';
part 'match_board_game_timing.dart';

const bool qaSpecialEffectsEnabled = bool.fromEnvironment('QA_SPECIAL_EFFECTS');

/// 판 문맥을 캡처한 이벤트 기록 함수. [MatchBoardGame.capturePlayEventSink] 참고.
typedef PlayEventSink =
    void Function(String name, [Map<String, Object?> params]);

enum MatchGameHudBottomPanel { inventory, qaEffects, developmentItems, none }

MatchGameHudBottomPanel matchGameHudBottomPanelFor({
  required JewelGameMode gameMode,
  required bool qaSpecialEffects,
  required bool release,
}) => switch (gameMode) {
  JewelGameMode.progression => MatchGameHudBottomPanel.inventory,
  JewelGameMode.timed => MatchGameHudBottomPanel.none,
  JewelGameMode.simple when qaSpecialEffects =>
    MatchGameHudBottomPanel.qaEffects,
  JewelGameMode.simple when release => MatchGameHudBottomPanel.none,
  JewelGameMode.simple => MatchGameHudBottomPanel.developmentItems,
};

/// 8×8 매치-3 Flame 게임 (스왑·연쇄·특수 보석).
/// 보드 탭은 전체 화면 [MatchGameHud]가 받아 상단 크롬 외 좌표를 [handleBoardTap]으로 전달한다.
class MatchBoardGame extends FlameGame {
  MatchBoardGame({
    this.safeAreaPadding = EdgeInsets.zero,
    this.gameMode = JewelGameMode.simple,
    EventLogger? eventLogger,
    RoundTiming? roundTiming,
  }) : eventLogger = eventLogger ?? EventLogger.instance,
       _roundTiming = roundTiming ?? RoundTiming() {
    _remainingHints = _initialHintsForMode(gameMode);
    board = MatchBoardLogic(
      rows: rows,
      cols: cols,
      colorCount: 6,
      onNoMoves: _showNoMovesOverlay,
      timedModeTimeRewardScale: timeRewardScaleForMode,
      timedModeBonusBaseUnits: timeBonusBaseUnitsForMode,
      timedModeBonusPerComboTierUnits: timeBonusPerComboTierUnitsForMode,
      onTimedModeTimeBonus: hasTimedClock ? _applyTimedModeTimeBonus : null,
      onInvalidSwap: _onInvalidSwap,
    );
    board.idleHintsEnabled = gameMode == JewelGameMode.simple;
    board.timedModeRules = isTimedMode;
    board.onIntroFillComplete = (BoardFillIntroKind kind) {
      overlays.remove('IntroBlock');
      _markRoundStartIntroComplete(kind);
    };
    board.onGemsRemoved = _spawnParticles;
    board.onSpecialsBorn = (spawns) {
      if (_effectPoolsReady) _juiceLayer.onSpecialsBorn(spawns);
    };
    board.onRemovalStarted = (cells) {
      if (_effectPoolsReady) _juiceLayer.onRemovalStarted(cells);
    };
    speedBonus = SpeedBonus(enabled: isTimedMode);
    if (isTimedMode) board.onValidSwapBonus = _onSpeedBonusSwap;
    board.onHyperSwap = (kind) =>
        logPlayEvent('hyper_swap', {'target_kind': kind.name});
    if (hasTimedClock) {
      timeRemaining = roundSecondsForMode;
      _lastFlooredSecondForTimeTic = timeRemaining.floor();
    }
    runInventory = RunInventory.phase2Initial();
    stageLoadout = StageLoadout.phase2Default(runInventory);
    nextStageLoadoutDraft = stageLoadout;
    latestStageRewards = const [];
    _stageStartRemainingHints = _remainingHints;
  }

  final EdgeInsets safeAreaPadding;
  final JewelGameMode gameMode;

  /// 게임 이벤트 로거. 테스트는 생성자로 주입한다.
  final EventLogger eventLogger;
  final RoundTiming _roundTiming;

  /// 현재 판과 시도(PLAN-009 Step 2). onLoad 전에는 null이라 판 이벤트를 남기지 않는다.
  PlayEventContext? _playContext;
  PlayEventContext? get playContext => _playContext;

  /// 현재 시도의 round_end를 이미 보냈는지. 로컬 기록 반영과 별도로 이벤트만 막는다.
  bool _roundEndLogged = false;
  bool _inBackground = false;

  /// 판 단위 입력 계수(PLAN-009 Step 3). 새 판마다 새로 만들고 이어하기/NoMoves는 유지한다.
  RoundInputStats _roundInput = RoundInputStats();
  RoundInputStats get roundInput => _roundInput;

  static int _initialHintsForMode(JewelGameMode mode) => switch (mode) {
    JewelGameMode.simple => 0,
    JewelGameMode.timed => timedModeInitialHints,
    JewelGameMode.progression => progressionModeInitialHints,
  };

  @override
  Color backgroundColor() => Colors.black.withValues(alpha: 0.4);

  /// 남은 시간이 이 초 이하로 떨어지면 매 정수 초마다 [sfxTimeTic] 재생.
  static const int timedLowTimeTickMaxSeconds = 10;
  static const int timedModeInitialHints = 3;
  static const int progressionModeInitialHints = 2;
  static const int progressionModeHintsPerStage = 1;

  late final MatchBoardLogic board;

  /// 타임 모드만 켠다(D5). 레벨 모드와 무한 모드는 비활성.
  late final SpeedBonus speedBonus;
  final SpeedBonusBadge _speedBonusBadge = SpeedBonusBadge();
  final LastHurrahBadge _lastHurrahBadge = LastHurrahBadge();

  /// 진행 중인 Last Hurrah. 타임 모드에서 시간이 0이 된 뒤 결과 전까지만 있다.
  LastHurrah? _lastHurrah;
  bool get lastHurrahActive => _lastHurrah != null;

  /// Last Hurrah 하이퍼 색 난수. 테스트와 재현을 위해 시드를 바꿀 수 있다.
  /// 타임 모드는 판 시작 때 날짜 시드에서 만든 난수로 바뀐다(BR-053).
  Random lastHurrahRandom = Random();

  /// 날짜 시드에서 Last Hurrah 난수를 보드 난수와 다르게 뽑기 위한 값.
  static const int lastHurrahSeedSalt = 0x5bd1e995;

  final BoardJuiceLayer _juiceLayer = BoardJuiceLayer();
  late final SpecialEffectPool _specialEffectPool;
  final MatchBoardCameraShake _boardShake = MatchBoardCameraShake();
  final Vector2 _boardShakeOffset = Vector2.zero();
  bool _effectPoolsReady = false;
  MatchGameHud? _hud;
  final Map<String, String> _localeStrings = {};
  final Completer<void> _firstBoardFrameCompleter = Completer<void>();
  final Completer<void> _firstRoundReadyCompleter = Completer<void>();
  bool _firstBoardFrameRendered = false;
  bool _roundStartSfxPending = false;

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

  bool _isPlaying = true;
  bool get isPlaying => _isPlaying;
  set isPlaying(bool value) {
    _isPlaying = value;
    _syncRoundPhase();
  }

  bool timeUp = false;
  int _stageAttemptSerial = 0;
  int _lastSavedScore = -1;
  late int _remainingHints;
  int progressionLevel = 1;
  int levelUpFromLevel = 1;
  int levelUpToLevel = 1;
  List<GemKind> progressionNextBoardBonusKinds = const [];
  ItemKind? activeTargetItem;
  int? selectedPrismColor;
  ItemKind? pendingImmediateItemConfirm;
  late RunInventory runInventory;
  late StageLoadout stageLoadout;
  late StageLoadout nextStageLoadoutDraft;
  bool _inventoryOpenedDuringPlay = false;
  bool get isInPlayInventoryOpen => _inventoryOpenedDuringPlay;

  bool get canOpenInPlayInventory =>
      isProgressionMode &&
      isPlaying &&
      !timeUp &&
      !_inBackground &&
      !board.inputLocked &&
      !board.introFillInProgress &&
      board.state == 'idle' &&
      !hasActiveVisualEffects &&
      !hasPendingImmediateItemConfirm;
  List<StageRewardGrant> latestStageRewards = const [];
  int stageLoadoutOpenSlotCount = StageLoadout.phase2InitialOpenSlotCount;
  List<int> recentlyUnlockedLoadoutSlotIndices = const [];
  String? _stageRewardClaimKey;
  late int _stageStartRemainingHints;
  final List<int> _recentStageRewardTotals = <int>[];
  String? _itemFeedbackText;
  double _itemFeedbackTimer = 0;

  /// `true`이면 `onGameResize`에서 기하만 갱신하고, 보석 데이터는 유지한다.
  /// (첫 유효 레이아웃에서 한 번만 `generateFreshBoard` — 문서 5절 `onLoad` 이후 레이아웃 확정 흐름과 동일한 단계)
  bool _boardSeededFromLayout = false;

  double timeRemaining = 0;

  /// [timeRemaining]의 정수 초(내림) — 저시간 틱이 중복되지 않도록 추적.
  int _lastFlooredSecondForTimeTic = -1;

  int get progressionXp => JewelRankProgression.xpFromScore(board.score);
  String get stageAttemptId => '$progressionLevel:$_stageAttemptSerial';
  int get rankingScore => isProgressionMode
      ? (progressionLevel > 1 ? progressionLevel - 1 : 0)
      : board.score;
  int get progressionTargetScore =>
      JewelRankProgression.scoreTargetForLevel(progressionLevel);

  /// 레벨 모드 도전 스테이지 목표. 일반 레벨과 다른 모드는 null.
  StageChallenge? get stageChallenge => isProgressionMode
      // 색 목표는 7색 스위치와 무관하게 6색 기준으로 정해 같은 레벨은 항상 같은 목표다(검수 R4 P3-6).
      ? StageChallenge.forLevel(progressionLevel)
      : null;
  double get progressionRatio => JewelRankProgression.stageProgressRatio(
    level: progressionLevel,
    score: board.score,
  );

  String progressionLabel() => JewelRankView(
    level: progressionLevel,
    xp: progressionXp,
  ).timeBarLabel(localeString('levelLabel', 'Lv.'));

  int get progressionNextBoardBonusCount =>
      progressionNextBoardBonusKinds.length;

  bool get hasLimitedHints =>
      gameMode == JewelGameMode.timed || gameMode == JewelGameMode.progression;

  int? get hintBadgeCount => hasLimitedHints ? _remainingHints : null;

  int get remainingHints => _remainingHints;
  bool get isItemTargeting => activeTargetItem != null;
  ItemKind? get targetingItem => activeTargetItem;
  bool get hasPendingImmediateItemConfirm =>
      pendingImmediateItemConfirm != null;
  bool get isPrismColorPicking =>
      activeTargetItem == ItemKind.prismTransform && selectedPrismColor == null;
  String? get itemFeedbackText {
    final targetItem = activeTargetItem;
    if (targetItem != null) return _itemTargetPrompt(targetItem);
    if (_itemFeedbackTimer <= 0) return null;
    return _itemFeedbackText;
  }

  double get itemFeedbackOpacity {
    if (activeTargetItem != null) return 1;
    if (_itemFeedbackText == null || _itemFeedbackTimer <= 0) return 0;
    return _itemFeedbackTimer < 0.24 ? _itemFeedbackTimer / 0.24 : 1;
  }

  List<ItemKind> get phaseOneTestItems => ItemKindMeta.phaseOneLoadout;
  int get stageStartRemainingHints => _stageStartRemainingHints;
  String? get stageRewardClaimKey => _stageRewardClaimKey;
  bool get hasPendingStageInventoryUnlock =>
      recentlyUnlockedLoadoutSlotIndices.isNotEmpty;
  bool get usesPhase2Inventory => isProgressionMode;
  MatchGameHudBottomPanel get hudBottomPanel => matchGameHudBottomPanelFor(
    gameMode: gameMode,
    qaSpecialEffects: qaSpecialEffectsEnabled,
    release: kReleaseMode,
  );

  static const List<GemKind> qaSpecialEffectKinds = [
    GemKind.row,
    GemKind.col,
    GemKind.bomb,
    GemKind.star,
    GemKind.hyper,
    GemKind.supernova,
  ];

  List<GemKind> get hudQaSpecialEffectKinds =>
      hudBottomPanel == MatchGameHudBottomPanel.qaEffects
      ? qaSpecialEffectKinds
      : const [];

  Future<void> get firstBoardFrameRendered => _firstBoardFrameCompleter.future;
  Future<void> get firstRoundReady => _firstRoundReadyCompleter.future;
  Vector2 get boardShakeOffset => _boardShakeOffset;
  List<StageLoadoutSlot> get hudLoadoutSlots {
    switch (hudBottomPanel) {
      case MatchGameHudBottomPanel.inventory:
        return stageLoadout.slots;
      case MatchGameHudBottomPanel.developmentItems:
        return [
          for (final (index, item) in phaseOneTestItems.indexed)
            StageLoadoutSlot(index: index, item: item, locked: false),
        ];
      case MatchGameHudBottomPanel.qaEffects:
      case MatchGameHudBottomPanel.none:
        return const [];
    }
  }

  Map<ItemKind, Rect> debugReadItemSlotRects() =>
      _hud?.debugReadItemSlotRects() ?? const {};
  Map<int, Rect> debugReadPrismColorRects() =>
      _hud?.debugReadPrismColorRects() ?? const {};
  Map<String, Rect> debugReadAlignedHudRects() =>
      _hud?.debugReadAlignedHudRects() ?? const {};

  /// 상단 1열: 일시정지 + 최고 기록만.
  static const double hudTopBarScale = 0.54;

  /// 점수 블록 (라벨 + 숫자). 보드 위 콤보/타임바 공간을 확보하기 위해 압축한다.
  static const double hudMainScoreBlockScale = 1.06;
  double get hudTopBarHeight => hudScale * hudTopBarScale;
  double get hudMainScoreBlockHeight => hudScale * hudMainScoreBlockScale;

  /// 점수 숫자 아래 ~ 콤보 줄까지 간격.
  double get hudGapScoreToCombo => hudScale * 0.04;

  /// 콤보(현재·최대) 고정 줄 높이 — 점수 블록과 보드 사이.
  double get hudComboStripHeight => hudScale * 0.77;

  /// 콤보 줄과 타임바 사이 간격.
  double get hudGapComboToTimeBar => hudScale * 0.18;

  /// 타임바와 보드 사이 간격.
  double get hudGapTimeBarToBoard => hudScale * 0.24;

  static const double hudBottomTimeBarScale = 0.44;

  double get hudBottomTimeBarHeight => hudScale * hudBottomTimeBarScale;

  /// [layoutRef] 계산 시 보드 아래에 확보할 최소 하단 여백.
  double get bottomChromeHeight => safeAreaPadding.bottom + hudScale * 1.68 + 8;

  /// 상단: 안전영역 + 상단바 + 점수 + 콤보 + 타임바 + 보드 전 간격.
  double get topChromeHeight =>
      safeAreaPadding.top +
      10 +
      hudTopBarHeight +
      hudMainScoreBlockHeight +
      hudGapScoreToCombo +
      hudComboStripHeight +
      hudGapComboToTimeBar +
      hudBottomTimeBarHeight +
      hudGapTimeBarToBoard;

  /// Flame 부트스트랩 (`code-flow-analysis.md` 5절과 같은 단계)
  /// 1) super.onLoad  2) viewfinder  3) viewport(HUD)  4) world(보드 렌더러)
  /// 실제 보석 채움은 `hasLayout`·`layoutRef`가 확보된 뒤 `onGameResize` → `_syncLayout`에서 수행.
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    board.onGemSelected = () => SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();

    _hud = MatchGameHud(
      onPausePressed: () => hudMenuAction('pause', pauseGame),
      onHintPressed: requestHint,
      onTutorialPressed: () => hudMenuAction('help', showHowToPlay),
      onRankingPressed: isTimedMode
          ? () => hudMenuAction('ranking', pauseForRankingPopup)
          : null,
    );
    camera.viewport.add(_hud!);

    world.add(MatchBoardRenderer(logic: board));

    await world.add(_juiceLayer);
    if (isTimedMode) {
      await world.add(_speedBonusBadge);
      await world.add(_lastHurrahBadge);
    }
    _specialEffectPool = SpecialEffectPool(world);
    if (kIsWeb) {
      await _warmInitialEffectPools();
    }
    _effectPoolsReady = true;
    installMatchBoardQaBridge(this);
    _beginRound(PlayEventContext.startRun());

    if (isTimedMode) {
      _fetchTop1();
    }
  }

  /// 지금 판 문맥을 캡처한 기록 함수. 비동기 작업은 await 전에 받아 두어
  /// 늦은 결과도 요청 시점의 판과 시도에 붙인다. 문맥이 없으면 문맥 없이 기록한다.
  PlayEventSink capturePlayEventSink() {
    final context = _playContext;
    final logger = eventLogger;
    return (String name, [Map<String, Object?> params = const {}]) =>
        context == null
        ? logger.log(name, params)
        : logger.logPlay(name, context, params);
  }

  void logPlayEvent(String name, [Map<String, Object?> params = const {}]) =>
      capturePlayEventSink()(name, params);

  /// 판 시작. 시간 누적을 새로 시작하고 round_start를 한 번 보낸다.
  /// [context]가 null이면(onLoad 전 다음 레벨) 판 이벤트 없이 상태만 초기화한다.
  void _beginRound(PlayEventContext? context) {
    _playContext = context;
    _roundEndLogged = false;
    _roundInput = RoundInputStats();
    _roundTiming.reset();
    speedBonus.reset();
    _syncRoundPhase();
    if (context == null) return;
    eventLogger.logPlay('round_start', context, {
      'mode': gameMode.name,
      if (isTimedMode)
        'daily_key': board.dailyKey ?? DailySeed.keyFor(DateTime.now()),
      if (board.flags.tag.isNotEmpty) 'exp': board.flags.tag,
    });
  }

  /// 판 종료 이벤트와 로컬 기록 반영. [reason]은 time_up, exit, restart.
  void logRoundEnd(String reason) {
    _logRoundEndEvent(reason);
    commitRecords(level: progressionLevel);
  }

  /// round_end는 시도마다 한 번. 시간은 판 시작부터의 누적이며 종료 뒤에도 계속 쌓인다.
  void _logRoundEndEvent(String reason) {
    final context = _playContext;
    if (context == null || _roundEndLogged) return;
    _roundEndLogged = true;
    if (speedBonus.enabled) {
      eventLogger.logPlay('speed_bonus_peak', context, {
        'max_tier': speedBonus.peakTier,
        'total_bonus': speedBonus.totalBonus,
      });
    }
    eventLogger.logPlay('round_end', context, {
      'mode': gameMode.name,
      'reason': reason,
      if (board.flags.tag.isNotEmpty) 'exp': board.flags.tag,
      'score': board.score,
      ...board.bonusGemEventParams,
      if (isProgressionMode) 'level': progressionLevel,
      ..._roundTiming.snapshot(),
    });
    // 판 요약은 표본 없이 시도마다 한 번. 이어하기 뒤 값은 같은 판의 누적이다.
    // 진행 중인 한 수를 확정한다. 모든 호출자가 곧이어 commitRecords에서 같은 확정을 한다.
    final stats = board.stats..finishMove();
    eventLogger.logPlay(
      'round_summary',
      context,
      roundSummaryParams(stats, maxCombo: board.maxCombo),
    );
    eventLogger.logPlay('round_specials', context, roundSpecialsParams(stats));
    eventLogger.logPlay('round_input', context, _roundInput.eventParams());
    // 종료 뒤 시간은 다음 시도나 새 판 전까지 paused(또는 background)로 쌓는다.
    _syncRoundPhase();
  }

  /// 시간 상태 우선순위: 백그라운드 > 엔진 정지/결과/메뉴/종료된 시도 > 인트로/Last Hurrah > 플레이.
  /// Last Hurrah는 isPlaying이 false여도 엔진이 돌므로 system이다.
  RoundPhase get _currentRoundPhase {
    if (_inBackground) return RoundPhase.background;
    if (timeUp || paused || _roundEndLogged) return RoundPhase.paused;
    if (lastHurrahActive) return RoundPhase.system;
    if (!_isPlaying) return RoundPhase.paused;
    if (board.introFillInProgress) return RoundPhase.system;
    return RoundPhase.active;
  }

  void _syncRoundPhase() => _roundTiming.setPhase(_currentRoundPhase);

  @override
  void pauseEngine() {
    super.pauseEngine();
    _syncRoundPhase();
  }

  @override
  void resumeEngine() {
    super.resumeEngine();
    _syncRoundPhase();
  }

  /// 직전 결과 화면에 보일 랭크 상승과 배지 획득. 없으면 null.
  RecordsUpdate? latestRecordsUpdate;
  RoundRecord? _recordsApplied;
  int? _recordsAppliedAttempt;
  MatchBoardGameStats? _recordsAppliedStats;

  /// 판(레벨 모드는 스테이지) 결과를 로컬 누적 기록에 반영한다.
  /// 광고 이어하기 뒤 같은 스테이지가 다시 끝나면 앞서 반영한 몫을 뺀다.
  void commitRecords({required int level}) {
    final stats = board.stats..finishMove();
    final round = RoundRecord.fromStats(
      stats,
      mode: gameMode,
      score: board.score,
      maxCombo: board.maxCombo,
      level: level,
    );
    final update = RecordsStore.apply(
      round.minus(
        _recordsApplied,
        sameScore: _recordsAppliedAttempt == _stageAttemptSerial,
        sameStats: identical(_recordsAppliedStats, stats),
      ),
      log: capturePlayEventSink(),
    );
    _recordsApplied = round;
    _recordsAppliedAttempt = _stageAttemptSerial;
    _recordsAppliedStats = stats;
    latestRecordsUpdate = update.isEmpty ? null : update;
  }

  Future<void> _warmInitialEffectPools() {
    return _specialEffectPool.warm(burstCount: 8);
  }

  @override
  void onRemove() {
    uninstallMatchBoardQaBridge(this);
    if (_effectPoolsReady) {
      _specialEffectPool.clear();
      _effectPoolsReady = false;
    }
    // GameView는 이탈 후 새 게임을 만든다. 정지된 엔진의 다음 tick을 기다리지
    // 않고 자식의 atlas/ticker를 해제한다. 공유 이미지 캐시는 유지한다.
    removeAll(children);
    processLifecycleEvents();
    super.onRemove();
  }

  Future<void> _fetchTop1() async {
    final result = await RankingService.fetchTop1();
    final top = result.data;
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

  /// 실제 8×8 셀 묶음의 가로 영역. HUD 하단/상단 보조 바와 폭을 맞추는 기준.
  Rect get boardContentRect => _boardContentRectImpl;

  /// 화면에 보이는 보드 프레임 외곽 영역.
  Rect get boardFrameRect => _boardFrameRectImpl;

  /// 인트로 중에는 Flutter [IntroBlock] 오버레이로 전체 입력 차단(투명).
  void _syncIntroInputBlock() => _syncIntroInputBlockImpl();

  void _syncLayout() => _syncLayoutImpl();

  bool get _roundStartBoardReady =>
      _firstBoardFrameRendered && !board.introFillInProgress;

  void _playStartSfxWhenBoardReady() {
    if (_roundStartBoardReady) {
      scheduleMicrotask(() => SoundManager.playSfx(AssetPaths.sfxStart));
    } else {
      _roundStartSfxPending = true;
    }
  }

  void _markRoundStartIntroComplete(BoardFillIntroKind kind) {
    if (kind != BoardFillIntroKind.roundStart) return;
    if (!_firstRoundReadyCompleter.isCompleted) {
      _firstRoundReadyCompleter.complete();
    }
    if (_roundStartSfxPending && _roundStartBoardReady) {
      _roundStartSfxPending = false;
      scheduleMicrotask(() => SoundManager.playSfx(AssetPaths.sfxStart));
    }
  }

  bool get _canMarkFirstBoardFrameRendered {
    if (_firstBoardFrameRendered || !hasLayout || size.x <= 0 || size.y <= 0) {
      return false;
    }
    if (board.tileSize <= 0 || board.getGem(0, 0) == null) return false;
    return true;
  }

  void _markFirstBoardFrameRenderedIfReady() {
    if (!_canMarkFirstBoardFrameRendered) return;
    _firstBoardFrameRendered = true;
    if (!_firstBoardFrameCompleter.isCompleted) {
      _firstBoardFrameCompleter.complete();
    }
    if (_roundStartSfxPending && _roundStartBoardReady) {
      _roundStartSfxPending = false;
      scheduleMicrotask(() => SoundManager.playSfx(AssetPaths.sfxStart));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncLayout();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _markFirstBoardFrameRenderedIfReady();
  }

  void pauseGame() {
    board.clearHint();
    _pauseGameImpl();
  }

  void resumeGame() => _resumeGameImpl();

  /// 타임 모드 HUD 랭킹 버튼: 게임 일시정지 + 랭킹 팝업.
  void pauseForRankingPopup() => _pauseForRankingPopupImpl();

  void closeRankingPopup() => _closeRankingPopupImpl();
  bool continueStageAfterAd() => _continueStageAfterAdImpl();
  void continueAfterLevelUp() => _continueAfterLevelUpImpl();
  void showLevelUpPopupAfterCelebration() =>
      _showLevelUpPopupAfterCelebrationImpl();
  void showStageInventory() => _showStageInventoryImpl();
  void closeStageInventory({bool apply = false}) =>
      _closeStageInventoryImpl(apply: apply);

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // 재개는 기존처럼 PauseMenu에서 한다. 시간 상태만 백그라운드에서 뺀다.
        _inBackground = false;
        _syncRoundPhase();
        return;
      case AppLifecycleState.inactive:
        return;
      case AppLifecycleState.detached:
        super.lifecycleStateChange(state);
        return;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _inBackground = true;
        _syncRoundPhase();
        // 마무리 중 백그라운드: 남은 발동을 즉시 계산하고 결과로 간다.
        _completeLastHurrah(instant: true);
        board.clearHint();
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
    board.idleHintsEnabled =
        gameMode == JewelGameMode.simple &&
        isPlaying &&
        !timeUp &&
        activeTargetItem == null &&
        pendingImmediateItemConfirm == null;
    _syncRoundPhase();
    board.update(dt);
    _spawnSpecialEffectEvents();
    _updateBoardShake(dt);
    _updateItemFeedback(dt);

    _updateTimedModeClock(dt);
    _updateLastHurrah(dt);
    _updateProgressionMode();
    _saveBestScoreIfChanged();
    _syncRoundPhase();
    super.update(dt);
  }

  int _onSpeedBonusSwap() {
    final bonus = speedBonus.onValidSwap();
    // 효과음 없음: 스왑 직후 콤보 피치 효과음과 겹친다.
    if (bonus > 0 && _speedBonusBadge.isMounted) _speedBonusBadge.show(bonus);
    return bonus;
  }

  void handleBoardTap(double x, double y) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress) {
      return;
    }
    if (activeTargetItem != null) {
      _handleItemTargetTap(x, y);
      return;
    }
    // Flame은 드래그 시작에도 누름을 먼저 보내므로 누름 수는 세지 않고 성공한 결과만 센다.
    final stats = board.stats;
    final swapsBefore = stats.validSwaps;
    final activatedBefore = stats.specialGemsActivated;
    board.handleTap(x, y);
    if (stats.validSwaps > swapsBefore) {
      _roundInput.tapSwaps++;
      _recordFirstInputSuccess();
    } else if (stats.specialGemsActivated > activatedBefore) {
      _roundInput.specialTaps++;
      _recordFirstInputSuccess();
    }
  }

  void _recordFirstInputSuccess() =>
      _roundInput.recordSuccess(_roundTiming.snapshot()['active_s']! as double);

  /// HUD 메뉴 버튼 이용(표본). 백그라운드 자동 일시정지는 HUD를 거치지 않아 세지 않는다.
  void hudMenuAction(String action, void Function() open) {
    eventLogger.logBehavior('game_menu_action', {
      'action': action,
      'mode': gameMode.name,
    }, context: _playContext);
    open();
  }

  /// 보드 누름을 뗄 때. 누른 하이퍼가 교환되지 않았으면 탭 발동한다.
  void handleBoardTapUp() {
    if (!isPlaying || timeUp || activeTargetItem != null) {
      board.cancelPendingHyperTap();
      return;
    }
    if (board.confirmPendingHyperTap()) {
      _roundInput.specialTaps++;
      _recordFirstInputSuccess();
    }
  }

  /// 스와이프 입력: 시작 좌표(px)에서 [dr]/[dc] 방향으로 1칸 스왑 시도.
  bool handleBoardSwipe(
    double startX,
    double startY,
    double currentX,
    double currentY,
    int dr,
    int dc,
  ) {
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress ||
        activeTargetItem != null) {
      return false;
    }
    board.clearHint();
    final cell = board.pixelToCell(startX, startY);
    if (cell == null) return false;
    final fromRow = cell.x;
    final fromCol = cell.y;
    final toRow = fromRow + dr;
    final toCol = fromCol + dc;
    if (!board.isInside(toRow, toCol) ||
        !board.canTrySwapNow(fromRow, fromCol, toRow, toCol)) {
      return false;
    }
    board.selected = null;
    final swapped = board.trySwap(fromRow, fromCol, toRow, toCol);
    if (swapped) {
      _roundInput.dragSwaps++;
      _recordFirstInputSuccess();
    }
    if (!swapped && board.getGem(fromRow, fromCol) != null) {
      board.startInvalidDragFeedback(
        row: fromRow,
        col: fromCol,
        startX: startX,
        startY: startY,
        currentX: currentX,
        currentY: currentY,
      );
    }
    return swapped;
  }

  bool updateInvalidBoardDrag(double x, double y) {
    if (!isPlaying || timeUp) return false;
    return board.updateInvalidDragFeedback(x, y);
  }

  void endBoardDrag() {
    board.endInvalidDragFeedback();
  }

  void requestHint() => _requestHintImpl();

  bool isItemEnabled(ItemKind item) => switch (item) {
    ItemKind.timeSlip => hasTimedClock && !timeUp,
    ItemKind.hintPlus => hasLimitedHints,
    _ => true,
  };

  bool isInventoryItemAvailable(ItemKind item) =>
      runInventory.quantityOf(item) > 0 && isItemEnabled(item);

  bool isLoadoutSlotUsable(StageLoadoutSlot slot) {
    final item = slot.item;
    return !slot.locked &&
        item != null &&
        isItemEnabled(item) &&
        (!usesPhase2Inventory || runInventory.quantityOf(item) > 0);
  }

  bool assignNextStageLoadoutSlot(int slotIndex, ItemKind item) {
    final before = nextStageLoadoutDraft;
    nextStageLoadoutDraft = nextStageLoadoutDraft.assignOpenSlot(
      slotIndex: slotIndex,
      item: item,
      inventory: runInventory,
      isAllowed: isItemEnabled,
    );
    final changed = !identical(before, nextStageLoadoutDraft);
    if (changed && !isInPlayInventoryOpen) {
      logPlayEvent('item_equipped', {
        'item_kind': item.name,
        'slot_index': slotIndex,
      });
    }
    return changed;
  }

  bool canUseTestItem(ItemKind item) {
    if (!isItemEnabled(item)) return false;
    if (usesPhase2Inventory &&
        (!stageLoadout.contains(item) || runInventory.quantityOf(item) <= 0)) {
      return false;
    }
    return isPlaying &&
        !timeUp &&
        !board.inputLocked &&
        !board.introFillInProgress &&
        board.state == 'idle';
  }

  bool startItemTargeting(ItemKind item) {
    if (!item.needsTarget || !canUseTestItem(item)) {
      _showItemFeedback(_blockedItemMessage(item));
      return false;
    }
    activeTargetItem = item;
    selectedPrismColor = null;
    _clearItemFeedback();
    board.state = 'itemTargeting';
    board.stageTimer = 3600;
    board.selected = null;
    dismissHint();
    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    return true;
  }

  bool useTestItem(ItemKind item) {
    if (activeTargetItem == item) {
      cancelItemTargeting();
      return true;
    }
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress ||
        board.state != 'idle') {
      _showItemFeedback('잠시 후 사용하세요');
      return false;
    }
    if (!isItemEnabled(item)) {
      _showItemFeedback(_blockedItemMessage(item));
      SoundManager.playSfx(AssetPaths.sfxFail);
      return false;
    }
    dismissHint();
    if (item.needsTarget) {
      return startItemTargeting(item);
    }
    return _activateImmediateItem(item);
  }

  bool usePhaseOneItem(ItemKind item) {
    if (item.needsTarget) return useTestItem(item);
    return requestImmediateItemConfirm(item);
  }

  bool requestImmediateItemConfirm(ItemKind item) {
    if (item.needsTarget) return false;
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress ||
        board.state != 'idle') {
      _showItemFeedback('잠시 후 사용하세요');
      return false;
    }
    if (!isItemEnabled(item)) {
      _showItemFeedback(_blockedItemMessage(item));
      SoundManager.playSfx(AssetPaths.sfxFail);
      return false;
    }
    activeTargetItem = null;
    selectedPrismColor = null;
    pendingImmediateItemConfirm = item;
    dismissHint();
    _clearItemFeedback();
    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    return true;
  }

  bool confirmImmediateItemUse() {
    final item = pendingImmediateItemConfirm;
    if (item == null) return false;
    pendingImmediateItemConfirm = null;
    if (item.needsTarget) return false;
    if (!isPlaying ||
        timeUp ||
        board.inputLocked ||
        board.introFillInProgress ||
        board.state != 'idle') {
      _showItemFeedback('잠시 후 사용하세요');
      return false;
    }
    return _activateImmediateItem(item);
  }

  void cancelImmediateItemConfirm() {
    if (pendingImmediateItemConfirm == null) return;
    pendingImmediateItemConfirm = null;
    _showItemFeedback('아이템 사용 취소');
    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
  }

  bool selectPrismTargetColor(int color) {
    if (activeTargetItem != ItemKind.prismTransform) return false;
    if (color < 1 || color > board.colorCount) return false;
    selectedPrismColor = color;
    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
    return true;
  }

  void cancelItemTargeting() {
    final item = activeTargetItem;
    if (item == null) return;
    _logItemEvent('item_target_cancel', item);
    activeTargetItem = null;
    selectedPrismColor = null;
    pendingImmediateItemConfirm = null;
    if (board.state == 'itemTargeting') {
      board.state = 'idle';
      board.stageTimer = 0;
    }
    board.selected = null;
    _showItemFeedback('아이템 선택 취소');
    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
  }

  void _handleItemTargetTap(double x, double y) {
    final item = activeTargetItem;
    if (item == null) return;
    if (item == ItemKind.prismTransform && selectedPrismColor == null) {
      SoundManager.playSfx(AssetPaths.sfxFail);
      return;
    }
    final cell = board.pixelToCell(x, y);
    if (cell == null) {
      cancelItemTargeting();
      return;
    }
    activeTargetItem = null;
    final prismColor = selectedPrismColor;
    selectedPrismColor = null;
    if (board.state == 'itemTargeting') {
      board.state = 'idle';
      board.stageTimer = 0;
    }
    final used = _activateTargetedItem(
      item,
      cell.x,
      cell.y,
      prismColor: prismColor,
    );
    if (used) {
      _consumeRunInventoryIfNeeded(item);
      _roundInput.itemsUsed++;
      _logItemEvent('item_used', item);
    }
    _showItemFeedback(used ? _targetUsedMessage(item) : '선택한 보석에는 사용할 수 없습니다');
    SoundManager.playSfx(used ? AssetPaths.sfxSpecialGem : AssetPaths.sfxFail);
  }

  bool _activateTargetedItem(
    ItemKind item,
    int row,
    int col, {
    int? prismColor,
  }) => switch (item) {
    ItemKind.runeHammer => board.removeSingleCellForItem(row, col),
    ItemKind.ancientBomb => board.triggerAreaItem(
      row,
      col,
      GemKind.bomb,
      'ancient bomb',
    ),
    ItemKind.thorHammer => board.triggerAreaItem(
      row,
      col,
      GemKind.star,
      'thor hammer',
    ),
    ItemKind.hyperCube => board.triggerHyperCubeItem(row, col),
    ItemKind.prismTransform => board.useBoardItem(
      item,
      row: row,
      col: col,
      prismColor: prismColor,
    ),
    ItemKind.fateShuffle || ItemKind.timeSlip || ItemKind.hintPlus => false,
  };

  bool _activateImmediateItem(ItemKind item) {
    var used = false;
    var feedback = '지금은 사용할 수 없습니다';
    switch (item) {
      case ItemKind.fateShuffle:
        used = board.shuffleOrdinaryGemsPreservingSpecials();
        feedback = used ? '보드를 섞었습니다' : '지금은 섞을 수 없습니다';
      case ItemKind.timeSlip:
        final before = timeRemaining;
        used = _applyTimeSlipItem();
        final gained = (timeRemaining - before).round();
        feedback = used ? '타임 슬립 +$gained초' : '시간이 이미 최대입니다';
      case ItemKind.hintPlus:
        used = _applyHintPlusItem();
        feedback = used ? '힌트를 표시했습니다' : '표시할 힌트가 없습니다';
      case ItemKind.runeHammer ||
          ItemKind.ancientBomb ||
          ItemKind.thorHammer ||
          ItemKind.hyperCube ||
          ItemKind.prismTransform:
        break;
    }
    if (used) {
      _consumeRunInventoryIfNeeded(item);
      _roundInput.itemsUsed++;
      _logItemEvent('item_used', item);
    }
    _showItemFeedback(feedback);
    SoundManager.playSfx(used ? AssetPaths.sfxSpecialGem : AssetPaths.sfxFail);
    return used;
  }

  /// 아이템 이벤트 공통 파라미터(Product Spec 웹 테스트 이벤트 로깅 필수 이벤트).
  void _logItemEvent(String name, ItemKind item) {
    logPlayEvent(name, {
      'item_kind': item.name,
      'target_required': item.needsTarget,
      'mode': gameMode.name,
      if (isProgressionMode) 'level': progressionLevel,
      if (hasTimedClock) 'time_left': timeRemaining.round(),
    });
  }

  void _consumeRunInventoryIfNeeded(ItemKind item) {
    if (!usesPhase2Inventory || !stageLoadout.contains(item)) return;
    runInventory.tryConsume(item);
  }

  bool _applyTimeSlipItem() {
    if (!hasTimedClock || timeUp) return false;
    final before = timeRemaining;
    _applyTimedModeTimeBonus(10);
    return timeRemaining > before;
  }

  bool _applyHintPlusItem() {
    if (!hasLimitedHints) return false;
    return board.showHint();
  }

  void _updateItemFeedback(double dt) {
    if (_itemFeedbackTimer <= 0) return;
    _itemFeedbackTimer -= dt;
    if (_itemFeedbackTimer <= 0) {
      _clearItemFeedback();
    }
  }

  void _showItemFeedback(String text, {double seconds = 1.4}) {
    _itemFeedbackText = text;
    _itemFeedbackTimer = seconds;
  }

  void _clearItemFeedback() {
    _itemFeedbackText = null;
    _itemFeedbackTimer = 0;
  }

  String _itemTargetPrompt(ItemKind item) => switch (item) {
    ItemKind.runeHammer => '룬 망치: 제거할 보석 선택',
    ItemKind.ancientBomb => '고대 폭탄: 폭발 중심 선택',
    ItemKind.thorHammer => '토르 망치: 십자 중심 선택',
    ItemKind.hyperCube => '하이퍼 큐브: 같은 색 제거할 보석 선택',
    ItemKind.prismTransform =>
      selectedPrismColor == null ? '프리즘: 바꿀 색 선택' : '프리즘: 바꿀 보석 선택',
    ItemKind.fateShuffle ||
    ItemKind.timeSlip ||
    ItemKind.hintPlus => '보석을 선택하세요',
  };

  String _targetUsedMessage(ItemKind item) => switch (item) {
    ItemKind.runeHammer => '보석을 제거했습니다',
    ItemKind.ancientBomb => '폭발 아이템 발동',
    ItemKind.thorHammer => '십자 번개 발동',
    ItemKind.hyperCube => '같은 색 보석 제거',
    ItemKind.prismTransform => '보석 변환 완료',
    ItemKind.fateShuffle || ItemKind.timeSlip || ItemKind.hintPlus => '아이템 발동',
  };

  String _blockedItemMessage(ItemKind item) => switch (item) {
    ItemKind.timeSlip => hasTimedClock ? '지금은 사용할 수 없습니다' : '타임 모드 전용 아이템',
    ItemKind.hintPlus => hasLimitedHints ? '지금은 사용할 수 없습니다' : '힌트 제한 모드 전용 아이템',
    _ => '잠시 후 사용하세요',
  };

  /// 힌트 디밍만 해제 (보드 탭 외 UI 탭 등).
  void dismissHint() => _dismissHintImpl();

  void showHowToPlay() {
    board.clearHint();
    _showHowToPlayImpl();
  }

  void closeHowToPlay() => _closeHowToPlayImpl();

  void showGameStats() => _showGameStatsImpl();

  void closeGameStats() => _closeGameStatsImpl();

  void shuffleBoard() => _shuffleBoardImpl();

  void debugTriggerSpecialEffects() => _debugTriggerSpecialEffectsImpl();

  void debugTriggerSpecialEffect(GemKind kind, {double durationScale = 1.0}) =>
      _debugTriggerSpecialEffectImpl(kind, durationScale: durationScale);

  void debugShowNoMovesOverlay() {
    _showNoMovesOverlay();
  }

  void newBoard() => _newBoardImpl();

  /// 매치 불성립으로 되돌아간 교환. 입력 계수는 이 경로에서만 올린다.
  void _onInvalidSwap() {
    _roundInput.invalidSwaps++;
    SoundManager.playSfx(AssetPaths.sfxFail);
  }

  /// [seconds]는 정수 초. [timedMaxTimeSeconds]까지 남은 여유(`room`)만큼만 가산하고,
  /// 보상 초 중 **초과분은 제외**(버림)한다.
  void _applyTimedModeTimeBonus(int seconds) =>
      _applyTimedModeTimeBonusImpl(seconds);

  void _showNoMovesOverlay() => _showNoMovesOverlayImpl();
}
