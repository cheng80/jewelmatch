import 'dart:math';

import 'package:flutter/material.dart';

import 'match_board_matching.dart';
import 'match_board_models.dart';
import 'match_board_spawn_classifier.dart';
import 'match_board_specials.dart';

export 'match_board_models.dart';

part 'match_board_resolution.dart';
part 'match_board_geometry.dart';
part 'match_board_generation.dart';
part 'match_board_input.dart';
part 'match_board_update.dart';

/// 8×8 등 격자 매치-3 보드 로직 (스왑, 연쇄, 특수 보석, 중력, 리필).
/// 좌표는 **0 기반** row, col 이다.
class MatchBoardLogic {
  MatchBoardLogic({
    required this.rows,
    required this.cols,
    this.colorCount = 6,
    this.onNoMoves,
    this.timedModeTimeRewardScale = 1.0,
    this.timedModeBonusBaseUnits = 1,
    this.timedModeBonusPerComboTierUnits = 1,
    this.onTimedModeTimeBonus,
    this.onInvalidSwap,
  }) {
    // `setGeometry`는 `generateFreshBoard`보다 먼저 호출될 수 있으므로
    // 빈 격자를 바로 준비해 둔다.
    resetCells();
  }

  final int rows;
  final int cols;
  final int colorCount;
  final void Function()? onNoMoves;

  /// 타임 모드 전용: 매치 제거 단계마다 **정수 초**만큼만 호출한다.
  final void Function(int secondsAdded)? onTimedModeTimeBonus;

  /// [MatchBoardGame.timedModeTimeRewardScale] 전달.
  final double timedModeTimeRewardScale;

  /// 기준 보상(정수 초). [MatchBoardGame.timedModeBonusBaseUnits]와 동기화.
  final int timedModeBonusBaseUnits;

  /// 콤보 단계당 가산(정수 초). [MatchBoardGame.timedModeBonusPerComboTierUnits]와 동기화.
  final int timedModeBonusPerComboTierUnits;

  /// 매치가 나오지 않아 스왑이 되돌아갈 때 (잘못된 스왑).
  final void Function()? onInvalidSwap;

  /// 보석 제거 직후 호출. 파티클·SFX 등 연출용.
  /// [bigMatch]: 4개 이상 매치 그룹 존재, [hasSpecial]: 특수 보석 발동 포함.
  void Function(
    List<({int row, int col, int color})> cells,
    bool bigMatch,
    bool hasSpecial,
    int combo,
  )?
  onGemsRemoved;

  double boardX = 0;
  double boardY = 0;
  double tileSize = 56;

  final List<List<BoardGem?>> cells = [];
  String state = 'idle';
  int score = 0;
  int combo = 0;
  int lastCombo = 0;

  /// 이번 라운드에서 달성한 연쇄 콤보 최댓값 (한 번의 스왑으로 이어진 매치 단계 기준).
  int maxCombo = 0;
  Point<int>? selected;
  Point<int>? _hintA;
  Point<int>? _hintB;

  /// 힌트로 표시할 두 칸 (행·열). 없으면 null. 렌더러에서 이 두 칸에만 흰색 펄스.
  Point<int>? get hintCellA => _hintA;
  Point<int>? get hintCellB => _hintB;

  int _nextGemId = 1;
  bool inputLocked = false;
  double lockTimer = 0;
  final List<FlashEffect> flashEffects = [];

  /// 직전 매치 데이터 — 파티클 판정(bigMatch 여부)에 사용.
  MatchData? _lastMatchData;

  MoveInfo? pendingMoveInfo;
  Map<String, bool>? pendingRemovalSet;
  String? pendingResultLabel;

  /// UI에서 `localizations` 넣기 전 폴백.
  String lastActionText = '';

  final Random _random = Random();

  /// BoardGem 오브젝트 풀. 제거된 보석을 여기 반납하고, 생성 시 재활용한다.
  final List<BoardGem> _gemPool = [];
  final List<SpecialEffectEvent> _specialEffectEvents = [];

