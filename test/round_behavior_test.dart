import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/services/telemetry_policy.dart';
import 'package:stonematch/utils/storage_helper.dart';

import 'round_lifecycle_events_test.dart'
    show Telemetry, putSpecial, timeUp, triggerClear;

// PLAN-009 Step 3: round_input 입력 계수는 실제 게임 입력 처리기 경로에서만 오른다.
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

  test('탭 교환, 실패 교환, 차단 입력, 첫 성공 시간', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    final bad = _invalidPair(game.board);
    final good = game.board.getAllValidMoves().first;

    game.board.lockInput(1);
    tap(game, good.a);
    tap(game, good.b);
    game.handleBoardTap(-5, -5); // 보드 바깥
    game.board.inputLocked = false;
    t.advance(1);
    tap(game, bad.a);
    tap(game, bad.b); // 매치 불성립
    settle(game);
    t.advance(0.5);
    tap(game, good.a);
    tap(game, good.b);
    settle(game);
    t.advance(2);
    game.pauseGame();
    game.logRoundEnd('exit');

    final input = (await t.events('round_input')).single;
    expect(input, {
      ...input,
      'invalid_swaps': 1,
      'tap_swaps': 1,
      'drag_swaps': 0,
      'special_taps': 0,
      'hints_used': 0,
      'items_used': 0,
    });
    expect(input['first_success_active_s'], closeTo(1.5, 1e-9));
  });

  test('드래그 시작의 누름은 탭으로 세지 않고 스와이프 결과만 센다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    final bad = _invalidPair(game.board);
    final good = game.board.getAllValidMoves().first;

    // Flame은 드래그에도 tapDown을 먼저 보낸다. 누름은 칸 선택만 하고 교환은 스와이프가 한다.
    tap(game, bad.a);
    expect(swipe(game, bad.a, bad.b), isFalse);
    game.endBoardDrag();
    settle(game);
    t.advance(3);
    tap(game, good.a);
    expect(swipe(game, good.a, good.b), isTrue);
    settle(game);
    game.pauseGame();
    game.logRoundEnd('exit');

    final input = (await t.events('round_input')).single;
    expect(input['invalid_swaps'], 1);
    expect(input['drag_swaps'], 1);
    expect(input['tap_swaps'], 0);
    expect(input['first_success_active_s'], closeTo(3, 1e-9));
  });

  test('특수 보석 직접 발동: 일반 특수는 누름, 하이퍼는 뗌', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    putSpecial(game.board, 2, 3, GemKind.bomb);
    putSpecial(game.board, 6, 6, GemKind.hyper);
    t.advance(0.25);
    tap(game, const Point(2, 3));
    settle(game);
    tap(game, const Point(6, 6));
    expect(game.roundInput.specialTaps, 1); // 누름만으로는 하이퍼를 발동하지 않는다
    game.handleBoardTapUp();
    settle(game);
    game.pauseGame();
    game.logRoundEnd('exit');

    final input = (await t.events('round_input')).single;
    expect(input['special_taps'], 2);
    expect(input['tap_swaps'], 0);
    expect(input['first_success_active_s'], closeTo(0.25, 1e-9));
    final specials = (await t.events('round_specials')).single;
    expect(specials['activated_bomb'], greaterThanOrEqualTo(1));
    expect(specials['activated_hyper'], greaterThanOrEqualTo(1));
  });

  test('힌트는 버튼 성공만, 자동 힌트는 세지 않는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.simple);
    expect(game.board.idleHintsEnabled, isTrue);
    for (var i = 0; i < 60 * 8 && game.board.hintCellA == null; i++) {
      game.update(1 / 60); // 5초 대기 자동 힌트
    }
    expect(game.board.hintCellA, isNotNull);
    game.board.clearHint();
    game.requestHint();
    game.pauseGame();
    game.requestHint(); // 멈춘 동안은 표시하지 않는다
    game.logRoundEnd('exit');

    final input = (await t.events('round_input')).single;
    expect(input['hints_used'], 1);
    expect(input.containsKey('first_success_active_s'), isFalse);
  });

  test('아이템은 items_used만 올리고 교환, 탭, 첫 성공에 넣지 않는다', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    expect(game.startItemTargeting(ItemKind.runeHammer), isTrue);
    tap(game, const Point(3, 3));
    settle(game);
    expect(game.requestImmediateItemConfirm(ItemKind.fateShuffle), isTrue);
    expect(game.confirmImmediateItemUse(), isTrue);
    settle(game);
    game.pauseGame();
    game.logRoundEnd('exit');

    final input = (await t.events('round_input')).single;
    expect(input['items_used'], 2);
    expect(input['tap_swaps'], 0);
    expect(input['special_taps'], 0);
    expect(input.containsKey('first_success_active_s'), isFalse);
    expect(await t.events('item_used'), hasLength(2));
  });

  test('입력 계수는 이어하기와 NoMoves에서 유지, 다음 레벨과 다시 하기에서 초기화', () async {
    final t = Telemetry();
    final game = t.game(JewelGameMode.progression);
    var good = game.board.getAllValidMoves().first;
    t.advance(1);
    tap(game, good.a);
    tap(game, good.b);
    settle(game);
    timeUp(game);
    expect(game.continueStageAfterAd(), isTrue);
    game.debugShowNoMovesOverlay();
    game.newBoard();
    game.board.introFillInProgress = false;
    good = game.board.getAllValidMoves().first;
    t.advance(1);
    expect(swipe(game, good.a, good.b), isTrue);
    settle(game);
    timeUp(game);
    expect(game.continueStageAfterAd(), isTrue);
    triggerClear(game);
    game.continueAfterLevelUp();
    expect(game.roundInput.tapSwaps, 0);
    game.pauseGame();
    game.logRoundEnd('exit');

    final inputs = await t.events('round_input');
    expect(inputs.map((e) => e['attempt_seq']), [0, 1, 2, 0]);
    expect(inputs.map((e) => e['tap_swaps']), [1, 1, 1, 0]);
    expect(inputs.map((e) => e['drag_swaps']), [0, 1, 1, 0]);
    expect(inputs.map((e) => e['first_success_active_s']), [
      closeTo(1, 1e-9),
      closeTo(1, 1e-9),
      closeTo(1, 1e-9),
      null,
    ]);
  });

  test('HUD 메뉴 이용은 표본 행동 이벤트로 현재 판 문맥을 붙인다', () async {
    final t = Telemetry(policy: const TelemetryPolicy(sessionSampled: true));
    final game = t.game(JewelGameMode.timed);
    game.hudMenuAction('pause', game.pauseGame);
    expect(game.overlays.isActive('PauseMenu'), isTrue);
    game.resumeGame();
    game.hudMenuAction('help', game.showHowToPlay);
    game.closeHowToPlay();
    game.hudMenuAction('ranking', game.pauseForRankingPopup);

    final rows = await t.events('game_menu_action');
    expect(rows.map((e) => e['action']), ['pause', 'help', 'ranking']);
    for (final row in rows) {
      expect(row['collection'], 'sampled');
      expect(row['mode'], 'timed');
      expect(row['run_id'], game.playContext!.runId);
    }

    final off = Telemetry(policy: const TelemetryPolicy(sessionSampled: false));
    final other = off.game(JewelGameMode.timed);
    other.hudMenuAction('pause', other.pauseGame);
    expect(other.overlays.isActive('PauseMenu'), isTrue);
    expect(await off.events('game_menu_action'), isEmpty);
  });
}

