import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../app_config.dart';
import '../../utils/storage_helper.dart';
import 'supabase_config.dart';

enum BackendFailure {
  notConfigured,
  network,
  unauthorized,
  notFound,
  rateLimited,
  rejected,
  server,
}

class BackendResult<T> {
  const BackendResult.success(this.data)
    : failure = null,
      errorCode = null,
      errorMessage = null;

  const BackendResult.failure(
    BackendFailure this.failure, {
    this.errorCode,
    this.errorMessage,
  }) : data = null;

  final T? data;
  final BackendFailure? failure;
  final String? errorCode;
  final String? errorMessage;

  bool get isSuccess => failure == null;
}

/// 익명 로그인 세션. 액세스 토큰은 만료 60초 전부터 갱신 대상으로 본다.
class SupabaseSession {
  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;

  bool isExpiredAt(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(seconds: 60)));

  SupabaseSession expired() => SupabaseSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    userId: userId,
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': expiresAt.millisecondsSinceEpoch ~/ 1000,
    'user_id': userId,
  };

  static SupabaseSession? fromJson(Map<String, dynamic> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresAt = json['expires_at'];
    final userId = json['user_id'];
    if (access is! String || refresh is! String || userId is! String) {
      return null;
    }
    if (expiresAt is! num) return null;
    return SupabaseSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt() * 1000,
        isUtc: true,
      ),
      userId: userId,
    );
  }

  /// GoTrue 인증 응답(access_token, refresh_token, expires_at 또는 expires_in, user.id).
  /// 기기 시계가 서버와 달라도 동작하도록 expires_in이 있으면 로컬 시각 기준으로 먼저 쓴다.
  static SupabaseSession? fromAuthResponse(
    Map<String, dynamic> body,
    DateTime now,
  ) {
    final access = body['access_token'];
    final refresh = body['refresh_token'];
    final user = body['user'];
    final userId = user is Map<String, dynamic> ? user['id'] : null;
    if (access is! String || refresh is! String || userId is! String) {
      return null;
    }
    final expiresAt = body['expires_at'];
    final expiresIn = body['expires_in'];
    final DateTime expiry;
    if (expiresIn is num) {
      expiry = now.toUtc().add(Duration(seconds: expiresIn.toInt()));
    } else if (expiresAt is num) {
      expiry = DateTime.fromMillisecondsSinceEpoch(
        expiresAt.toInt() * 1000,
        isUtc: true,
      );
    } else {
      return null;
    }
    return SupabaseSession(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: expiry,
      userId: userId,
    );
  }
}

abstract interface class SupabaseSessionStore {
  SupabaseSession? read();

  /// 캐시가 아니라 저장 매체의 최신 값을 읽는다(웹의 다른 탭이 쓴 값 포함).
  Future<SupabaseSession?> readLatest();

  Future<void> write(SupabaseSession? session);
}

class MemorySupabaseSessionStore implements SupabaseSessionStore {
  MemorySupabaseSessionStore([this._session]);

  SupabaseSession? _session;

  @override
  SupabaseSession? read() => _session;

  @override
  Future<SupabaseSession?> readLatest() async => _session;

  @override
  Future<void> write(SupabaseSession? session) async {
    _session = session;
  }
}

/// shared_preferences(웹은 localStorage)에 세션을 저장한다.
class PrefsSupabaseSessionStore implements SupabaseSessionStore {
  const PrefsSupabaseSessionStore();

