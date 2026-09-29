import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/ranking_service.dart';
import 'package:stonematch/utils/storage_helper.dart';
import 'package:stonematch/vm/ranking_notifier.dart';

import 'round_lifecycle_events_test.dart' show Telemetry, timeUp;

// PLAN-009 Step 2: 랭킹 제출은 요청 시점(await 전)의 판 문맥으로 기록한다.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  Future<void> submit(
    ProviderContainer container,
    RankingMode mode,
    int score,
    void Function(String, Map<String, Object?>) logEvent, {
    String? skipMessage,
  }) => container
      .read(rankingProvider.notifier)
      .submit(
        mode: mode,
        score: score,
        trRankSuccess: 'ok',
        trRankNotInTop: 'no',
        trRankNotFound: 'nf',
        trRankLoadFailed: 'lf',
        trRankSaveFailed: 'sf',
        trRankSubmitFailed: 'fail',
        trIntossLevelRankSubmitFailed: 'toss',
        skipMessage: skipMessage,
        logEvent: logEvent,
      );

  test('늦은 제출 결과는 다시 하기 뒤에도 요청한 run에 붙는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final requested = game.playContext!;
    game.board.score = 1200;
    timeUp(game);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pending = submit(
      container,
      RankingMode.time,
      game.rankingScore,
      game.capturePlayEventSink(),
    );
    game.restartRound(); // 응답 전에 새 run
    expect(game.playContext!.runId, isNot(requested.runId));
    await pending;

    final row = (await t.events('ranking_submit')).single;
    expect(row['run_id'], requested.runId);
    expect(row['round_seq'], 1);
    expect(row['attempt_seq'], 0);
    expect(row['ok'], isFalse);
  });

  test('늦은 제출 결과는 이어하기 뒤에도 끝난 시도에 붙는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    game.progressionLevel = 3;
    timeUp(game);
    final requested = game.playContext!;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pending = submit(
      container,
      RankingMode.level,
      game.rankingScore,
      game.capturePlayEventSink(),
    );
    expect(game.continueStageAfterAd(), isTrue);
    expect(game.playContext!.attemptSeq, 1);
    await pending;

    final row = (await t.events('ranking_submit')).single;
    expect(row['run_id'], requested.runId);
    expect(row['attempt_seq'], 0);
  });

  test('실험 URL 건너뛰기도 캡처한 문맥으로 기록한다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await submit(
      container,
      RankingMode.time,
      500,
      game.capturePlayEventSink(),
      skipMessage: 'skipped',
    );

    final row = (await t.events('ranking_submit')).single;
    expect(row['run_id'], game.playContext!.runId);
    expect(row['failure'], 'experiment_url');
  });
}
