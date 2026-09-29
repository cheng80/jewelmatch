import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/game/round_timing.dart';
import 'package:stonematch/services/backend/pocketbase_config.dart';
import 'package:stonematch/services/backend/pocketbase_gateway.dart';
import 'package:stonematch/services/event_logger.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/records/records_store.dart';
import 'package:stonematch/services/telemetry_policy.dart';
import 'package:stonematch/utils/storage_helper.dart';

// PLAN-009 Step 2: 판/시도 문맥과 시간 분류. 가짜 단조 시계와 MockClient 로거만 쓴다.
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

  test('문맥 전에는 판 이벤트 없이 로컬 기록만 반영한다', () async {
    final t = Telemetry();
    final exited = t.game(JewelGameMode.timed, start: false);
    exited.board.score = 4200;
    exited.logRoundEnd('exit');
    expect(RecordsStore.load().totalScore, 4200);
    expect(exited.playContext, isNull);
    final game = t.game(JewelGameMode.timed, start: false);
    game.board.score = 1000;
    game.restartRound(); // 다시 하기는 새 run을 연다
    expect(RecordsStore.load().totalScore, 5200);

    expect(await t.names(), ['round_start']);
    final start = (await t.events('round_start')).single;
    expect(start['run_id'], game.playContext!.runId);
    expect(start['round_seq'], 1);
    expect(start['attempt_seq'], 0);
  });

  testWidgets('onLoad가 새 run의 round_start를 한 번 보낸다', (tester) async {
    final t = Telemetry();
    late MatchBoardGame game;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GameWidget<MatchBoardGame>.controlled(
            gameFactory: () => game = MatchBoardGame(
              gameMode: JewelGameMode.progression,
              eventLogger: t.logger,
              roundTiming: t.timing,
            ),
            overlayBuilderMap: {
              for (final name in overlayNames) name: (_, _) => const SizedBox(),
            },
          ),
        ),
      );
      await game.toBeLoaded();
    });
    await tester.pump();
    final context = game.playContext!;
    expect(context.roundSeq, 1);
    expect(context.attemptSeq, 0);
    game.isPlaying = false;
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      final starts = await t.events('round_start');
      expect(starts, hasLength(1));
      expect(starts.single['run_id'], context.runId);
      expect(starts.single['mode'], 'progression');
      // 강제 이탈은 새 종료/기록 처리를 넣지 않는다(PLAN-009 11절).
      expect(await t.events('round_end'), isEmpty);
    });
  });

  test('진행 중 다시 하기는 이전 run 종료와 새 run 시작을 한 번씩 보낸다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final first = game.playContext!;
    t.advance(2);
    game.pauseGame();
    game.restartRound();
    final second = game.playContext!;
    expect(second.runId, isNot(first.runId));
    expect(second.roundSeq, 1);
    expect(second.attemptSeq, 0);

    final ends = await t.events('round_end');
    expect(ends, hasLength(1));
    expect(ends.single['reason'], 'restart');
    expect(ends.single['run_id'], first.runId);
    final starts = await t.events('round_start');
    expect(starts.map((e) => e['run_id']), [first.runId, second.runId]);
  });

  test('시간 종료는 시도마다 round_end 한 번이고 이후 경로가 중복하지 않는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final context = game.playContext!;
    game.board.score = 3000;
    t.advance(4);
    game.timeRemaining = 0.01;
    game.update(0.02);
    expect(game.timeUp, isTrue);
    game.update(1 / 60);
    game.lifecycleStateChange(AppLifecycleState.paused);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    game.restartRound(); // TimeUp 뒤 다시 하기는 추가 종료가 없다
    expect(RecordsStore.load().totalScore, 3000);

    final ends = await t.events('round_end');
    expect(ends, hasLength(1));
    expect(ends.single['reason'], 'time_up');
    expect(ends.single['run_id'], context.runId);
    expect(ends.single['duration_s'], closeTo(4, 1e-9));
    expect(ends.single['active_s'], closeTo(4, 1e-9));
    expect(await t.events('speed_bonus_peak'), hasLength(1));
    expect(await t.events('round_start'), hasLength(2));
  });

  test('다음 레벨은 같은 run의 다음 판이고 시간과 시도를 초기화한다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    final first = game.playContext!;
    final serial = game.stageAttemptId;
    t.advance(3);
    triggerClear(game);
    expect(game.overlays.isActive('LevelCelebration'), isTrue);
    expect(RecordsStore.load().bestLevel, 2); // levelUpToLevel 기준 반영 유지
    t.advance(5); // 축하/레벨업 화면

    game.continueAfterLevelUp();
    final second = game.playContext!;
    expect(second.runId, first.runId);
    expect(second.roundSeq, 2);
    expect(second.attemptSeq, 0);
    expect(game.stageAttemptId, isNot(serial));
    t.advance(1); // 인트로
    game.pauseGame();
    game.logRoundEnd('exit');

    final clears = await t.events('level_clear');
    expect(clears, hasLength(1));
    expect(clears.single['round_seq'], 1);
    final ends = await t.events('round_end');
    expect(ends.map((e) => e['reason']), ['level_clear', 'exit']);
    expect(ends.first['round_seq'], 1);
    expect(ends.first['level'], 1);
    expect(ends.first['active_s'], closeTo(3, 1e-9));
    expect(ends.first['paused_s'], 0.0);
    expect(ends.last['round_seq'], 2);
    expect(ends.last['duration_s'], closeTo(1, 1e-9));
    expect(ends.last['system_s'], closeTo(1, 1e-9));
    final starts = await t.events('round_start');
    expect(starts.map((e) => e['round_seq']), [1, 2]);
    expect(starts.map((e) => e['run_id']).toSet(), {first.runId});
  });

  test('다음 레벨 콜백이 중복돼도 판과 round_start는 한 번만 연다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    triggerClear(game);
    game.continueAfterLevelUp();
    final context = game.playContext!;
    final serial = game.stageAttemptId;
    final hints = game.remainingHints;
    game.continueAfterLevelUp();

    expect(game.playContext, context);
    expect(context.roundSeq, 2);
    expect(game.progressionLevel, 2);
    expect(game.stageAttemptId, serial);
    expect(game.remainingHints, hints);
    final starts = await t.events('round_start');
    expect(starts.map((e) => e['round_seq']), [1, 2]);
  });

  test('플레이 중 바로 나가기 종료 뒤 시간은 paused, 백그라운드는 우선한다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    t.advance(2);
    game.logRoundEnd('exit'); // 일시정지 없이 엔진이 도는 상태
    t.advance(3);
    game.update(1 / 60);
    t.advance(1);
    game.lifecycleStateChange(AppLifecycleState.hidden);
    t.advance(4);

    expectTiming((await t.events('round_end')).single, active: 2);
    expectTiming(t.timing.snapshot(), active: 2, paused: 4, background: 4);
  });

  test('광고 이어하기는 같은 판의 다음 시도이고 시간은 판 시작부터 누적된다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    final first = game.playContext!;
    game.board.score = 500;
    t.advance(5);
    timeUp(game);
    t.advance(3); // 결과 화면과 광고
    expect(game.continueStageAfterAd(), isTrue);
    expect(game.playContext, first.nextAttempt());
    expect(game.timeRemaining, game.roundSecondsForMode);
    game.board.score = 800;
    t.advance(2);
    timeUp(game);
    t.advance(1);
    expect(game.continueStageAfterAd(), isTrue);
    t.advance(1);
    timeUp(game);
    // 로컬 기록은 기존 차감 규칙으로 최종 점수만 남는다.
    expect(RecordsStore.load().totalScore, 800);

    final ends = await t.events('round_end');
    expect(ends.map((e) => e['attempt_seq']), [0, 1, 2]);
    expect(ends.map((e) => e['round_seq']).toSet(), {1});
    expect(ends.map((e) => e['score']), [500, 800, 800]);
    expect(ends[1]['duration_s'], closeTo(10, 1e-9));
    expect(ends[1]['active_s'], closeTo(7, 1e-9));
    expect(ends[1]['paused_s'], closeTo(3, 1e-9));
    expect(ends[2]['duration_s'], closeTo(12, 1e-9));
    final continues = await t.events('stage_continue');
    expect(continues.map((e) => e['attempt_seq']), [1, 2]);
    expect(await t.events('round_start'), hasLength(1));
  });

  test('NoMoves와 새 보드는 같은 문맥이고 멈춘 시간은 paused, 채움은 system이다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    final context = game.playContext!;
    t.advance(1);
    game.debugShowNoMovesOverlay();
    t.advance(2);
    game.newBoard();
    expect(game.board.introFillInProgress, isTrue);
    t.advance(0.5);
    game.board.introFillInProgress = false;
    game.update(0);
    t.advance(1);
    game.pauseGame();
    t.advance(4);
    game.logRoundEnd('exit');

    expect(game.playContext, context);
    expect(await t.names(), ['round_start', 'round_end', ...roundSummaryNames]);
    expectTiming(
      (await t.events('round_end')).single,
      active: 2,
      system: 0.5,
      paused: 6,
    );
  });

  test('일시정지, 도움말, 랭킹 팝업 시간은 paused다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    t.advance(1);
    game.pauseGame();
    t.advance(2);
    game.resumeGame();
    t.advance(1);
    game.showHowToPlay();
    t.advance(3);
    game.closeHowToPlay();
    t.advance(1);
    game.pauseForRankingPopup();
    t.advance(4);
    game.closeRankingPopup();
    t.advance(1);
    game.pauseGame();
    game.logRoundEnd('exit');
    game.logRoundEnd('exit'); // 빠른 두 번 누름도 이벤트는 한 번

    final ends = await t.events('round_end');
    expect(ends, hasLength(1));
    expectTiming(ends.single, active: 4, paused: 9);
  });

  test('아이템 확인, 프리즘 선택, 힌트는 타이머가 멈춰도 active다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final context = game.playContext!;
    expect(game.requestImmediateItemConfirm(ItemKind.fateShuffle), isTrue);
    final time = game.timeRemaining;
    t.advance(2);
    game.update(2);
    expect(game.timeRemaining, time);
    game.cancelImmediateItemConfirm();
    expect(game.startItemTargeting(ItemKind.prismTransform), isTrue);
    expect(game.isPrismColorPicking, isTrue);
    t.advance(1);
    game.update(1);
    expect(game.timeRemaining, time);
    game.cancelItemTargeting();
    game.requestHint();
    t.advance(1);
    game.pauseGame();
    game.logRoundEnd('exit');

    expectTiming((await t.events('round_end')).single, active: 4);
    final cancel = (await t.events('item_target_cancel')).single;
    expect(cancel['run_id'], context.runId);
    expect(cancel['item_kind'], 'prismTransform');
  });

  test('inactive는 그대로, hidden/paused는 background, resumed는 메뉴 대기다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    t.advance(1);
    game.lifecycleStateChange(AppLifecycleState.inactive);
    t.advance(1);
    game.lifecycleStateChange(AppLifecycleState.hidden);
    expect(game.overlays.isActive('PauseMenu'), isTrue);
    t.advance(5);
    game.lifecycleStateChange(AppLifecycleState.paused);
    t.advance(1);
    game.lifecycleStateChange(AppLifecycleState.inactive);
    game.lifecycleStateChange(AppLifecycleState.resumed);
    // 재개 동작은 기존과 같다. 사용자가 PauseMenu에서 이어 한다.
    expect(game.isPlaying, isFalse);
    expect(game.paused, isTrue);
    expect(game.overlays.isActive('PauseMenu'), isTrue);
    t.advance(2);
    game.resumeGame();
    t.advance(1);
    game.pauseGame();
    game.logRoundEnd('exit');

    expect(await t.names(), ['round_start', 'round_end', ...roundSummaryNames]);
    expectTiming(
      (await t.events('round_end')).single,
      active: 3,
      paused: 2,
      background: 6,
    );
  });

  test('Last Hurrah는 system이고 끝난 뒤 round_end 한 번이다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final context = game.playContext!;
    putSpecial(game.board, 2, 3, GemKind.bomb);
    putSpecial(game.board, 5, 1, GemKind.row);
    t.advance(2);
    game.timeRemaining = 0.01;
    game.update(0.02);
    expect(game.lastHurrahActive, isTrue);
    expect(game.paused, isFalse);
    var frames = 0;
    while (!game.timeUp && frames < 60 * 8) {
      t.advance(1 / 60);
      game.update(1 / 60);
      frames++;
    }
    expect(game.timeUp, isTrue);
    game.update(1 / 60);

    final end = (await t.events('round_end')).single;
    expect(end['reason'], 'time_up');
    // 가짜 시계는 프레임마다 16667us씩 간다.
    expectTiming(end, active: 2, system: frames * 16667 / 1e6);
    final hurrah = (await t.events('last_hurrah')).single;
    expect(hurrah['run_id'], context.runId);
    expect(hurrah['attempt_seq'], 0);
  });

  test('Last Hurrah 중 백그라운드는 즉시 끝내고 종료 뒤 시간은 background다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    putSpecial(game.board, 2, 3, GemKind.bomb);
    t.advance(1);
    game.timeRemaining = 0.01;
    game.update(0.02);
    t.advance(0.5);
    game.lifecycleStateChange(AppLifecycleState.paused);
    expect(game.timeUp, isTrue);
    t.advance(10);
    game.update(1 / 60);

    final end = (await t.events('round_end')).single;
    expectTiming(end, active: 1, system: 0.5);
    expect(t.timing.snapshot()['background_s'], closeTo(10, 1e-9));
  });

  test('기록과 아이템과 하이퍼 이벤트도 현재 판 문맥을 붙인다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    final context = game.playContext!;
    game.board.score = 16000;
    game.board.onHyperSwap!(GemKind.bomb);
    game.pauseGame();
    game.logRoundEnd('exit');

    for (final name in ['hyper_swap', 'rank_up', 'badge_earned']) {
      final rows = await t.events(name);
      expect(rows, isNotEmpty, reason: name);
      for (final row in rows) {
        expect(row['run_id'], context.runId, reason: name);
        expect(row['round_seq'], 1, reason: name);
      }
    }
  });

  test('보너스 보석 round_end 최악 조합도 사용자 12개 안에서 잘리지 않는다', () async {
    final previous = GameplayFlags.current;
    addTearDown(() => GameplayFlags.current = previous);
    GameplayFlags.current = const GameplayFlags(
      timeRewardT1: true,
      timeGem: true,
      multiplierGem: true,
    );
    final t = Telemetry();
    final game = t.game(JewelGameMode.timed);
    expect(game.board.timeGemActive, isTrue);
    expect(game.board.multiplierGemActive, isTrue);
    game.board.score = 999999999;
    t.clock += const Duration(days: 30, microseconds: 123457);
    game.timeRemaining = 0.01;
    game.update(0.02);

    final end = (await t.events('round_end')).single;
    const user = {
      'mode',
      'reason',
      'exp',
      'score',
      'time_gems',
      'time_gem_seconds',
      'max_multiplier',
      'duration_s',
      'active_s',
      'system_s',
      'paused_s',
      'background_s',
    };
    expect(end.keys.toSet().intersection(user), user);
    expect(end.containsKey(EventLogger.paramsDroppedKey), isFalse);
    expect(utf8.encode(jsonEncode(end)).length, lessThan(1500));
  });
}

