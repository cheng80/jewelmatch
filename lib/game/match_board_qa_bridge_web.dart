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

  web.window.setProperty(
    '__jewelMatchDebugShowSlot3Unlock'.toJS,
    (() {
      final currentGame = _installedGame;
      if (currentGame == null || !currentGame.isProgressionMode) return;
      currentGame.progressionLevel = 6;
      currentGame.board.score = currentGame.progressionTargetScore;
      currentGame.board.introFillInProgress = false;
      currentGame.board.introFillPaused = false;
      currentGame.isPlaying = true;
      currentGame.update(0);
      currentGame.showLevelUpPopupAfterCelebration();
    }).toJS,
  );
}

void uninstallMatchBoardQaBridge(MatchBoardGame game) {
  if (_installedGame != game) return;
  _installedGame = null;
  web.window.setProperty('__jewelMatchGetHintMove'.toJS, (() => null).toJS);
  web.window.setProperty('__jewelMatchGetState'.toJS, (() => null).toJS);
  web.window.setProperty('__jewelMatchContinueLevelUp'.toJS, (() {}).toJS);
  web.window.setProperty('__jewelMatchDebugShowSlot3Unlock'.toJS, (() {}).toJS);
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
    'stageInventoryActive'.toJS,
    (state['stageInventoryActive'] as bool).toJS,
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
  object.setProperty(
    'remainingHints'.toJS,
    (state['remainingHints'] as int).toJS,
  );
  object.setProperty(
    'hasLimitedHints'.toJS,
    (state['hasLimitedHints'] as bool).toJS,
  );
  object.setProperty(
    'hasTimedClock'.toJS,
    (state['hasTimedClock'] as bool).toJS,
  );
  object.setProperty(
    'runInventory'.toJS,
    _mapToJsObject(state['runInventory'] as Map<String, Object?>),
  );
  object.setProperty(
    'stageLoadout'.toJS,
    _listToIndexedJsObject(state['stageLoadout'] as List<Map<String, Object?>>),
  );
  object.setProperty(
    'latestStageRewards'.toJS,
    _listToIndexedJsObject(
      state['latestStageRewards'] as List<Map<String, Object?>>,
    ),
  );
  final stageRewardClaimKey = state['stageRewardClaimKey'] as String?;
  object.setProperty('stageRewardClaimKey'.toJS, stageRewardClaimKey?.toJS);
  object.setProperty(
    'stageLoadoutOpenSlotCount'.toJS,
    (state['stageLoadoutOpenSlotCount'] as int).toJS,
  );
  object.setProperty(
    'recentlyUnlockedLoadoutSlotIndices'.toJS,
    _intListToIndexedJsObject(
      state['recentlyUnlockedLoadoutSlotIndices'] as List<int>,
    ),
  );
  object.setProperty('isPlaying'.toJS, (state['isPlaying'] as bool).toJS);
  object.setProperty('boardState'.toJS, (state['boardState'] as String).toJS);
  object.setProperty(
    'boardGeometry'.toJS,
    _mapToJsObject(state['boardGeometry'] as Map<String, Object?>),
  );
  object.setProperty(
    'alignedHudRects'.toJS,
    _nestedMapToJsObject(
      state['alignedHudRects'] as Map<String, Map<String, double>>,
    ),
  );
  object.setProperty(
    'itemSlotRects'.toJS,
    _nestedMapToJsObject(
      state['itemSlotRects'] as Map<String, Map<String, double>>,
    ),
  );
  object.setProperty(
    'isItemTargeting'.toJS,
    (state['isItemTargeting'] as bool).toJS,
  );
  final activeTargetItem = state['activeTargetItem'] as String?;
  object.setProperty('activeTargetItem'.toJS, activeTargetItem?.toJS);
  final selectedPrismColor = state['selectedPrismColor'] as int?;
  object.setProperty('selectedPrismColor'.toJS, selectedPrismColor?.toJS);
  final pendingImmediateItemConfirm =
      state['pendingImmediateItemConfirm'] as String?;
  object.setProperty(
    'pendingImmediateItemConfirm'.toJS,
    pendingImmediateItemConfirm?.toJS,
  );
  object.setProperty(
    'prismColorRects'.toJS,
    _nestedMapToJsObject(
      state['prismColorRects'] as Map<String, Map<String, double>>,
    ),
  );
  final itemFeedbackText = state['itemFeedbackText'] as String?;
  object.setProperty('itemFeedbackText'.toJS, itemFeedbackText?.toJS);
  object.setProperty(
    'itemFeedbackOpacity'.toJS,
    (state['itemFeedbackOpacity'] as double).toJS,
  );
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

JSObject _nestedMapToJsObject(Map<String, Map<String, double>> source) {
  final object = JSObject();
  for (final entry in source.entries) {
    object.setProperty(entry.key.toJS, _mapToJsObject(entry.value));
  }
  return object;
}

JSObject _listToIndexedJsObject(List<Map<String, Object?>> source) {
  final object = JSObject();
  for (var i = 0; i < source.length; i++) {
    object.setProperty('$i'.toJS, _mapToJsObject(source[i]));
  }
  object.setProperty('length'.toJS, source.length.toJS);
  return object;
}

JSObject _intListToIndexedJsObject(List<int> source) {
  final object = JSObject();
  for (var i = 0; i < source.length; i++) {
    object.setProperty('$i'.toJS, source[i].toJS);
  }
  object.setProperty('length'.toJS, source.length.toJS);
  return object;
}

JSObject _mapToJsObject(Map<String, Object?> source) {
  final object = JSObject();
  for (final entry in source.entries) {
    final value = entry.value;
    if (value is int) {
      object.setProperty(entry.key.toJS, value.toJS);
    } else if (value is double) {
      object.setProperty(entry.key.toJS, value.toJS);
    } else if (value is bool) {
      object.setProperty(entry.key.toJS, value.toJS);
    } else if (value is String) {
      object.setProperty(entry.key.toJS, value.toJS);
    }
  }
  return object;
}
