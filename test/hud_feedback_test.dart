import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';
import 'package:stonematch/services/game_settings.dart';
import 'package:stonematch/utils/storage_helper.dart';

(MatchBoardGame, MatchGameHud) fixture(JewelGameMode mode) {
  final g = MatchBoardGame(gameMode: mode);
  g.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
  g.onGameResize(Vector2(390, 750));
  g.board.introFillInProgress = false;
  g.board.state = 'idle';
  g.board.inputLocked = false;
  final h = MatchGameHud(
    onPausePressed: () {},
    onHintPressed: g.requestHint,
    onTutorialPressed: () {},
    onRankingPressed: mode == JewelGameMode.timed ? () {} : null,
  )..game = g;
  h.onGameResize(g.size);
  h.update(0);
  return (g, h);
}

void paint(MatchGameHud hud) {
  final rec = ui.PictureRecorder();
  hud.render(ui.Canvas(rec));
  rec.endRecording().dispose();
}

void hintBoard(MatchBoardGame g) {
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      g.board.setGem(
        r,
        c,
        g.board.createGem(r, c, (r + c) % 6 + 1, GemKind.normal),
      );
    }
  }
  g.board.setGem(0, 0, g.board.createGem(0, 0, 1, GemKind.normal));
  g.board.setGem(0, 1, g.board.createGem(0, 1, 2, GemKind.normal));
  g.board.setGem(0, 2, g.board.createGem(0, 2, 1, GemKind.normal));
  g.board.setGem(1, 1, g.board.createGem(1, 1, 1, GemKind.normal));
}

// 실제 GameRenderBox에 붙이되 보드 update는 호출하지 않아 HUD 독립성을 검사한다.
class HudOnlyGame extends MatchBoardGame {
  HudOnlyGame() : super(gameMode: JewelGameMode.timed);
  late MatchGameHud hud;
  int updates = 0;
  @override
  Future<void> onLoad() async {
    hud = MatchGameHud(
      onPausePressed: pauseEngine,
      onHintPressed: requestHint,
      onTutorialPressed: pauseEngine,
      onRankingPressed: pauseEngine,
    )..game = this;
    hud.onGameResize(size);
  }

  @override
  // This HUD harness intentionally excludes board simulation.
  // ignore: must_call_super
  void update(double dt) {
    updates++;
    hud.update(dt);
  }

