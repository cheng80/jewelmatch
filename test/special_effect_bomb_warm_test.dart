import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/components/special_effect_burst.dart';
import 'package:stonematch/game/components/special_effect_pool.dart';

/// 첫 발동 때 끊기지 않으려면 워밍업이 끝난 시점에 bomb 아틀라스도 준비돼야 한다.
/// 정적 캐시를 공유하므로 이 파일은 워밍업 경로만 본다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preload 경로가 bomb 레이어 아틀라스까지 끝낸다', () async {
    expect(SpecialEffectBurst.debugBombLayerAtlasReady, isFalse);
    await SpecialEffectBurst.preloadAreaEffectSprites();
    expect(SpecialEffectBurst.debugBombLayerAtlasReady, isTrue);
  });

  test('pool.warm이 끝나면 아틀라스도 준비돼 있다', () async {
    final parent = Component();
    await parent.onLoad();
    final pool = SpecialEffectPool(parent, constrainedDevice: false);
    await pool.warm(burstCount: 2);
    expect(SpecialEffectBurst.debugBombLayerAtlasReady, isTrue);
    pool.clear();
  });
}