/// round_end 직후 같은 가드 안에서 한 번씩 오는 Step 3 판 요약 이벤트.
const roundSummaryNames = ['round_summary', 'round_specials', 'round_input'];

const overlayNames = [
  'IntroBlock',
  'PauseMenu',
  'NoMoves',
  'TimeUp',
  'HowToPlay',
  'RankingList',
  'LevelCelebration',
  'LevelUp',
  'StageInventory',
  'GameStats',
];

const _config = PocketBaseConfig(url: 'https://pb.example');
final _now = DateTime.utc(2026, 9, 29, 12);

/// MockClient로 실제 EventLogger 전송 본문을 받고, 가짜 단조 시계로 RoundTiming을 움직인다.
class Telemetry {
  Telemetry({this.policy}) {
    addTearDown(logger.dispose);
  }

  /// 표본 행동 이벤트를 검사할 때만 주입한다.
  final TelemetryPolicy? policy;

  final rows = <Map<String, Object?>>[];
  Duration clock = Duration.zero;
  late final RoundTiming timing = RoundTiming(now: () => clock);
  late final EventLogger logger = EventLogger(
    gateway: PocketBaseGateway(
      config: _config,
      now: () => _now,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/guest')) {
          return http.Response(
            jsonEncode({
              'token': 'token',
              'record': {'id': 'user-1'},
              'expires_in': 3600,
            }),
            200,
          );
        }
        for (final row in jsonDecode(request.body) as List<dynamic>) {
          rows.add((row as Map).cast<String, Object?>());
        }
        return http.Response('', 204);
      }),
    ),
    flushDelay: const Duration(hours: 1),
    batchSize: 1000,
    maxQueue: 1000,
    now: () => _now,
    policy: policy,
  );

  void advance(double seconds) =>
      clock += Duration(microseconds: (seconds * 1e6).round());

  /// 이름이 [name]인 이벤트의 params(없으면 전체).
  Future<List<Map<String, Object?>>> events([String? name]) async {
    await logger.flush();
    return [
      for (final row in rows)
        if (name == null || row['name'] == name)
          (row['params']! as Map).cast<String, Object?>(),
    ];
  }

  Future<List<String>> names() async {
    await logger.flush();
    return [for (final row in rows) row['name']! as String];
  }

  /// [start]면 onLoad 대신 다시 하기로 첫 run을 연다(onLoad는 별도 위젯 테스트).
  MatchBoardGame game(JewelGameMode mode, {bool start = true}) {
    final game = MatchBoardGame(
      gameMode: mode,
      eventLogger: logger,
      roundTiming: timing,
    )..lastHurrahRandom = Random(5);
    for (final name in overlayNames) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    prepare(game);
    if (start) {
      game.restartRound();
      prepare(game);
    }
    return game;
  }
}

