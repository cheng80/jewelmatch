import 'dart:math';

import 'package:flutter/material.dart';

/// 인트로식 보드 채움 완료 시 구분. [BoardFillIntroKind.roundStart]만 Start 효과음.
enum BoardFillIntroKind {
  /// 첫 진입·재시작·새 보드
  roundStart,
  /// 노무브 셔플 등 — 연출만, Start 효과음 없음
  shuffleRefill,
}

/// 보석 종류. Love2D `board.lua`의 `kind` 문자열에 대응한다.
enum GemKind { normal, row, col, bomb, hyper }

/// 단일 보석 인스턴스 (논리 격자 + 화면 보간 좌표).
class BoardGem {
  BoardGem({
    required this.id,
    required this.color,
    required this.kind,
    required this.row,
    required this.col,
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
  });

  int id;
  int color;
  GemKind kind;
  int row;
  int col;
  double x;
  double y;
  double targetX;
  double targetY;
}

/// 제거 순간 플래시 이펙트.
class FlashEffect {
  FlashEffect({
    required this.x,
    required this.y,
    required this.size,
    required this.timer,
  });

  double x;
  double y;
  double size;
  double timer;
}

class MatchGroup {
  MatchGroup({
    required this.direction,
    required this.length,
    required this.color,
    required this.cells,
  });

  final String direction; // 'row' | 'col'
  final int length;
  final int color;
  final List<Point<int>> cells;
}

class MatchData {
  final Map<String, bool> cells = {};
  final List<MatchGroup> groups = [];
}

class MoveInfo {
  MoveInfo({required this.movedA, required this.movedB});

  final Point<int> movedA;
  final Point<int> movedB;
}

class SpecialSpawn {
  SpecialSpawn({
    required this.row,
    required this.col,
    required this.kind,
    required this.color,
  });

  final int row;
  final int col;
  final GemKind kind;
  final int color;
}

/// 8×8 등 격자 매치-3 보드 로직 (스왑, 연쇄, 특수 보석, 중력, 리필).
/// 좌표는 **0 기반** row, col 이다.
class MatchBoardLogic {
  MatchBoardLogic({
    required this.rows,
    required this.cols,
    this.colorCount = 6,
    this.onNoMoves,
  }) {
    // `setGeometry`는 `generateFreshBoard`보다 먼저 호출될 수 있으므로
    // 빈 격자를 바로 준비해 둔다.
    resetCells();
  }

  final int rows;
  final int cols;
  final int colorCount;
  final void Function()? onNoMoves;

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

  MoveInfo? pendingMoveInfo;
  Map<String, bool>? pendingRemovalSet;
  String? pendingResultLabel;

  /// UI에서 `localizations` 넣기 전 폴백.
  String lastActionText = '';

