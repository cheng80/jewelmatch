import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';
import 'package:stonematch/services/backend/backend_gateway.dart';
import 'package:stonematch/services/error_reporter.dart';
import 'package:stonematch/services/play_event_context.dart';
import 'package:stonematch/services/telemetry_policy.dart';

const _prodDsn = 'https://prodkey@o1.ingest.sentry.io/1';
const _testDsn = 'https://testkey@o1.ingest.sentry.io/2';

/// 실제 envelope 바이트를 모아 JSON 이벤트로 돌려준다.
class _Transport implements Transport {
  _Transport({this.fail = false});
  final bool fail;
  final List<Map<String, dynamic>> events = [];
  final List<String> raw = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bytes = <int>[];
    await for (final chunk in envelope.envelopeStream(SentryOptions())) {
      bytes.addAll(chunk);
    }
    final text = utf8.decode(bytes);
    raw.add(text);
    final lines = text.split('\n');
    for (var i = 1; i + 1 < lines.length; i += 2) {
      if ((jsonDecode(lines[i]) as Map)['type'] == 'event') {
        events.add(jsonDecode(lines[i + 1]) as Map<String, dynamic>);
      }
    }
    if (fail) throw http.ClientException('offline');
    return envelope.header.eventId;
  }
}

var _clock = DateTime.utc(2026, 9, 29, 12);

ErrorReporter _reporter(
  _Transport transport, {
  TelemetryEnv env = TelemetryEnv.production,
  bool Function()? qa,
  String prodDsn = _prodDsn,
  String testDsn = _testDsn,
  Map<String, String> debugIds = const {},
}) => ErrorReporter(
  productionDsn: prodDsn,
  testDsn: testDsn,
  release: 'stonematch@1.0.0+1',
  policy: TelemetryPolicy(env: env, qaProbe: qa ?? () => false),
  channel: 'intoss',
  transport: transport,
  debugIds: () => debugIds,
  now: () => _clock,
);

StackTrace _stack(String where) => StackTrace.fromString(
  '#0      $where (package:stonematch/game/x.dart:10:5)\n'
  '#1      main (package:stonematch/main.dart:3:1)\n',
);

/// FlutterError 훅을 설치하는 run 테스트용. 테스트 프레임워크 훅을 돌려놓는다.
void _isolateFlutterErrorHook() {
  final saved = FlutterError.onError;
  addTearDown(() => FlutterError.onError = saved);
  FlutterError.onError = (_) {};
}

