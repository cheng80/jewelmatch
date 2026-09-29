import 'match_board_models.dart';

/// round_summary 파라미터(PLAN-009 Step 3). 기존 보드 통계를 그대로 옮긴다.
/// 제거와 특수 수치는 Last Hurrah 자동 마무리를 포함하고 best_move는 제외한다(기존 규칙).
Map<String, Object?> roundSummaryParams(
  MatchBoardGameStats stats, {
  required int maxCombo,
}) => {
  'valid_swaps': stats.validSwaps,
  'match_groups': stats.matchGroups,
  'removed_gems': stats.removedGems,
  'removed_specials': stats.removedSpecialGems,
  'specials_created': stats.specialGemsCreated,
  'specials_activated': stats.specialGemsActivated,
  'hyper_swaps': stats.hyperSwaps,
  'best_move': stats.bestMoveScore,
  'max_combo': maxCombo,
};

/// round_specials 파라미터. 일반 보석을 뺀 6종의 생성/발동 수(12개, 0 포함).
Map<String, Object?> roundSpecialsParams(MatchBoardGameStats stats) => {
  for (final kind in GemKind.values)
    if (kind != GemKind.normal) ...{
      'created_${kind.name}': stats.specialCreatedByKind[kind] ?? 0,
      'activated_${kind.name}': stats.specialActivatedByKind[kind] ?? 0,
    },
};

/// 판 단위 사용자 입력 계수(round_input). 새 판과 다시 하기에서 새로 만들고,
/// 광고 이어하기와 NoMoves 섞기/새 보드에서는 유지한다. 게임 입력 처리기에서만 올린다.
class RoundInputStats {
  /// 매치가 안 돼 되돌아간 교환(onInvalidSwap)만. 입력 차단, 바깥 좌표, 안정 구역 거절은 세지 않는다.
  int invalidSwaps = 0;

  /// 칸 선택 뒤 인접 칸 누름으로 성공한 교환(하이퍼 교환 포함). 누름 시점에 교환되므로
  /// 선택된 칸 옆에서 드래그를 시작해도 여기로 센다.
  int tapSwaps = 0;

  /// 스와이프 제스처로 성공한 교환(하이퍼 교환 포함).
  int dragSwaps = 0;

  /// 특수 보석 직접 발동(누름, 또는 하이퍼는 뗌).
  int specialTaps = 0;

  /// 힌트 버튼으로 실제 표시한 수. 일반 모드 자동 힌트와 힌트 아이템은 세지 않는다.
  int hintsUsed = 0;

  /// 실제로 쓰인 아이템 수(item_used와 같은 조건).
  int itemsUsed = 0;

  /// 첫 교환 또는 특수 직접 발동이 성공한 순간의 판 active_s. 없으면 필드를 뺀다.
  double? firstSuccessActiveS;

  void recordSuccess(double activeS) => firstSuccessActiveS ??= activeS;

  Map<String, Object?> eventParams() => {
    'invalid_swaps': invalidSwaps,
    'tap_swaps': tapSwaps,
    'drag_swaps': dragSwaps,
    'special_taps': specialTaps,
    'hints_used': hintsUsed,
    'items_used': itemsUsed,
    'first_success_active_s': ?firstSuccessActiveS,
  };
}