  final Random _random = Random();

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
    Color(0xFFE85150),
    Color(0xFF3BA8F0),
    Color(0xFFFCB838),
    Color(0xFF5EC76B),
    Color(0xFFB275E0),
    Color(0xFFF58530),
    Color(0xFF33D6CC),
  ];

  double stageTimer = 0;

  String _cellKey(int row, int col) => '$row:$col';

  bool isInside(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  void resetCells() {
    cells.clear();
    for (var r = 0; r < rows; r++) {
      cells.add(List<BoardGem?>.filled(cols, null, growable: false));
    }
  }

  int _nextId() => _nextGemId++;

  void setGeometry({
    required double x,
    required double y,
    required double tile,
  }) {
    boardX = x;
    boardY = y;
    tileSize = tile;
    if (cells.length != rows ||
        cells.any((row) => row.length != cols)) {
      return;
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final g = cells[r][c];
        if (g != null) {
          _updateGemTarget(g);
          if (state == 'idle' && !introFillInProgress) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
    if (introFillInProgress) {
      _syncIntroPositionsAfterGeometry();
    }
  }

  /// 목표보다 위(작은 y)로 둘 거리. `rows+4` 타일이면 보드 상단(boardY) 밖까지 충분히 올라간다.
  double get _introFallDy => (rows + 4) * tileSize;

  /// 인트로: 슬롯 **위**에서 대기(낙하 직전). 각 칸마다 목표보다 위에 둔다.
  double _introHoldYAbove(BoardGem gem) => gem.targetY - _introFallDy;

  /// 현재 웨이브에서 낙하 중인 **행** 인덱스 (맨 아래 줄이 먼저).
  int get _introActiveRow => rows - 1 - _introWaveIndex;

  /// 레이아웃 변경 중 인트로일 때 타깃만 갱신하고 대기/이동 중 위치를 맞춘다.
  void _syncIntroPositionsAfterGeometry() {
    if (!introFillInProgress) return;
    final activeRow = _introActiveRow;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = cells[r][c];
        if (gem == null) continue;
        gem.x = gem.targetX;
        if (r > activeRow) {
          gem.y = gem.targetY;
        } else if (r < activeRow) {
          gem.y = _introHoldYAbove(gem);
        } else {
          gem.y = gem.targetY;
        }
      }
    }
  }

  /// [_fillBoardWithRandomValidLayout] 직후: **줄 단위** 낙하(아래→위 [rows]번), 마스크·화면 밖 스폰은 유지.
  void prepareIntroFill({BoardFillIntroKind kind = BoardFillIntroKind.roundStart}) {
    _pendingIntroKind = kind;
    _introWaveIndex = 0;
    introFillInProgress = true;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final gem = cells[r][c];
        if (gem == null) continue;
        gem.x = gem.targetX;
        gem.y = _introHoldYAbove(gem);
      }
    }
  }

  void _updateGemTarget(BoardGem gem) {
    final p = cellToPixel(gem.row, gem.col);
    gem.targetX = p.dx;
    gem.targetY = p.dy;
  }

  Offset cellToPixel(int row, int col) {
    return Offset(
      boardX + col * tileSize,
      boardY + row * tileSize,
    );
  }

  Point<int>? pixelToCell(double px, double py) {
    if (px < boardX || py < boardY) return null;
    final lx = px - boardX;
    final ly = py - boardY;
    final col = (lx / tileSize).floor();
    final row = (ly / tileSize).floor();
    if (!isInside(row, col)) return null;
    return Point(row, col);
  }

  BoardGem createGem(
    int row,
    int col,
    int color,
    GemKind kind, {
    int spawnOffsetRows = 0,
  }) {
    final t = cellToPixel(row, col);
    var gy = t.dy;
    if (spawnOffsetRows > 0) {
      gy = t.dy - spawnOffsetRows * tileSize;
    }
    return BoardGem(
      id: _nextId(),
      color: color,
      kind: kind,
      row: row,
      col: col,
      x: t.dx,
      y: gy,
      targetX: t.dx,
      targetY: t.dy,
    );
  }

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

  int? gemMatchColor(BoardGem? gem) {
    if (gem == null || gem.kind == GemKind.hyper) return null;
    return gem.color;
  }

  bool causesImmediateMatch(int row, int col, int color) {
    final l1 = getGem(row, col - 1);
    final l2 = getGem(row, col - 2);
    if (l1 != null &&
        l2 != null &&
        gemMatchColor(l1) == color &&
        gemMatchColor(l2) == color) {
      return true;
    }
    final u1 = getGem(row - 1, col);
    final u2 = getGem(row - 2, col);
    if (u1 != null &&
        u2 != null &&
        gemMatchColor(u1) == color &&
        gemMatchColor(u2) == color) {
      return true;
    }
    return false;
  }

  int randomAllowedColor(int row, int col) {
    final allowed = <int>[];
    for (var color = 1; color <= colorCount; color++) {
      if (!causesImmediateMatch(row, col, color)) {
        allowed.add(color);
      }
    }
    if (allowed.isEmpty) {
      return _random.nextInt(colorCount) + 1;
    }
    return allowed[_random.nextInt(allowed.length)];
  }

  /// 무작위로 유효한 초기 보드를 채운다 (즉시 매치 없음·최소 한 수 있는 상태). 기존 보석은 제거된다.
  void _fillBoardWithRandomValidLayout() {
    var attempts = 0;
    do {
      attempts++;
      resetCells();
      flashEffects.clear();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final color = randomAllowedColor(r, c);
          setGem(r, c, createGem(r, c, color, GemKind.normal));
        }
      }
    } while (hasMatches() || !hasAnyValidMove());

    selected = null;
    state = 'idle';
    lastActionText = attempts > 1 ? 'board regen x$attempts' : 'ready';
    clearHint();
    introFillInProgress = false;
  }

  /// [newBoard]·재시작·셔플 등 공통: 보드 재생성 후 인트로 연출 여부만 선택.
  void generateFreshBoard({
    bool withIntroFill = true,
    BoardFillIntroKind introKind = BoardFillIntroKind.roundStart,
  }) {
    _fillBoardWithRandomValidLayout();
    if (withIntroFill) {
      prepareIntroFill(kind: introKind);
    } else {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final g = cells[r][c];
          if (g != null) {
            g.x = g.targetX;
            g.y = g.targetY;
          }
        }
      }
    }
  }

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

  MatchData findAllMatches() {
    final matchData = MatchData();

    for (var row = 0; row < rows; row++) {
      var startCol = 0;
      int? currentColor;
      for (var col = 0; col <= cols; col++) {
        final gem = col < cols ? getGem(row, col) : null;
        final color = gemMatchColor(gem);
        if (color != currentColor) {
          final length = col - startCol;
          if (currentColor != null && length >= 3) {
            final groupCells = <Point<int>>[];
            for (var fc = startCol; fc < col; fc++) {
              matchData.cells[_cellKey(row, fc)] = true;
              groupCells.add(Point(row, fc));
            }
            matchData.groups.add(MatchGroup(
              direction: 'row',
              length: length,
              color: currentColor,
              cells: groupCells,
            ));
          }
          currentColor = color;
          startCol = col;
        }
      }
    }

    for (var col = 0; col < cols; col++) {
      var startRow = 0;
      int? currentColor;
      for (var row = 0; row <= rows; row++) {
        final gem = row < rows ? getGem(row, col) : null;
        final color = gemMatchColor(gem);
        if (color != currentColor) {
          final length = row - startRow;
          if (currentColor != null && length >= 3) {
            final groupCells = <Point<int>>[];
            for (var fr = startRow; fr < row; fr++) {
              matchData.cells[_cellKey(fr, col)] = true;
              groupCells.add(Point(fr, col));
            }
            matchData.groups.add(MatchGroup(
              direction: 'col',
              length: length,
              color: currentColor,
              cells: groupCells,
            ));
          }
          currentColor = color;
          startRow = row;
        }
      }
    }

    return matchData;
  }

  MatchData findMatchesAt(int row, int col) {
    final all = findAllMatches();
    final targetKey = _cellKey(row, col);
    if (!all.cells.containsKey(targetKey)) {
      return MatchData();
    }

    final result = MatchData();
    for (final group in all.groups) {
      var include = false;
      for (final cell in group.cells) {
        if (cell.x == row && cell.y == col) {
          include = true;
          break;
        }
      }
      if (include) {
        result.groups.add(group);
        for (final cell in group.cells) {
          result.cells[_cellKey(cell.x, cell.y)] = true;
        }
      }
    }
    return result;
  }

  Point<int> pickSpawnCell(MatchGroup group, Set<String> movedCells) {
    for (final cell in group.cells) {
      if (movedCells.contains(_cellKey(cell.x, cell.y))) {
        return Point(cell.x, cell.y);
      }
    }
    final mid = group.cells[(group.cells.length - 1) ~/ 2];
    return Point(mid.x, mid.y);
  }

  List<SpecialSpawn> classifyMatchGroups(
    MatchData matchData,
    Point<int>? movedA,
    Point<int>? movedB,
  ) {
    final movedCells = <String>{};
    if (movedA != null) {
      movedCells.add(_cellKey(movedA.x, movedA.y));
    }
    if (movedB != null) {
      movedCells.add(_cellKey(movedB.x, movedB.y));
    }

    final spawns = <SpecialSpawn>[];
    final reserved = <String, bool>{};

    final rowGroups = matchData.groups.where((g) => g.direction == 'row').toList();
    final colGroups = matchData.groups.where((g) => g.direction == 'col').toList();

    for (final rowGroup in rowGroups) {
      for (final colGroup in colGroups) {
        Point<int>? overlap;
        final merged = <String, bool>{};
        for (final cell in rowGroup.cells) {
          merged[_cellKey(cell.x, cell.y)] = true;
        }
        for (final cell in colGroup.cells) {
          final key = _cellKey(cell.x, cell.y);
          if (merged.containsKey(key)) {
            overlap = Point(cell.x, cell.y);
          }
          merged[key] = true;
        }
        if (overlap != null && merged.length >= 5) {
          final key = _cellKey(overlap.x, overlap.y);
          if (!reserved.containsKey(key)) {
            final g = getGem(overlap.x, overlap.y)!;
            spawns.add(SpecialSpawn(
              row: overlap.x,
              col: overlap.y,
              kind: GemKind.bomb,
              color: g.color,
            ));
            reserved[key] = true;
          }
        }
      }
    }

    for (final group in matchData.groups) {
      if (group.length >= 5) {
        final spawn = pickSpawnCell(group, movedCells);
        final key = _cellKey(spawn.x, spawn.y);
        if (!reserved.containsKey(key)) {
          spawns.add(SpecialSpawn(
            row: spawn.x,
            col: spawn.y,
            kind: GemKind.hyper,
            color: 0,
          ));
          reserved[key] = true;
        }
      }
    }

    for (final group in matchData.groups) {
      if (group.length == 4) {
        final spawn = pickSpawnCell(group, movedCells);
        final key = _cellKey(spawn.x, spawn.y);
        if (!reserved.containsKey(key)) {
          final g = getGem(spawn.x, spawn.y)!;
          final stripeKind =
              group.direction == 'row' ? GemKind.row : GemKind.col;
          spawns.add(SpecialSpawn(
            row: spawn.x,
            col: spawn.y,
            kind: stripeKind,
            color: g.color,
          ));
          reserved[key] = true;
        }
      }
    }

    return spawns;
  }

  Map<String, bool> buildRemovalSet(MatchData matchData, List<SpecialSpawn> spawns) {
    final removalSet = Map<String, bool>.fromEntries(
      matchData.cells.keys.map((k) => MapEntry(k, true)),
    );
    for (final s in spawns) {
      removalSet.remove(_cellKey(s.row, s.col));
    }
    return removalSet;
  }

  void applySpawnInfo(List<SpecialSpawn> spawns) {
    for (final s in spawns) {
      final gem = getGem(s.row, s.col);
      if (gem != null) {
        gem.kind = s.kind;
        gem.color = s.color;
      }
    }
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

  bool _isSpecial(GemKind k) => k != GemKind.normal;

  List<MatchChainItem> buildSpecialQueue(Map<String, bool> removalSet) {
    final queue = <MatchChainItem>[];
    final queued = <String, bool>{};

    for (final key in removalSet.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final gem = getGem(row, col);
      if (gem != null && _isSpecial(gem.kind) && !queued.containsKey(key)) {
        queue.add(MatchChainItem(
          row: row,
          col: col,
          kind: gem.kind,
          triggerColor: gem.color > 0 ? gem.color : null,
        ));
        queued[key] = true;
      }
    }
    return queue;
  }

  void enqueueTriggeredSpecial(
    List<MatchChainItem> queue,
    Map<String, bool> queued,
    int row,
    int col,
    int? triggerColor,
  ) {
    final gem = getGem(row, col);
    final key = _cellKey(row, col);
    if (gem != null && _isSpecial(gem.kind) && !queued.containsKey(key)) {
      queue.add(MatchChainItem(
        row: row,
        col: col,
        kind: gem.kind,
        triggerColor: triggerColor,
      ));
      queued[key] = true;
    }
  }

  void markCellForRemoval(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
    Map<String, bool> queued,
    int row,
    int col,
    int? triggerColor,
  ) {
    if (!isInside(row, col)) return;
    final key = _cellKey(row, col);
    removalSet[key] = true;
    enqueueTriggeredSpecial(queue, queued, row, col, triggerColor);
  }

  void activateSpecials(Map<String, bool> removalSet, List<MatchChainItem> queue) {
    final queued = <String, bool>{};
    for (final item in queue) {
      queued[_cellKey(item.row, item.col)] = true;
    }

    final processed = <String, bool>{};
    var index = 0;
    while (index < queue.length) {
      final item = queue[index];
      index++;
      final key = _cellKey(item.row, item.col);
      if (processed.containsKey(key)) continue;
      processed[key] = true;

      if (item.kind == GemKind.row) {
        for (var c = 0; c < cols; c++) {
          markCellForRemoval(
            removalSet,
            queue,
            queued,
            item.row,
            c,
            item.triggerColor,
          );
        }
      } else if (item.kind == GemKind.col) {
        for (var r = 0; r < rows; r++) {
          markCellForRemoval(
            removalSet,
            queue,
            queued,
            r,
            item.col,
            item.triggerColor,
          );
        }
      } else if (item.kind == GemKind.bomb) {
        for (var r = item.row - 1; r <= item.row + 1; r++) {
          for (var c = item.col - 1; c <= item.col + 1; c++) {
            markCellForRemoval(
              removalSet,
              queue,
              queued,
              r,
              c,
              item.triggerColor,
            );
          }
        }
      } else if (item.kind == GemKind.hyper) {
        final targetColor = item.triggerColor ?? pickExistingColor();
        if (targetColor != null) {
          for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
              final gem = getGem(r, c);
              if (gem != null &&
                  gem.kind != GemKind.hyper &&
                  gem.color == targetColor) {
                markCellForRemoval(
                  removalSet,
                  queue,
                  queued,
                  r,
                  c,
                  targetColor,
                );
              }
            }
          }
        }
      }
    }
  }

  void addFlashEffect(int row, int col) {
    final p = cellToPixel(row, col);
    flashEffects.add(FlashEffect(
      x: p.dx,
      y: p.dy,
      size: tileSize,
      timer: flashDuration,
    ));
  }

  int removeMarkedGems(Map<String, bool> removalSet) {
    var removed = 0;
    for (final key in removalSet.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final row = int.parse(parts[0]);
      final col = int.parse(parts[1]);
      final gem = getGem(row, col);
      if (gem != null) {
        removed++;
        addFlashEffect(row, col);
        cells[row][col] = null;
      }
    }

    if (removed > 0) {
      final base = scoreBase + max(0, removed - 3) * scoreExtraPerGem;
      final comboBonus = max(1, combo);
      score += (base * comboBonus).round();
    }
    return removed;
  }

  bool applyGravity() {
    var moved = false;
    for (var col = 0; col < cols; col++) {
      var writeRow = rows - 1;
      for (var row = rows - 1; row >= 0; row--) {
        final gem = cells[row][col];
        if (gem != null) {
          if (writeRow != row) {
            cells[writeRow][col] = gem;
            cells[row][col] = null;
            gem.row = writeRow;
            gem.col = col;
            _updateGemTarget(gem);
            moved = true;
          }
          writeRow--;
        }
      }
      for (var row = writeRow; row >= 0; row--) {
        cells[row][col] = null;
      }
    }
    return moved;
  }

  int refillBoard() {
    var spawned = 0;
    for (var col = 0; col < cols; col++) {
      var missing = 0;
      for (var row = 0; row < rows; row++) {
        if (cells[row][col] == null) missing++;
      }
      for (var row = 0; row < rows; row++) {
        if (cells[row][col] == null) {
          final color = _random.nextInt(colorCount) + 1;
          final gem = createGem(row, col, color, GemKind.normal,
              spawnOffsetRows: missing);
          setGem(row, col, gem);
          spawned++;
          missing--;
        }
      }
    }
    return spawned;
  }

  void resolveMatchCascade(MoveInfo moveInfo) {
    pendingMoveInfo = moveInfo;
    combo = 0;
    pendingResultLabel = null;
    beginNextResolutionCycle();
  }

  void startRemovalPhase(Map<String, bool> removalSet) {
    pendingRemovalSet = removalSet;
    state = 'removing';
    stageTimer = removeDelay;
  }

  bool beginNextResolutionCycle() {
    final matchData = findAllMatches();
    if (matchData.groups.isEmpty) {
      finishResolutionFlow();
      return false;
    }

    combo++;
    lastCombo = combo;
    if (combo > maxCombo) {
      maxCombo = combo;
    }

    final mi = pendingMoveInfo;
    final spawns = classifyMatchGroups(
      matchData,
      mi?.movedA,
      mi?.movedB,
    );
    var removalSet = buildRemovalSet(matchData, spawns);
    final queue = buildSpecialQueue(removalSet);

    applySpawnInfo(spawns);
    activateSpecials(removalSet, queue);
    pendingMoveInfo = null;
    startRemovalPhase(removalSet);
    return true;
  }

  void finishResolutionFlow() {
    if (pendingResultLabel != null) {
      lastActionText = pendingResultLabel!;
    } else if (combo > 1) {
      lastActionText = 'combo x$combo';
    } else if (combo == 1) {
      lastActionText = 'match';
    }

    pendingResultLabel = null;
    pendingMoveInfo = null;
    pendingRemovalSet = null;
    combo = 0;

    state = 'idle';
    selected = null;

    if (!hasAnyValidMove()) {
      lastActionText = 'no moves';
      onNoMoves?.call();
    }
  }

  void resolveSpecialSwap(
    Map<String, bool> removalSet,
    List<MatchChainItem> queue,
    String label,
  ) {
    combo = 1;
    lastCombo = 1;
    if (maxCombo < 1) {
      maxCombo = 1;
    }
    pendingResultLabel = label;
    activateSpecials(removalSet, queue);
    startRemovalPhase(removalSet);
  }

  void advanceResolutionStep() {
    if (state == 'removing') {
      removeMarkedGems(pendingRemovalSet ?? {});
      state = 'falling';
      stageTimer = fallingDelay;
      return;
    }
    if (state == 'falling') {
      applyGravity();
      state = 'refilling';
      stageTimer = refillDelay;
      return;
    }
    if (state == 'refilling') {
      refillBoard();
      state = 'checking';
      stageTimer = checkingDelay;
      return;
    }
    if (state == 'checking') {
      pendingRemovalSet = null;
      beginNextResolutionCycle();
    }
  }

  bool triggerSpecialSwap(int ar, int ac, int br, int bc) {
    final gemA = getGem(ar, ac)!;
    final gemB = getGem(br, bc)!;
    final removalSet = <String, bool>{};
    final queue = <MatchChainItem>[];

    if (gemA.kind == GemKind.hyper && gemB.kind == GemKind.hyper) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          removalSet[_cellKey(r, c)] = true;
        }
      }
      resolveSpecialSwap(removalSet, queue, 'hyper x2');
      return true;
    }

    if (gemA.kind == GemKind.hyper || gemB.kind == GemKind.hyper) {
      late int hyperR, hyperC;
      late BoardGem other;
      if (gemA.kind == GemKind.hyper) {
        hyperR = ar;
        hyperC = ac;
        other = gemB;
      } else {
        hyperR = br;
        hyperC = bc;
        other = gemA;
      }
      removalSet[_cellKey(ar, ac)] = true;
      removalSet[_cellKey(br, bc)] = true;
      queue.add(MatchChainItem(
        row: hyperR,
        col: hyperC,
        kind: GemKind.hyper,
        triggerColor:
            other.kind == GemKind.hyper ? pickExistingColor() : other.color,
      ));
      resolveSpecialSwap(removalSet, queue, 'hyper');
      return true;
    }

    if (_isSpecial(gemA.kind) && _isSpecial(gemB.kind)) {
      removalSet[_cellKey(ar, ac)] = true;
      removalSet[_cellKey(br, bc)] = true;
      queue.add(MatchChainItem(
        row: ar,
        col: ac,
        kind: gemA.kind,
        triggerColor: gemA.color > 0 ? gemA.color : null,
      ));
      queue.add(MatchChainItem(
        row: br,
        col: bc,
        kind: gemB.kind,
        triggerColor: gemB.color > 0 ? gemB.color : null,
      ));
      resolveSpecialSwap(removalSet, queue, 'special swap');
      return true;
    }

    if (_isSpecial(gemA.kind) && gemB.kind == GemKind.normal) {
      removalSet[_cellKey(ar, ac)] = true;
      removalSet[_cellKey(br, bc)] = true;
      queue.add(MatchChainItem(
        row: ar,
        col: ac,
        kind: gemA.kind,
        triggerColor: gemB.color,
      ));
      resolveSpecialSwap(removalSet, queue, 'special');
      return true;
    }

    if (_isSpecial(gemB.kind) && gemA.kind == GemKind.normal) {
      removalSet[_cellKey(ar, ac)] = true;
      removalSet[_cellKey(br, bc)] = true;
      queue.add(MatchChainItem(
        row: br,
        col: bc,
        kind: gemB.kind,
        triggerColor: gemA.color,
      ));
      resolveSpecialSwap(removalSet, queue, 'special');
      return true;
    }

    return false;
  }

  bool trySwap(int ar, int ac, int br, int bc) {
    clearHint();
    if (inputLocked || state != 'idle') return false;
    if (!isInside(ar, ac) || !isInside(br, bc)) return false;
    if (!areAdjacent(ar, ac, br, bc)) return false;

    final gemA = getGem(ar, ac);
    final gemB = getGem(br, bc);
    if (gemA == null || gemB == null) return false;

    if (triggerSpecialSwap(ar, ac, br, bc)) {
      selected = null;
      return true;
    }

    swapCells(ar, ac, br, bc);

    final matchA = findMatchesAt(br, bc);
    final matchB = findMatchesAt(ar, ac);
    if (matchA.groups.isEmpty && matchB.groups.isEmpty) {
      swapCells(ar, ac, br, bc);
      lastActionText = 'bad swap';
      lockInput(invalidSwapLock);
      return false;
    }

    resolveMatchCascade(MoveInfo(
      movedA: Point(br, bc),
      movedB: Point(ar, ac),
    ));
    selected = null;
    return true;
  }

  bool hasAnyValidMove() => getAllValidMoves().isNotEmpty;

  void clearHint() {
    _hintA = null;
    _hintB = null;
  }

  /// 유효한 스왑 하나를 골라 두 칸을 힌트로 표시한다. 없으면 false.
  /// 해제는 [clearHint] — 탭·스왑·보드 재생성 등에서 호출.
  bool showHint() {
    if (state != 'idle' || inputLocked) return false;
    final moves = getAllValidMoves();
    if (moves.isEmpty) return false;
    final pick = moves[_random.nextInt(moves.length)];
    _hintA = pick.a;
    _hintB = pick.b;
    return true;
  }

  List<ValidMovePair> getAllValidMoves() {
    final moves = <ValidMovePair>[];
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        for (final dir in const [[0, 1], [1, 0]]) {
          final or = row + dir[0];
          final oc = col + dir[1];
          if (!isInside(or, oc)) continue;
          final gemA = getGem(row, col);
          final gemB = getGem(or, oc);
          if (gemA == null || gemB == null) continue;

          var isValid = false;
          if (gemA.kind == GemKind.hyper || gemB.kind == GemKind.hyper) {
            isValid = true;
          } else if (_isSpecial(gemA.kind) && _isSpecial(gemB.kind)) {
            isValid = true;
          } else {
            swapCells(row, col, or, oc);
            final matchA = findMatchesAt(or, oc);
            final matchB = findMatchesAt(row, col);
            swapCells(row, col, or, oc);
            isValid = matchA.groups.isNotEmpty || matchB.groups.isNotEmpty;
          }

          if (isValid) {
            moves.add(ValidMovePair(
              a: Point(row, col),
              b: Point(or, oc),
            ));
          }
        }
      }
    }
    return moves;
  }

  void shuffle() {
    generateFreshBoard(
      withIntroFill: true,
      introKind: BoardFillIntroKind.shuffleRefill,
    );
    lastActionText = 'shuffled';
  }

  void lockInput([double? duration]) {
    inputLocked = true;
    lockTimer = duration ?? defaultLock;
  }

  void update(double dt) {
    if (inputLocked && !introFillInProgress) {
      lockTimer -= dt;
      if (lockTimer <= 0) {
        inputLocked = false;
        lockTimer = 0;
      }
    }

    if (state != 'idle' && state != 'gameover') {
      stageTimer -= dt;
      if (stageTimer <= 0) {
        advanceResolutionStep();
      }
    }

    if (introFillInProgress) {
      final activeRow = _introActiveRow;
      final s = min(1.0, dt * introTweenSpeed);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final gem = cells[r][c];
          if (gem == null) continue;
          gem.x = gem.targetX;
          if (r > activeRow) {
            gem.y = gem.targetY;
          } else if (r < activeRow) {
            gem.y = _introHoldYAbove(gem);
          } else {
            gem.y += (gem.targetY - gem.y) * s;
            if ((gem.targetY - gem.y).abs() <= 0.45) {
              gem.y = gem.targetY;
            }
          }
        }
      }
      var waveComplete = true;
      for (var c = 0; c < cols; c++) {
        final g = cells[activeRow][c];
        if (g == null) continue;
        if ((g.targetY - g.y).abs() > 0.45) {
          waveComplete = false;
          break;
        }
      }
      if (waveComplete) {
        _introWaveIndex++;
        if (_introWaveIndex >= rows) {
          introFillInProgress = false;
          _introWaveIndex = 0;
          onIntroFillComplete?.call(_pendingIntroKind);
        }
      }
    } else {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final gem = cells[r][c];
          if (gem != null) {
            final s = min(1.0, dt * tweenSpeed);
            gem.x += (gem.targetX - gem.x) * s;
            gem.y += (gem.targetY - gem.y) * s;
          }
        }
      }
    }

    for (var i = flashEffects.length - 1; i >= 0; i--) {
      flashEffects[i].timer -= dt;
      if (flashEffects[i].timer <= 0) {
        flashEffects.removeAt(i);
      }
    }

  }

  void clearSelection() => selected = null;

  void selectCell(int row, int col) {
    if (!isInside(row, col)) {
      selected = null;
      return;
    }
    selected = Point(row, col);
  }

  /// 화면 좌표 탭. 첫 탭은 선택, 인접 두 번째 탭은 스왑.
  void handleTap(double px, double py) {
    if (introFillInProgress) return;
    clearHint();
    if (inputLocked) return;
    final cell = pixelToCell(px, py);
    if (cell == null) {
      selected = null;
      return;
    }
    final row = cell.x;
    final col = cell.y;

    if (selected == null) {
      selectCell(row, col);
      return;
    }
    if (selected!.x == row && selected!.y == col) {
      selected = null;
      return;
    }
    if (areAdjacent(selected!.x, selected!.y, row, col)) {
      final sr = selected!.x;
      final sc = selected!.y;
      selected = null;
      trySwap(sr, sc, row, col);
      return;
    }
    selectCell(row, col);
  }
}

class MatchChainItem {
  MatchChainItem({
    required this.row,
    required this.col,
    required this.kind,
    this.triggerColor,
  });
  final int row;
  final int col;
  final GemKind kind;
  final int? triggerColor;
}

class ValidMovePair {
  ValidMovePair({required this.a, required this.b});
  final Point<int> a;
  final Point<int> b;
}