  @override
  // Render only the HUD under test.
  // ignore: must_call_super
  void render(ui.Canvas canvas) => hud.render(canvas);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
    GameSettings.sfxMuted = true;
    GameSettings.bgmMuted = true;
  });
  test('goal proximity threshold and achievement fire once, then decay', () {
    final (g, h) = fixture(JewelGameMode.progression);
    final target = g.progressionTargetScore;
    g.board.score = (target * .79).floor();
    h.update(.016);
    expect(h.debugReadFeedback()['goalNear'], false);
    g.board.score = (target * .8).ceil();
    h.update(.016);
    expect(h.debugReadFeedback()['goalNear'], true);
    g.board.score = target;
    h.update(.016);
    expect(h.debugReadFeedback()['goalPunch'], 1);
    expect(h.debugReadFeedback()['goalNear'], false);
    h.update(.2);
    expect(h.debugReadFeedback()['goalPunch'], lessThan(1));
    h.update(1);
    expect(h.debugReadFeedback()['goalPunch'], 0);
    expect(g.board.score, target);
  });
  test('bonus is a single event: interval stays fixed while fill follows', () {
    final (g, h) = fixture(JewelGameMode.timed);
    g.timeRemaining = 30;
    h.update(1);
    g.timeRemaining = 36;
    h.update(.016);
    final first = h.debugReadFeedback();
    expect(first['timeBonus'], 1);
    expect(first['timeFill'], greaterThan(.5));
    expect(first['timeFill'], lessThan(.6));
    h.update(.1);
    expect(h.debugReadFeedback()['timeBonus'], lessThan(1));
    expect(h.debugReadFeedback()['timeBonusFrom'], first['timeBonusFrom']);
    h.update(1);
    expect(h.debugReadFeedback()['timeBonus'], 0);
    expect(h.debugReadFeedback()['timeFill'], closeTo(.6, .00001));
  });
  test('large legitimate bonus follows smoothly rather than snapping', () {
    final (g, h) = fixture(JewelGameMode.timed);
    g.timeRemaining = 1;
    h.update(1);
    g.timeRemaining = 35;
    h.update(.016);
    expect(h.debugReadFeedback()['timeBonus'], 1);
    expect(h.debugReadFeedback()['timeFill'], lessThan(35 / 60));
  });
  test('hint badge event does not depend on rendering between updates', () {
    final (g, h) = fixture(JewelGameMode.timed);
    hintBoard(g);
    paint(h);
    final original = g.hintBadgeCount;
    g.requestHint();
    h.update(.016);
    expect(g.hintBadgeCount, original! - 1);
    expect(h.debugReadFeedback()['hintPunch'], 1);
    h.update(.1);
    expect(h.debugReadFeedback()['hintPunch'], lessThan(1));
    h.update(1);
    expect(h.debugReadFeedback()['hintPunch'], 0);
  });
  test('combo heat rises by tier and decays fully after chain', () {
    final (g, h) = fixture(JewelGameMode.simple);
    g.board.state = 'removing';
    g.board.combo = 3;
    h.update(.2);
    final warm = h.debugReadFeedback()['comboHeat'] as double;
    expect(warm, greaterThan(0));
    g.board.combo = 7;
    h.update(.2);
    expect(h.debugReadFeedback()['comboHeat'], greaterThan(warm));
    g.board.state = 'idle';
    h.update(1);
    expect(h.debugReadFeedback()['comboHeat'], 0);
  });
  test('button input preserves hit rects and returns to rest', () {
    final (g, h) = fixture(JewelGameMode.timed);
    hintBoard(g);
    final before = h.debugReadAlignedHudRects();
    for (final key in ['pause', 'hint', 'ranking', 'tutorial']) {
      final rect = h.debugReadButtonRects()[key]!;
      expect(h.debugTapButton(rect.center), true);
      expect(h.debugReadFeedback()['pressPunch'], 1);
      h.update(.3);
      expect(h.debugReadFeedback()['pressPunch'], 0);
    }
    expect(h.debugReadAlignedHudRects(), before);
  });
  test('time shader survives repeated updates and renders', () {
    final (g, h) = fixture(JewelGameMode.timed);
    final shader = h.debugReadFeedback()['timeShader'];
    for (var i = 0; i < 10; i++) {
      g.timeRemaining -= .1;
      h.update(.1);
      paint(h);
    }
    expect(h.debugReadFeedback()['timeShader'], same(shader));
  });
  test(
    'actual targeted item consumption reacts after targeting press expired',
    () {
      final (g, h) = fixture(JewelGameMode.progression);
      hintBoard(g);
      final rect = h.debugReadItemSlotRects()[ItemKind.runeHammer]!;
      h.debugTapButton(rect.center);
      h.update(.3);
      expect(g.activeTargetItem, ItemKind.runeHammer);
      final cell = g.board.cellToPixel(0, 0);
      g.handleBoardTap(cell.dx + 1, cell.dy + 1);
      h.update(.016);
      expect(g.runInventory.quantityOf(ItemKind.runeHammer), 0);
      expect(h.debugReadFeedback()['itemUsePunch'], greaterThan(0));
    },
  );
  test('new round resets bonus and hint pulses without changing the model', () {
    final (g, h) = fixture(JewelGameMode.progression);
    hintBoard(g);
    g.timeRemaining = 20;
    h.update(1);
    g.timeRemaining = 30;
    h.update(.016);
    expect(h.debugReadFeedback()['timeBonus'], 1);
    g.board.generateFreshBoard();
    g.timeRemaining = g.roundSecondsForMode;
    h.update(.016);
    expect(h.debugReadFeedback()['timeBonus'], 0);
    expect(h.debugReadFeedback()['timeFill'], 1);
    expect(h.debugReadFeedback()['goalPunch'], 0);
  });
  test('unchanged score redraws target label after next level', () {
    final (g, h) = fixture(JewelGameMode.progression);
    g.board.score = g.progressionTargetScore;
    h.update(.016);
    g.progressionLevel++;
    h.update(.016);
    expect(h.debugReadFeedback()['goalReached'], false);
    expect(h.debugReadFeedback()['goalPunch'], 0);
  });
  testWidgets('paused menu press returns to rest without advancing game', (
    tester,
  ) async {
    final g = HudOnlyGame();
    g.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget(game: g),
      ),
    );
    await tester.pump();
    await tester.pump();
    final h = g.hud;
    final before = g.updates;
    h.debugTapButton(h.debugReadButtonRects()['pause']!.center);
    expect(g.paused, true);
    expect(h.debugReadFeedback()['pressPunch'], 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(h.debugReadFeedback()['pressPunch'], inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.debugReadFeedback()['pressPunch'], 0);
    expect(g.updates, before);
    h.onRemove();
    g.isPlaying = false;
    await tester.pumpWidget(const SizedBox());
  });
}