void main() {
  setUp(() => _clock = DateTime.utc(2026, 9, 29, 12));
  tearDown(Sentry.close);

  test('정제한 envelope: 종류와 스택, 허용 문맥만 보낸다', () async {
    final transport = _Transport();
    final reporter = _reporter(
      transport,
      debugIds: {
        'Error\n    at https://stonematch.example/match/main.dart.js?v=1:1:10':
            'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      },
    );
    expect(await reporter.init(), isTrue);
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: 'player-1', email: 'me@mail.com'));
      scope.setTag('device_id', 'dev-secret');
      scope.setContexts('extra_ctx', {'token': 'tok-secret'});
    });
    final run = PlayEventContext.startRun();
    reporter.noteEvent('round_start', {
      'mode': 'progression',
      'exp': 't1,c7:5',
      'player_name': 'NAME-SECRET',
      'query': 'q=QUERY-SECRET',
    }, run);
    reporter.noteEvent('round_end', {'level': 7, 'score': 999}, run);
    reporter.noteEvent('Bad Name me@mail.com', const {}, null);

    reporter.report(
      StateError('token=tok-secret email me@mail.com NAME-SECRET'),
      _stack('boom'),
      mechanism: 'runZonedGuarded',
    );
    await pumpEventQueue();

    expect(transport.events, hasLength(1));
    final raw = transport.raw.single;
    for (final secret in [
      'tok-secret',
      'me@mail.com',
      'player-1',
      'dev-secret',
      'NAME-SECRET',
      'QUERY-SECRET',
      'player_name',
      // 숫자 999는 임의 event_id에도 나타날 수 있으므로 필드로 검사한다.
      '"score"',
    ]) {
      expect(raw, isNot(contains(secret)), reason: secret);
    }
    final event = transport.events.single;
    for (final key in ['user', 'request', 'extra', 'message', 'breadcrumbs']) {
      expect(event.containsKey(key), isFalse, reason: key);
    }
    expect(event['environment'], 'production');
    expect(event['release'], 'stonematch@1.0.0+1');
    expect(event['tags'], {'channel': 'intoss', 'runtime': 'native'});
    expect(event['sdk']['settings'], {'infer_ip': 'never'});
    final exception = event['exception']['values'].single as Map;
    expect(exception['type'], 'StateError');
    expect(exception.containsKey('value'), isFalse);
    expect(exception['mechanism'], {
      'type': 'runZonedGuarded',
      'handled': false,
    });
    expect(exception['stacktrace']['frames'], hasLength(2));
    expect((event['contexts'] as Map).keys, ['game']);
    final game = event['contexts']['game'] as Map;
    expect(game['run_id'], run.runId);
    expect(game['round_seq'], 1);
    expect(game['attempt_seq'], 0);
    expect(game['mode'], 'progression');
    expect(game['level'], 7);
    expect(game['exp'], 't1,c7:5');
    expect(game['recent'], [
      {'name': 'round_start', 'at': '2026-09-29T12:00:00.000Z'},
      {'name': 'round_end', 'at': '2026-09-29T12:00:00.000Z'},
    ]);
    // SDK 웹 프레임 abs_path처럼 하위 경로(/match/)와 query 없이 출처 + 파일 이름으로 맞춘다.
    expect(event['debug_meta']['images'], [
      {
        'type': 'sourcemap',
        'debug_id': 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        'code_file': 'https://stonematch.example/main.dart.js',
      },
    ]);
  });

  test('sanitize: 프레임 원문 필드, URL query, 요청, 사용자를 옮기지 않는다', () async {
    final reporter = _reporter(_Transport());
    await reporter.init();
    final event = SentryEvent(
      message: SentryMessage('message me@mail.com'),
      user: SentryUser(id: 'player-1'),
      request: SentryRequest(url: 'https://x.example/?token=tok-secret'),
      serverName: 'my-host',
      tags: {'device_id': 'dev-secret'},
      exceptions: [
        SentryException(
          type: 'StateError',
          value: 'secret value',
          module: 'secret.module',
          stackTrace: SentryStackTrace(
            frames: [
              SentryStackFrame(
                function: 'handler',
                absPath:
                    'https://user:pass@stonematch.example/main.dart.js?token=tok-secret#frag',
                fileName: 'main.dart.js?q=QUERY-SECRET',
                lineNo: 1,
                colNo: 2,
                contextLine: 'NAME-SECRET',
                preContext: ['NAME-SECRET'],
                postContext: ['NAME-SECRET'],
                vars: {'token': 'tok-secret'},
                platform: 'javascript',
              ),
              SentryStackFrame(function: 'TypeError: me@mail.com unparsed'),
            ],
          ),
          mechanism: Mechanism(
            type: 'onerror',
            handled: false,
            data: {'secret': 'tok-secret'},
            description: 'NAME-SECRET',
          ),
        ),
      ],
      debugMeta: DebugMeta(
        images: [
          DebugImage(
            type: 'elf',
            debugId: 'dbg',
            codeFile: '/home/secret-user/app.so',
          ),
        ],
      ),
    );
    final clean = reporter.sanitize(
      event,
      Hint.withMap({'stone_match_type': ErrorReporter.jsErrorType('Custom')}),
    )!;
    final json = jsonEncode(clean.toJson());
    for (final secret in [
      'me@mail.com',
      'player-1',
      'tok-secret',
      'my-host',
      'dev-secret',
      'secret value',
      'secret.module',
      'user:pass',
      'QUERY-SECRET',
      'NAME-SECRET',
      'frag',
      'secret-user',
    ]) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    final exception = clean.exceptions!.single;
    expect(exception.type, 'JsError');
    final frame = exception.stackTrace!.frames.single;
    expect(frame.absPath, 'https://stonematch.example/main.dart.js');
    expect(frame.fileName, 'main.dart.js');
    expect(frame.lineNo, 1);
    expect(clean.debugMeta!.images.single.debugId, 'dbg');
    expect(ErrorReporter.jsErrorType('TypeError'), 'TypeError');
    expect(ErrorReporter.jsErrorType(null), 'JsError');
  });

  test('같은 오류는 5초 안에 한 번, 세션 상한까지만, 정상 실패는 보내지 않는다', () async {
    final transport = _Transport();
    final reporter = _reporter(transport);
    await reporter.init();
    final error = StateError('x');
    reporter.report(error, _stack('a'), mechanism: 'zone');
    reporter.report(error, _stack('a'), mechanism: 'FlutterError');
    reporter.report(StateError('y'), _stack('a'), mechanism: 'zone');
    reporter.report(http.ClientException('down'), _stack('n'), mechanism: 'z');
    reporter.report(TimeoutException('slow'), _stack('t'), mechanism: 'z');
    reporter.report(BackendFailure.network, _stack('b'), mechanism: 'z');
    reporter.report(BackendFailure.server, _stack('b'), mechanism: 'z');
    await pumpEventQueue();
    expect(transport.events, hasLength(1));

    // 같은 예외 객체는 SDK 중복 제거가 다시 막으므로 같은 종류와 위치의 새 오류로 확인한다.
    _clock = _clock.add(ErrorReporter.repeatWindow);
    reporter.report(StateError('x'), _stack('a'), mechanism: 'zone');
    await pumpEventQueue();
    expect(transport.events, hasLength(2));

    for (var i = 0; i < ErrorReporter.maxEvents + 5; i++) {
      reporter.report(StateError('$i'), _stack('f$i'), mechanism: 'zone');
    }
    await pumpEventQueue();
    expect(transport.events, hasLength(ErrorReporter.maxEvents));
  });

  test('QA 분리: 운영 빌드도 QA면 테스트 DSN, 늦게 켜진 QA는 운영으로 보내지 않는다', () async {
    final qaTransport = _Transport();
    final qaStart = _reporter(qaTransport, qa: () => true);
    expect(await qaStart.init(), isTrue);
    qaStart.report(StateError('q'), _stack('q'), mechanism: 'zone');
    await pumpEventQueue();
    expect(qaTransport.events.single['environment'], 'qa');
    expect(qaTransport.raw.single, contains('testkey'));
    expect(qaTransport.raw.single, isNot(contains('prodkey')));
    await Sentry.close();

    var qa = false;
    final late = _Transport();
    final lateReporter = _reporter(late, qa: () => qa);
    expect(await lateReporter.init(), isTrue);
    qa = true;
    lateReporter.report(StateError('l'), _stack('l'), mechanism: 'zone');
    await pumpEventQueue();
    expect(late.events, isEmpty);
  });

  test('운영이 아니면 SENTRY_TEST_DSN 없이는 켜지지 않는다', () async {
    final transport = _Transport();
    final dev = _reporter(
      transport,
      env: TelemetryEnv.development,
      testDsn: '',
    );
    expect(await dev.init(), isFalse);
    dev.report(StateError('d'), _stack('d'), mechanism: 'zone');
    final ran = <bool>[];
    await dev.run(() async => ran.add(true));
    await pumpEventQueue();
    expect(ran, [true]);
    expect(transport.events, isEmpty);

    final withTest = _reporter(transport, env: TelemetryEnv.development);
    expect(await withTest.init(), isTrue);
    withTest.report(StateError('t'), _stack('t'), mechanism: 'zone');
    await pumpEventQueue();
    expect(transport.events.single['environment'], 'development');
    expect(transport.raw.single, contains('testkey'));
  });

  test('초기화 실패와 전송 실패: 본문은 한 번 실행되고 예외가 밖으로 나오지 않는다', () async {
    _isolateFlutterErrorHook();
    // 프로젝트 ID가 없어 SDK 초기화가 실패하는 DSN.
    final transport = _Transport();
    final bad = _reporter(
      transport,
      prodDsn: 'https://key@o1.ingest.sentry.io',
    );
    var ran = 0;
    await bad.run(() async {
      ran++;
      throw StateError('startup');
    });
    await pumpEventQueue();
    expect(ran, 1);
    expect(await bad.init(), isFalse);
    expect(transport.events, isEmpty);

    final failing = _Transport(fail: true);
    final reporter = _reporter(failing);
    expect(await reporter.init(), isTrue);
    reporter.report(StateError('f'), _stack('f'), mechanism: 'zone');
    await pumpEventQueue();
    expect(failing.events, hasLength(1));
  });

  test('run: 초기화를 기다리지 않고 본문을 실행, 초기화 중 오류도 보내며 훅과 init은 한 번', () async {
    _isolateFlutterErrorHook();
    final transport = _Transport();
    final reporter = _reporter(transport);
    bool? enabledWhenBodyStarted;
    await reporter.run(() async {
      enabledWhenBodyStarted = reporter.enabled;
      unawaited(Future<void>(() => throw StateError('async')));
      final framework = FlutterErrorDetails(
        exception: ArgumentError('fw'),
        stack: _stack('build'),
      );
      FlutterError.reportError(framework);
      FlutterError.reportError(framework);
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('image'), silent: true),
      );
    });
    await pumpEventQueue();
    expect(enabledWhenBodyStarted, isFalse);
    final mechanisms = [
      for (final e in transport.events)
        e['exception']['values'].single['mechanism']['type'],
    ];
    expect(mechanisms..sort(), ['FlutterError', 'runZonedGuarded']);

    final hook = FlutterError.onError;
    await reporter.run(() async {});
    expect(FlutterError.onError, same(hook));
    expect(reporter.init(), same(reporter.init()));
  });

  test('최근 이벤트는 20건까지만, 새 run이면 판 문맥을 바꾼다', () async {
    final transport = _Transport();
    final reporter = _reporter(transport);
    await reporter.init();
    final first = PlayEventContext.startRun();
    reporter.noteEvent('round_end', {'level': 3, 'mode': 'progression'}, first);
    for (var i = 0; i < 25; i++) {
      reporter.noteEvent('e$i', const {}, null);
    }
    final second = PlayEventContext.startRun();
    reporter.noteEvent('round_start', {
      'mode': 'timed',
      'level': -1,
      'exp': 'bad value!',
    }, second);
    reporter.report(StateError('r'), _stack('r'), mechanism: 'zone');
    await pumpEventQueue();
    final game = transport.events.single['contexts']['game'] as Map;
    final recent = game['recent'] as List;
    expect(recent, hasLength(ErrorReporter.maxRecent));
    expect(recent.first['name'], 'e6');
    expect(recent.last['name'], 'round_start');
    expect(game['run_id'], second.runId);
    expect(game['mode'], 'timed');
    expect(game.containsKey('level'), isFalse);
    expect(game.containsKey('exp'), isFalse);
  });

  test('JS 오류 경로: 서로 다른 오류는 모두 전송한다(SDK 중복 제거가 같은 인스턴스를 버린다)', () async {
    final transport = _Transport();
    final reporter = _reporter(transport);
    expect(await reporter.init(), isTrue);
    for (var i = 1; i <= 3; i++) {
      _clock = _clock.add(const Duration(seconds: 10));
      reporter.reportJsError(
        'TypeError',
        'TypeError: message $i\n    at f$i (https://h.example/match/main.dart.js:$i:5)',
      );
      await pumpEventQueue();
    }
    expect(transport.events, hasLength(3));
    final functions = [
      for (final e in transport.events)
        e['exception']['values']
            .single['stacktrace']['frames']
            .single['function'],
    ];
    expect(functions, ['f1', 'f2', 'f3']);
  });

  test('JS 오류 경로: 프레임이 한 줄인 V8와 Firefox 스택도 프레임이 남고 메시지는 보내지 않는다', () async {
    final transport = _Transport();
    final reporter = _reporter(transport);
    expect(await reporter.init(), isTrue);
    reporter.reportJsError(
      'Error',
      'Error: SECRET-MESSAGE\n    at https://h.example/match/main.dart.js?t=QSECRET:9:5',
    );
    reporter.reportJsError(
      'Error',
      'g@https://h.example/match/main.dart.js:7:3',
    );
    await pumpEventQueue();
    expect(transport.events, hasLength(2));
    for (final e in transport.events) {
      expect(
        e['exception']['values'].single['stacktrace']['frames'],
        hasLength(1),
      );
    }
    for (final secret in ['SECRET-MESSAGE', 'QSECRET']) {
      expect(transport.raw.join(), isNot(contains(secret)), reason: secret);
    }
  });

  test('JS 스택은 프레임 줄만 남긴다', () {
    const stack =
        'TypeError: Cannot read me@mail.com\n'
        'second message line\n'
        '    at Object.a (https://stonematch.example/main.dart.js:1:20)\n'
        '    at https://stonematch.example/main.dart.js:2:30\n'
        'b@https://stonematch.example/main.dart.js:3:40\n'
        'global code@https://stonematch.example/main.dart.js:4:50';
    expect(
      ErrorReporter.jsFrameLines(stack),
      '    at Object.a (https://stonematch.example/main.dart.js:1:20)\n'
      '    at https://stonematch.example/main.dart.js:2:30\n'
      'b@https://stonematch.example/main.dart.js:3:40\n'
      'global code@https://stonematch.example/main.dart.js:4:50',
    );
  });
}
