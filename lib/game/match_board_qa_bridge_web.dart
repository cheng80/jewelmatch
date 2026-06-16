import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'match_board_game.dart';
import 'match_board_qa_bridge.dart';

MatchBoardGame? _installedGame;

void installMatchBoardQaBridge(MatchBoardGame game) {
  if (Uri.base.queryParameters['qaPerf'] != '1') return;
  _installedGame = game;

  web.window.setProperty(
    '__jewelMatchGetHintMove'.toJS,
    (() {
      final currentGame = _installedGame;
      if (currentGame == null) return null;
      final move = currentGame.readSimulationHintMove();
      return move == null ? null : _moveToJs(move);
    }).toJS,
  );

  web.window.setProperty(
    '__jewelMatchGetState'.toJS,
    (() {
      final currentGame = _installedGame;
      if (currentGame == null) return null;
      return _stateToJs(currentGame.readSimulationState());
    }).toJS,
  );

  web.window.setProperty(
    '__jewelMatchContinueLevelUp'.toJS,
    (() {
      final currentGame = _installedGame;
      if (currentGame != null && currentGame.overlays.isActive('LevelUp')) {
        currentGame.continueAfterLevelUp();
      }
    }).toJS,
  );
}

void uninstallMatchBoardQaBridge(MatchBoardGame game) {
  if (_installedGame != game) return;
  _installedGame = null;
  web.window.setProperty('__jewelMatchGetHintMove'.toJS, (() => null).toJS);
  web.window.setProperty('__jewelMatchGetState'.toJS, (() => null).toJS);
  web.window.setProperty('__jewelMatchContinueLevelUp'.toJS, (() {}).toJS);
}

JSObject _moveToJs(SimulationHintMove move) {
  final object = JSObject();
  object.setProperty('a'.toJS, _cellToJs(move['a'] as Map<String, Object?>));
  object.setProperty('b'.toJS, _cellToJs(move['b'] as Map<String, Object?>));
  object.setProperty('tileSize'.toJS, (move['tileSize'] as double).toJS);
  object.setProperty('state'.toJS, (move['state'] as String).toJS);
  return object;
}

JSObject _cellToJs(Map<String, Object?> cell) {
  final object = JSObject();
  object.setProperty('row'.toJS, (cell['row'] as int).toJS);
  object.setProperty('col'.toJS, (cell['col'] as int).toJS);
  object.setProperty('x'.toJS, (cell['x'] as double).toJS);
  object.setProperty('y'.toJS, (cell['y'] as double).toJS);
  return object;
}

JSObject _stateToJs(SimulationGameState state) {
  final object = JSObject();
  object.setProperty('mode'.toJS, (state['mode'] as String).toJS);
  object.setProperty('score'.toJS, (state['score'] as int).toJS);
  object.setProperty('level'.toJS, (state['level'] as int).toJS);
  object.setProperty('targetScore'.toJS, (state['targetScore'] as int).toJS);
  object.setProperty(
    'levelUpActive'.toJS,
    (state['levelUpActive'] as bool).toJS,
  );
  object.setProperty(
    'levelCelebrationActive'.toJS,
    (state['levelCelebrationActive'] as bool).toJS,
  );
  object.setProperty('timeUp'.toJS, (state['timeUp'] as bool).toJS);
  object.setProperty(
    'timeRemaining'.toJS,
    (state['timeRemaining'] as double).toJS,
  );
  object.setProperty('isPlaying'.toJS, (state['isPlaying'] as bool).toJS);
  object.setProperty('boardState'.toJS, (state['boardState'] as String).toJS);
  object.setProperty(
    'hasActiveVisualEffects'.toJS,
    (state['hasActiveVisualEffects'] as bool).toJS,
  );
  object.setProperty(
    'introFillInProgress'.toJS,
    (state['introFillInProgress'] as bool).toJS,
  );
  return object;
}
