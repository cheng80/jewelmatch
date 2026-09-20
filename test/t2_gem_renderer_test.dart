import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/match_board_renderer.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/game/match_board_logic.dart';

class AtlasSpy implements ui.Canvas {
  ui.Image? image;
  final transforms = <double>[];
  final colors = <int>[];
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #drawRawAtlas) {
      calls++;
      image = invocation.positionalArguments[0] as ui.Image;
      transforms.addAll(invocation.positionalArguments[1] as Float32List);
      colors.addAll(invocation.positionalArguments[3] as Int32List);
      final paint = invocation.positionalArguments[6] as ui.Paint;
      expect(paint.colorFilter, isNull, reason: '색 보정은 atlas에 미리 굽는다');
      expect(paint.maskFilter, isNull);
    }
    expect(invocation.memberName, isNot(#saveLayer));
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MatchBoardRenderer> renderer() async {
    final game = MatchBoardGame();
    final board = game.board;
    board.setGeometry(x: 16, y: 16, tile: 48);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        board.setGem(
          r,
          c,
          board.createGem(
            r,
            c,
            c % 6 + 1,
            r < 7 ? GemKind.values[r] : GemKind.normal,
          ),
        );
      }
    }
    final result = MatchBoardRenderer(logic: board)..game = game;
    await result.onLoad();
    result.onMount();
    result.update(2); // 광택 위상 밖에서 원본과 비교
    return result;
  }

  Future<Uint8List> pixels(MatchBoardRenderer renderer) async {
    final recorder = ui.PictureRecorder();
    renderer.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(416, 416);
    final bytes = await image.toByteData();
    final result = Uint8List.fromList(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    return result;
  }

  Future<void> compare(MatchBoardRenderer renderer, String scenario) async {
    renderer.useGemBatching = true;
    final batched = await pixels(renderer);
    renderer.useGemBatching = false;
    final individual = await pixels(renderer);
    var sum = 0;
    for (var i = 0; i < batched.length; i++) {
      sum += (batched[i] - individual[i]).abs();
    }
    // 128px 원본→64px atlas→48px 화면의 이중 샘플링 오차는 허용하되
    // 색/크기/좌표/알파가 틀린 슬롯은 화면 전체 평균 오차로 검출한다.
    expect(sum / batched.length, lessThan(4), reason: scenario);
  }

  test(
    'real renderer batches 64 normal and legacy/action gems in one draw',
    () async {
      final r = await renderer();
      await pixels(r);
      expect(r.batchedGemCount, 64);
      expect(r.gemAtlasDrawCalls, 1);
      expect(r.individualGemDrawCalls, 0);
      await compare(r, 'normal, row, col, bomb, star, hyper, supernova');
      r.onRemove();
    },
  );

  test(
    'squash fallback preserves anchor and ordering alongside batched gems',
    () async {
      final r = await renderer();
      r.logic.getGem(2, 2)!.landT = 0.06;
      await pixels(r);
      expect(r.batchedGemCount, 63);
      expect(r.individualGemDrawCalls, 1);
      expect(r.gemAtlasDrawCalls, 2);
      await compare(r, 'nonuniform landing squash');
      r.onRemove();
    },
  );

  test(
    'removal alpha/rotation and special contraction retain drawing',
    () async {
      final r = await renderer();
      r.logic.state = 'removing';
      r.logic.pendingRemovalSet = {
        for (var row = 0; row < 7; row++) '$row:3': true,
      };
      for (final elapsed in [0.0, 0.035, 0.07, 0.10, 0.16]) {
        r.logic.stageTimer = MatchBoardLogic.removeDelay - elapsed;
        await compare(r, 'removal at $elapsed');
      }
      expect(r.logic.score, 0); // render가 규칙/점수를 변경하지 않음
      expect(r.logic.state, 'removing');
      r.onRemove();
    },
  );

  test('pop, selection, hint nudge preserve transforms', () async {
    final r = await renderer();
    r.logic.getGem(2, 2)!.popT = 0.08;
    r.logic.selectCell(4, 4);
    r.logic.showHint();
    r.update(0.2);
    await compare(r, 'spawn pop and selection/hint');
    r.onRemove();
  });

  test(
    'Canvas receives contraction then burst inside unchanged removal duration',
    () async {
      final r = await renderer();
      r.logic.resetCells();
      final gem = r.logic.createGem(0, 0, 1, GemKind.bomb);
      r.logic.setGem(0, 0, gem);
      r.logic.state = 'removing';
      r.logic.pendingRemovalSet = {'0:0': true};
      final scales = <double>[];
      final alphas = <int>[];
      for (final elapsed in [0.0, 0.035, 0.07, 0.0975, 0.17]) {
        r.logic.stageTimer = MatchBoardLogic.removeDelay - elapsed;
        final spy = AtlasSpy();
        r.render(spy);
        expect(spy.calls, 1);
        expect(spy.colors, hasLength(1));
        scales.add(
          math.sqrt(
                math.pow(spy.transforms[0], 2) + math.pow(spy.transforms[1], 2),
              ) /
              (48 / 64),
        );
        alphas.add((spy.colors.single >> 24) & 255);
        expect(r.logic.stageTimer, MatchBoardLogic.removeDelay - elapsed);
      }
      expect(scales[0], closeTo(1, 0.001));
      expect(scales[1], lessThan(scales[0]));
      expect(scales[2], closeTo(0.78, 0.001));
      expect(scales[3], closeTo(1.24, 0.001));
      expect(scales[4], lessThan(0.6));
      expect(alphas.first, 255);
      expect(alphas.last, lessThan(70));
      r.onRemove();
    },
  );

  test(
    'baked sheen keeps source alpha and cannot spill into neighboring tiles',
    () async {
      final r = await renderer();
      final spy = AtlasSpy();
      r.render(spy);
      final image = spy.image!;
      final bytes = (await image.toByteData())!.buffer.asUint8List();
      final width = image.width;
      var changed = 0;
      for (var phase = 0; phase < 6; phase++) {
        final slot = 42 + phase;
        final ox = slot % 8 * 64;
        final oy = slot ~/ 8 * 64;
        for (var y = 0; y < 64; y++) {
          for (var x = 0; x < 64; x++) {
            final base = (y * width + x) * 4;
            final shine = ((oy + y) * width + ox + x) * 4;
            // srcATop의 8bit premultiplied 합성 반올림은 1단계 허용.
            // 완전 투명한 셀 바깥은 정확히 투명을 유지해야 한다.
            expect(
              bytes[shine + 3],
              bytes[base + 3] == 0 ? equals(0) : closeTo(bytes[base + 3], 1),
            );
            if (bytes[shine] != bytes[base]) changed++;
          }
        }
      }
      expect(changed, greaterThan(100));
      r.onRemove();
    },
  );

  test(
    'atlas and chrome survive onRemove then onMount with same sources',
    () async {
      final r = await renderer();
      final before = await pixels(r);
      r.onRemove();
      expect(r.hasGemAtlas, isFalse);
      r.onMount();
      expect(r.hasGemAtlas, isTrue);
      final after = await pixels(r);
      expect(after, orderedEquals(before));
      expect(r.gemAtlasDrawCalls, 1);
      r.onRemove();
    },
  );
}