  /// 풀에서 꺼내거나 새로 생성한 BoardGem을 반환한다.
  BoardGem _acquireGem({
    required int id,
    required int color,
    required GemKind kind,
    required int row,
    required int col,
    required double x,
    required double y,
    required double targetX,
    required double targetY,
  }) {
    if (_gemPool.isNotEmpty) {
      final gem = _gemPool.removeLast();
      gem.reset(
        id: id,
        color: color,
        kind: kind,
        row: row,
        col: col,
        x: x,
        y: y,
        targetX: targetX,
        targetY: targetY,
      );
      return gem;
    }
    return BoardGem(
      id: id,
      color: color,
      kind: kind,
      row: row,
      col: col,
      x: x,
      y: y,
      targetX: targetX,
      targetY: targetY,
    );
  }

  /// 제거된 보석을 풀에 반납한다.
  void _releaseGem(BoardGem gem) {
    _gemPool.add(gem);
  }

  /// 첫 보드·재시작 시 낙하 인트로 연출 중이면 true.
  bool introFillInProgress = false;

  /// 인트로: **한 줄씩** 낙하(0 = 맨 아래 줄, … rows-1 = 맨 위 줄). 총 [rows]번이면 전부 착지.
  int _introWaveIndex = 0;

  BoardFillIntroKind _pendingIntroKind = BoardFillIntroKind.roundStart;

  /// 인트로가 끝나 모든 보석이 제자리에 안착했을 때 한 번 호출 (종류에 따라 SFX 분기).
  void Function(BoardFillIntroKind kind)? onIntroFillComplete;

  static const double removeDelay = 0.09;
  static const double fallingDelay = 0.11;
  static const double refillDelay = 0.11;
  static const double checkingDelay = 0.09;
  static const double invalidSwapLock = 0.04;
  static const double shuffleLock = 0.08;
  static const double defaultLock = 0.10;
  static const double tweenSpeed = 18;

  /// 인트로 줄 낙하만 — 일반 스왑/중력과 분리. 전체 8줄 합쳐 약 1.5~1.6초(기본 타일·60fps 근사).
  static const double introTweenSpeed = 29;
  static const double flashDuration = 0.18;
  static const double flashAlpha = 0.7;
  static const int scoreBase = 100;
  static const int scoreExtraPerGem = 50;

  /// 표시용 팔레트 (Love2D `palette`와 동일 계열).
  static const List<Color> palette = [
    Color(0xFFE65A68),
    Color(0xFF469FE2),
    Color(0xFFF0B84F),
    Color(0xFF66C982),
    Color(0xFFA56ED4),
    Color(0xFFEF8B48),
    Color(0xFF55C8C4),
  ];

  double stageTimer = 0;

  String _cellKey(int row, int col) => matchBoardCellKey(row, col);

  List<SpecialEffectEvent> consumeSpecialEffectEvents() {
    final events = List<SpecialEffectEvent>.unmodifiable(_specialEffectEvents);
    _specialEffectEvents.clear();
    return events;
  }

