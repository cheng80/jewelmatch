part of 'match_board_renderer.dart';

/// 고정 버퍼와 길이별 뷰를 재사용한다. 착지 스쿼시 앞에서는 flush하여
/// 기존 행 순서(겹친 보석의 앞뒤)를 유지한다.
class _GemAtlasBatch {
  _GemAtlasBatch(int capacity)
    : transforms = Float32List(capacity * 4),
      sources = Float32List(capacity * 4),
      colors = Int32List(capacity) {
    transformViews = [
      for (var n = 0; n <= capacity; n++)
        Float32List.sublistView(transforms, 0, n * 4),
    ];
    sourceViews = [
      for (var n = 0; n <= capacity; n++)
        Float32List.sublistView(sources, 0, n * 4),
    ];
    colorViews = [
      for (var n = 0; n <= capacity; n++) Int32List.sublistView(colors, 0, n),
    ];
  }

  static const double cell = 64;
  static const int columns = 8;
  static const int baseCount = 42; // 7종 × 기존 색상 6종, 폴백도 색 보존
  static const int shineFrames = 6;
  static const int glowSlot = baseCount + 6 * shineFrames;
  static const int slotCount = glowSlot + 1;
  ui.Image? image;
  final Float32List transforms;
  final Float32List sources;
  final Int32List colors;
  late final List<Float32List> transformViews;
  late final List<Float32List> sourceViews;
  late final List<Int32List> colorViews;
  final Paint paint = Paint()..filterQuality = FilterQuality.medium;
  final List<Rect> rects = List.generate(
    slotCount,
    (i) =>
        Rect.fromLTWH((i % columns) * cell, (i ~/ columns) * cell, cell, cell),
  );
  int count = 0;
  int drawCalls = 0;
  int submittedGems = 0;

  void beginFrame() {
    count = 0;
    drawCalls = 0;
    submittedGems = 0;
  }

  void add({
    required int slot,
    required double x,
    required double y,
    required double size,
    double scale = 1,
    double rotation = 0,
    double alpha = 1,
    bool gem = true,
  }) {
    final i = count * 4;
    final s = size / cell * scale;
    final scos = s * math.cos(rotation);
    final ssin = s * math.sin(rotation);
    transforms[i] = scos;
    transforms[i + 1] = ssin;
    transforms[i + 2] = x - (scos - ssin) * cell / 2;
    transforms[i + 3] = y - (ssin + scos) * cell / 2;
    final rect = rects[slot];
    sources[i] = rect.left;
    sources[i + 1] = rect.top;
    sources[i + 2] = rect.right;
    sources[i + 3] = rect.bottom;
    colors[count] = ((alpha.clamp(0.0, 1.0) * 255).round() << 24) | 0xFFFFFF;
    count++;
    if (gem) submittedGems++;
  }

  void flush(Canvas canvas) {
    if (count == 0 || image == null) return;
    canvas.drawRawAtlas(
      image!,
      transformViews[count],
      sourceViews[count],
      colorViews[count],
      BlendMode.modulate,
      null,
      paint,
    );
    drawCalls++;
    count = 0;
  }

  void dispose() {
    image?.dispose();
    image = null;
    count = 0;
  }
}

