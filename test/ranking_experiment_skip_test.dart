import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/vm/ranking_notifier.dart';

// 검수 R4 P1-2: URL 실험 설정 판은 서버에 보내지 않고 안내 문구만 남긴다.
void main() {
  test('skipMessage skips the server and marks the round submitted', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(rankingProvider.notifier)
        .submit(
          mode: RankingMode.time,
          score: 1200,
          trRankSuccess: 'ok',
          trRankNotInTop: 'no',
          trRankNotFound: 'nf',
          trRankLoadFailed: 'lf',
          trRankSaveFailed: 'sf',
          trRankSubmitFailed: 'fail',
          trIntossLevelRankSubmitFailed: 'toss',
          skipMessage: 'skipped',
        );
    final state = container.read(rankingProvider);
    expect(state.submitted, isTrue);
    expect(state.isSubmitting, isFalse);
    expect(state.rankMessage, 'skipped');
  });
}
