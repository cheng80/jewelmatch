import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../game/item_kind.dart';
import 'asset_paths.dart';

/// `tools/pack_atlas.py`가 만든 텍스처 한 장과 칸 좌표.
///
/// 이미지는 [Flame.images]에 한 번만 올려 Flame HUD와 Flutter 위젯이 같은 텍스처를 쓴다.
class TextureAtlas {
  TextureAtlas(this.image, this.frames);

  /// 같은 칸 크기로 가로 우선 늘어선 시트를 `prefix + 번호` 이름으로 감싼다.
  factory TextureAtlas.grid(
    ui.Image image, {
    required String prefix,
    required double cell,
    required int count,
  }) {
    final columns = image.width ~/ cell;
    return TextureAtlas(image, {
      for (var i = 0; i < count; i++)
        '$prefix$i': Rect.fromLTWH(
          (i % columns) * cell,
          (i ~/ columns) * cell,
          cell,
          cell,
        ),
    });
  }

  final ui.Image image;
  final Map<String, Rect> frames;

  Rect? operator [](String name) => frames[name];

  static Map<String, Rect> parseFrames(String manifest) {
    final frames = (jsonDecode(manifest) as Map<String, dynamic>)['frames'];
    return {
      for (final MapEntry(:key, :value)
          in (frames as Map<String, dynamic>).entries)
        key: Rect.fromLTWH(
          (value['x'] as num).toDouble(),
          (value['y'] as num).toDouble(),
          (value['w'] as num).toDouble(),
          (value['h'] as num).toDouble(),
        ),
    };
  }

  static final Map<String, Future<TextureAtlas?>> _pending = {};
  static final Map<String, TextureAtlas> _loaded = {};

  /// 이미 올라온 아틀라스. 없으면 null.
  static TextureAtlas? cached(String imagePath) => _loaded[imagePath];

  /// [imagePath]는 Flame 기준(assets/images 이후), [manifestPath]는 전체 에셋 경로다.
  /// 실패하면 null을 돌려주고 부른 쪽이 조용히 대체한다.
  static Future<TextureAtlas?> load(String imagePath, String manifestPath) =>
      _pending[imagePath] ??= () async {
        try {
          final manifest = await rootBundle.loadString(manifestPath);
          final atlas = TextureAtlas(
            await Flame.images.load(imagePath),
            parseFrames(manifest),
          );
          return _loaded[imagePath] = atlas;
        } catch (_) {
          return null;
        }
      }();

  /// ui_atlas와 ui_buttons_atlas를 함께 올린다.
  static Future<void> precacheUi() => Future.wait([
    load(AssetPaths.uiAtlas, AssetPaths.uiAtlasManifest),
    load(AssetPaths.uiButtonsAtlas, AssetPaths.uiButtonsAtlasManifest),
  ]);

  /// UI 칸 이름으로 이미지와 소스 사각형을 찾는다. 아직 안 올라왔으면 null.
  static (ui.Image, Rect)? findUi(String frame) {
    for (final path in const [AssetPaths.uiAtlas, AssetPaths.uiButtonsAtlas]) {
      final atlas = _loaded[path];
      final src = atlas?[frame];
      if (src != null) return (atlas!.image, src);
    }
    return null;
  }

  /// 보석 아이콘 `gem_0` ~ `gem_6`(시트 열 순서). 보드와 같은 board_atlas 한 장을 쓴다.
  static Future<TextureAtlas?> loadGems() => load(
    AssetPaths.boardAtlas,
    'assets/images/${AssetPaths.boardAtlasManifest}',
  );
}

/// ui_atlas 칸 이름. 원본 파일 이름에서 `.png`를 뺀 것이다.
abstract final class UiFrames {
  static const String iconButtonFrame = 'obsidian_icon_button_frame';
  static const String hintBulbIcon = 'obsidian_hint_bulb_icon';
  static const String tutorialIcon = 'obsidian_tutorial_icon';
  static const String pauseIcon = 'obsidian_pause_icon';
  static const String rankingCrownIcon = 'obsidian_ranking_crown_icon';
  static const String panelFrame = 'obsidian_panel_frame';

  /// [panelFrame] 칸 안에서 늘어나는 가운데 영역.
  static const Rect panelFrameCenter = Rect.fromLTRB(58, 58, 334, 420);