Offset _center(Point<int> cell) => Offset(cell.y * 10.0 + 5, cell.x * 10.0 + 5);

void tap(MatchBoardGame game, Point<int> cell) {
  final p = _center(cell);
  game.handleBoardTap(p.dx, p.dy);
}

bool swipe(MatchBoardGame game, Point<int> from, Point<int> to) {
  final p = _center(from);
  final q = _center(to);
  return game.handleBoardSwipe(
    p.dx,
    p.dy,
    q.dx,
    q.dy,
    to.x - from.x,
    to.y - from.y,
  );
}

/// 보드가 멈추고 입력 잠금이 풀릴 때까지 프레임을 돌린다.
void settle(MatchBoardGame game) {
  for (var i = 0; i < 60 * 10; i++) {
    if (game.board.state == 'idle' && !game.board.inputLocked) return;
    game.update(1 / 60);
  }
  fail('보드가 멈추지 않음: ${game.board.state}');
}

/// 매치가 나오지 않는 인접 일반 보석 쌍.
({Point<int> a, Point<int> b}) _invalidPair(MatchBoardLogic board) {
  final valid = {for (final m in board.getAllValidMoves()) '${m.a}${m.b}'};
  for (var r = 0; r < board.rows; r++) {
    for (var c = 0; c + 1 < board.cols; c++) {
      final a = Point(r, c);
      final b = Point(r, c + 1);
      if (!valid.contains('$a$b')) return (a: a, b: b);
    }
  }
  throw StateError('실패 교환 쌍이 없음');
}
