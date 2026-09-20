import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../game/components/board_juice_layer.dart';
import '../../game/match_board_game.dart';

/// 멈춘 게임 위에서 기존 아틀라스만 구동하는 일회성 시각 연출.
/// 보석 제거/특수 발동/점수/보상 API는 호출하지 않는다.
class LevelClearWave extends ChangeNotifier {
  LevelClearWave(this.game)
    : attempt = game.levelCelebrationAttempt,
      _layer = (BoardJuiceLayer()..game = game) {
    final board = game.board;
    for (var diagonal = 0; diagonal < board.rows + board.cols - 1; diagonal++) {
      final cells = <({int row, int col, int color})>[];
      final keys = <String, bool>{};
      for (var row = 0; row < board.rows; row++) {
        final col = diagonal - row;
        if (col < 0 || col >= board.cols) continue;
        final gem = board.getGem(row, col);
        if (gem == null) continue;
        cells.add((row: row, col: col, color: gem.color));
        keys['$row:$col'] = true;
      }
      _diagonals.add(cells);
      _keys.add(keys);
    }
    _layer.onMount();
  }

  final MatchBoardGame game;
  final int attempt;
  final BoardJuiceLayer _layer;
  final _diagonals = <List<({int row, int col, int color})>>[];
  final _keys = <Map<String, bool>>[];
  int _nextEvent = 0;
  double _elapsed = 0;
  bool _disposed = false;
  int _litCells = 0;
  int _burstCells = 0;

  int get litCells => _litCells;
  int get burstCells => _burstCells;
  int get liveSparkCount => _layer.liveSparkCount;

  /// 절대 시각을 받아 낮은 FPS에서도 지나친 이벤트를 순서대로 처리한다.
  /// 이벤트마다 기존 파티클 나이를 먼저 전진시켜 늦은 프레임의 몰림을 막는다.
  void advance(double seconds) {
    if (_disposed || !game.isCurrentLevelCelebration(attempt)) return;
    final end = seconds.clamp(_elapsed, 3.0);
    while (_nextEvent < _diagonals.length * 2) {
      final diagonal = _nextEvent ~/ 2;
      final burst = _nextEvent.isOdd;
      final at = 0.12 + diagonal * 0.09 + (burst ? 0.07 : 0.0);
      if (at > end) break;
      _layer.update(at - _elapsed);
      _elapsed = at;
      if (burst) {
        _layer.onGemsRemoved(
          _diagonals[diagonal],
          bigMatch: false,
          hasSpecial: false,
          combo: 1,
          gained: 0,
        );
        _burstCells += _diagonals[diagonal].length;
      } else {
        _layer.onRemovalStarted(_keys[diagonal]);
        _litCells += _diagonals[diagonal].length;
      }
      _nextEvent++;
    }
    _layer.update(end - _elapsed);
    _elapsed = end;
    notifyListeners();
  }

  void paint(Canvas canvas) {
    if (!_disposed && game.isCurrentLevelCelebration(attempt)) {
      _layer.render(canvas);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _layer.onRemove();
    super.dispose();
  }
}

/// 별도 파티클 painter 없이 기존 Flame atlas render를 overlay canvas에 연결한다.
/// 게임/월드는 업데이트하지 않으며 기존 게임 좌표를 그대로 사용한다.
class LevelClearWaveView extends LeafRenderObjectWidget {
  const LevelClearWaveView({super.key, required this.wave});

  final LevelClearWave wave;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LevelClearWaveBox(wave);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _LevelClearWaveBox).wave = wave;
  }
}

class _LevelClearWaveBox extends RenderBox {
  _LevelClearWaveBox(this._wave);

  LevelClearWave _wave;

  set wave(LevelClearWave value) {
    if (identical(value, _wave)) return;
    if (attached) _wave.removeListener(markNeedsPaint);
    _wave = value;
    if (attached) _wave.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _wave.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _wave.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _wave.paint(canvas);
    canvas.restore();
  }
}