void prepare(MatchBoardGame game) {
  for (var row = 0; row < _validMoveRows.length; row++) {
    for (var col = 0; col < _validMoveRows[row].length; col++) {
      game.board.setGem(
        row,
        col,
        game.board.createGem(
          row,
          col,
          _validMoveRows[row][col],
          GemKind.normal,
        ),
      );
    }
  }
  game.board.setGeometry(x: 0, y: 0, tile: 10);
  game.board.introFillInProgress = false;
  game.update(0);
}

void timeUp(MatchBoardGame game) {
  game.timeRemaining = 0.01;
  game.update(0.02);
  expect(game.timeUp, isTrue);
}

void triggerClear(MatchBoardGame game) {
  game.board.score = game.progressionTargetScore;
  game.update(0);
}

void putSpecial(MatchBoardLogic board, int row, int col, GemKind kind) {
  final color = kind == GemKind.hyper ? 0 : board.getGem(row, col)!.color;
  board.setGem(row, col, board.createGem(row, col, color, kind));
}

void expectTiming(
  Map<String, Object?> end, {
  double active = 0,
  double system = 0,
  double paused = 0,
  double background = 0,
}) {
  expect(end['active_s'], closeTo(active, 1e-6), reason: 'active_s');
  expect(end['system_s'], closeTo(system, 1e-6), reason: 'system_s');
  expect(end['paused_s'], closeTo(paused, 1e-6), reason: 'paused_s');
  expect(end['background_s'], closeTo(background, 1e-6), reason: 'background');
  expect(
    end['duration_s'],
    closeTo(active + system + paused + background, 1e-6),
    reason: 'duration_s',
  );
}

const _validMoveRows = [
  [1, 2, 1, 4, 5, 6, 1, 2],
  [2, 1, 4, 5, 6, 1, 2, 3],
  [3, 4, 3, 6, 1, 2, 3, 4],
  [4, 3, 6, 1, 2, 3, 4, 5],
  [5, 6, 1, 2, 3, 4, 5, 6],
  [6, 1, 2, 3, 4, 5, 6, 1],
  [1, 2, 3, 4, 5, 6, 1, 2],
  [2, 3, 4, 5, 6, 1, 2, 3],
];
