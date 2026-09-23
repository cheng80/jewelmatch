part of 'match_game_hud.dart';

extension _MatchGameHudButtonRenderer on MatchGameHud {
  /// 누른 버튼만 자기 중심으로 살짝 눌러 그린다. 히트 영역은 그대로다.
  ///
  /// `true`를 돌려주면 부른 쪽이 `canvas.restore()`를 해야 한다.
  bool _pushPressScale(Canvas canvas, Rect r) {
    if (_pressedRect != r || !_pressPunch.isActive) return false;
    final s = 1 - 0.09 * _pressPunch.value;
    canvas.save();
    canvas.translate(r.center.dx, r.center.dy);
    canvas.scale(s);
    canvas.translate(-r.center.dx, -r.center.dy);
    return true;
  }

  void _drawTutorialButton(Canvas canvas) {
    final r = _tutorialRect;
    final pressed = _pushPressScale(canvas, r);
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(
      canvas,
      r,
      _uiAtlas?[UiFrames.tutorialIcon],
      sizeFactor: 0.58,
    );
    if (pressed) canvas.restore();
  }

  /// 힌트 — 전구 형태 (튜토리얼용 ? 버튼과 구분).
  void _drawHintButton(Canvas canvas) {
    final r = _hintRect;
    final pressed = _pushPressScale(canvas, r);
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(
      canvas,
      r,
      _uiAtlas?[UiFrames.hintBulbIcon],
      sizeFactor: 0.62,
      offsetYFactor: 0.02,
    );
    _drawHintBadge(canvas, r);
    if (pressed) canvas.restore();
  }

  void _drawHintBadge(Canvas canvas, Rect buttonRect) {
    final count = game.hintBadgeCount;
    if (count == null) return;

    // 숫자가 바뀌면 배지가 한 번 튀고, 0이 되면 색이 가라앉는다.
    final punched = _hintBadgePunch.isActive;
    if (punched) {
      canvas.save();
      canvas.translate(_hintBadgeCenter.dx, _hintBadgeCenter.dy);
      canvas.scale(1 + 0.38 * _hintBadgePunch.eased);
      canvas.translate(-_hintBadgeCenter.dx, -_hintBadgeCenter.dy);
    }
    canvas.drawCircle(
      _hintBadgeCenter,
      _hintBadgeDiameter / 2,
      count == 0 ? _hintBadgeZeroPaint : _hintBadgePaint,
    );
    canvas.drawCircle(
      _hintBadgeCenter,
      _hintBadgeDiameter / 2,
      _hintBadgeStrokePaint,
    );

    if (_cachedHintBadgeCount != count) {
      _cachedHintBadgeCount = count;
      final label = count > 99 ? '99+' : '$count';
      _hintBadgePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: _ts(
            size: buttonRect.width * (label.length > 2 ? 0.18 : 0.22),
            color: count == 0
                ? const Color(0xFFFFF1CF)
                : const Color(0xFF211204),
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
      )..layout(maxWidth: _hintBadgeDiameter * 0.92);
    }
    final painter = _hintBadgePainter!;
    painter.paint(
      canvas,
      _hintBadgeCenter - Offset(painter.width / 2, painter.height / 2),
    );
    if (punched) canvas.restore();
  }

  /// 랭킹 — 왕관 심볼 (힌트 전구와 구분).
  void _drawRankingButton(Canvas canvas) {
    final r = _rankingRect;
    if (r.isEmpty) return;
    final pressed = _pushPressScale(canvas, r);
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(
      canvas,
      r,
      _uiAtlas?[UiFrames.rankingCrownIcon],
      sizeFactor: 0.6,
    );
    if (pressed) canvas.restore();
  }

  void _drawPause(Canvas canvas) {
    final r = _pauseRect;
    final pressed = _pushPressScale(canvas, r);
    _drawIconButtonFrame(canvas, r);
    _drawButtonIcon(canvas, r, _uiAtlas?[UiFrames.pauseIcon], sizeFactor: 0.70);
    if (pressed) canvas.restore();
  }

  void _drawItemSlots(Canvas canvas) {
    final panel = game.hudBottomPanel;
    if (panel == MatchGameHudBottomPanel.none) return;
    _drawItemTray(canvas);
    if (panel == MatchGameHudBottomPanel.qaEffects) {
      for (final entry in _debugEffectPreviewRects.entries) {
        _drawDebugEffectPreviewButton(canvas, entry.value, entry.key);
      }
      return;
    }
    for (final slot in game.hudLoadoutSlots) {
      final r = _loadoutSlotRects[slot.index];
      if (r == null || r.isEmpty) continue;
      final previewKind = _debugEffectPreviewKindForRect(r);
      if (previewKind != null) {
        _drawDebugEffectPreviewButton(canvas, r, previewKind);
        continue;
      }
      final item = slot.item;
      if (slot.locked || item == null) {
        _drawLockedItemSlot(canvas, r);
        continue;
      }
      _drawItemSlot(
        canvas,
        r,
        item,
        enabledOverride: game.isLoadoutSlotUsable(slot),
        quantity: game.usesPhase2Inventory
            ? game.runInventory.quantityOf(item)
            : null,
      );
    }
  }

