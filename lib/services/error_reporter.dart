import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:sentry/sentry.dart';

import '../app_config.dart';
import 'backend/backend_gateway.dart';
import 'error_reporter_stub.dart'
    if (dart.library.js_interop) 'error_reporter_web.dart';
import 'play_event_context.dart';
import 'telemetry_policy.dart';

/// 처리되지 않은 오류 수집(PLAN-012). 게임 코드는 Sentry가 아니라 이 클래스만 부른다.
///
/// - 순수 Dart `sentry` SDK만 쓴다. JS SDK를 싣지 않으므로 전송 전 정제([sanitize])를 우회하는 경로가 없다.
///   tracing, profiling, replay, 세션 추적, breadcrumb는 쓰지 않는다.
/// - 보낼 곳: TELEMETRY_ENV가 production이고 QA 스위치가 꺼졌을 때만 `SENTRY_DSN`.
///   그 밖에는 `SENTRY_TEST_DSN`이며 없으면 아예 켜지 않는다. 운영 DSN으로 시작한 뒤 QA가 켜지면 그 뒤 오류는 버린다.
/// - 수집: zone(비동기 포함), FlutterError(silent 제외), 웹 창의 JS 오류.
///   네트워크 실패, 시간 초과, BackendFailure는 정상 실패로 보고 보내지 않는다.
/// - 보내는 것: 오류 종류, 스택 프레임, release, environment, channel, runtime, 최근 내부 이벤트 이름과 시각 20건,
///   run_id, round_seq, attempt_seq, mode, level, exp. 오류 메시지, 사용자, 요청, 기기 문맥, 이벤트 params는 보내지 않는다.
/// - 같은 종류와 위치의 오류는 [repeatWindow] 안에 한 번, 세션 전체 [maxEvents]건까지만 보낸다.
/// - 게임 시작은 SDK 초기화를 기다리지 않는다. 초기화 중 오류는 초기화 결과를 기다렸다 보내거나 버린다.
///   초기화와 전송 실패는 게임에 예외를 던지지 않는다.
class ErrorReporter {
  ErrorReporter({
    this.productionDsn = const String.fromEnvironment('SENTRY_DSN'),
    this.testDsn = const String.fromEnvironment('SENTRY_TEST_DSN'),
    this.release = const String.fromEnvironment('SENTRY_RELEASE'),
    TelemetryPolicy? policy,
    String? channel,
    this.transport,
    Map<String, String> Function()? debugIds,
    DateTime Function()? now,
  }) : policy = policy ?? TelemetryPolicy.fromBuild(),
       channel = channel ?? AppConfig.storeChannel.name,
       _readDebugIds = debugIds ?? readSentryDebugIds,
       _now = now ?? DateTime.now;

  static final ErrorReporter instance = ErrorReporter();

  static const int maxRecent = 20;
  static const int maxEvents = 20;
  static const Duration repeatWindow = Duration(seconds: 5);
  static const String runtime = kIsWeb
      ? (bool.fromEnvironment('dart.tool.dart2wasm') ? 'wasm' : 'js')
      : 'native';

  final String productionDsn;
  final String testDsn;
  final String release;
  final TelemetryPolicy policy;
  final String channel;

  /// 테스트에서 실제 전송 대신 envelope를 받는다.
  final Transport? transport;
  final Map<String, String> Function() _readDebugIds;
  final DateTime Function() _now;

  final ListQueue<Map<String, String>> _recent = ListQueue();
  final Map<String, Object> _play = {};
  final Map<String, DateTime> _lastSent = {};
  Future<bool>? _ready;
  int _sent = 0;
  bool _enabled = false;
  bool _hooked = false;
  bool _production = false;
  bool _qa = false;
  bool _reporting = false;
  List<DebugImage>? _sourceMaps;

  static const String _typeHint = 'stone_match_type';
  static const Set<String> _jsNames = {
    'Error',
    'TypeError',
    'RangeError',
    'SyntaxError',
    'ReferenceError',
    'EvalError',
    'URIError',
    'AggregateError',
    'InternalError',
  };
  static final RegExp _eventName = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
  static final RegExp _token = RegExp(r'^[A-Za-z0-9_:,]{1,48}$');
  static final RegExp _jsFrame = RegExp(
    r'^\s+at \S.*$|^[^@\n]*@https?://\S+:\d+:\d+$',
    multiLine: true,
  );
  static final RegExp _url = RegExp(r'https?://[^\s()]+?(?=:\d+:\d+)');
  static final RegExp _userInfo = RegExp(
    r'^([a-z][a-z0-9+.-]*://)[^/@]*@',
    caseSensitive: false,
  );

  bool get enabled => _enabled;

  /// QA 스위치는 라우트로 늦게 켜질 수 있다. 한 번 켜지면 세션 끝까지 유지한다.
  bool _qaNow() {
    if (!_qa) {
      try {
        _qa = policy.qaProbe?.call() ?? false;
      } catch (_) {}
    }
    return _qa;
  }

