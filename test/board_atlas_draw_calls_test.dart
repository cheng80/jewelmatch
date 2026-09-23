import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/match_board_renderer.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/components/special_effect_pool.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';

/// 이미지 그리기 호출과 서로 다른 ui.Image, 연속 호출 사이 텍스처 전환을 센다.
class DrawSpy implements ui.Canvas {
  static const imageCalls = {
    #drawImage,
    #drawImageRect,
    #drawImageNine,
    #drawAtlas,
    #drawRawAtlas,
  };
  final calls = <Symbol, int>{};
  final images = LinkedHashSet<ui.Image>.identity();
  int switches = 0;
  ui.Image? _last;

  int get imageDrawCalls => calls.entries
      .where((e) => imageCalls.contains(e.key))
      .fold(0, (a, e) => a + e.value);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (imageCalls.contains(name) || name == #drawPicture) {
      calls[name] = (calls[name] ?? 0) + 1;
    }
    if (imageCalls.contains(name)) {
      final image = invocation.positionalArguments[0] as ui.Image;
      images.add(image);
      if (_last != null && !identical(_last, image)) switches++;
      _last = image;
    }
    return null;
  }
}

/// 측정 장면: 8x8 일반 보석, 특수 4종, 배지 2개, bomb, hyper, supernova 동시 1프레임.
/// 효과 부모는 실제 게임처럼 붙어 있어야 레이어 묶음이 켜진다.
Future<(MatchBoardRenderer, Component)> buildScene(WidgetTester tester) async {
  final game = MatchBoardGame();
  final board = game.board;
  board.setGeometry(x: 16, y: 16, tile: 48);
  const specials = [
    GemKind.bomb,
    GemKind.star,
    GemKind.hyper,
    GemKind.supernova,
  ];
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      final kind = r == 0 && c < 4 ? specials[c] : GemKind.normal;
      board.setGem(r, c, board.createGem(r, c, (r + c) % 6 + 1, kind));
    }
  }
  board.getGem(1, 0)!.bonus = GemBonus.time;
  board.getGem(1, 1)!.bonus = GemBonus.multiplier;
  final renderer = MatchBoardRenderer(logic: board)..game = game;
  final host = FlameGame();
  final parent = Component();
  await tester.runAsync(() async {
    await renderer.onLoad();
    await SpecialEffectBurst.preloadAreaEffectSprites();
    await tester.pumpWidget(GameWidget(game: host));
    await host.toBeLoaded();
    await host.add(parent);
    await host.ready();
  });
  renderer.onMount();
  renderer.update(2);

  final pool = SpecialEffectPool(parent, constrainedDevice: false);
  const kinds = [GemKind.bomb, GemKind.hyper, GemKind.supernova];
  for (var i = 0; i < kinds.length; i++) {
    pool.spawn(
      effectKind: kinds[i],
      origin: Vector2(88 + i * 120, 208),
      affectedCenters: const [],
      tileSize: 48,
      baseColor: Colors.orange,
    );
  }
  await tester.runAsync(host.ready);
  for (final burst in parent.children.whereType<SpecialEffectBurst>()) {
    burst.update(0.15);
  }
  return (renderer, parent);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('measurement scene draw calls and distinct textures', (
    tester,
  ) async {
    final (renderer, effects) = await buildScene(tester);
    final board = DrawSpy();
    renderer.render(board);
    final fx = DrawSpy();
    effects.renderTree(fx);
    final all = DrawSpy();
    renderer.render(all);
    effects.renderTree(all);
    String line(String name, DrawSpy s) =>
        '$name image draws=${s.imageDrawCalls} textures=${s.images.length} '
        'switches=${s.switches} ${s.calls}';
    // ignore: avoid_print
    print(line('board', board));
    // ignore: avoid_print
    print(line('effects', fx));
    // ignore: avoid_print
    print(line('total', all));

    // 보석 한 호출과 배지 둘(board_atlas), 범위 효과 레이어 셋은 한 호출이다.
    expect(board.imageDrawCalls, 3);
    expect(board.images, hasLength(2));
    expect(fx.calls[#drawRawAtlas], 2, reason: 'bomb 글로우 1 + 레이어 묶음 1');

    final dir = Platform.environment['BOARD_ATLAS_CAPTURE'];
    if (dir != null) {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const Color(0xFF20211E), BlendMode.src);
        renderer.render(canvas);
        effects.renderTree(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(416, 416);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(dir).createSync(recursive: true);
        File('$dir/scene.png').writeAsBytesSync(Uint8List.sublistView(bytes!));
        image.dispose();
        picture.dispose();
      });
    }
    renderer.onRemove();
  });
}