  GemKind? _debugEffectPreviewKindForRect(Rect r) {
    if (!_isQaEffectPanel) return null;
    for (final entry in _debugEffectPreviewRects.entries) {
      if ((entry.value.center - r.center).distance < 0.5) {
        return entry.key;
      }
    }
    return null;
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
    _drawGemSprite(canvas, iconRect, color);
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
    ItemKind.hintPlus => '힌트를 바로 표시합니다',
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

    final atlas = _uiAtlas;
    final frame = atlas?[UiFrames.panelFrame];
    if (atlas != null && frame != null) {
      drawAtlasNine(
        canvas,
        atlas.image,
        frame,
        UiFrames.panelFrameCenter,
        r,
        _panelNinePaint,
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
    _drawGemSprite(canvas, inset, color);

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
      _hudGlows.draw(
        canvas,
        HudGlowKind.prismSelection,
        r.deflate(1.2).topLeft,
        const Color(0xFF6FF7E8).withValues(alpha: 0.55),
      );
    }
  }

  void _drawItemTray(Canvas canvas) {
    final r = _itemTrayRect;
    if (r.isEmpty) return;

    final radius = Radius.circular(math.min(10.0, r.height * 0.12));
    final rr = RRect.fromRectAndRadius(r, radius);
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

    if (!game.usesPhase2Inventory) {
      final y = r.center.dy;
      canvas.drawLine(
        Offset(r.left + r.width * 0.05, y),
        Offset(r.right - r.width * 0.05, y),
        _itemTrayGroovePaint,
      );
    }
  }

  void _drawItemSlot(
    Canvas canvas,
    Rect r,
    ItemKind item, {
    bool? enabledOverride,
    int? quantity,
  }) {
    final enabled = enabledOverride ?? game.isItemEnabled(item);
    final active = game.activeTargetItem == item;
    final pressed = _pushPressScale(canvas, r);
    _drawIconButtonFrame(canvas, r);

    if (active) {
      _hudGlows.draw(
        canvas,
        HudGlowKind.itemTarget,
        r.deflate(1.8).topLeft,
        const Color(0x7A6FF7E8),
      );
    }

    if (_usedItem == item && _itemUsePunch.isActive) {
      _itemUsePaint
        ..strokeWidth = 1.5 + 2 * _itemUsePunch.eased
        ..color = const Color(
          0xFFFFF0A8,
        ).withValues(alpha: _itemUsePunch.value);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(9)),
        _itemUsePaint,
      );
    }
    final icon = _uiAtlas?[UiFrames.itemIcon(item)];
    if (icon != null) {
      final iconBounds = r.deflate(math.max(7.0, r.height * 0.18));
      final side = math.min(iconBounds.width, iconBounds.height);
      final dst = Rect.fromCenter(
        center: iconBounds.center,
        width: side,
        height: side,
      );
      _drawUi(canvas, icon, dst, enabled ? null : _itemIconDimPaint);
      if (quantity != null) {
        _drawItemQuantityBadge(canvas, r, item, quantity);
      }
      if (pressed) canvas.restore();
      return;
    }

    final labelState = enabled ? (active ? 2 : 1) : 0;
    var painter = _itemLabelPainters[item];
    if (painter == null || _itemLabelStates[item] != labelState) {
      final label = item.shortLabel;
      painter = TextPainter(
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
      _itemLabelPainters[item] = painter;
      _itemLabelStates[item] = labelState;
    }
    painter.paint(
      canvas,
      Offset(r.center.dx - painter.width / 2, r.center.dy - painter.height / 2),
    );
    if (quantity != null) {
      _drawItemQuantityBadge(canvas, r, item, quantity);
    }
    if (pressed) canvas.restore();
  }

