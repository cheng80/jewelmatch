import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/services/telemetry_policy.dart';

void main() {
  group('환경 결정', () {
    TelemetryEnv env(String define, {bool release = false, bool qa = false}) =>
        TelemetryPolicy.resolveEnv(
          define: define,
          release: release,
          qaActive: qa,
        );

    test('정의가 없으면 release는 production, 그 밖은 development', () {
      expect(env('', release: true), TelemetryEnv.production);
      expect(env(''), TelemetryEnv.development);
    });

    test('명시 정의는 대소문자와 공백을 무시하고 따른다', () {
      expect(env('production'), TelemetryEnv.production);
      expect(env(' QA '), TelemetryEnv.qa);
      expect(env('Development', release: true), TelemetryEnv.development);
    });

    test('알 수 없는 값은 release에서도 production이 되지 않는다', () {
      for (final bad in ['prod', 'PRODUCTIO', 'staging', 'test', 'null']) {
        expect(env(bad, release: true), TelemetryEnv.development, reason: bad);
        expect(env(bad), TelemetryEnv.development, reason: bad);
      }
    });

    test('QA 스위치는 production 정의와 release도 qa로 덮는다', () {
      expect(env('production', release: true, qa: true), TelemetryEnv.qa);
      expect(env('', release: true, qa: true), TelemetryEnv.qa);
      expect(env('bogus', qa: true), TelemetryEnv.qa);
    });

    test('test 환경은 생성자로만 주입한다', () {
      expect(
        const TelemetryPolicy(env: TelemetryEnv.test).env,
        TelemetryEnv.test,
      );
      expect(
        TelemetryPolicy.fromBuild(
          envDefine: 'test',
          release: true,
          qaActive: false,
        ).env,
        TelemetryEnv.development,
      );
    });

    test('fromBuild는 주입한 값으로 결정한다', () {
      final policy = TelemetryPolicy.fromBuild(
        envDefine: 'production',
        release: false,
        qaActive: false,
      );
      expect(policy.env, TelemetryEnv.production);
      expect(policy.sampleRate, 0.1);
      expect(policy.maxSampledEvents, 40);
    });
  });

  group('QA 스위치 감지', () {
    test('실제 query 스위치가 1이면 켜진다', () {
      for (final key in [
        'qaPerf',
        'qaSixRewards',
        'qaVfx',
        'qaLevelUp',
        'qaNoMoves',
      ]) {
        expect(
          TelemetryPolicy.isQaActive(query: {key: '1'}, defines: false),
          isTrue,
          reason: key,
        );
      }
    });

    test('값이 1이 아니거나 QA가 아닌 query는 무시한다', () {
      expect(
        TelemetryPolicy.isQaActive(
          query: {
            'qaPerf': '0',
            'qaVfx': '',
            'fps': '1',
            'mode': 'qa',
            'exp': '1',
          },
          defines: false,
        ),
        isFalse,
      );
      expect(TelemetryPolicy.isQaActive(query: {}, defines: false), isFalse);
    });

    test('기본 hash 라우팅의 fragment query도 QA로 본다', () {
      bool qa(String url) =>
          TelemetryPolicy.isQaActive(uri: Uri.parse(url), defines: false);

      expect(qa('https://x.test/#/game?qaNoMoves=1'), isTrue);
      expect(qa('https://x.test/#/game?mode=timed&qaVfx=1'), isTrue);
      expect(qa('https://x.test/?qaPerf=1#/'), isTrue);
      expect(qa('https://x.test/game?qaSixRewards=1'), isTrue);
      expect(qa('https://x.test/#/game?qaNoMoves=0'), isFalse);
      expect(qa('https://x.test/#/game?mode=timed'), isFalse);
      expect(qa('https://x.test/#/qaNoMoves=1'), isFalse);
      expect(qa('https://x.test/#/game?a=%zz'), isFalse);
      expect(qa('https://x.test/'), isFalse);
    });

    test('fromBuild는 qaActive를 주면 고정하고 안 주면 probe를 기본으로 쓴다', () {
      final fixed = TelemetryPolicy.fromBuild(
        envDefine: 'production',
        release: true,
        qaActive: false,
      );
      expect(fixed.qaProbe, isNull);
      expect(fixed.env, TelemetryEnv.production);
      expect(
        TelemetryPolicy.fromBuild(
          envDefine: 'production',
          release: true,
        ).qaProbe,
        isNotNull,
      );
      expect(
        TelemetryPolicy.fromBuild(qaActive: true, release: true).env,
        TelemetryEnv.qa,
      );
    });

    test('QA 빌드 정의가 켜져 있으면 query와 무관하게 켜진다', () {
      expect(TelemetryPolicy.isQaActive(query: {}, defines: true), isTrue);
    });

    test('정의 없는 테스트 빌드에서는 꺼져 있다', () {
      expect(TelemetryPolicy.isQaActive(), isFalse);
    });
  });

  group('표본', () {
    test('FNV-1a 해시가 알려진 값과 같다(JS와 VM 공통)', () {
      expect(TelemetryPolicy.fnv1a32(''), 0x811c9dc5);
      expect(TelemetryPolicy.fnv1a32('a'), 0xe40c292c);
      expect(TelemetryPolicy.fnv1a32('foobar'), 0xbf9cf968);
      expect(
        TelemetryPolicy.fnv1a32('\u{1F48E}'),
        inInclusiveRange(0, 0xFFFFFFFF),
      );
    });

    test('같은 세션 ID는 언제나 같은 결과이고 비율에 수렴한다', () {
      const policy = TelemetryPolicy();
      var hits = 0;
      for (var i = 0; i < 10000; i++) {
        final id = 'session-$i';
        final first = policy.isSessionSampled(id);
        expect(policy.isSessionSampled(id), first);
        if (first) hits++;
      }
      expect(hits, inInclusiveRange(800, 1200));
    });

    test('비율 0은 아무도 뽑지 않고 1은 모두 뽑으며 범위 밖 값은 잘린다', () {
      const none = TelemetryPolicy(sampleRate: 0);
      const all = TelemetryPolicy(sampleRate: 1);
      for (var i = 0; i < 200; i++) {
        expect(none.isSessionSampled('s$i'), isFalse);
        expect(all.isSessionSampled('s$i'), isTrue);
      }
      expect(
        const TelemetryPolicy(
          sampleRate: 5,
        ).rateFor(TelemetryCollection.sampled),
        1.0,
      );
      expect(
        const TelemetryPolicy(
          sampleRate: -1,
        ).rateFor(TelemetryCollection.sampled),
        0.0,
      );
      expect(
        TelemetryPolicy(sampleRate: double.nan).isSessionSampled('x'),
        isFalse,
      );
    });

    test('sessionSampled 주입은 해시보다 우선한다', () {
      expect(
        const TelemetryPolicy(sessionSampled: true).isSessionSampled('a'),
        isTrue,
      );
      expect(
        const TelemetryPolicy(
          sampleRate: 1,
          sessionSampled: false,
        ).isSessionSampled('a'),
        isFalse,
      );
    });

    test('full 이벤트의 sample_rate는 항상 1.0이다', () {
      const policy = TelemetryPolicy();
      expect(policy.rateFor(TelemetryCollection.full), 1.0);
      expect(policy.rateFor(TelemetryCollection.sampled), 0.1);
    });
  });
}
