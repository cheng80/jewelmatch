import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/game_settings.dart';
import '../services/ranking_service.dart';

/// 랭킹 제출 상태.
class RankingSubmitState {
  const RankingSubmitState({
    this.isSubmitting = false,
    this.submitted = false,
    this.rankMessage,
  });

  final bool isSubmitting;
  final bool submitted;
  final String? rankMessage;

  RankingSubmitState copyWith({
    bool? isSubmitting,
    bool? submitted,
    String? rankMessage,
  }) {
    return RankingSubmitState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitted: submitted ?? this.submitted,
      rankMessage: rankMessage ?? this.rankMessage,
    );
  }
}

/// 타임 모드 종료 시 랭킹 제출을 담당하는 Notifier.
///
/// View에서 `ref.read(rankingProvider.notifier).submit(...)` 호출.
/// 결과는 필요한 필드만 `select`로 구독해 UI에 반영한다.
class RankingNotifier extends Notifier<RankingSubmitState> {
  @override
  RankingSubmitState build() => const RankingSubmitState();

  /// 점수를 서버에 제출한다. [trRankSuccess] 등은 이미 번역된 템플릿 문자열.
  Future<void> submit({
    required int score,
    required String trRankSuccess,
    required String trRankNotInTop,
    required String trRankSubmitFailed,
  }) async {
    if (state.submitted || score <= 0) return;

    state = state.copyWith(isSubmitting: true);

    final name = GameSettings.playerName;
    final result = await RankingService.submit(name: name, score: score);

    String message;
    if (result == null) {
      message = trRankSubmitFailed;
    } else if (result.ranked) {
      message = trRankSuccess
          .replaceAll('{rank}', '${result.rank}')
          .replaceAll('{score}', '${result.score}');
    } else {
      message = trRankNotInTop;
    }

    state = RankingSubmitState(
      isSubmitting: false,
      submitted: true,
      rankMessage: message,
    );
  }

  /// 재시작 등으로 상태를 초기화한다.
  void reset() {
    state = const RankingSubmitState();
  }
}

final rankingProvider = NotifierProvider<RankingNotifier, RankingSubmitState>(
  RankingNotifier.new,
);
