import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_models.dart';

void main() {
  test('QA special effect buttons use the real board path for every kind', () {
    for (final kind in GemKind.values.skip(1)) {
      final game = _readyGame();

      expect(game.triggerQaSpecialEffect(kind), isTrue, reason: '$kind');
      expect(game.board.stats.specialActivatedByKind[kind], 1);
      expect(game.board.consumeSpecialEffectEvents().single.effectKind, kind);
    }
  });

  test(
    'QA chain buttons enqueue four requested effects for non-hyper kinds',
    () {
      for (final kind
          in GemKind.values.skip(1).where((kind) => kind != GemKind.hyper)) {
        final game = _readyGame();

        expect(
          game.triggerQaSpecialEffect(kind, chain: true),
          isTrue,
          reason: '$kind',
        );
        expect(
          game.board.stats.specialActivatedByKind[kind],
          greaterThanOrEqualTo(4),
          reason: '$kind',
        );
        expect(
          game.board.consumeSpecialEffectEvents().where(
            (event) => event.effectKind == kind,
          ),
          hasLength(greaterThanOrEqualTo(4)),
        );
      }
    },
  );

  test('QA chain hyper keeps production single-effect semantics', () {
    final game = _readyGame();

    expect(game.triggerQaSpecialEffect(GemKind.hyper, chain: true), isTrue);
    expect(game.board.stats.specialActivatedByKind[GemKind.hyper], 1);
    expect(
      game.board.consumeSpecialEffectEvents().where(
        (event) => event.effectKind == GemKind.hyper,
      ),
      hasLength(1),
    );
  });

  test('QA special effect buttons reject a non-idle board', () {
    final game = _readyGame();
    game.board.state = 'falling';

    expect(game.triggerQaSpecialEffect(GemKind.row), isFalse);
    expect(game.board.stats.specialGemsActivated, 0);
    expect(game.board.consumeSpecialEffectEvents(), isEmpty);
  });
}

MatchBoardGame _readyGame() {
  final game = MatchBoardGame();
  game.board.setGeometry(x: 0, y: 0, tile: 56);
  game.board.generateFreshBoard(withIntroFill: false);
  return game;
}
