import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stonematch/game/components/match_game_hud.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';
import 'package:stonematch/game/jewel_game_mode.dart';
import 'package:stonematch/game/match_board_game.dart';
import 'package:stonematch/utils/storage_helper.dart';

/// 이미지 그리기 호출과 서로 다른 텍스처 수를 세는 캔버스 스파이.
class ImageDrawSpy implements ui.Canvas {
  static const _imageDraws = {
    #drawImage,
    #drawImageRect,
    #drawImageNine,
    #drawAtlas,
    #drawRawAtlas,
  };
  final counts = <Symbol, int>{};
  final images = <ui.Image>{};
  ui.Image? _last;

  /// 바로 앞 이미지 그리기와 다른 텍스처로 바뀐 횟수(첫 그리기 포함).
  int textureSwitches = 0;

  int get imageDrawCalls => counts.values.fold(0, (a, b) => a + b);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName;
    if (_imageDraws.contains(name)) {
      counts[name] = (counts[name] ?? 0) + 1;
      final image = invocation.positionalArguments[0] as ui.Image;
      images.add(image);
      if (!identical(image, _last)) textureSwitches++;
      _last = image;
    }
    return null;
  }

  String describe() {
    String n(Symbol s) => '${counts[s] ?? 0}';
    return 'imageDraws=$imageDrawCalls textures=${images.length} '
        'switches=$textureSwitches '
        'drawImage=${n(#drawImage)} drawImageRect=${n(#drawImageRect)} '
        'drawImageNine=${n(#drawImageNine)} drawAtlas=${n(#drawAtlas)} '
        'drawRawAtlas=${n(#drawRawAtlas)}';
  }
}

Future<(MatchBoardGame, MatchGameHud)> loadedHud(JewelGameMode mode) async {
  final g = MatchBoardGame(gameMode: mode);
  g.overlays.addEntry('IntroBlock', (_, _) => const SizedBox());
  g.onGameResize(Vector2(390, 750));
  g.board.introFillInProgress = false;
  g.board.state = 'idle';
  final h = MatchGameHud(
    onPausePressed: () {},
    onHintPressed: g.requestHint,
    onTutorialPressed: () {},
    onRankingPressed: mode == JewelGameMode.timed ? () {} : null,
  )..game = g;
  await h.onLoad();
  h.onGameResize(g.size);
  h.update(0);
  return (g, h);
}

ImageDrawSpy measure(MatchGameHud hud) {
  final spy = ImageDrawSpy();
  hud.render(spy);
  return spy;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageHelper.init();
  });

  test('timed HUD frame: 4 buttons, top ranker crown, score', () async {
    final (g, h) = await loadedHud(JewelGameMode.timed);
    g.rankingTop1Name = 'Ruby';
    g.rankingTop1Score = 12345;
    h.onGameResize(g.size);
    h.update(0);
    final spy = measure(h);
    // ignore: avoid_print
    print('[draw-calls] timed ${spy.describe()}');
    // 기준(e37bbf3): 그리기 11회, 텍스처 6장, 전환 10번.
    // ui atlas 한 장 + 콤보와 타임바 글로우 atlas 한 장.
    expect(spy.images, hasLength(2));
    expect(spy.imageDrawCalls, 11);
    expect(spy.textureSwitches, 3);
  });

  test(
    'level HUD frame: 4 item slots with icons, prism color picker',
    () async {
      final (g, h) = await loadedHud(JewelGameMode.progression);
      for (final item in ItemKind.values) {
        g.runInventory.add(item, 2);
      }
      g.stageLoadout = StageLoadout.fromOpenItems([
        ItemKind.runeHammer,
        ItemKind.ancientBomb,
        ItemKind.thorHammer,
        ItemKind.prismTransform,
      ], openSlotCount: 4);
      g.activeTargetItem = ItemKind.prismTransform;
      h.onGameResize(g.size);
      h.update(0);
      expect(g.isPrismColorPicking, isTrue);
      final spy = measure(h);
      // ignore: avoid_print
      print('[draw-calls] level ${spy.describe()}');
      // 기준(e37bbf3): 그리기 24회, 텍스처 11장, 전환 18번.
      // ui atlas + 보석 텍스처 + HUD 글로우 atlas.
      expect(spy.images, hasLength(3));
      // 나인패치가 drawImageNine 1회에서 같은 텍스처 drawImageRect 9회로 는다.
      expect(spy.imageDrawCalls, 32);
      expect(spy.textureSwitches, 7);
    },
  );
}