extension _MatchBoardGemAtlas on MatchBoardRenderer {
  void _buildGemAtlas() {
    _gemBatch.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const cell = _GemAtlasBatch.cell;
    final shinePaint = Paint()..blendMode = BlendMode.srcATop;
    for (var slot = 0; slot < _GemAtlasBatch.glowSlot; slot++) {
      final shining = slot >= _GemAtlasBatch.baseCount;
      final baseSlot = shining ? (slot - _GemAtlasBatch.baseCount) ~/ 6 : slot;
      final kind = GemKind.values[baseSlot ~/ 6];
      final color = baseSlot % 6 + 1;
      final gem = BoardGem(
        id: 0,
        color: color,
        kind: kind,
        row: 0,
        col: 0,
        x: 0,
        y: 0,
        targetX: 0,
        targetY: 0,
      );
      final rect = _gemBatch.rects[slot];
      canvas.save();
      canvas.clipRect(rect);
      canvas.translate(rect.left, rect.top);
      _drawGemAppearance(canvas, gem, cell, removing: false);
      if (shining) {
        // srcATop를 셀 안에만 그려 보석의 기존 알파로 마스킹한다.
        // 로딩 때 구우므로 런타임 레이어, blur, shader 생성이 없다.
        final phase = (slot - _GemAtlasBatch.baseCount) % 6;
        final x = -cell * 0.7 + phase / 5 * cell * 1.7;
        shinePaint.shader = ui.Gradient.linear(
          Offset(x, 0),
          Offset(x + cell * 0.42, cell * 0.18),
          const [Color(0x00FFFFFF), Color(0x88FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.5, 1],
        );
        canvas.drawRect(const Rect.fromLTWH(0, 0, cell, cell), shinePaint);
      }
      canvas.restore();
    }
    final glow = _gemBatch.rects[_GemAtlasBatch.glowSlot];
    canvas.drawCircle(
      glow.center,
      cell / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          glow.center,
          cell / 2,
          const [
            Color(0x004DDAFF),
            Color(0x104DDAFF),
            Color(0xAA83EFFF),
            Color(0x004DDAFF),
          ],
          const [0, 0.50, 0.72, 1],
        ),
    );
    final picture = recorder.endRecording();
    _gemBatch.image = picture.toImageSync(
      (_GemAtlasBatch.columns * cell).toInt(),
      ((_GemAtlasBatch.slotCount / _GemAtlasBatch.columns).ceil() * cell)
          .toInt(),
    );
    picture.dispose();
  }

  int _atlasSlot(BoardGem gem) {
    final color = gem.color.clamp(1, 6) - 1;
    if (gem.kind == GemKind.normal &&
        logic.state == 'idle' &&
        !logic.inputLocked &&
        !logic.introFillInProgress &&
        gem.bumpT < 0 &&
        logic.activeInvalidDragGem == null) {
      final phase = (_animTime + gem.row * 0.14 + gem.col * 0.11) % 6;
      if (phase < 0.72) {
        return _GemAtlasBatch.baseCount +
            color * 6 +
            (phase / 0.12).floor().clamp(0, 5);
      }
    }
    return gem.kind.index * 6 + color;
  }

  void _drawInteractionGlows(Canvas canvas, double ts) {
    if (_gemBatch.image == null ||
        logic.state != 'idle' ||
        logic.introFillInProgress) {
      return;
    }
    final sel = logic.selected;
    final preview = logic.swapPreviewCell;
    if (sel == null && preview == null) return;
    for (var r = 0; r < logic.rows; r++) {
      for (var c = 0; c < logic.cols; c++) {
        final selected = sel?.x == r && sel?.y == c;
        final target = preview?.x == r && preview?.y == c;
        final adjacent = sel != null && logic.areAdjacent(sel.x, sel.y, r, c);
        if ((!selected && !target && !adjacent) || logic.getGem(r, c) == null) {
          continue;
        }
        _gemBatch.add(
          slot: _GemAtlasBatch.glowSlot,
          x: logic.boardX + (c + 0.5) * ts,
          y: logic.boardY + (r + 0.5) * ts,
          size: ts * (selected ? 1.25 : 1.10),
          alpha: selected || target
              ? 0.85
              : 0.28 + 0.10 * math.sin(_animTime * 5),
          gem: false,
        );
      }
    }
    _gemBatch.flush(canvas);
  }

  void _drawShuffleFeedback(
    Canvas canvas,
    double bx,
    double by,
    double bw,
    double bh,
  ) {
    final noMoves = logic.lastActionText == 'no moves';
    final shuffling =
        logic.introFillInProgress && logic.lastActionText == 'shuffled';
    if (!noMoves && !shuffling && _shuffleVisualTime <= 0) return;
    _shufflePaint
      ..color = noMoves ? const Color(0xCCFFB75B) : const Color(0xAA83EFFF)
      ..strokeWidth = logic.tileSize * (noMoves ? 0.065 : 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(10),
      ),
      _shufflePaint,
    );
  }
}