  @override
  SupabaseSession? read() {
    try {
      final raw = StorageHelper.read<String>(StorageKeys.supabaseSession);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SupabaseSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 웹은 탭마다 SharedPreferences 캐시가 따로라 localStorage를 다시 읽는다.
  @override
  Future<SupabaseSession?> readLatest() async {
    if (kIsWeb) {
      try {
        await StorageHelper.reload();
      } catch (_) {
        // 다시 읽기 실패는 캐시 값으로 대신한다.
      }
    }
    return read();
  }

  @override
  Future<void> write(SupabaseSession? session) async {
    try {
      if (session == null) {
        await StorageHelper.remove(StorageKeys.supabaseSession);
      } else {
        await StorageHelper.write(
          StorageKeys.supabaseSession,
          jsonEncode(session.toJson()),
        );
      }
    } catch (_) {
      // 저장 실패는 다음 실행에서 새 익명 사용자를 만드는 것으로 끝난다.
    }
  }
}

/// Supabase REST(Auth, PostgREST) 최소 클라이언트.
///
/// Wasm 웹 빌드와 기존 http 패키지만으로 동작하도록 공식 SDK 대신 필요한 호출만 둔다.
/// 모든 실패는 [BackendResult]로 돌려주고 예외를 밖으로 던지지 않는다(BR-002).
class SupabaseGateway {
  SupabaseGateway({
    required this.config,
    SupabaseSessionStore? sessionStore,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 6),
  }) : _sessionStore = sessionStore ?? MemorySupabaseSessionStore(),
       _client = client,
       _now = now ?? DateTime.now;

  static final SupabaseGateway instance = SupabaseGateway(
    config: SupabaseConfig.fromEnvironment,
    sessionStore: const PrefsSupabaseSessionStore(),
  );

  final SupabaseConfig config;
  final Duration timeout;
  final SupabaseSessionStore _sessionStore;
  final http.Client? _client;
  final DateTime Function() _now;

  SupabaseSession? _session;
  bool _sessionLoaded = false;
  Future<BackendResult<SupabaseSession>>? _pendingAuth;
  int _authFailures = 0;
  int _tokenRejections = 0;
  DateTime? _authRetryAt;
  BackendFailure _lastAuthFailure = BackendFailure.network;

  /// 인증 실패 뒤 대기 시간. 60초에서 시작해 실패마다 2배, 상한 10분.
  static const Duration _authBackoffBase = Duration(seconds: 60);
  static const Duration _authBackoffMax = Duration(minutes: 10);

  /// 네트워크 실패 뒤 대기. 서버 부하와 무관하므로 재연결 뒤 곧 다시 시도한다.
  static const Duration _networkRetryDelay = Duration(seconds: 10);

  bool get isConfigured => config.isConfigured;

  String? get currentUserId => _session?.userId;

  /// 유효한 익명 세션을 보장한다. 저장된 세션이 만료되면 갱신하고, 없으면 익명 가입한다.
  /// 갱신이 네트워크 문제로 실패하면 새 사용자를 만들지 않는다.
  Future<BackendResult<SupabaseSession>> ensureSession() async {
    if (!isConfigured) {
      return const BackendResult.failure(BackendFailure.notConfigured);
    }
    if (!_sessionLoaded) {
      _session = _sessionStore.read();
      _sessionLoaded = true;
    }
    final current = _session;
    if (current != null && !current.isExpiredAt(_now())) {
      return BackendResult.success(current);
    }
    final pending = _pendingAuth;
    if (pending != null) return pending;
    final future = _authenticate(current);
    _pendingAuth = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingAuth, future)) _pendingAuth = null;
    }
  }

  /// 가입과 갱신 요청을 보내기 전에 대기 시간과 다른 탭이 저장한 세션을 확인한다.
  Future<BackendResult<SupabaseSession>> _authenticate(
    SupabaseSession? stale,
  ) async {
    // 웹의 다른 탭이 refresh 토큰을 회전시켰다면 저장소의 새 세션을 기준으로 삼는다.
    // 액세스 토큰이 만료됐어도 옛 refresh 토큰 대신 저장된 refresh 토큰으로 갱신한다.
    final stored = await _rotatedStoredSession(stale);
    if (stored != null) {
      if (!stored.isExpiredAt(_now())) {
        _session = stored;
        return BackendResult.success(stored);
      }
      stale = stored;
    }
    final now = _now();
    final retryAt = _authRetryAt;
    // 시계를 되돌려 대기 끝이 상한보다 멀어졌으면 대기가 끝난 것으로 본다.
    if (retryAt != null &&
        now.isBefore(retryAt) &&
        retryAt.difference(now) <= _authBackoffMax) {
      return BackendResult.failure(_lastAuthFailure);
    }
    final result = await _refreshOrSignUp(stale);
    if (result.isSuccess) {
      _authFailures = 0;
      _authRetryAt = null;
    } else if (result.failure == BackendFailure.network) {
      _lastAuthFailure = BackendFailure.network;
      _authRetryAt = _now().add(_networkRetryDelay);
    } else {
      _startAuthBackoff(result.failure!, _authFailures);
      _authFailures += 1;
    }
    return result;
  }

  /// [attempt]번째 실패의 대기(60초부터 2배, 상한 10분)를 건다.
  void _startAuthBackoff(BackendFailure failure, int attempt) {
    _lastAuthFailure = failure;
    final backoff = _authBackoffBase * (1 << attempt.clamp(0, 4));
    _authRetryAt = _now().add(
      backoff > _authBackoffMax ? _authBackoffMax : backoff,
    );
  }

  /// 저장소의 refresh 토큰이 [stale]과 다르면 그 세션을 돌려준다.
  Future<SupabaseSession?> _rotatedStoredSession(SupabaseSession? stale) async {
    final stored = await _sessionStore.readLatest();
    if (stored == null || stored.refreshToken == stale?.refreshToken) {
      return null;
    }
    return stored;
  }

  Future<BackendResult<SupabaseSession>> _refreshOrSignUp(
    SupabaseSession? stale,
  ) async {
    if (stale != null) {
      final refreshed = await _authRequest('token?grant_type=refresh_token', {
        'refresh_token': stale.refreshToken,
      });
      if (refreshed.isSuccess) return refreshed;
      final failure = refreshed.failure;
      if (failure != BackendFailure.unauthorized &&
          failure != BackendFailure.rejected) {
        return refreshed;
      }
      // 거절이 다른 탭의 회전 때문이면 그 탭이 저장한 세션을 쓴다.
      final shared = await _rotatedStoredSession(stale);
      if (shared != null && !shared.isExpiredAt(_now())) {
        _session = shared;
        return BackendResult.success(shared);
      }
    }
    return _authRequest('signup', {'data': <String, Object?>{}});
  }

  Future<BackendResult<SupabaseSession>> _authRequest(
    String path,
    Map<String, Object?> body,
  ) async {
    final result = await _post(
      Uri.parse('${config.baseUrl}/auth/v1/$path'),
      headers: _baseHeaders(),
      body: jsonEncode(body),
    );
    if (!result.isSuccess) {
      return BackendResult.failure(
        result.failure!,
        errorCode: result.errorCode,
        errorMessage: result.errorMessage,
      );
    }
    final decoded = result.data;
    final session = decoded is Map<String, dynamic>
        ? SupabaseSession.fromAuthResponse(decoded, _now())
        : null;
    if (session == null) {
      return const BackendResult.failure(BackendFailure.server);
    }
    _session = session;
    await _sessionStore.write(session);
    return BackendResult.success(session);
  }

  /// PostgREST RPC. [requireAuth]가 false면 공개용 키만으로 anon 역할로 호출한다.
  Future<BackendResult<Object?>> rpc(
    String function,
    Map<String, Object?> params, {
    bool requireAuth = true,
  }) {
    return _restPost(
      '/rest/v1/rpc/$function',
      jsonEncode(params),
      requireAuth: requireAuth,
    );
  }

  /// 여러 행 삽입. 응답 본문은 받지 않는다(return=minimal).
  Future<BackendResult<Object?>> insert(
    String table,
    List<Map<String, Object?>> rows,
  ) {
    return _restPost(
      '/rest/v1/$table',
      jsonEncode(rows),
      requireAuth: true,
      extraHeaders: const {'Prefer': 'return=minimal'},
    );
  }

  /// 공개 조회(anon). [pathAndQuery]는 `/rest/v1/` 뒤 경로와 쿼리(예: `app_config?key=eq.x&select=value`).
  Future<BackendResult<Object?>> select(String pathAndQuery) {
    if (!isConfigured) {
      return Future.value(
        const BackendResult.failure(BackendFailure.notConfigured),
      );
    }
    return _send(
      Uri.parse('${config.baseUrl}/rest/v1/$pathAndQuery'),
      headers: _baseHeaders(),
    );
  }

  Future<BackendResult<Object?>> _restPost(
    String path,
    String body, {
    required bool requireAuth,
    Map<String, String> extraHeaders = const {},
    bool retried = false,
  }) async {
    if (!isConfigured) {
      return const BackendResult.failure(BackendFailure.notConfigured);
    }
    String? token;
    if (requireAuth) {
      final session = await ensureSession();
      if (!session.isSuccess) {
        return BackendResult.failure(session.failure!);
      }
      token = session.data!.accessToken;
    }
    final result = await _post(
      Uri.parse('${config.baseUrl}$path'),
      headers: {
        ..._baseHeaders(),
        if (token != null) 'Authorization': 'Bearer $token',
        ...extraHeaders,
      },
      body: body,
    );
    if (result.failure == BackendFailure.unauthorized && requireAuth) {
      final current = _session;
      _session = current?.expired();
      if (retried || _tokenRejections > 0) {
        // 갱신한 토큰도 거절되면 대기에 넣어 호출마다 갱신을 반복하지 않는다.
        // 거절이 이어지는 동안에는 대기 뒤 갱신한 토큰의 401도 재시도 없이 대기를 늘린다.
        _startAuthBackoff(BackendFailure.unauthorized, _tokenRejections);
        _tokenRejections += 1;
        return result;
      }
      // 서버가 토큰을 거절하면 한 번만 갱신 후 다시 보낸다.
      return _restPost(
        path,
        body,
        requireAuth: requireAuth,
        extraHeaders: extraHeaders,
        retried: true,
      );
    }
    if (requireAuth && result.isSuccess) _tokenRejections = 0;
    return result;
  }

  Map<String, String> _baseHeaders() => {
    'apikey': config.publishableKey,
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<BackendResult<Object?>> _post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) => _send(uri, headers: headers, body: body);

  /// [body]가 null이면 GET, 아니면 POST.
  Future<BackendResult<Object?>> _send(
    Uri uri, {
    required Map<String, String> headers,
    String? body,
  }) async {
    final ownsClient = _client == null;
    final client = _client ?? http.Client();
    try {
      final response =
          await (body == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: body))
              .timeout(timeout);
      final decoded = _tryDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BackendResult.success(decoded);
      }
      return _failureFor(response.statusCode, decoded);
    } catch (_) {
      return const BackendResult.failure(BackendFailure.network);
    } finally {
      if (ownsClient) client.close();
    }
  }

  static Object? _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static BackendResult<Object?> _failureFor(int status, Object? body) {
    String? code;
    String? message;
    if (body is Map<String, dynamic>) {
      final rawCode = body['code'] ?? body['error_code'] ?? body['error'];
      code = rawCode?.toString();
      final rawMessage =
          body['message'] ?? body['msg'] ?? body['error_description'];
      message = rawMessage?.toString();
    }
    final text = '${code ?? ''} ${message ?? ''}';
    final BackendFailure failure;
    if (status == 429 || text.contains('rate_limited')) {
      failure = BackendFailure.rateLimited;
    } else if (status == 401) {
      // 403은 권한 부족(RLS, 열 권한)이라 토큰을 갱신해도 풀리지 않는다.
      failure = BackendFailure.unauthorized;
    } else if (status == 404) {
      failure = BackendFailure.notFound;
    } else if (status >= 500) {
      failure = BackendFailure.server;
    } else {
      failure = BackendFailure.rejected;
    }
    return BackendResult.failure(
      failure,
      errorCode: code,
      errorMessage: message,
    );
  }
}
