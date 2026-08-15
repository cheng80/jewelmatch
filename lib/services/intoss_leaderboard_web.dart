import 'dart:js_interop';

Future<bool> submitLevelScore(int score) async {
  try {
    return (await _submitLevelScore('$score'.toJS).toDart).toDart == 'SUCCESS';
  } catch (_) {
    return false;
  }
}

Future<bool> openLevelLeaderboard() async {
  try {
    return (await _openLevelLeaderboard().toDart).toDart;
  } catch (_) {
    return false;
  }
}

@JS('stoneMatchLeaderboard.submitLevelScore')
external JSPromise<JSString> _submitLevelScore(JSString score);

@JS('stoneMatchLeaderboard.openLevelLeaderboard')
external JSPromise<JSBoolean> _openLevelLeaderboard();
