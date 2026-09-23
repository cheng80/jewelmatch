import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';
import '../match_board_game.dart';

/// Last Hurrah 동안 보드 아래 가운데에 LAST HURRAH를 표시한다.
///
/// 마무리 중에는 시간 보상이 없어 시간 보너스 표시 자리가 비어 있다.
/// [TextPainter] 1개와 짧은 팝만 쓴다(모바일 웹 예산, saveLayer 없음).
class LastHurrahBadge extends PositionComponent
    with HasGameReference<MatchBoardGame> {
  LastHurrahBadge() : super(priority: 131);

  static const double _popTime = 0.16;
  static const Color _color = Color(0xFFFFD36B);

  TextPainter? _painter;
  double _age = 0;
  bool _still = false;

  bool get visible => _painter != null;

  void show() {
    final ts = game.board.tileSize;
    if (ts <= 0) return;
    _painter?.dispose();
    _painter = TextPainter(
      text: TextSpan(
        text: 'LAST HURRAH',
        style: TextStyle(
          fontFamily: AssetPaths.fontNexonLv2Gothic,
          fontSize: ts * 0.42,
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
    // reduced motion: 팝 없이 표시만 한다. MediaQuery.disableAnimations와 같은 값.
    _still = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
  }

  void hide() {
    _painter?.dispose();
    _painter = null;
  }

  @override
  void update(double dt) {
    if (_painter != null) _age += dt;
  }

  @override
  void render(Canvas canvas) {
    final painter = _painter;
    if (painter == null) return;
    final board = game.board;
    final ts = board.tileSize;
    final centerX = board.boardX + board.cols * ts / 2;
    final bottom = board.boardY + board.rows * ts - ts * 0.18;
    final scale = _still || _age >= _popTime
        ? 1.0
        : 0.8 + 0.2 * _age / _popTime;
    canvas.save();
    canvas.translate(centerX, bottom);
    canvas.scale(scale);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height));
    canvas.restore();
  }

  @override
  void onRemove() {
    hide();
    super.onRemove();
  }
}
