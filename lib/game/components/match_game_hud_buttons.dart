part of 'match_game_hud.dart';

extension _MatchGameHudButtonRenderer on MatchGameHud {
  void _drawIconButtonFrame(Canvas canvas, Rect r) {
    final image = _iconButtonFrameImage;
    if (image == null) return;
    final frameRect = r.inflate(r.width * 0.08);
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      frameRect,
      paint,
    );
  }

  void _drawTutorialButton(Canvas canvas) {
    final r = _tutorialRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _tutorialIconImage, sizeFactor: 0.58);
  }

  /// 힌트 — 전구 형태 (튜토리얼용 ? 버튼과 구분).
  void _drawHintButton(Canvas canvas) {
    final r = _hintRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(
      canvas,
      r,
      _hintBulbIconImage,
      sizeFactor: 0.62,
      offsetYFactor: 0.02,
    );
    _drawHintBadge(canvas, r);
  }

  void _drawHintBadge(Canvas canvas, Rect buttonRect) {
    final count = game.hintBadgeCount;
    if (count == null) return;

    final diameter = buttonRect.width * 0.36;
    final center = Offset(
      buttonRect.right - diameter * 0.18,
      buttonRect.bottom - diameter * 0.18,
    ).translate(-5, -5);
    final badgePaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFC58A22)],
      ).createShader(Rect.fromCircle(center: center, radius: diameter / 2));
    final strokePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, buttonRect.width * 0.04)
      ..color = const Color(0xFF2A1606);

    canvas.drawCircle(center, diameter / 2, badgePaint);
    canvas.drawCircle(center, diameter / 2, strokePaint);

    final label = count > 99 ? '99+' : '$count';
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _ts(
          size: buttonRect.width * (label.length > 2 ? 0.18 : 0.22),
          color: const Color(0xFF211204),
          weight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.45),
              offset: const Offset(0, 0.5),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: diameter * 0.92);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawButtonIcon(
    Canvas canvas,
    Rect r,
    ui.Image? image, {
    required double sizeFactor,
    double offsetYFactor = 0,
  }) {
    if (image == null) return;
    final iconSize = r.width * sizeFactor;
    final iconRect = Rect.fromCenter(
      center: r.center.translate(0, r.width * offsetYFactor),
      width: iconSize,
      height: iconSize,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      iconRect,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
  }

  /// 랭킹 — 왕관 심볼 (힌트 전구와 구분).
  void _drawRankingButton(Canvas canvas) {
    final r = _rankingRect;
    if (r.isEmpty) return;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _rankingCrownIconImage, sizeFactor: 0.6);
  }

  void _drawPause(Canvas canvas) {
    final r = _pauseRect;
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _pauseIconImage, sizeFactor: 0.70);
  }

  void _drawItemSlots(Canvas canvas) {
    _drawItemTray(canvas);
    for (final item in MatchGameHud._phaseOneItems) {
      final r = _itemRects[item];
      if (r == null || r.isEmpty) continue;
      _drawItemSlot(canvas, r, item);
    }
  }

  void _drawItemDecisionScrim(Canvas canvas) {
    return;
  }

  void _drawItemFeedbackBanner(Canvas canvas) {
    if (game.isPrismColorPicking) return;

    final message = game.itemFeedbackText;
    final opacity = game.itemFeedbackOpacity;
    if (message == null || opacity <= 0) return;

    final gap = math.max(4.0, game.hudScale * 0.07);
    final hasSelectedPrism =
        game.activeTargetItem == ItemKind.prismTransform &&
        game.selectedPrismColor != null;
    final bannerHeight = hasSelectedPrism
        ? math.max(32.0, game.hudScale * 0.40)
        : math.max(24.0, game.hudScale * 0.30);
    final bannerWidth = math.min(
      game.safeContentWidth * 0.92,
      game.hudScale * 4.5,
    );
    var top = _itemTrayRect.top - gap - bannerHeight;
    final minTop = game.boardPixelBottom + gap;
    if (top < minTop && minTop + bannerHeight <= _itemTrayRect.top - gap) {
      top = minTop;
    }
    final r = Rect.fromCenter(
      center: Offset(
        game.safeContentLeft + game.safeContentWidth / 2,
        top + bannerHeight / 2,
      ),
      width: bannerWidth,
      height: bannerHeight,
    );
    final radius = Radius.circular(math.min(8.0, r.height * 0.24));
    final rr = RRect.fromRectAndRadius(r, radius);

    final fill = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF30271F).withValues(alpha: 0.92 * opacity),
          const Color(0xFF0D1112).withValues(alpha: 0.95 * opacity),
        ],
      ).createShader(r);
    canvas.drawRRect(rr, fill);

    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color =
          (game.isItemTargeting
                  ? const Color(0xFF69F6E7)
                  : const Color(0xFFC8953C))
              .withValues(alpha: opacity);
    canvas.drawRRect(rr, stroke);

    if (hasSelectedPrism) {
      _drawPrismSelectedFeedback(canvas, r, opacity);
      return;
    }

    final textStyle = _ts(
      size: math.min(r.height * 0.45, game.hudScale * 0.16),
      color: Color.lerp(
        const Color(0xFFFFF1CF),
        const Color(0xFF88FFF0),
        game.isItemTargeting ? 0.22 : 0,
      )!.withValues(alpha: opacity),
      weight: FontWeight.w900,
      shadows: _hudLegibilityShadows(),
    );
    final painter = TextPainter(
      text: TextSpan(text: message, style: textStyle),
      maxLines: 1,
      ellipsis: '...',
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width - 18);
    painter.paint(
      canvas,
      Offset(r.center.dx - painter.width / 2, r.center.dy - painter.height / 2),
    );
  }

  void _drawPrismSelectedFeedback(Canvas canvas, Rect r, double opacity) {
    final color = game.selectedPrismColor;
    if (color == null) return;
    final fontSize = math.min(r.height * 0.42, game.hudScale * 0.15);
    final textStyle = _ts(
      size: fontSize,
      color: const Color(0xFF88FFF0).withValues(alpha: opacity),
      weight: FontWeight.w900,
      shadows: _hudLegibilityShadows(),
    );
    final leftText = TextPainter(
      text: TextSpan(text: '프리즘 :', style: textStyle),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final rightText = TextPainter(
      text: TextSpan(text: '로 바꿀 보석 선택', style: textStyle),
      maxLines: 1,
      ellipsis: '...',
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width * 0.48);

    final iconSide = math.min(game.board.tileSize * 0.70, r.height * 0.88);
    final itemGap = math.max(4.0, game.hudScale * 0.045);
    final groupWidth =
        leftText.width + itemGap + iconSide + itemGap + rightText.width;
    var x = r.center.dx - groupWidth / 2;
    final textY = r.center.dy - leftText.height / 2;
    leftText.paint(canvas, Offset(x, textY));
    x += leftText.width + itemGap;

    final iconRect = Rect.fromCenter(
      center: Offset(x + iconSide / 2, r.center.dy),
      width: iconSide,
      height: iconSide,
    );
    _drawPrismGemSprite(canvas, iconRect, color);
    x += iconSide + itemGap;
    rightText.paint(canvas, Offset(x, r.center.dy - rightText.height / 2));
  }

  void _drawItemConfirmPopup(Canvas canvas) {
    final item = game.pendingImmediateItemConfirm;
    if (item == null) return;
    final r = _itemConfirmRect;
    if (r.isEmpty) return;

    _drawObsidianPanelSurface(canvas, r);

    final itemName = item.label.replaceAll('\n', ' ');
    final title = TextPainter(
      text: TextSpan(
        text: '$itemName 사용?',
        style: _ts(
          size: math.min(r.height * 0.18, game.hudScale * 0.18),
          color: const Color(0xFFFFE7A6),
          weight: FontWeight.w900,
          shadows: _hudLegibilityShadows(),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width - 24);
    title.paint(
      canvas,
      Offset(r.center.dx - title.width / 2, r.center.dy - r.height * 0.17),
    );

    final body = TextPainter(
      text: TextSpan(
        text: _immediateItemConfirmBody(item),
        style: _ts(
          size: math.min(r.height * 0.13, game.hudScale * 0.13),
          color: const Color(0xFFE8D5B8),
          weight: FontWeight.w700,
          shadows: _hudLegibilityShadows(),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width - 28);
    body.paint(
      canvas,
      Offset(r.center.dx - body.width / 2, r.center.dy - r.height * 0.07),
    );

    _drawConfirmButton(canvas, _itemConfirmCancelRect, '취소', false);
    _drawConfirmButton(canvas, _itemConfirmUseRect, '사용', true);
  }

  String _immediateItemConfirmBody(ItemKind item) => switch (item) {
    ItemKind.fateShuffle => '현재 보드를 섞습니다',
    ItemKind.timeSlip => '남은 시간을 늘립니다',
    ItemKind.hintPlus => '힌트 횟수를 1개 늘립니다',
    _ => '아이템을 사용합니다',
  };

  void _drawConfirmButton(Canvas canvas, Rect r, String label, bool primary) {
    if (r.isEmpty) return;
    final radius = Radius.circular(math.min(8.0, r.height * 0.22));
    final rr = RRect.fromRectAndRadius(r, radius);
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: primary
            ? const [Color(0xFF1D6B65), Color(0xFF104642), Color(0xFF092927)]
            : const [Color(0xFF4A3427), Color(0xFF281A15), Color(0xFF100B09)],
      ).createShader(r);
    canvas.drawRRect(rr, fill);

    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = primary ? const Color(0xFF77F0DF) : const Color(0xFFC8953C);
    canvas.drawRRect(rr, stroke);

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _ts(
          size: math.min(r.height * 0.42, game.hudScale * 0.15),
          color: primary ? const Color(0xFFEFFFFB) : const Color(0xFFFFE2A8),
          weight: FontWeight.w900,
          shadows: _hudLegibilityShadows(),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width - 8);
    painter.paint(
      canvas,
      Offset(r.center.dx - painter.width / 2, r.center.dy - painter.height / 2),
    );
  }

  void _drawPrismColorPicker(Canvas canvas) {
    if (!game.isPrismColorPicking) return;
    final r = _prismColorPickerRect;
    if (r.isEmpty) return;

    _drawObsidianPanelSurface(canvas, r);

    final title = TextPainter(
      text: TextSpan(
        text: '프리즘: 바꿀 색 선택',
        style: _ts(
          size: math.min(r.height * 0.075, game.hudScale * 0.22),
          color: const Color(0xFFFFD978),
          weight: FontWeight.w900,
          shadows: _hudLegibilityShadows(),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width * 0.80);
    title.paint(
      canvas,
      Offset(r.center.dx - title.width / 2, r.center.dy - r.height * 0.20),
    );

    for (final entry in _prismColorRects.entries) {
      _drawPrismColorSwatch(canvas, entry.value, entry.key);
    }
  }

  void _drawObsidianPanelSurface(Canvas canvas, Rect r) {
    final radius = Radius.circular(math.min(10.0, r.shortestSide * 0.12));
    final rr = RRect.fromRectAndRadius(r, radius);

    final shadowPaint = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withValues(alpha: 0.54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.translate(0, 3), radius),
      shadowPaint,
    );

    final basePaint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF30271F), Color(0xFF121416), Color(0xFF070708)],
        stops: [0.0, 0.48, 1.0],
      ).createShader(r);
    canvas.drawRRect(rr, basePaint);

    final frame = _obsidianPanelFrameImage;
    if (frame != null) {
      canvas.drawImageNine(
        frame,
        const Rect.fromLTRB(58, 58, 334, 420),
        r,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );
      return;
    }

    final fallbackStroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC8953C);
    canvas.drawRRect(rr, fallbackStroke);
  }

  void _drawPrismColorSwatch(Canvas canvas, Rect r, int color) {
    final selected = game.selectedPrismColor == color;
    final outer = RRect.fromRectAndRadius(
      r,
      Radius.circular(math.min(7.0, r.height * 0.18)),
    );
    final outerPaint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: selected
            ? const [Color(0xFFFFF0A8), Color(0xFFC8953C), Color(0xFF4B2A0C)]
            : const [Color(0xFF8B6634), Color(0xFF2B1B10), Color(0xFF090807)],
      ).createShader(r);
    canvas.drawRRect(outer, outerPaint);

    final inset = r.deflate(math.max(3.0, r.height * 0.12));
    _drawPrismGemSprite(canvas, inset, color);

    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.0 : 1.0
      ..color = selected
          ? const Color(0xFF79F6E8)
          : Colors.white.withValues(alpha: 0.34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        inset,
        Radius.circular(math.min(6.0, inset.height * 0.16)),
      ),
      stroke,
    );

    if (selected) {
      final glow = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF6FF7E8).withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);
      canvas.drawRRect(outer.deflate(1.2), glow);
    }
  }

  void _drawPrismGemSprite(Canvas canvas, Rect r, int color) {
    final image = _jewelSpriteSheetImage;
    if (image == null) return;
    final index =
        MatchGameHud._gemSheetColByColor1based[(color - 1).clamp(
          0,
          MatchGameHud._gemSheetColByColor1based.length - 1,
        )];
    final src = Rect.fromLTWH(
      index * MatchGameHud._gemFrameSize,
      0,
      MatchGameHud._gemFrameSize,
      MatchGameHud._gemFrameSize,
    );
    final side = math.min(r.width, r.height) * 1.08;
    final dst = Rect.fromCenter(center: r.center, width: side, height: side);
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
  }

  void _drawItemTray(Canvas canvas) {
    final r = _itemTrayRect;
    if (r.isEmpty) return;

    final radius = Radius.circular(math.min(10.0, r.height * 0.12));
    final rr = RRect.fromRectAndRadius(r, radius);
    _itemTrayPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [Color(0xFF392D20), Color(0xFF17120E), Color(0xFF08090B)],
      stops: [0.0, 0.44, 1.0],
    ).createShader(r);
    canvas.drawRRect(rr, _itemTrayPaint);

    _itemTrayStrokePaint
      ..strokeWidth = 2.0
      ..color = const Color(0xFFC8953C);
    canvas.drawRRect(rr, _itemTrayStrokePaint);
    _itemTrayStrokePaint
      ..strokeWidth = 1.0
      ..color = const Color(0xFF3E2A13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(2.5), radius),
      _itemTrayStrokePaint,
    );

    final groovePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF7F5A2A).withValues(alpha: 0.72);
    final y = r.center.dy;
    canvas.drawLine(
      Offset(r.left + r.width * 0.05, y),
      Offset(r.right - r.width * 0.05, y),
      groovePaint,
    );
  }

  void _drawItemSlot(Canvas canvas, Rect r, ItemKind item) {
    final enabled = game.isItemEnabled(item);
    final active = game.activeTargetItem == item;
    _drawIconButtonFrame(canvas, r);

    if (active) {
      final glow = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF6FF7E8).withValues(alpha: 0.48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(1.8), Radius.circular(9)),
        glow,
      );
    }

    final icon = _itemIconImages[item];
    if (icon != null) {
      final iconBounds = r.deflate(math.max(7.0, r.height * 0.18));
      final side = math.min(iconBounds.width, iconBounds.height);
      final dst = Rect.fromCenter(
        center: iconBounds.center,
        width: side,
        height: side,
      );
      final imagePaint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      if (!enabled) {
        imagePaint.colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: 0.30),
          BlendMode.modulate,
        );
      }
      canvas.drawImageRect(
        icon,
        Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
        dst,
        imagePaint,
      );
      return;
    }

    final label = item.shortLabel;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _ts(
          size: math.min(
            r.height * 0.36,
            r.width / math.max(4.5, label.length),
          ),
          color: enabled
              ? (active ? const Color(0xFF241504) : const Color(0xFFFFF1CF))
              : const Color(0xFFC7C7C7),
          weight: FontWeight.w900,
          shadows: enabled && !active ? _hudLegibilityShadows() : null,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: r.width * 0.9);
    painter.paint(
      canvas,
      Offset(r.center.dx - painter.width / 2, r.center.dy - painter.height / 2),
    );
  }
}