  bool isInside(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  void resetCells() {
    for (final row in cells) {
      for (final gem in row) {
        if (gem != null) _releaseGem(gem);
      }
    }
    cells.clear();
    _specialEffectEvents.clear();
    for (var r = 0; r < rows; r++) {
      cells.add(List<BoardGem?>.filled(cols, null, growable: false));
    }
  }

  int _nextId() => _nextGemId++;

  void setGeometry({
    required double x,
    required double y,
    required double tile,
  }) => _setGeometryImpl(x: x, y: y, tile: tile);

  /// 목표보다 위(작은 y)로 둘 거리. `rows+4` 타일이면 보드 상단(boardY) 밖까지 충분히 올라간다.
  double get _introFallDy => _introFallDyImpl;

  /// 인트로: 슬롯 **위**에서 대기(낙하 직전). 각 칸마다 목표보다 위에 둔다.
  double _introHoldYAbove(BoardGem gem) => _introHoldYAboveImpl(gem);

  /// 현재 웨이브에서 낙하 중인 **행** 인덱스 (맨 아래 줄이 먼저).
  int get _introActiveRow => _introActiveRowImpl;

  /// 레이아웃 변경 중 인트로일 때 타깃만 갱신하고 대기/이동 중 위치를 맞춘다.
  void _syncIntroPositionsAfterGeometry() =>
      _syncIntroPositionsAfterGeometryImpl();

  /// [_fillBoardWithRandomValidLayout] 직후: **줄 단위** 낙하(아래→위 [rows]번), 마스크·화면 밖 스폰은 유지.
  void prepareIntroFill({
    BoardFillIntroKind kind = BoardFillIntroKind.roundStart,
  }) => _prepareIntroFillImpl(kind: kind);

  void _updateGemTarget(BoardGem gem) => _updateGemTargetImpl(gem);

  Offset cellToPixel(int row, int col) => _cellToPixelImpl(row, col);

  Point<int>? pixelToCell(double px, double py) => _pixelToCellImpl(px, py);

  BoardGem createGem(
    int row,
    int col,
    int color,
    GemKind kind, {
    int spawnOffsetRows = 0,
  }) => _createGemImpl(row, col, color, kind, spawnOffsetRows: spawnOffsetRows);

  BoardGem? getGem(int row, int col) {
    if (!isInside(row, col)) return null;
    return cells[row][col];
  }

  void setGem(int row, int col, BoardGem? gem) {
    cells[row][col] = gem;
    if (gem != null) {
      gem.row = row;
      gem.col = col;
      _updateGemTarget(gem);
    }
  }

  int? gemMatchColor(BoardGem? gem) => gemMatchColorToken(gem);

  bool causesImmediateMatch(int row, int col, int color) =>
      _causesImmediateMatchImpl(row, col, color);

  int randomAllowedColor(int row, int col) => _randomAllowedColorImpl(row, col);

  /// 무작위로 유효한 초기 보드를 채운다 (즉시 매치 없음·최소 한 수 있는 상태). 기존 보석은 제거된다.
  void _fillBoardWithRandomValidLayout() =>
      _fillBoardWithRandomValidLayoutImpl();

  /// [newBoard]·재시작·셔플 등 공통: 보드 재생성 후 인트로 연출 여부만 선택.
  void generateFreshBoard({
    bool withIntroFill = true,
    BoardFillIntroKind introKind = BoardFillIntroKind.roundStart,
  }) => _generateFreshBoardImpl(
    withIntroFill: withIntroFill,
    introKind: introKind,
  );

  bool areAdjacent(int ar, int ac, int br, int bc) {
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  void swapCells(int ar, int ac, int br, int bc) {
    final a = getGem(ar, ac);
    final b = getGem(br, bc);
    cells[ar][ac] = b;
    cells[br][bc] = a;
    if (a != null) {
      a.row = br;
      a.col = bc;
      _updateGemTarget(a);
    }
    if (b != null) {
      b.row = ar;
      b.col = ac;
      _updateGemTarget(b);
    }
  }

  bool hasMatches() => findAllMatches().groups.isNotEmpty;

  MatchData findAllMatches() =>
      findAllBoardMatches(rows: rows, cols: cols, getGem: getGem);

  MatchData findMatchesAt(int row, int col) {
    return findBoardMatchesAt(all: findAllMatches(), row: row, col: col);
  }

  Point<int> pickSpawnCell(MatchGroup group, Set<String> movedCells) {
    return pickMatchSpawnCell(group, movedCells);
  }

  List<SpecialSpawn> classifyMatchGroups(
    MatchData matchData,
    Point<int>? movedA,
    Point<int>? movedB,
  ) {
    return classifyBoardMatchGroups(
      matchData: matchData,
      getGem: getGem,
      movedA: movedA,
      movedB: movedB,
    );
  }

  Map<String, bool> buildRemovalSet(
    MatchData matchData,
    List<SpecialSpawn> spawns,
  ) {
    return buildBoardRemovalSet(matchData, spawns);
  }

  void applySpawnInfo(List<SpecialSpawn> spawns) {
    applySpecialSpawnInfo(spawns: spawns, getGem: getGem);
  }

  int? pickExistingColor() {
    final colors = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = getGem(r, c);
        if (gem != null && gem.kind != GemKind.hyper) {
          colors.add(gem.color);
        }
      }
    }
    if (colors.isEmpty) return null;
    return colors[_random.nextInt(colors.length)];
  }

