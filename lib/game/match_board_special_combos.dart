import 'match_board_matching.dart';
import 'match_board_models.dart';
import 'match_board_specials.dart';

typedef ComboGemLookup = BoardGem? Function(int row, int col);

class SpecialSwapCombo {
  SpecialSwapCombo({
    required this.removalSet,
    required this.queue,
    required this.label,
  });

  final Map<String, bool> removalSet;
  final List<MatchChainItem> queue;
  final String label;
}

SpecialSwapCombo? buildNonHyperSpecialSwapCombo({
  required BoardGem a,
  required BoardGem b,
  required ComboGemLookup getGem,
  required int rows,
  required int cols,
}) {
  if (!_isNonHyperSpecial(a.kind) || !_isNonHyperSpecial(b.kind)) {
    return null;
  }

  final removalSet = <String, bool>{};
  final queue = <MatchChainItem>[];
  final queued = <String, bool>{};

  void queueSpecial(BoardGem gem) {
    final key = matchBoardCellKey(gem.row, gem.col);
    if (queued.containsKey(key)) return;
    queue.add(
      MatchChainItem(
        row: gem.row,
        col: gem.col,
        kind: gem.kind,
        triggerColor: gem.color > 0 ? gem.color : null,
      ),
    );
    queued[key] = true;
  }

  void mark(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    final key = matchBoardCellKey(row, col);
    removalSet[key] = true;
    final gem = getGem(row, col);
    if (gem != null && isSpecialGemKind(gem.kind)) {
      queueSpecial(gem);
    }
  }

  queueSpecial(a);
  queueSpecial(b);
  mark(a.row, a.col);
  mark(b.row, b.col);

  if (_isBombPair(a.kind, b.kind)) {
    _markBlast(mark, a.row, a.col, 2);
    _markBlast(mark, b.row, b.col, 2);
    return SpecialSwapCombo(
      removalSet: removalSet,
      queue: queue,
      label: 'bomb combo',
    );
  }

  if (_isBombStarPair(a.kind, b.kind)) {
    final star = a.kind == GemKind.star ? a : b;
    for (var col = 0; col < cols; col++) {
      _markBlast(mark, star.row, col, 1);
    }
    for (var row = 0; row < rows; row++) {
      _markBlast(mark, row, star.col, 1);
    }
    return SpecialSwapCombo(
      removalSet: removalSet,
      queue: queue,
      label: 'bomb star combo',
    );
  }

  if (a.kind == GemKind.star && b.kind == GemKind.star) {
    _markRow(mark, a.row, cols);
    _markCol(mark, a.col, rows);
    _markRow(mark, b.row, cols);
    _markCol(mark, b.col, rows);
    return SpecialSwapCombo(
      removalSet: removalSet,
      queue: queue,
      label: 'star combo',
    );
  }

  return SpecialSwapCombo(
    removalSet: removalSet,
    queue: queue,
    label: 'special combo',
  );
}

bool _isNonHyperSpecial(GemKind kind) =>
    kind != GemKind.normal && kind != GemKind.hyper;

bool _isBombPair(GemKind a, GemKind b) =>
    a == GemKind.bomb && b == GemKind.bomb;

bool _isBombStarPair(GemKind a, GemKind b) =>
    (a == GemKind.bomb && b == GemKind.star) ||
    (a == GemKind.star && b == GemKind.bomb);

void _markBlast(void Function(int row, int col) mark, int row, int col, int r) {
  for (var rr = row - r; rr <= row + r; rr++) {
    for (var cc = col - r; cc <= col + r; cc++) {
      mark(rr, cc);
    }
  }
}

void _markRow(void Function(int row, int col) mark, int row, int cols) {
  for (var col = 0; col < cols; col++) {
    mark(row, col);
  }
}

void _markCol(void Function(int row, int col) mark, int col, int rows) {
  for (var row = 0; row < rows; row++) {
    mark(row, col);
  }
}
