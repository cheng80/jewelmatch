import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/baked_hud_glow_atlas.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/utils/storage_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
  });

  for (final strokeWidth in [0.0, 2.2]) {
    test(
      'baked HUD mask preserves blurred rounded rectangle ($strokeWidth)',
      () async {
        final shape = RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 180.3, 37.2),
          const Radius.circular(14),
        );
        final atlas = BakedHudGlowAtlas()
          ..configure([HudGlowMask(shape, 8, strokeWidth)])
          ..mount();
        final tint = strokeWidth == 0
            ? const Color(0x61000000)
            : const Color(0x7A6FF7E8);
        const position = Offset(40.25, 40.75);
        final baked = await _record(
          (canvas) =>
              atlas.draw(canvas, HudGlowKind.comboShadow, position, tint),
        );
        final reference = await _record((canvas) {
          canvas.drawRRect(
            shape.shift(position),
            Paint()
              ..color = tint
              ..style = strokeWidth == 0
                  ? PaintingStyle.fill
                  : PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..maskFilter = MaskFilter.blur(
                strokeWidth == 0 ? BlurStyle.normal : BlurStyle.outer,
                8,
              ),
          );
        });
        var difference = 0;
        var alpha = 0;
        for (var i = 3; i < baked.length; i += 4) {
          difference += (baked[i] - reference[i]).abs();
          alpha += baked[i];
        }
        expect(alpha, greaterThan(1000));
        // Subpixel placement may differ by one sample; no cropped/dropped halo.
        expect(difference / (baked.length / 4), lessThan(0.3));
        expect(baked[3], 0, reason: 'atlas padding must remain transparent');
        atlas.dispose();
      },
    );
  }

  test(
    'HUD draws cached shadows, retains hit rects and rebuilds only for layout',
    () async {
      final game = MatchBoardGame(gameMode: JewelGameMode.timed);
      game.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
      game.onGameResize(Vector2(390, 750));
      final hud = MatchGameHud(
        onPausePressed: () {},
        onHintPressed: () {},
        onTutorialPressed: () {},
      )..game = game;
      hud.onGameResize(game.size);
      hud.update(0);
      final rects = hud.debugReadAlignedHudRects();
      final before = await _record(hud.render);
      hud.onMount();
      final after = await _record(hud.render);
      final combo = rects['combo']!;
      final x = (combo.left - 8).floor();
      final y = combo.center.dy.floor();
      expect(
        after[(y * 390 + x) * 4 + 3],
        greaterThan(before[(y * 390 + x) * 4 + 3]),
        reason: 'real HUD render must draw the baked shadow outside the strip',
      );
      final generation = hud.debugGlowGeneration;
      for (var i = 0; i < 8; i++) {
        hud.update(0.02);
        await _record(hud.render);
      }
      expect(hud.debugGlowGeneration, generation);
      hud.onGameResize(game.size);
      expect(hud.debugGlowGeneration, generation);
      expect(hud.debugReadAlignedHudRects(), rects);
      hud.onRemove();
      expect(hud.debugGlowReady, isFalse);
      hud.onMount();
      expect(hud.debugGlowReady, isTrue);
      expect(hud.debugGlowGeneration, generation + 1);
      game.onGameResize(Vector2(430, 850));
      hud.onGameResize(game.size);
      expect(hud.debugGlowGeneration, generation + 2);
      await _record(hud.render);
      hud.onRemove();
    },
  );
}

Future<Uint8List> _record(void Function(ui.Canvas) render) async {
  final recorder = ui.PictureRecorder();
  render(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(390, 750);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}