  ({String dsn, bool production})? _target() {
    final production = policy.env == TelemetryEnv.production && !_qaNow();
    final dsn = production ? productionDsn : testDsn;
    return dsn.isEmpty ? null : (dsn: dsn, production: production);
  }

  /// main 본문을 오류 수집 zone에서 곧바로 실행하고 SDK는 뒤에서 켠다.
  /// 보낼 곳이 없으면 zone 없이 그대로 실행한다.
  Future<void> run(Future<void> Function() body) async {
    if (_target() == null) return body();
    runZonedGuarded(
      () {
        unawaited(init());
        _installHooks();
        return body();
      },
      (error, stack) {
        report(error, stack, mechanism: 'runZonedGuarded');
        debugPrint('Uncaught $error\n$stack');
      },
    );
  }

  /// SDK를 한 번만 켠다. 보낼 곳이 없거나 실패하면 false이며 예외를 던지지 않는다.
  Future<bool> init() => _ready ??= _init();

  Future<bool> _init() async {
    final target = _target();
    if (target == null) return false;
    _production = target.production;
    try {
      await Sentry.init((o) {
        o.dsn = target.dsn;
        o.environment = _qa ? TelemetryEnv.qa.name : policy.env.name;
        o.release = release.isEmpty ? null : release;
        o.sendDefaultPii = false;
        o.maxBreadcrumbs = 0;
        o.enableMetrics = false;
        o.beforeSend = (event, hint) => sanitize(event, hint);
        final fake = transport;
        if (fake != null) o.transport = fake;
      }).timeout(const Duration(seconds: 3));
      _enabled = Sentry.isEnabled;
    } catch (_) {
      _enabled = false;
    }
    return _enabled;
  }

