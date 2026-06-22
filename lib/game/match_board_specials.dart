import 'dart:math';

import 'match_board_models.dart';

typedef BoardGemLookup = BoardGem? Function(int row, int col);
typedef ExistingColorPicker = int? Function();

String specialCellKey(int row, int col) => '$row:$col';

bool isSpecialGemKind(GemKind kind) => kind != GemKind.normal;

SpecialEffectShake specialEffectShakeForKind(GemKind kind) {
  switch (kind) {
    case GemKind.row:
    case GemKind.col:
      return const SpecialEffectShake(intensity: 3.4, duration: 0.30);
    case GemKind.bomb:
      return const SpecialEffectShake(intensity: 6.2, duration: 0.38);
    case GemKind.star:
      return const SpecialEffectShake(intensity: 5.5, duration: 0.34);
    case GemKind.hyper:
      return const SpecialEffectShake(intensity: 7.0, duration: 0.46);
    case GemKind.supernova:
      return const SpecialEffectShake(intensity: 9.4, duration: 0.58);
    case GemKind.normal:
      return const SpecialEffectShake(intensity: 0, duration: 0);
  }
}

List<MatchChainItem> buildSpecialQueueForRemoval({
  required Map<String, bool> removalSet,
  required BoardGemLookup getGem,
}) {
  final queue = <MatchChainItem>[];
  final queued = <String, bool>{};

  for (final key in removalSet.keys) {
    final parts = key.split(':');
    if (parts.length != 2) continue;
    final row = int.parse(parts[0]);
    final col = int.parse(parts[1]);
    final gem = getGem(row, col);
    if (gem != null && isSpecialGemKind(gem.kind) && !queued.containsKey(key)) {
      queue.add(
        MatchChainItem(
          row: row,
          col: col,
          kind: gem.kind,
          triggerColor: gem.color > 0 ? gem.color : null,
        ),
      );
      queued[key] = true;
    }
  }
  return queue;
}

void enqueueTriggeredSpecialForBoard({
  required List<MatchChainItem> queue,
  required Map<String, bool> queued,
  required BoardGemLookup getGem,
  required int row,
  required int col,
  required int? triggerColor,
  bool includeHyper = true,
}) {
  final gem = getGem(row, col);
  final key = specialCellKey(row, col);
  if (gem != null &&
      isSpecialGemKind(gem.kind) &&
      (includeHyper || gem.kind != GemKind.hyper) &&
      !queued.containsKey(key)) {
    queue.add(
      MatchChainItem(
        row: row,
        col: col,
        kind: gem.kind,
        triggerColor: triggerColor,
      ),
    );
    queued[key] = true;
  }
}

void markSpecialCellForRemoval({
  required Map<String, bool> removalSet,
  required List<MatchChainItem> queue,
  required Map<String, bool> queued,
  required BoardGemLookup getGem,
  required int rows,
  required int cols,
  required int row,
  required int col,
  required int? triggerColor,
}) {
  if (!_isInside(rows, cols, row, col)) return;
  final key = specialCellKey(row, col);
  removalSet[key] = true;
  enqueueTriggeredSpecialForBoard(
    queue: queue,
    queued: queued,
    getGem: getGem,
    row: row,
    col: col,
    triggerColor: triggerColor,
    includeHyper: false,
  );
}

List<SpecialEffectEvent> activateSpecialsForBoard({
  required Map<String, bool> removalSet,
  required List<MatchChainItem> queue,
  required BoardGemLookup getGem,
  required ExistingColorPicker pickExistingColor,
  required int rows,
  required int cols,
  void Function(GemKind kind)? onSpecialActivated,
}) {
  final events = <SpecialEffectEvent>[];
  final queued = <String, bool>{};
  for (final item in queue) {
    queued[specialCellKey(item.row, item.col)] = true;
  }

  final processed = <String, bool>{};
  var index = 0;
  while (index < queue.length) {
    final item = queue[index];
    index++;
    final key = specialCellKey(item.row, item.col);
    if (processed.containsKey(key)) continue;
    processed[key] = true;
    onSpecialActivated?.call(item.kind);

    final affectedKeys = <String, bool>{};
    final affectedCells = <Point<int>>[];
    void markAffected(int row, int col, int? triggerColor) {
      if (!_isInside(rows, cols, row, col)) return;
      final affectedKey = specialCellKey(row, col);
      if (!affectedKeys.containsKey(affectedKey)) {
        affectedCells.add(Point(row, col));
        affectedKeys[affectedKey] = true;
      }
      markSpecialCellForRemoval(
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
    }

    if (item.kind == GemKind.row) {
      for (var c = 0; c < cols; c++) {
        markAffected(item.row, c, item.triggerColor);
      }
    } else if (item.kind == GemKind.col) {
      for (var r = 0; r < rows; r++) {
        markAffected(r, item.col, item.triggerColor);
      }
    } else if (item.kind == GemKind.bomb) {
      for (var r = item.row - 1; r <= item.row + 1; r++) {
        for (var c = item.col - 1; c <= item.col + 1; c++) {
          markAffected(r, c, item.triggerColor);
        }
      }
    } else if (item.kind == GemKind.star) {
      for (var c = 0; c < cols; c++) {
        markAffected(item.row, c, item.triggerColor);
      }
      for (var r = 0; r < rows; r++) {
        markAffected(r, item.col, item.triggerColor);
      }
    } else if (item.kind == GemKind.supernova) {
      for (var r = item.row - 1; r <= item.row + 1; r++) {
        for (var c = item.col - 1; c <= item.col + 1; c++) {
          markAffected(r, c, item.triggerColor);
        }
      }
      for (var c = 0; c < cols; c++) {
        markAffected(item.row, c, item.triggerColor);
      }
      for (var r = 0; r < rows; r++) {
        markAffected(r, item.col, item.triggerColor);
      }
    } else if (item.kind == GemKind.hyper) {
      final targetColor = item.triggerColor ?? pickExistingColor();
      if (targetColor != null) {
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            final gem = getGem(r, c);
            if (gem != null &&
                gem.kind == GemKind.normal &&
                gem.color == targetColor) {
              markAffected(r, c, targetColor);
            }
          }
        }
      }
    }

    final event = specialEffectEventForItem(item, affectedCells);
    if (event != null) events.add(event);
  }

  return events;
}

SpecialEffectEvent? specialEffectEventForItem(
  MatchChainItem item,
  List<Point<int>> cells,
) {
  if (cells.isEmpty) return null;
  return SpecialEffectEvent(
    effectKind: item.kind,
    origin: Point(item.row, item.col),
    affectedCells: List<Point<int>>.unmodifiable(cells),
    shake: specialEffectShakeForKind(item.kind),
    triggerColor: item.triggerColor,
  );
}

bool _isInside(int rows, int cols, int row, int col) =>
    row >= 0 && row < rows && col >= 0 && col < cols;
