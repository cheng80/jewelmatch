import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../services/game_settings.dart';
import '../services/intoss_leaderboard_service.dart';
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

  @override
  bool operator ==(Object other) {
    return other is RankingSubmitState &&
        other.isSubmitting == isSubmitting &&
        other.submitted == submitted &&
        other.rankMessage == rankMessage;
  }

  @override
  int get hashCode => Object.hash(isSubmitting, submitted, rankMessage);
}

/// 타임 모드 종료 시 랭킹 제출을 담당하는 Notifier.
///
/// View에서 `ref.read(rankingProvider.notifier).submit(...)` 호출.
/// 결과는 필요한 필드만 `select`로 구독해 UI에 반영한다.
class RankingNotifier extends Notifier<RankingSubmitState> {
  @override
  RankingSubmitState build() => const RankingSubmitState();

  @override
  bool updateShouldNotify(
    RankingSubmitState previous,
    RankingSubmitState next,
  ) {
    return previous != next;
  }

  /// 점수를 서버에 제출한다. [trRankSuccess] 등은 이미 번역된 템플릿 문자열.
  Future<void> submit({
    required RankingMode mode,
    required int score,
    required String trRankSuccess,
    required String trRankNotInTop,
    required String trRankNotFound,
    required String trRankLoadFailed,
    required String trRankSaveFailed,
    required String trRankSubmitFailed,
    required String trIntossLevelRankSubmitFailed,
  }) async {
    if (state.isSubmitting || state.submitted || score <= 0) return;

    state = state.copyWith(isSubmitting: true);

    final name = GameSettings.playerName;
    final intossSubmission =
        IntossLeaderboardService.shouldSubmit(AppConfig.storeChannel, mode)
        ? IntossLeaderboardService.submitLevelScore(score)
        : null;
    final result = await RankingService.submit(
      mode: mode,
      name: name,
      score: score,
    );
    final intossSubmitted = await intossSubmission;

    String message;
    if (!result.isSuccess) {
      message = switch (result.failure!) {
        RankingFailure.notFound => trRankNotFound,
        RankingFailure.loadFailed => trRankLoadFailed,
        RankingFailure.saveFailed => trRankSaveFailed,
        RankingFailure.unavailable => trRankSubmitFailed,
      };
    } else if (result.data!.ranked) {
      message = trRankSuccess
          .replaceAll('{rank}', '${result.data!.rank}')
          .replaceAll('{score}', '${result.data!.score}');
    } else {
      message = trRankNotInTop;
    }
    if (intossSubmitted == false) {
      message = '$message\n$trIntossLevelRankSubmitFailed';
    }

    state = RankingSubmitState(
      isSubmitting: false,
      submitted: true,
      rankMessage: message,
    );
  }

  /// 재시작 등으로 상태를 초기화한다.
  void reset() {
    if (state == const RankingSubmitState()) return;
    state = const RankingSubmitState();
  }
}

final rankingProvider = NotifierProvider<RankingNotifier, RankingSubmitState>(
  RankingNotifier.new,
);
