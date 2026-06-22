part of 'match_game_hud.dart';

typedef _HudSwipe = ({Vector2 start, Vector2 current, int dr, int dc});

class _HudDragTracker {
  Vector2? _startCanvas;
  Vector2? _currentCanvas;
  Vector2 _delta = Vector2.zero();
  bool _active = false;
  bool _consumed = false;

  void start(Vector2 canvasPosition) {
    _startCanvas = canvasPosition.clone();
    _currentCanvas = canvasPosition.clone();
    _delta = Vector2.zero();
    _active = true;
    _consumed = false;
  }

  _HudSwipe? consumeSwipe(
    Vector2 localDelta,
    Vector2 canvasPosition,
    double threshold,
  ) {
    if (!_active || _consumed || _startCanvas == null) return null;
    _currentCanvas = canvasPosition.clone();
    _delta += localDelta;
    if (_delta.length < threshold) return null;

    _consumed = true;
    final dx = _delta.x.abs();
    final dy = _delta.y.abs();
    var dr = 0;
    var dc = 0;
    if (dx >= dy) {
      dc = _delta.x > 0 ? 1 : -1;
    } else {
      dr = _delta.y > 0 ? 1 : -1;
    }
    return (
      start: _startCanvas!.clone(),
      current: _currentCanvas!.clone(),
      dr: dr,
      dc: dc,
    );
  }

  Vector2? updateConsumedPosition(Vector2 canvasPosition) {
    if (!_active || !_consumed) return null;
    _currentCanvas = canvasPosition.clone();
    return _currentCanvas!.clone();
  }

  Vector2? get fallbackTap {
    if (!_active || _consumed || _startCanvas == null) return null;
    return _startCanvas!.clone();
  }

  void reset() {
    _startCanvas = null;
    _currentCanvas = null;
    _delta = Vector2.zero();
    _active = false;
    _consumed = false;
  }
}