  void _drawLockedItemSlot(Canvas canvas, Rect r) {
    _drawIconButtonFrame(canvas, r);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.deflate(4), Radius.circular(r.width * 0.18)),
      _lockedItemPaint,
    );

    _lockShacklePaint.strokeWidth = math.max(2.0, r.width * 0.07);
    var bodyPaint = _lockBodyPaints[r];
    if (bodyPaint == null) {
      bodyPaint = Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9E7A44), Color(0xFF3E2A13)],
        ).createShader(r);
      _lockBodyPaints[r] = bodyPaint;
    }
    final shackle = Rect.fromCenter(
      center: r.center.translate(0, -r.height * 0.08),
      width: r.width * 0.34,
      height: r.height * 0.34,
    );
    canvas.drawArc(shackle, math.pi, math.pi, false, _lockShacklePaint);
    final body = Rect.fromCenter(
      center: r.center.translate(0, r.height * 0.10),
      width: r.width * 0.46,
      height: r.height * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(r.width * 0.07)),
      bodyPaint,
    );
  }

  void _drawDebugEffectPreviewButton(Canvas canvas, Rect r, GemKind kind) {
    _drawIconButtonFrame(canvas, r);
    final colors = _debugEffectPreviewColors(kind);
    final inner = r.deflate(math.max(4.0, r.width * 0.11));
    final radius = Radius.circular(math.min(8.0, inner.width * 0.20));
    final rr = RRect.fromRectAndRadius(inner, radius);
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.$1.withValues(alpha: 0.92),
          colors.$2.withValues(alpha: 0.72),
          const Color(0xFF08090B).withValues(alpha: 0.92),
        ],
      ).createShader(inner);
    canvas.drawRRect(rr, fill);

    _hudGlows.draw(
      canvas,
      HudGlowKind.preview,
      inner.topLeft,
      colors.$1.withValues(alpha: 0.52),
    );

    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = colors.$1.withValues(alpha: 0.86);
    canvas.drawRRect(rr, stroke);

    final label = _debugEffectPreviewLabel(kind);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _ts(
          size: math.min(
            r.height * 0.34,
            r.width / math.max(2.2, label.length),
          ),
          color: const Color(0xFFFFF4D6),
          weight: FontWeight.w900,
          shadows: _hudLegibilityShadows(),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: inner.width * 0.92);
    painter.paint(
      canvas,
      Offset(
        inner.center.dx - painter.width / 2,
        inner.center.dy - painter.height / 2,
      ),
    );
  }

  String _debugEffectPreviewLabel(GemKind kind) {
    return switch (kind) {
      GemKind.row => 'R',
      GemKind.col => 'C',
      GemKind.bomb => 'B',
      GemKind.star => 'S',
      GemKind.hyper => 'H',
      GemKind.supernova => 'SN',
      GemKind.normal => '',
    };
  }

  (Color, Color) _debugEffectPreviewColors(GemKind kind) {
    return switch (kind) {
      GemKind.row ||
      GemKind.col => (const Color(0xFF7CF7FF), const Color(0xFF145B65)),
      GemKind.bomb => (const Color(0xFFFFD366), const Color(0xFF7D2A08)),
      GemKind.star => (const Color(0xFFFFF1A8), const Color(0xFF825F12)),
      GemKind.hyper => (const Color(0xFFC98DFF), const Color(0xFF1F5F78)),
      GemKind.supernova => (const Color(0xFFFFF3B0), const Color(0xFF8B6A12)),
      GemKind.normal => (const Color(0xFFE6E6E6), const Color(0xFF454545)),
    };
  }

  /// 수량 배지. 슬롯마다 매 프레임 그려지므로 페인트와 글자는 캐시해 둔다.
  /// 수량 0은 색을 가라앉혀 쓸 수 없는 슬롯임을 한눈에 구분한다.
  void _drawItemQuantityBadge(
    Canvas canvas,
    Rect r,
    ItemKind item,
    int quantity,
  ) {
    final badge = Rect.fromCircle(
      center: Offset(r.right - r.width * 0.13, r.bottom - r.height * 0.13),
      radius: r.width * 0.16,
    );
    var fill = _qtyBadgeFillPaints[item];
    if (fill == null) {
      fill = Paint()
        ..isAntiAlias = true
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFF0A8), Color(0xFFC58A22)],
        ).createShader(badge);
      _qtyBadgeFillPaints[item] = fill;
    }
    canvas.drawOval(badge, quantity == 0 ? _qtyBadgeZeroPaint : fill);
    canvas.drawOval(badge, _qtyBadgeStrokePaint);

    final quantityKey = quantity.clamp(0, 100);
    var painter = _qtyBadgePainters[quantityKey];
    if (painter == null) {
      final text = quantity > 99 ? '99+' : '$quantity';
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: _ts(
            size: r.width * (text.length > 2 ? 0.16 : 0.20),
            color: quantity == 0
                ? const Color(0xFFFFF1CF)
                : const Color(0xFF211204),
            weight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: badge.width);
      _qtyBadgePainters[quantityKey] = painter;
    }
    painter.paint(
      canvas,
      Offset(
        badge.center.dx - painter.width / 2,
        badge.center.dy - painter.height / 2,
      ),
    );
  }
}
