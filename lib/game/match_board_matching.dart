import 'dart:math';

import 'match_board_models.dart';

typedef MatchBoardGemLookup = BoardGem? Function(int row, int col);
typedef MatchBoardTokenForGem = int? Function(BoardGem? gem);

String matchBoardCellKey(int row, int col) => '$row:$col';

int? gemMatchColorToken(BoardGem? gem) {
  if (gem == null || gem.kind == GemKind.hyper) return null;
  return gem.color;
}

void scanBoardMatchesBy({
  required MatchData matchData,
  required int rows,
  required int cols,
  required MatchBoardGemLookup getGem,
  required MatchBoardTokenForGem tokenForGem,
}) {
  void addGroup(String direction, int token, List<Point<int>> cells) {
    final isDuplicate = matchData.groups.any((group) {
      if (group.direction != direction || group.cells.length != cells.length) {
        return false;
      }
      for (var i = 0; i < cells.length; i++) {
        if (group.cells[i].x != cells[i].x || group.cells[i].y != cells[i].y) {
          return false;
        }
      }
      return true;
    });
    if (isDuplicate) return;
    for (final cell in cells) {
      matchData.cells[matchBoardCellKey(cell.x, cell.y)] = true;
    }
    matchData.groups.add(
      MatchGroup(
        direction: direction,
        length: cells.length,
        color: token,
        cells: cells,
      ),
    );
  }

  for (var row = 0; row < rows; row++) {
    var startCol = 0;
    int? currentToken;
    for (var col = 0; col <= cols; col++) {
      final gem = col < cols ? getGem(row, col) : null;
      final token = tokenForGem(gem);
      if (token != currentToken) {
        final length = col - startCol;
        if (currentToken != null && length >= 3) {
          final groupCells = <Point<int>>[];
          for (var fc = startCol; fc < col; fc++) {
            groupCells.add(Point(row, fc));
          }
          addGroup('row', currentToken, groupCells);
        }
        currentToken = token;
        startCol = col;
      }
    }
  }

  for (var col = 0; col < cols; col++) {
    var startRow = 0;
    int? currentToken;
    for (var row = 0; row <= rows; row++) {
      final gem = row < rows ? getGem(row, col) : null;
      final token = tokenForGem(gem);
      if (token != currentToken) {
        final length = row - startRow;
        if (currentToken != null && length >= 3) {
          final groupCells = <Point<int>>[];
          for (var fr = startRow; fr < row; fr++) {
            groupCells.add(Point(fr, col));
          }
          addGroup('col', currentToken, groupCells);
        }
        currentToken = token;
        startRow = row;
      }
    }
  }
}

MatchData findAllBoardMatches({
  required int rows,
  required int cols,
  required MatchBoardGemLookup getGem,
}) {
  final matchData = MatchData();
  scanBoardMatchesBy(
    matchData: matchData,
    rows: rows,
    cols: cols,
    getGem: getGem,
    tokenForGem: gemMatchColorToken,
  );
  return matchData;
}

MatchData findBoardMatchesAt({
  required MatchData all,
  required int row,
  required int col,
}) {
  final targetKey = matchBoardCellKey(row, col);
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
        result.cells[matchBoardCellKey(cell.x, cell.y)] = true;
      }
    }
  }
  return result;
}
