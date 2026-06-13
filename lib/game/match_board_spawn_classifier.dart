import 'dart:math';

import 'match_board_matching.dart';
import 'match_board_models.dart';

Point<int> pickMatchSpawnCell(MatchGroup group, Set<String> movedCells) {
  for (final cell in group.cells) {
    if (movedCells.contains(matchBoardCellKey(cell.x, cell.y))) {
      return Point(cell.x, cell.y);
    }
  }
  final mid = group.cells[(group.cells.length - 1) ~/ 2];
  return Point(mid.x, mid.y);
}

List<SpecialSpawn> classifyBoardMatchGroups({
  required MatchData matchData,
  required MatchBoardGemLookup getGem,
  Point<int>? movedA,
  Point<int>? movedB,
}) {
  final movedCells = <String>{};
  if (movedA != null) {
    movedCells.add(matchBoardCellKey(movedA.x, movedA.y));
  }
  if (movedB != null) {
    movedCells.add(matchBoardCellKey(movedB.x, movedB.y));
  }

  final spawns = <SpecialSpawn>[];
  final reserved = <String, bool>{};
  final consumed = <String, bool>{};

  final rowGroups = matchData.groups
      .where((g) => g.direction == 'row')
      .toList();
  final colGroups = matchData.groups
      .where((g) => g.direction == 'col')
      .toList();

  for (final rowGroup in rowGroups) {
    for (final colGroup in colGroups) {
      Point<int>? overlap;
      final merged = <String, bool>{};
      for (final cell in rowGroup.cells) {
        merged[matchBoardCellKey(cell.x, cell.y)] = true;
      }
      for (final cell in colGroup.cells) {
        final key = matchBoardCellKey(cell.x, cell.y);
        if (merged.containsKey(key)) {
          overlap = Point(cell.x, cell.y);
        }
        merged[key] = true;
      }
      if (overlap != null && merged.length >= 5) {
        final key = matchBoardCellKey(overlap.x, overlap.y);
        if (!reserved.containsKey(key)) {
          final gem = getGem(overlap.x, overlap.y)!;
          spawns.add(
            SpecialSpawn(
              row: overlap.x,
              col: overlap.y,
              kind: GemKind.star,
              color: gem.color,
            ),
          );
          reserved[key] = true;
          consumed.addAll(merged);
        }
      }
    }
  }

  for (final group in matchData.groups) {
    if (group.cells.any(
      (cell) => consumed.containsKey(matchBoardCellKey(cell.x, cell.y)),
    )) {
      continue;
    }
    if (group.length >= 6) {
      final spawn = pickMatchSpawnCell(group, movedCells);
      final key = matchBoardCellKey(spawn.x, spawn.y);
      if (!reserved.containsKey(key)) {
        final gem = getGem(spawn.x, spawn.y)!;
        spawns.add(
          SpecialSpawn(
            row: spawn.x,
            col: spawn.y,
            kind: GemKind.supernova,
            color: gem.color,
          ),
        );
        reserved[key] = true;
      }
    } else if (group.length == 5) {
      final spawn = pickMatchSpawnCell(group, movedCells);
      final key = matchBoardCellKey(spawn.x, spawn.y);
      if (!reserved.containsKey(key)) {
        spawns.add(
          SpecialSpawn(
            row: spawn.x,
            col: spawn.y,
            kind: GemKind.hyper,
            color: 0,
          ),
        );
        reserved[key] = true;
      }
    }
  }

  for (final group in matchData.groups) {
    if (group.cells.any(
      (cell) => consumed.containsKey(matchBoardCellKey(cell.x, cell.y)),
    )) {
      continue;
    }
    if (group.length == 4) {
      final spawn = pickMatchSpawnCell(group, movedCells);
      final key = matchBoardCellKey(spawn.x, spawn.y);
      if (!reserved.containsKey(key)) {
        final gem = getGem(spawn.x, spawn.y)!;
        spawns.add(
          SpecialSpawn(
            row: spawn.x,
            col: spawn.y,
            kind: GemKind.bomb,
            color: gem.color,
          ),
        );
        reserved[key] = true;
      }
    }
  }

  return spawns;
}

Map<String, bool> buildBoardRemovalSet(
  MatchData matchData,
  List<SpecialSpawn> spawns,
) {
  final removalSet = Map<String, bool>.fromEntries(
    matchData.cells.keys.map((key) => MapEntry(key, true)),
  );
  for (final spawn in spawns) {
    removalSet.remove(matchBoardCellKey(spawn.row, spawn.col));
  }
  return removalSet;
}

void applySpecialSpawnInfo({
  required List<SpecialSpawn> spawns,
  required MatchBoardGemLookup getGem,
}) {
  for (final spawn in spawns) {
    final gem = getGem(spawn.row, spawn.col);
    if (gem != null) {
      gem.kind = spawn.kind;
      gem.color = spawn.color;
    }
  }
}
