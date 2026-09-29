import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/round_summary.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

import 'round_lifecycle_events_test.dart'
    show Telemetry, putSpecial, roundSummaryNames, timeUp, triggerClear;

// PLAN-009 Step 3: round_end 가드 안의 판 요약 3종(round_summary, round_specials, round_input).
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

  test('요약 3종은 각각 사용자 12개 이하이며 최대값에서도 잘리지 않는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    const big = 999999999;
    final stats = game.board.stats
      ..validSwaps = big
      ..matchGroups = big
      ..removedGems = big
      ..specialGemsCreated = big
      ..specialGemsActivated = big
      ..hyperSwaps = big
      ..bestMoveScore = big;
    for (final kind in GemKind.values) {
      stats.removedByKind[kind] = big;
      stats.specialCreatedByKind[kind] = big;
      stats.specialActivatedByKind[kind] = big;
    }
    game.board.maxCombo = big;
    game.roundInput
      ..invalidSwaps = big
      ..tapSwaps = big
      ..dragSwaps = big
      ..specialTaps = big
      ..hintsUsed = big
      ..itemsUsed = big
      ..firstSuccessActiveS = 2592000.123457;
    game.pauseGame();
    game.logRoundEnd('exit');

    const expected = {
      'round_summary': {
        'valid_swaps',
        'match_groups',
        'removed_gems',
        'removed_specials',
        'specials_created',
        'specials_activated',
        'hyper_swaps',
        'best_move',
        'max_combo',
      },
      'round_specials': {
        'created_row',
        'activated_row',
        'created_col',
        'activated_col',
        'created_bomb',
        'activated_bomb',
        'created_star',
        'activated_star',
        'created_hyper',
        'activated_hyper',
        'created_supernova',
        'activated_supernova',
      },
      'round_input': {
        'invalid_swaps',
        'tap_swaps',
        'drag_swaps',
        'special_taps',
        'hints_used',
        'items_used',
        'first_success_active_s',
      },
    };
    for (final MapEntry(key: name, value: keys) in expected.entries) {
      final row = (await t.events(name)).single;
      final user = row.keys.where((k) => !_reserved.contains(k)).toSet();
      expect(user, keys, reason: name);
      expect(user.length, lessThanOrEqualTo(12), reason: name);
      expect(row.containsKey(EventLogger.paramsDroppedKey), isFalse);
      expect(utf8.encode(jsonEncode(row)).length, lessThan(1500));
      expect(row['run_id'], game.playContext!.runId);
    }
    final summary = (await t.events('round_summary')).single;
    expect(summary['removed_specials'], big * (GemKind.values.length - 1));
    expect(summary['max_combo'], big);
  });

  test('요약은 보드 통계와 같고 시도당 한 번, 이어하기는 누적, 다음 레벨은 초기화한다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    game.board.stats
      ..recordValidSwap()
      ..recordMatchGroups(2)
      ..recordGemRemoved(GemKind.normal, 1)
      ..recordGemRemoved(GemKind.bomb)
      ..recordSpecialCreated(GemKind.row)
      ..recordSpecialActivated(GemKind.bomb)
      ..recordMoveScore(120); // 진행 중인 한 수도 종료에서 확정한다
    game.board.maxCombo = 3;
    timeUp(game);
    game.logRoundEnd('exit'); // 이미 끝난 시도라 요약을 다시 보내지 않는다
    expect(game.continueStageAfterAd(), isTrue);
    game.board.stats
      ..recordValidSwap()
      ..recordSpecialActivated(GemKind.row);
    timeUp(game);
    expect(game.continueStageAfterAd(), isTrue);
    game.debugShowNoMovesOverlay();
    game.newBoard(); // NoMoves 새 보드도 같은 판의 누적을 유지한다
    game.board.introFillInProgress = false;
    triggerClear(game);
    game.continueAfterLevelUp();
    game.pauseGame();
    game.logRoundEnd('exit');

    final summaries = await t.events('round_summary');
    expect(summaries.map((e) => e['attempt_seq']), [0, 1, 2, 0]);
    expect(summaries.map((e) => e['round_seq']), [1, 1, 1, 2]);
    expect(summaries.map((e) => e['valid_swaps']), [1, 2, 2, 0]);
    expect(summaries.first, {
      ...summaries.first,
      'match_groups': 2,
      'removed_gems': 2,
      'removed_specials': 1,
      'specials_created': 1,
      'specials_activated': 1,
      'hyper_swaps': 0,
      'best_move': 120,
      'max_combo': 3,
    });
    expect(summaries[1]['specials_activated'], 2);
    final specials = await t.events('round_specials');
    expect(specials.map((e) => e['activated_row']), [0, 1, 1, 0]);
    expect(specials.map((e) => e['created_row']), [1, 1, 1, 0]);
    expect(specials.first['activated_bomb'], 1);
    expect(specials.first['created_supernova'], 0);
    for (final name in roundSummaryNames) {
      expect(await t.events(name), hasLength(4), reason: name);
    }
    final ends = await t.events('round_end');
    expect(ends.map((e) => e['reason']), [
      'time_up',
      'time_up',
      'level_clear',
      'exit',
    ]);
  });

  test('다시 하기는 새 run으로 요약을 초기화한다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    game.board.stats.recordValidSwap();
    game.pauseGame();
    game.restartRound();
    game.pauseGame();
    game.logRoundEnd('exit');

    final summaries = await t.events('round_summary');
    expect(summaries.map((e) => e['valid_swaps']), [1, 0]);
    expect(summaries[0]['run_id'], isNot(summaries[1]['run_id']));
  });

  test('Last Hurrah 자동 발동은 제거와 특수 수치에 들고 best_move에는 빠진다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    putSpecial(game.board, 2, 3, GemKind.bomb);
    putSpecial(game.board, 5, 1, GemKind.row);
    game.timeRemaining = 0.01;
    game.update(0.02);
    expect(game.lastHurrahActive, isTrue);
    var frames = 0;
    while (!game.timeUp && frames < 60 * 8) {
      game.update(1 / 60);
      frames++;
    }
    expect(game.timeUp, isTrue);

    final summary = (await t.events('round_summary')).single;
    final stats = game.board.stats;
    expect(summary, {
      ...summary,
      ...roundSummaryParams(stats, maxCombo: game.board.maxCombo),
    });
    expect(summary['specials_activated'], greaterThanOrEqualTo(2));
    expect(summary['removed_gems'], greaterThan(0));
    expect(summary['valid_swaps'], 0);
    expect(summary['best_move'], 0);
    final specials = (await t.events('round_specials')).single;
    expect(specials['activated_bomb'], 1);
    expect(specials['activated_row'], 1);
    final input = (await t.events('round_input')).single;
    expect(input['special_taps'], 0); // 자동 발동은 사용자 입력이 아니다
    expect(input.containsKey('first_success_active_s'), isFalse);
  });
}

const _reserved = {
  'event_id',
  'event_seq',
  'schema_version',
  'telemetry_env',
  'collection',
  'sample_rate',
  'run_id',
  'round_seq',
  'attempt_seq',
};
