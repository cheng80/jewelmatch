part of 'match_game_hud.dart';

/// ui_atlas와 보석 텍스처에서 칸을 잘라 그린다.
///
/// 칸마다 `drawImageRect`를 쓴다. `drawRawAtlas`로 묶으면 웹(skwasm)에서 `FilterQuality.high`의
/// 큐빅 샘플링이 선형으로 바뀌어 축소된 아이콘이 흐려진다(2026-09-24 스크린샷 비교). 같은 텍스처를
/// 연달아 그리므로 텍스처 전환은 없다.
extension _MatchGameHudAtlas on MatchGameHud {
  Rect? get _uiFrameSrc => _uiAtlas?[UiFrames.iconButtonFrame];

  void _drawUi(Canvas canvas, Rect? src, Rect dst, [Paint? paint]) {
    final atlas = _uiAtlas;
    if (atlas == null || src == null) return;
    canvas.drawImageRect(atlas.image, src, dst, paint ?? _hudImagePaint);
  }

  void _drawIconButtonFrame(Canvas canvas, Rect r) =>
      _drawUi(canvas, _uiFrameSrc, r.inflate(r.width * 0.08));

  void _drawButtonIcon(
    Canvas canvas,
    Rect r,
    Rect? src, {
    required double sizeFactor,
    double offsetYFactor = 0,
  }) {
    final iconSize = r.width * sizeFactor;
    final iconRect = Rect.fromCenter(
      center: r.center.translate(0, r.width * offsetYFactor),
      width: iconSize,
      height: iconSize,
    );
    _drawUi(canvas, src, iconRect);
  }

  /// 보석 아이콘. board_atlas의 `gem_<시트 열>` 칸(없으면 Jewel_Arcane 시트)에서 잘라 그린다.
  void _drawGemSprite(Canvas canvas, Rect r, int color) {
    final atlas = _gemAtlas;
    if (atlas == null) return;
    final index =
        MatchGameHud._gemSheetColByColor1based[(color - 1).clamp(
          0,
          MatchGameHud._gemSheetColByColor1based.length - 1,
        )];
    final src = atlas['gem_$index'];
    if (src == null) return;
    final side = math.min(r.width, r.height) * 1.08;
    final dst = Rect.fromCenter(center: r.center, width: side, height: side);
    canvas.drawImageRect(atlas.image, src, dst, _hudImagePaint);
  }
}
