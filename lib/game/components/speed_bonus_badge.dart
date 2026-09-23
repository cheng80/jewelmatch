import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../match_board_game.dart';

/// Speed Bonus 단계(예: SPEED +400)를 보드 오른쪽 아래에 잠깐 보여 준다.
///
/// 콤보 콜아웃(보드 위 가운데), 시간 보너스(보드 아래 가운데), 점수 롤업(상단 HUD)과
/// 겹치지 않는 자리다. 표시마다 [TextPainter] 1개만 만든다.
class SpeedBonusBadge extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  SpeedBonusBadge() : super(priority: 131);

  static const double duration = 1.1;
  static const double _popTime = 0.12;
  static const Color _color = Color(0xFF7FE3FF);

  TextPainter? _painter;
  double _age = 0;
  bool _still = false;

  void show(int bonus) {
    final ts = game.board.tileSize;
    if (bonus <= 0 || ts <= 0) return;
    _painter?.dispose();
    _painter = TextPainter(
      text: TextSpan(
        text: 'SPEED +$bonus',
        style: TextStyle(
          fontFamily: AssetPaths.fontNexonLv2Gothic,
          fontSize: ts * 0.34,
          fontWeight: FontWeight.w900,
          color: _color,
          shadows: const [
            Shadow(color: Color(0xE6000000), offset: Offset(0, 2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _age = 0;
    // reduced motion: 팝 없이 표시만 한다.
    // MediaQuery.disableAnimations와 같은 플랫폼 값을 읽는다.
    _still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
  }

  @override
  void update(double dt) {
    if (_painter == null) return;
    _age += dt;
    if (_age >= duration) {
      _painter!.dispose();
      _painter = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final painter = _painter;
    if (painter == null) return;
    final board = game.board;
    final ts = board.tileSize;
    final right = board.boardX + board.cols * ts - ts * 0.18;
    final bottom = board.boardY + board.rows * ts - ts * 0.18;
    // 모바일 웹 예산: saveLayer 없이 짧은 팝만 준다.
    final scale = _still || _age >= _popTime
        ? 1.0
        : 0.8 + 0.2 * _age / _popTime;
    canvas.save();
    canvas.translate(right, bottom);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width, -painter.height));
    canvas.restore();
  }

  @override
  void onRemove() {
    _painter?.dispose();
    _painter = null;
    super.onRemove();
  }
}
