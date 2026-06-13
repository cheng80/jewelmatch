part of 'match_game_hud.dart';

extension _MatchGameHudSectionRenderer on MatchGameHud {
  void _renderBestBlock(Canvas canvas) {
    final g = game;
    final layout = g.hudScale;
    final top = g.safeAreaPadding.top + 10;
    final row1H = g.hudTopBarHeight;

    final bestBlockW = math.max(_bestLabel.width, _bestValue.width);
    final gapBestTutorial = layout * 0.1;
    // 튜토리얼 왼쪽까지가 베스트 영역 오른쪽 끝. 랭킹 버튼 추가 시 bestRight를 왼쪽으로 당기면
    // 블록 전체가 일시정지·힌트 위로 겹친다 → 오른쪽 끝은 항상 튜토리얼 기준.
    final bestRight = _tutorialRect.left - gapBestTutorial;
    final minLeft = (_rankingRect.width > 0)
        ? _rankingRect.right + gapBestTutorial
        : _hintRect.right + gapBestTutorial;
    var bestLeft = bestRight - bestBlockW;
    if (bestLeft < minLeft) {
      bestLeft = minLeft;
    }
    final bestTop =
        top + (row1H - (_bestLabel.height + 4 + _bestValue.height)) / 2;
    final slotTop = top;
    final slotBottom = top + row1H;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(minLeft, slotTop, bestRight, slotBottom));
    _bestLabel.paint(
      canvas,
      Offset(bestLeft + (bestBlockW - _bestLabel.width) / 2, bestTop),
    );
    _bestValue.paint(
      canvas,
      Offset(
        bestLeft + (bestBlockW - _bestValue.width) / 2,
        bestTop + _bestLabel.height + 4,
      ),
    );
    canvas.restore();
  }

  void _renderScoreBlock(Canvas canvas) {
    final cx = game.safeContentCenterX;
    final scoreY = _scoreBlockTop + 4;
    _scoreLabel.paint(canvas, Offset(cx - _scoreLabel.width / 2, scoreY));
    _scoreValue.paint(
      canvas,
      Offset(cx - _scoreValue.width / 2, scoreY + _scoreLabel.height + 4),
    );
  }

  void _renderComboStrip(Canvas canvas) {
    if (_comboRect.width <= 0 || _comboRect.height <= 0) {
      return;
    }

    final layout = game.hudScale;
    final comboR = math.min(14.0, _comboRect.height / 2);
    final comboBg = RRect.fromRectAndRadius(
      _comboRect,
      Radius.circular(comboR),
    );
    canvas.drawRRect(
      comboBg,
      _comboGradientPaint
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: JewelCandyLuminaTheme.comboStripGradient,
        ).createShader(_comboRect),
    );
    _comboStrokePaint.color = Colors.white.withValues(alpha: 0.22);
    canvas.drawRRect(comboBg, _comboStrokePaint);

    final halfW = _comboRect.width / 2;
    final leftCol = Rect.fromLTWH(
      _comboRect.left,
      _comboRect.top,
      halfW,
      _comboRect.height,
    );
    final rightCol = Rect.fromLTWH(
      _comboRect.left + halfW,
      _comboRect.top,
      halfW,
      _comboRect.height,
    );

    final gapLabelValue = math.max(5.0, layout * 0.06);
    final lh = _comboLeftLabel.height + gapLabelValue + _comboLeftValue.height;
    final rh =
        _comboRightLabel.height + gapLabelValue + _comboRightValue.height;
    final blockH = math.max(lh, rh);
    final labelTopInset = layout * 0.02;
    final minPad = layout * 0.22;
    var padTop = (_comboRect.height - blockH) / 2 + layout * 0.025;
    if (padTop < minPad) {
      padTop = minPad;
    }
    if (padTop + blockH > _comboRect.height - minPad * 0.75) {
      // blockH > 높이 이면 상한이 음수가 되어 clamp(0, 음수) 가 ArgumentError — 라벨 키운 뒤 발생
      final maxPadTop = math.max(0.0, _comboRect.height - blockH);
      padTop = ((_comboRect.height - blockH) / 2).clamp(0.0, maxPadTop);
    }
    final ly0 = _comboRect.top + padTop + (blockH - lh) / 2 + labelTopInset;
    final ry0 = _comboRect.top + padTop + (blockH - rh) / 2 + labelTopInset;
    _comboLeftLabel.paint(
      canvas,
      Offset(leftCol.center.dx - _comboLeftLabel.width / 2, ly0),
    );
    _comboLeftValue.paint(
      canvas,
      Offset(
        leftCol.center.dx - _comboLeftValue.width / 2,
        ly0 + _comboLeftLabel.height + gapLabelValue,
      ),
    );

    _comboRightLabel.paint(
      canvas,
      Offset(rightCol.center.dx - _comboRightLabel.width / 2, ry0),
    );
    _comboRightValue.paint(
      canvas,
      Offset(
        rightCol.center.dx - _comboRightValue.width / 2,
        ry0 + _comboRightLabel.height + gapLabelValue,
      ),
    );
  }

  void _renderTimeBar(Canvas canvas) {
    if (_timeBarRect.width <= 0 || _timeBarRect.height <= 0) {
      return;
    }

    final barBg = RRect.fromRectAndRadius(
      _timeBarRect,
      Radius.circular(_timeBarRect.height / 2),
    );
    canvas.drawRRect(
      barBg,
      _timeBarBgPaint..color = JewelCandyLuminaTheme.surfaceContainer,
    );
    _timeBarStrokePaint.color = JewelCandyLuminaTheme.outlineBright.withValues(
      alpha: 0.55,
    );
    canvas.drawRRect(barBg, _timeBarStrokePaint);

    // 고정 inset(3)은 타임바가 낮을 때 inner 높이가 음수가 되어 셰이더/ RRect 가 실패할 수 있음
    final inset = math.min(3.0, _timeBarRect.height / 3);
    final inner = Rect.fromLTWH(
      _timeBarRect.left + inset,
      _timeBarRect.top + inset,
      _timeBarRect.width - inset * 2,
      _timeBarRect.height - inset * 2,
    );

    if (inner.width <= 0 || inner.height <= 0) {
      return;
    }

    final innerR = RRect.fromRectAndRadius(
      inner,
      Radius.circular(inner.height / 2),
    );

    if (game.isTimedMode) {
      final r = _timeRatio();
      final fillW = inner.width * r;
      if (fillW > 0.5) {
        final rad = inner.height / 2;
        canvas.save();
        canvas.clipRRect(innerR);
        final fillRect = Rect.fromLTWH(
          inner.left,
          inner.top,
          fillW,
          inner.height,
        );
        final fillR = RRect.fromRectAndCorners(
          fillRect,
          topLeft: Radius.circular(rad),
          bottomLeft: Radius.circular(rad),
          topRight: Radius.circular(fillW >= inner.width - 1 ? rad : 0),
          bottomRight: Radius.circular(fillW >= inner.width - 1 ? rad : 0),
        );
        final low = r < 0.2;
        canvas.drawRRect(
          fillR,
          _timeFillPaint
            ..shader = LinearGradient(
              colors: low
                  ? JewelCandyLuminaTheme.timeBarFillCritical
                  : JewelCandyLuminaTheme.timeBarFillVibrant,
            ).createShader(fillRect),
        );
        canvas.restore();
      }
    } else {
      _untimedFillPaint.color = JewelCandyLuminaTheme.secondaryCyan.withValues(
        alpha: 0.14,
      );
      canvas.drawRRect(innerR, _untimedFillPaint);
    }

    if (_timeInBar != null) {
      final tp = _timeInBar!;
      tp.paint(
        canvas,
        Offset(inner.center.dx - tp.width / 2, inner.center.dy - tp.height / 2),
      );
    }
  }

  double _timeRatio() {
    if (!game.isTimedMode) return 1;
    final initial = MatchBoardGame.timedRoundSeconds;
    if (initial <= 0) return 0;
    final t = game.timeRemaining;
    // 보너스로 시작 분(120초)을 넘기면 바는 가득 찬 상태로 유지
    if (t >= initial) {
      return 1.0;
    }
    return (t / initial).clamp(0.0, 1.0);
  }
}