  static const String itemRuneHammer = 'rune_hammer';
  static const String itemAncientBomb = 'ancient_bomb';
  static const String itemThorHammer = 'thor_hammer';
  static const String itemHyperCube = 'hyper_cube';
  static const String itemPrismTransform = 'prism_transform';
  static const String itemFateShuffle = 'fate_shuffle';
  static const String itemTimeSlip = 'time_slip';
  static const String itemHintPlus = 'hint_plus';

  static String itemIcon(ItemKind item) => switch (item) {
    ItemKind.runeHammer => itemRuneHammer,
    ItemKind.ancientBomb => itemAncientBomb,
    ItemKind.thorHammer => itemThorHammer,
    ItemKind.hyperCube => itemHyperCube,
    ItemKind.prismTransform => itemPrismTransform,
    ItemKind.fateShuffle => itemFateShuffle,
    ItemKind.timeSlip => itemTimeSlip,
    ItemKind.hintPlus => itemHintPlus,
  };

  static const String modeIconSimple = 'mode_icon_simple_infinity_256';
  static const String modeIconProgression = 'mode_icon_progression_256';
  static const String modeIconTimed = 'mode_icon_timed_hourglass_256';
  static const String modeIconSettings = 'mode_icon_settings_gear_256';
  static const String modeIconRanking = 'mode_icon_ranking_crown_256';
  static const String modeIconInventory = 'mode_icon_inventory_256';

  static const String modeButtonPanelBase = 'mode_button_panel_base';
  static const String modeButtonFrameFront = 'mode_button_frame_front';
  static const String normalButtonTintBg = 'normal_button_tint_bg';
  static const String normalButtonFrontFrame = 'normal_button_front_frame';
}

/// 아틀라스 칸 하나를 나인패치로 그린다. `drawImageNine`은 소스 사각형을 받지 않아
/// Impeller `NinePatchConverter`와 같은 규칙으로 조각마다 `drawImageRect`를 쓴다.
/// `drawImageNine`과 같게 하려면 [paint]는 안티앨리어스 없이 `FilterQuality.low`(선형)로 준다.
void drawAtlasNine(
  Canvas canvas,
  ui.Image image,
  Rect src,
  Rect center,
  Rect dst,
  Paint paint,
) {
  if (dst.isEmpty) return;
  final xs = _nineSlices(
    src.left,
    src.left + center.left,
    src.left + center.right,
    src.right,
    dst.left,
    dst.right,
  );
  final ys = _nineSlices(
    src.top,
    src.top + center.top,
    src.top + center.bottom,
    src.bottom,
    dst.top,
    dst.bottom,
  );
  for (var yi = 0; yi < ys.length; yi += 4) {
    for (var xi = 0; xi < xs.length; xi += 4) {
      final s = Rect.fromLTRB(xs[xi], ys[yi], xs[xi + 2], ys[yi + 2]);
      final d = Rect.fromLTRB(xs[xi + 1], ys[yi + 1], xs[xi + 3], ys[yi + 3]);
      if (s.isEmpty || d.isEmpty) continue;
      canvas.drawImageRect(image, s, d, paint);
    }
  }
}

/// 한 축의 조각 목록. 네 값씩 (소스 시작, 대상 시작, 소스 끝, 대상 끝)이다.
List<double> _nineSlices(
  double img0,
  double imgC0,
  double imgC1,
  double img1,
  double dst0,
  double dst1,
) {
  final imageDim = img1 - img0;
  final destDim = dst1 - dst0;
  if (imageDim == destDim) return [img0, dst0, img1, dst1];
  final edge0 = imgC0 - img0;
  final edge1 = img1 - imgC1;
  final edges = edge0 + edge1;
  if (edges >= destDim) {
    final dstC = dst0 + destDim * edge0 / edges;
    return [img0, dst0, imgC0, dstC, imgC1, dstC, img1, dst1];
  }
  final dstC0 = dst0 + edge0;
  final dstC1 = dst1 - edge1;
  return [
    ...[img0, dst0, imgC0, dstC0],
    ...[imgC0, dstC0, imgC1, dstC1],
    ...[imgC1, dstC1, img1, dst1],
  ];
}
