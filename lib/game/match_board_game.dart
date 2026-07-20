import 'dart:async';
import 'dart:math' show min;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import '../resources/sound_manager.dart';
import '../services/game_settings.dart';
import '../services/ranking_service.dart';
import 'components/match_board_renderer.dart';
import 'components/match_game_hud.dart';
import 'components/particle_burst.dart';
import 'components/special_effect_pool.dart';
import 'item_inventory.dart';
import 'item_kind.dart';
import 'jewel_game_mode.dart';
import 'jewel_rank_progression.dart';
import 'match_board_camera_shake.dart';
import 'match_board_logic.dart';
import 'match_board_qa_bridge.dart';
import 'match_board_specials.dart';
import 'stage_reward.dart';

part 'match_board_game_vfx.dart';
part 'match_board_game_debug_vfx.dart';
part 'match_board_game_flow.dart';
part 'match_board_game_layout.dart';
part 'match_board_game_mode_rules.dart';
part 'match_board_game_progression.dart';
part 'match_board_game_timing.dart';

const bool qaSpecialEffectsEnabled = bool.fromEnvironment('QA_SPECIAL_EFFECTS');

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
  }) {
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
      onInvalidSwap: _playInvalidSwapSfx,
    );
    board.onIntroFillComplete = (BoardFillIntroKind kind) {
      overlays.remove('IntroBlock');
      _markRoundStartIntroComplete(kind);
    };
    board.onGemsRemoved = _spawnParticles;
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
  late final ParticlePool _particlePool;
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

  bool isPlaying = true;
  bool timeUp = false;
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
  int get progressionTargetScore =>
      JewelRankProgression.scoreTargetForLevel(progressionLevel);
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
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();

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
    if (kIsWeb) {
      await _warmInitialEffectPools();
    }
    _effectPoolsReady = true;
    installMatchBoardQaBridge(this);

    if (isTimedMode) {
      _fetchTop1();
    }
  }

  Future<void> _warmInitialEffectPools() {
    return Future.wait([
      _particlePool.warm(burstCount: 10, particleCapacity: 18),
      _specialEffectPool.warm(burstCount: 8),
    ]);
  }

  @override
  void onRemove() {
    uninstallMatchBoardQaBridge(this);
    if (_effectPoolsReady) {
      _particlePool.clear();
      _specialEffectPool.clear();
      _effectPoolsReady = false;
    }
    super.onRemove();
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

  void pauseGame() => _pauseGameImpl();

  void resumeGame() => _resumeGameImpl();

  /// 타임 모드 HUD 랭킹 버튼: 게임 일시정지 + 랭킹 팝업.
  void pauseForRankingPopup() => _pauseForRankingPopupImpl();

  void closeRankingPopup() => _closeRankingPopupImpl();
  void continueAfterLevelUp() => _continueAfterLevelUpImpl();
  void showLevelUpPopupAfterCelebration() =>
      _showLevelUpPopupAfterCelebrationImpl();
  void showStageInventory() => _showStageInventoryImpl();
  void closeStageInventory() => _closeStageInventoryImpl();

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
    _updateBoardShake(dt);
    _updateItemFeedback(dt);

    _updateTimedModeClock(dt);
    _updateProgressionMode();
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
    if (activeTargetItem != null) {
      _handleItemTargetTap(x, y);
      return;
    }
    board.handleTap(x, y);
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
    if (!board.isInside(toRow, toCol)) return false;
    board.selected = null;
    final swapped = board.trySwap(fromRow, fromCol, toRow, toCol);
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
    return !identical(before, nextStageLoadoutDraft);
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
    if (activeTargetItem == null) return;
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
    }
    _showItemFeedback(feedback);
    SoundManager.playSfx(used ? AssetPaths.sfxSpecialGem : AssetPaths.sfxFail);
    return used;
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

  void showHowToPlay() => _showHowToPlayImpl();

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

  /// [seconds]는 정수 초. [timedMaxTimeSeconds]까지 남은 여유(`room`)만큼만 가산하고,
  /// 보상 초 중 **초과분은 제외**(버림)한다.
  void _playInvalidSwapSfx() {
    SoundManager.playSfx(AssetPaths.sfxFail);
  }

  void _applyTimedModeTimeBonus(int seconds) =>
      _applyTimedModeTimeBonusImpl(seconds);

  void _showNoMovesOverlay() => _showNoMovesOverlayImpl();
}