  void _installHooks() {
    if (_hooked) return;
    _hooked = true;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.silent) {
        report(details.exception, details.stack, mechanism: 'FlutterError');
      }
      previous?.call(details);
    };
    listenJsErrors(reportJsError);
  }

  /// 웹 창의 JS 오류 한 건. 자리표시는 const로 만들지 않는다. SDK의 중복 제거가 throwable.hashCode로 최근 5건을
  /// 비교하므로 같은 인스턴스를 재사용하면 두 번째 JS 오류부터 조용히 버려진다.
  @visibleForTesting
  void reportJsError(String? name, String stack) {
    final frames = jsFrameLines(stack);
    if (frames.isEmpty) return;
    report(
      _JsError(),
      // stack_trace의 V8 형식 판별은 "\n    at "이 있어야 한다. 프레임이 한 줄이면 머리줄이 없어 판별에 실패한다.
      StackTrace.fromString('Error\n$frames'),
      mechanism: 'onerror',
      type: jsErrorType(name),
    );
  }

  /// JS error.name은 자유형이라 표준 오류 이름만 그대로 쓰고 나머지는 JsError로 묶는다.
  @visibleForTesting
  static String jsErrorType(String? name) =>
      _jsNames.contains(name) ? name! : 'JsError';

  /// JS 스택에서 프레임 줄만 남긴다. 첫 줄의 오류 메시지와 여러 줄 메시지를 버린다.
  @visibleForTesting
  static String jsFrameLines(String stack) =>
      _jsFrame.allMatches(stack).map((m) => m[0]).join('\n');

  /// 처리되지 않은 오류 한 건을 보낸다. [init] 전이면 버리고, 초기화 중이면 결과를 기다린다.
  /// 게임 흐름에 예외를 던지지 않는다.
  void report(
    Object error,
    StackTrace? stack, {
    required String mechanism,
    String? type,
  }) {
    final ready = _ready;
    if (ready == null || _reporting) return;
    if (error is ClientException ||
        error is TimeoutException ||
        error is BackendFailure) {
      return;
    }
    _reporting = true;
    try {
      if (_sent >= maxEvents) return;
      final now = _now();
      final key =
          '${type ?? error.runtimeType}|'
          '${stack?.toString().split('\n').take(4).join('|')}';
      final last = _lastSent[key];
      if (last != null && now.difference(last).abs() < repeatWindow) return;
      _lastSent[key] = now;
      _sent++;
      unawaited(
        ready
            .then((ok) async {
              if (!ok) return;
              await Sentry.captureException(
                ThrowableMechanism(
                  Mechanism(type: mechanism, handled: false),
                  error,
                ),
                stackTrace: stack,
                hint: Hint.withMap({_typeHint: ?type}),
              );
            })
            .catchError((_) {}),
      );
    } catch (_) {
    } finally {
      _reporting = false;
    }
  }

  /// EventLogger가 이벤트를 쌓을 때 부른다. 이름과 시각만 최근 행동으로 남긴다.
  /// 판 문맥이 있는 이벤트에서만 mode, level, exp를 형식 검사 뒤 읽고 새 run이면 이전 값을 지운다.
  /// 다른 params는 읽지 않는다.
  void noteEvent(
    String name,
    Map<String, Object?> params,
    PlayEventContext? context,
  ) {
    try {
      if (!_eventName.hasMatch(name)) return;
      _recent.addLast({'name': name, 'at': _now().toUtc().toIso8601String()});
      while (_recent.length > maxRecent) {
        _recent.removeFirst();
      }
      if (context == null) return;
      if (_play['run_id'] != context.runId) _play.clear();
      _play.addAll(context.toParams());
      final mode = params['mode'], level = params['level'], exp = params['exp'];
      if (mode is String && _token.hasMatch(mode)) _play['mode'] = mode;
      if (level is int && level >= 0 && level < 100000) _play['level'] = level;
      if (exp is String && _token.hasMatch(exp)) _play['exp'] = exp;
    } catch (_) {}
  }

  /// SDK가 만든 이벤트에서 허용한 값만 옮겨 새 이벤트를 만든다(beforeSend).
  /// beforeSend가 예외를 던지면 SDK가 원본을 보내므로 실패는 모두 버림(null)으로 처리한다.
  @visibleForTesting
  SentryEvent? sanitize(SentryEvent event, Hint hint) {
    try {
      if (_production && _qaNow()) return null;
      final exceptions = event.exceptions;
      if (exceptions == null || exceptions.isEmpty) return null;
      final type = hint.get(_typeHint) as String?;
      final sdk = event.sdk;
      return SentryEvent(
        eventId: event.eventId,
        timestamp: event.timestamp,
        platform: event.platform,
        level: SentryLevel.error,
        release: event.release,
        environment: _qa ? TelemetryEnv.qa.name : event.environment,
        sdk: sdk == null
            ? null
            : SdkVersion(
                name: sdk.name,
                version: sdk.version,
                unknown: {
                  'settings': {'infer_ip': 'never'},
                },
              ),
        tags: {'channel': channel, 'runtime': runtime},
        contexts: Contexts()..['game'] = {..._play, 'recent': _recent.toList()},
        exceptions: [
          for (final e in exceptions)
            SentryException(
              type: type ?? e.type,
              value: null,
              stackTrace: _cleanStack(e.stackTrace),
              mechanism: _cleanMechanism(e.mechanism),
            ),
        ],
        debugMeta: DebugMeta(
          images: [
            for (final i in event.debugMeta?.images ?? const <DebugImage>[])
              if (i.type != 'sourcemap')
                DebugImage(
                  type: i.type,
                  debugId: i.debugId,
                  codeId: i.codeId,
                  imageAddr: i.imageAddr,
                  imageSize: i.imageSize,
                  arch: i.arch,
                ),
            ..._sourceMaps ??= _sourceMapImages(),
          ],
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 프레임은 위치 필드만 새로 옮긴다. 해석하지 못한 줄(SDK가 원문을 함수 이름에 넣음)은 뺀다.
  static SentryStackTrace? _cleanStack(SentryStackTrace? stack) => stack == null
      ? null
      : SentryStackTrace(
          frames: [
            for (final f in stack.frames)
              if (f.lineNo != null || f.instructionAddr != null)
                SentryStackFrame(
                  function: f.function,
                  fileName: _cleanUrl(f.fileName),
                  absPath: _cleanUrl(f.absPath),
                  lineNo: f.lineNo,
                  colNo: f.colNo,
                  inApp: f.inApp,
                  package: f.package,
                  platform: f.platform,
                  instructionAddr: f.instructionAddr,
                ),
          ],
          lang: stack.lang,
          snapshot: stack.snapshot,
        );

  /// URL의 query, fragment, 사용자 정보를 뗀다.
  static String? _cleanUrl(String? value) => value
      ?.split(RegExp('[?#]'))
      .first
      .replaceFirstMapped(_userInfo, (m) => m[1]!);

  static Mechanism? _cleanMechanism(Mechanism? m) => m == null
      ? null
      : Mechanism(
          type: m.type,
          handled: m.handled,
          isExceptionGroup: m.isExceptionGroup,
          exceptionId: m.exceptionId,
          parentId: m.parentId,
          source: m.source,
        );

  /// SDK 웹 스택 프레임의 abs_path는 `출처 + / + 파일 이름`이다(sentry 9.30.1
  /// sentry_stack_trace_factory.dart의 eventOrigin과 경로 마지막 조각). `/match/` 같은 하위 경로는
  /// 프레임에서도 사라지므로 debug image도 같은 모양으로 맞춰야 서버가 source map을 찾는다.
  List<DebugImage> _sourceMapImages() {
    final images = <String, DebugImage>{};
    _readDebugIds().forEach((stack, id) {
      final url = _url.firstMatch(stack)?[0];
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null || uri.pathSegments.isEmpty) return;
      final file = '${uri.origin}/${uri.pathSegments.last}';
      images[file] = DebugImage(type: 'sourcemap', codeFile: file, debugId: id);
    });
    return images.values.toList();
  }
}

/// 웹 창 JS 오류의 자리표시. 종류는 hint로 넘기고 메시지는 담지 않는다.
class _JsError {
  _JsError();
}
