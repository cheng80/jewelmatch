import 'dart:math';

/// 인트로식 보드 채움 완료 시 구분. [BoardFillIntroKind.roundStart]만 Start 효과음.
enum BoardFillIntroKind {
  /// 첫 진입·재시작·새 보드
  roundStart,

  /// 노무브 셔플 등 — 연출만, Start 효과음 없음
  shuffleRefill,
}

/// 보석 종류. `row`/`col`은 예전 저장 상태 호환용으로 유지한다.
enum GemKind { normal, row, col, bomb, star, hyper, supernova }

/// 단일 보석 인스턴스 (논리 격자 + 화면 보간 좌표).
/// 오브젝트 풀링을 위해 [reset]으로 필드를 재설정할 수 있다.
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

  /// 풀에서 꺼낸 인스턴스를 새 보석처럼 재설정한다.
  void reset({
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
    this.id = id;
    this.color = color;
    this.kind = kind;
    this.row = row;
    this.col = col;
    this.x = x;
    this.y = y;
    this.targetX = targetX;
    this.targetY = targetY;
  }
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

class SpecialEffectShake {
  const SpecialEffectShake({required this.intensity, required this.duration});

  final double intensity;
  final double duration;
}

class SpecialEffectEvent {
  SpecialEffectEvent({
    required this.effectKind,
    required this.origin,
    required this.affectedCells,
    required this.shake,
    this.triggerColor,
  });

  final GemKind effectKind;
  final Point<int> origin;
  final List<Point<int>> affectedCells;
  final SpecialEffectShake shake;
  final int? triggerColor;
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