  bool _isSpecial(GemKind k) => isSpecialGemKind(k);

  List<MatchChainItem> buildSpecialQueue(Map<String, bool> removalSet) =>
      buildSpecialQueueForRemoval(removalSet: removalSet, getGem: getGem);

  void enqueueTriggeredSpecial(
    List<MatchChainItem> queue,
    Map<String, bool> queued,
    int row,
    int col,
    int? triggerColor,
  ) => enqueueTriggeredSpecialForBoard(
    queue: queue,
    queued: queued,
    getGem: getGem,
    row: row,
    col: col,
    triggerColor: triggerColor,
  );

  void markCellForRemoval(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
    Map<String, bool> queued,
    int row,
    int col,
    int? triggerColor,
  ) => markSpecialCellForRemoval(
    removalSet: removalSet,
    queue: queue,
    queued: queued,
    getGem: getGem,
    rows: rows,
    cols: cols,
    row: row,
    col: col,
    triggerColor: triggerColor,
  );

  void activateSpecials(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
  ) => _specialEffectEvents.addAll(
    activateSpecialsForBoard(
      removalSet: removalSet,
      queue: queue,
      getGem: getGem,
      pickExistingColor: pickExistingColor,
      rows: rows,
      cols: cols,
    ),
  );

  void addFlashEffect(int row, int col) {
    final p = cellToPixel(row, col);
    flashEffects.add(
      FlashEffect(x: p.dx, y: p.dy, size: tileSize, timer: flashDuration),
    );
  }

  bool triggerSpecialSwap(int ar, int ac, int br, int bc) =>
      _triggerSpecialSwapImpl(ar, ac, br, bc);

  bool trySwap(int ar, int ac, int br, int bc) => _trySwapImpl(ar, ac, br, bc);

  bool hasAnyValidMove() => getAllValidMoves().isNotEmpty;

  void clearHint() => _clearHintImpl();

  /// 유효한 스왑 하나를 골라 두 칸을 힌트로 표시한다. 없으면 false.
  /// 해제는 [clearHint] — 탭·스왑·보드 재생성 등에서 호출.
  bool showHint() => _showHintImpl();

  List<ValidMovePair> getAllValidMoves() => _getAllValidMovesImpl();

  void shuffle() => _shuffleImpl();

  int removeMarkedGems(Map<String, bool> removalSet) =>
      _removeMarkedGemsImpl(removalSet);

  bool applyGravity() => _applyGravityImpl();

  int refillBoard() => _refillBoardImpl();

  void resolveMatchCascade(MoveInfo moveInfo) =>
      _resolveMatchCascadeImpl(moveInfo);

  void startRemovalPhase(Map<String, bool> removalSet) =>
      _startRemovalPhaseImpl(removalSet);

  bool beginNextResolutionCycle() => _beginNextResolutionCycleImpl();

  void finishResolutionFlow() => _finishResolutionFlowImpl();

  void resolveSpecialSwap(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
    String label,
  ) => _resolveSpecialSwapImpl(removalSet, queue, label);

  void advanceResolutionStep() => _advanceResolutionStepImpl();

  void lockInput([double? duration]) {
    inputLocked = true;
    lockTimer = duration ?? defaultLock;
  }

  void update(double dt) => _updateImpl(dt);

  void clearSelection() => _clearSelectionImpl();

  void selectCell(int row, int col) => _selectCellImpl(row, col);

  /// 화면 좌표 탭. 첫 탭은 선택, 인접 두 번째 탭은 스왑.
  void handleTap(double px, double py) => _handleTapImpl(px, py);
}
