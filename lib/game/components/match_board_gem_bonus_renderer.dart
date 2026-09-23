part of 'match_board_renderer.dart';

/// Time, Multiplier 보석 배지. 보석을 모두 제출한 뒤 한 장 시트에서 drawImageRect로 그린다.
/// 보드 위 속성 보석은 최대 3개라 그리기 호출이 몇 번만 늘어난다.
extension _MatchBoardGemBonusRenderer on MatchBoardRenderer {
  static const double _badgeFrame = 128;
  static const double _timeBadgeRatio = 0.45;
  static const double _multiplierBadgeRatio = 0.55;

  void _drawBonusBadges(Canvas canvas, double ts, {BoardGem? skip}) {
    if (_badgeImage == null) return;
    for (final row in logic.cells) {
      for (final gem in row) {
        if (gem == null || gem.bonus == GemBonus.none) continue;
        if (identical(gem, skip)) continue;
        _drawBonusBadge(canvas, gem, ts);
      }
    }
  }

  void _drawBonusBadge(Canvas canvas, BoardGem gem, double ts) {
    final image = _badgeImage;
    if (image == null || gem.bonus == GemBonus.none) return;
    final removing = _isRemovalVisualCell(gem);
    var scale = 1.0;
    if (removing) {
      scale = _removalVisualScale;
    } else if (gem.popT >= 0) {
      final p = 1 - gem.popT / MatchBoardLogic.spawnPopDuration;
      scale = 1 + 0.5 * p * p;
    }
    final alpha = removing ? _removalVisualAlpha : 1.0;
    final cx = gem.x + ts / 2;
    final cy = gem.y + ts / 2;
    final transformed = scale != 1;
    if (transformed) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(-cx, -cy);
    }
    _badgePaint.color = Colors.white.withValues(alpha: alpha);
    final isTime = gem.bonus == GemBonus.time;
    final size = ts * (isTime ? _timeBadgeRatio : _multiplierBadgeRatio);
    final dst = isTime
        ? Rect.fromLTWH(
            gem.x + ts * 0.97 - size,
            gem.y + ts * 0.97 - size,
            size,
            size,
          )
        : Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(isTime ? 0 : _badgeFrame, 0, _badgeFrame, _badgeFrame),
      dst,
      _badgePaint,
    );
    // 사라지는 중에는 글자를 빼서 saveLayer 없이 흐려지게 한다.
    if (!removing) {
      if (isTime) {
        final label = _badgeLabel(
          '+${MatchBoardLogic.timeGemBonusSeconds}',
          ts,
        );
        label.paint(
          canvas,
          Offset(dst.left - label.width * 0.7, dst.bottom - label.height),
        );
      } else {
        // 지우면 얻는 배율(m + 1).
        final label = _badgeLabel('×${logic.scoreMultiplier + 1}', ts);
        label.paint(
          canvas,
          Offset(cx - label.width / 2, cy - label.height / 2),
        );
      }
    }
    if (transformed) canvas.restore();
  }

  /// 글자 그림은 칸 크기가 바뀔 때만 다시 만든다.
  TextPainter _badgeLabel(String text, double ts) {
    if (_badgeLabelTileSize != ts) {
      _disposeBadgeLabels();
      _badgeLabelTileSize = ts;
    }
    return _badgeLabels.putIfAbsent(text, () {
      final isTimeLabel = text.startsWith('+');
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AssetPaths.fontNexonLv2Gothic,
            fontSize: ts * (isTimeLabel ? 0.22 : 0.26),
            fontWeight: FontWeight.w900,
            color: isTimeLabel
                ? const Color(0xFF9FF3FF)
                : const Color(0xFFFFFDE7),
            shadows: const [
              Shadow(color: Color(0xE6000000), offset: Offset(0, 1.5)),
              Shadow(color: Color(0x99000000), blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  void _disposeBadgeLabels() {
    for (final painter in _badgeLabels.values) {
      painter.dispose();
    }
    _badgeLabels.clear();
  }
}
