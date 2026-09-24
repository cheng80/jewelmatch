import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/resources/texture_atlas.dart';

Future<ui.Image> decodeFile(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

Future<Uint8List> rgba(ui.Image image) async =>
    (await image.toByteData())!.buffer.asUint8List();

Future<Uint8List> render(int w, int h, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await rgba(image);
  image.dispose();
  picture.dispose();
  return bytes;
}

double meanDiff(Uint8List a, Uint8List b) {
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 파일 픽셀은 pack_atlas.py가 원본과 같음을 확인한다. Flutter 디코더는 PNG와 WebP의
  // 알파 곱셈 반올림이 달라 반투명 픽셀에서 곱해진 값이 1까지 다를 수 있다.
  // 원본 PNG(assets/design/legacy/ui)는 Git에서 빠져 있어 없는 곳에서는 비교를 건너뛴다.
  final hasSources = Directory('assets/design/legacy/ui').existsSync();

  test(
    'every ui atlas frame decodes within 1/255 of its source PNG',
    () async {
      var differing = 0;
      var total = 0;
      for (final sheet in ['ui_atlas', 'ui_buttons_atlas']) {
        final atlas = await decodeFile('assets/images/ui/$sheet.webp');
        final frames = TextureAtlas.parseFrames(
          File('assets/images/ui/$sheet.json').readAsStringSync(),
        );
        final atlasBytes = await rgba(atlas);
        for (final MapEntry(key: name, value: r) in frames.entries) {
          final path = Directory('assets/design/legacy/ui')
              .listSync(recursive: true)
              .whereType<File>()
              .firstWhere((f) => f.path.endsWith('/$name.png'))
              .path;
          final source = await decodeFile(path);
          final sourceBytes = await rgba(source);
          expect(source.width, r.width.toInt(), reason: name);
          expect(source.height, r.height.toInt(), reason: name);
          for (var y = 0; y < source.height; y++) {
            for (var x = 0; x < source.width * 4; x++) {
              final a =
                  atlasBytes[((r.top.toInt() + y) * atlas.width +
                              r.left.toInt()) *
                          4 +
                      x];
              final s = sourceBytes[y * source.width * 4 + x];
              total++;
              if (a != s) differing++;
              if ((a - s).abs() > 1) fail('$name ($x, $y) $a != $s');
            }
          }
          source.dispose();
        }
        atlas.dispose();
      }
      // ignore: avoid_print
      print('[decode] differing=$differing / $total bytes (max 1)');
    },
    skip: hasSources ? false : '원본 PNG 없음(Git 제외)',
  );

  test(
    'atlas nine slice matches drawImageNine of the original panel',
    () async {
      final atlas = await decodeFile('assets/images/ui/ui_atlas.webp');
      final frame = TextureAtlas.parseFrames(
        File('assets/images/ui/ui_atlas.json').readAsStringSync(),
      )[UiFrames.panelFrame]!;
      final panel = await decodeFile(
        'assets/design/legacy/ui/obsidian_panel_frame.png',
      );
      final ninePaint = Paint()..filterQuality = FilterQuality.high;
      final paint = Paint()..filterQuality = FilterQuality.low;
      for (final dst in const [
        Rect.fromLTWH(12.3, 20.6, 350.4, 351.2),
        Rect.fromLTWH(8, 8, 140, 140),
        Rect.fromLTWH(10, 10, 100, 80),
        Rect.fromLTWH(4, 4, 392, 478),
      ]) {
        final expected = await render(400, 500, (c) {
          c.drawImageNine(panel, UiFrames.panelFrameCenter, dst, ninePaint);
        });
        final actual = await render(400, 500, (c) {
          drawAtlasNine(c, atlas, frame, UiFrames.panelFrameCenter, dst, paint);
        });
        // ignore: avoid_print
        print('[nine] $dst mean=${meanDiff(expected, actual)}');
        expect(meanDiff(expected, actual), lessThan(0.5), reason: '$dst');
      }
    },
    skip: hasSources ? false : '원본 PNG 없음(Git 제외)',
  );
}
