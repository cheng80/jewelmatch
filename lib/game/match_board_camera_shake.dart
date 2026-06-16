import 'dart:math' show max, pi, sin;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'match_board_models.dart';

class MatchBoardCameraShake {
  double _remaining = 0;
  double _duration = 0;
  double _intensity = 0;
  double _elapsed = 0;

  bool get isActive => _remaining > 0 && _duration > 0;

  void queue(SpecialEffectShake shake) {
    if (kIsWeb) return;
    if (shake.intensity <= 0 || shake.duration <= 0) return;
    _intensity = max(_intensity, shake.intensity);
    _duration = max(_duration, shake.duration);
    _remaining = max(_remaining, shake.duration);
    _elapsed = 0;
  }

  Vector2 update(double dt) {
    if (_remaining <= 0 || _duration <= 0) {
      _reset();
      return Vector2.zero();
    }

    _remaining = max(0, _remaining - dt);
    _elapsed += dt;
    if (_remaining <= 0) {
      _resetElapsedShake();
      return Vector2.zero();
    }

    final falloff = _remaining / _duration;
    final amplitude = _intensity * falloff * falloff;
    final phase = _elapsed / _duration;
    final primary = sin(phase * pi * 9.0);
    final secondary = sin(phase * pi * 13.0 + pi / 3);
    final vertical = sin(phase * pi * 7.0 + pi / 2);
    return Vector2(
      (primary * 0.82 + secondary * 0.18) * amplitude,
      vertical * amplitude * 0.48,
    );
  }

  void _reset() {
    _intensity = 0;
    _duration = 0;
    _remaining = 0;
    _elapsed = 0;
  }

  void _resetElapsedShake() {
    _intensity = 0;
    _duration = 0;
    _elapsed = 0;
  }
}
