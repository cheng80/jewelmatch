import 'dart:math';

import 'match_board_logic.dart';
import 'match_board_specials.dart';

/// Last Hurrah(Product Spec 6-4, PLAN-005 1c, ADR-007 개정).
///
/// 타임 모드에서 시간이 0이 된 뒤 보드에 남은 특수 보석을 위쪽 행부터 왼쪽에서
/// 오른쪽 순서로 하나씩 발동한다. 한 발동의 연쇄 해소가 끝나면 다음 것을 다시 찾으므로
/// 연쇄로 새로 생긴 특수 보석도 발동한다. 보드 해소 단계는 [MatchBoardLogic.update]가
/// 진행하고, 이 클래스는 다음 발동 시점과 연출 상한만 정한다.
class LastHurrah {
  LastHurrah(this.board, {Random? random})
    : _random = random ?? Random(),
      scoreBefore = board.score {
    board.comboScoreMultiplier = useComboMultiplier;
  }

  /// 전체 마무리 연출 상한(초). 넘으면 남은 발동을 즉시 계산으로 끝낸다.
  static const double maxSeconds = 6;

  /// 첫 발동 전에 LAST HURRAH 표시를 읽을 시간(초). [maxSeconds]에 포함된다.
  static const double startDelaySeconds = 0.4;

  /// 마무리 점수의 콤보 배수 적용 여부(BR-011 연쇄 규칙). 플레이테스트로 바꾼다.
  static const bool useComboMultiplier = true;

  /// 연쇄로 특수 보석이 계속 생겨도 끝나도록 둔 발동 상한.
  static const int maxActivations = 64;

  /// 즉시 계산에서 보드 해소 단계를 진행하는 상한. 멈춘 상태에서 무한 반복을 막는다.
  static const int _maxInstantSteps = 10000;

  final MatchBoardLogic board;
  final Random _random;
  final int scoreBefore;
  int activations = 0;
  bool done = false;
  double _elapsed = 0;

  int get scoreAdded => board.score - scoreBefore;

  /// `last_hurrah` 이벤트 값(Product Spec 8-3).
  Map<String, Object?> get eventParams => {
    'specials_count': activations,
    'score_added': scoreAdded,
  };

  static bool hasSpecial(MatchBoardLogic board) => nextSpecial(board) != null;

  /// 다음 발동 칸. 위쪽 행(0)부터 왼쪽에서 오른쪽.
  static Point<int>? nextSpecial(MatchBoardLogic board) {
    for (var row = 0; row < board.rows; row++) {
      for (var col = 0; col < board.cols; col++) {
        final gem = board.getGem(row, col);
        if (gem != null && isSpecialGemKind(gem.kind)) return Point(row, col);
      }
    }
    return null;
  }

  /// 하이퍼가 지울 색: 보드에 남은 일반 보석 색 중 무작위. 없으면 null.
  static int? pickHyperColor(MatchBoardLogic board, Random random) {
    final colors = <int>{};
    for (var row = 0; row < board.rows; row++) {
      for (var col = 0; col < board.cols; col++) {
        final gem = board.getGem(row, col);
        if (gem != null && gem.kind == GemKind.normal) colors.add(gem.color);
      }
    }
    if (colors.isEmpty) return null;
    final sorted = colors.toList()..sort();
    return sorted[random.nextInt(sorted.length)];
  }

  /// 한 프레임 진행. 보드가 idle일 때만 다음 특수 보석을 발동한다.
  void update(double dt) {
    if (done) return;
    _elapsed += dt;
    if (_elapsed >= maxSeconds) {
      finishInstantly();
      return;
    }
    if (_elapsed < startDelaySeconds || board.state != 'idle') return;
    if (!_fireNext()) _finish();
  }

  /// 남은 해소와 발동을 연출 없이 한 번에 계산한다(상한 도달, reduced motion, 백그라운드).
  void finishInstantly() {
    if (done) return;
    final onGemsRemoved = board.onGemsRemoved;
    final onRemovalStarted = board.onRemovalStarted;
    final onSpecialsBorn = board.onSpecialsBorn;
    board
      ..onGemsRemoved = null
      ..onRemovalStarted = null
      ..onSpecialsBorn = null;
    for (var step = 0; step < _maxInstantSteps; step++) {
      if (board.state != 'idle') {
        board.advanceResolutionStep();
      } else if (!_fireNext()) {
        break;
      }
    }
    board
      ..onGemsRemoved = onGemsRemoved
      ..onRemovalStarted = onRemovalStarted
      ..onSpecialsBorn = onSpecialsBorn
      ..consumeSpecialEffectEvents();
    for (final row in board.cells) {
      for (final gem in row) {
        if (gem == null) continue;
        gem
          ..x = gem.targetX
          ..y = gem.targetY;
      }
    }
    _finish();
  }

  bool _fireNext() {
    if (activations >= maxActivations) return false;
    final cell = nextSpecial(board);
    if (cell == null) return false;
    final gem = board.getGem(cell.x, cell.y)!;
    board.selected = null;
    board.resolveSpecialSwap(
      {'${cell.x}:${cell.y}': true},
      [
        MatchChainItem(
          row: cell.x,
          col: cell.y,
          kind: gem.kind,
          triggerColor: gem.kind == GemKind.hyper
              ? pickHyperColor(board, _random)
              : gem.color,
        ),
      ],
      'last hurrah',
    );
    activations++;
    return true;
  }

  void _finish() {
    done = true;
    board.comboScoreMultiplier = true;
  }
}
