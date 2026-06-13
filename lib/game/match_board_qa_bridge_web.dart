import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'match_board_game.dart';
import 'match_board_qa_bridge.dart';

void installMatchBoardQaBridge(MatchBoardGame game) {
  if (Uri.base.queryParameters['qaPerf'] != '1') return;

  web.window.setProperty(
    '__jewelMatchGetHintMove'.toJS,
    (() {
      final move = game.readSimulationHintMove();
      return move == null ? null : _moveToJs(move);
    }).toJS,
  );
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
