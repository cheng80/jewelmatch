import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/services.dart';

import '../../resources/asset_paths.dart';

/// `board_atlas.webp` 한 장과 칸 좌표(`board_atlas.json`).
/// 보드 보석, 특수 보석, 배지, 범위 효과 레이어, 게임 방법 화면이 이 한 장에서 잘라 쓴다.
/// 칸 이름: `gem_0`~`gem_6`(Jewel_Arcane 열), `action_0`~`action_3`(bomb, star,
/// hyper, supernova), `legacy_0`~`legacy_1`(col, row), `badge_0`~`badge_1`(Time,
/// Multiplier), `bomb_`/`hyper_`/`supernova_` + `0`~`4`(범위 효과 레이어).
/// 이미지는 Flame.images가 소유하므로 여기서 해제하지 않는다.
class BoardAtlas {
  const BoardAtlas(this.image, this.frames);

  final ui.Image image;
  final Map<String, ui.Rect> frames;

  static Future<BoardAtlas>? _shared;

  /// 앱 전체가 공유하는 아틀라스. 실패하면 다음 호출에서 다시 읽는다.
  static Future<BoardAtlas> load() {
    return _shared ??= read(rootBundle, Flame.images.load).catchError((
      Object error,
      StackTrace stack,
    ) {
      _shared = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  /// manifest와 이미지를 읽는다. 이미지 밖으로 나가는 칸은 버린다.
  static Future<BoardAtlas> read(
    AssetBundle bundle,
    Future<ui.Image> Function(String) loadImage,
  ) async {
    final raw =
        jsonDecode(
              await bundle.loadString(
                'assets/images/${AssetPaths.boardAtlasManifest}',
              ),
            )
            as Map<String, dynamic>;
    final image = await loadImage(AssetPaths.boardAtlas);
    final bounds = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final frames = <String, ui.Rect>{};
    for (final entry in (raw['frames'] as Map<String, dynamic>).entries) {
      final f = entry.value as Map<String, dynamic>;
      final rect = ui.Rect.fromLTWH(
        (f['x'] as num).toDouble(),
        (f['y'] as num).toDouble(),
        (f['w'] as num).toDouble(),
        (f['h'] as num).toDouble(),
      );
      if (rect.isEmpty || bounds.intersect(rect) != rect) continue;
      frames[entry.key] = rect;
    }
    return BoardAtlas(image, frames);
  }
}
