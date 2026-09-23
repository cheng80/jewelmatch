import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_config.dart';
import '../services/event_logger.dart';
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
  static const Duration submitTimeout = Duration(seconds: 8);

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
    String? skipMessage,
  }) async {
    if (state.isSubmitting || state.submitted || score <= 0) return;
    // URL 실험 설정으로 한 판은 서버와 앱인토스 리더보드에 올리지 않는다.
    if (skipMessage != null) {
      EventLogger.instance.log('ranking_submit', {
        'mode': mode.queryValue,
        'score': score,
        'ok': false,
        'failure': 'experiment_url',
      });
      state = RankingSubmitState(submitted: true, rankMessage: skipMessage);
      return;
    }

    state = state.copyWith(isSubmitting: true);

    final name = GameSettings.playerName;
    final intossSubmission =
        IntossLeaderboardService.shouldSubmit(AppConfig.storeChannel, mode)
        ? IntossLeaderboardService.submitLevelScore(
            score,
          ).timeout(submitTimeout, onTimeout: () => false)
        : null;
    // 나가기 대기 상한(BR-093). 두 제출의 상한은 같은 시각에 시작해 전체 대기가 8초를 넘지 않는다.
    final result =
        await RankingService.submit(
          mode: mode,
          name: name,
          score: score,
        ).timeout(
          submitTimeout,
          onTimeout: () =>
              const RankingResult.failure(RankingFailure.unavailable),
        );
    final intossSubmitted = await intossSubmission;
    EventLogger.instance.log('ranking_submit', {
      'mode': mode.queryValue,
      'score': score,
      'ok': result.isSuccess,
      if (result.isSuccess) 'ranked': result.data!.ranked,
      if (result.isSuccess && result.data!.rank != null)
        'rank': result.data!.rank!,
      if (!result.isSuccess) 'failure': result.failure!.name,
    });

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
      submitted: result.isSuccess,
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
