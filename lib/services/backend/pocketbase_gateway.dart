import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_gateway.dart';
import 'pocketbase_config.dart';
import 'pocketbase_session_store.dart';

/// 전용 Stone Match API만 허용하는 PocketBase 클라이언트.
class PocketBaseGateway implements BackendGateway {
  PocketBaseGateway({
    required this.config,
    PocketBaseSessionStore? sessionStore,
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 6),
  }) : _store = sessionStore ?? MemoryPocketBaseSessionStore(),
       _client = client,
       _now = now ?? DateTime.now;
  final PocketBaseConfig config;
  final PocketBaseSessionStore _store;
  final http.Client? _client;
  final DateTime Function() _now;
  final Duration timeout;
  PocketBaseSession? _session;
  Future<BackendResult<PocketBaseSession>>? _pending;
  String? _rejectedToken;
  DateTime? _retryAt;
  int _failures = 0;
  BackendFailure _lastFailure = BackendFailure.network;
  @override
  bool get isConfigured => config.isConfigured;
  @override
  String? get currentUserId => _session?.userId;

  @override
  Future<BackendResult<PocketBaseSession>> ensureSession() async {
    if (!isConfigured) {
      return const BackendResult.failure(BackendFailure.notConfigured);
    }
    final pending = _pending;
    if (pending != null) return pending;
    final future = _authenticate();
    _pending = future;
    try {
      return await future;
    } finally {
      if (identical(_pending, future)) _pending = null;
    }
  }

  void _backoff(BackendFailure failure) {
    _lastFailure = failure;
    final seconds = failure == BackendFailure.network
        ? 10
        : (60 * (1 << _failures.clamp(0, 4))).clamp(60, 600);
    _failures++;
    _retryAt = _now().add(Duration(seconds: seconds));
  }

  Future<BackendResult<PocketBaseSession>> _authenticate() async {
    try {
      var identity = await _store.readLatest(config.baseUrl);
      final stored = identity?.session;
      if (stored != null &&
          stored.token != _rejectedToken &&
          !stored.isExpiredAt(_now())) {
        _session = stored;
        return BackendResult.success(stored);
      }
      final retry = _retryAt;
      if (retry != null &&
          _now().isBefore(retry) &&
          retry.difference(_now()) <= const Duration(minutes: 10)) {
        return BackendResult.failure(_lastFailure);
      }
      if (identity == null) {
        identity = PocketBaseIdentity.generate();
        await _store.write(config.baseUrl, identity);
        // 다른 탭이 먼저 저장했다면 저장 매체의 자격정보를 사용한다.
        identity = await _store.readLatest(config.baseUrl);
        if (identity == null) {
          throw StateError('Missing persisted device identity');
        }
      }
      final result = await _send('/auth/guest', body: identity.credentials);
      if (!result.isSuccess) {
        _backoff(result.failure!);
        return BackendResult.failure(result.failure!);
      }
      final body = result.data;
      final token = body is Map ? body['token'] : null;
      final record = body is Map ? body['record'] : null;
      final id = record is Map ? record['id'] : null;
      final expires = body is Map ? body['expires_in'] : null;
      if (token is! String ||
          token.trim().isEmpty ||
          token.contains(RegExp(r'\s')) ||
          id is! String ||
          id.trim().isEmpty ||
          expires is! int ||
          expires <= 60 ||
          expires > 604800) {
        _backoff(BackendFailure.server);
        return const BackendResult.failure(BackendFailure.server);
      }
      // 보존 작업으로 삭제된 사용자는 같은 기기 자격정보로 새 ID를 받을 수 있다.
      final session = PocketBaseSession(
        token: token,
        userId: id,
        expiresAt: _now().toUtc().add(Duration(seconds: expires)),
      );
      // 인증 도중 다른 탭에서 바뀐 기기의 자격정보를 덮어쓰지 않는다.
      final latest = await _store.readLatest(config.baseUrl);
      if (latest?.deviceId != identity.deviceId ||
          latest?.deviceSecret != identity.deviceSecret) {
        _backoff(BackendFailure.unauthorized);
        return const BackendResult.failure(BackendFailure.unauthorized);
      }
      await _store.write(config.baseUrl, identity.withSession(session));
      _session = session;
      _rejectedToken = null;
      _retryAt = null;
      _failures = 0;
      return BackendResult.success(session);
    } catch (_) {
      _backoff(BackendFailure.network);
      return const BackendResult.failure(BackendFailure.network);
    }
  }

  @override
  Future<BackendResult<Object?>> rpc(
    String function,
    Map<String, Object?> params, {
    bool requireAuth = true,
  }) {
    final path = switch (function) {
      'get_ranking' => '/ranking/list',
      'submit_ranking' => '/ranking/submit',
      'ad_refill_status' => '/ads/status',
      'claim_ad_refill' => '/ads/claim',
      _ => null,
    };
    if (path == null) {
      return Future.value(const BackendResult.failure(BackendFailure.rejected));
    }
    return _request(path, body: params, auth: function != 'get_ranking');
  }

  @override
  Future<BackendResult<Object?>> insert(
    String table,
    List<Map<String, Object?>> rows, {
    String? expectedUserId,
  }) {
    if (table != 'game_events') {
      return Future.value(const BackendResult.failure(BackendFailure.rejected));
    }
    return _request(
      '/events',
      body: rows,
      auth: true,
      expectedUserId: expectedUserId,
    );
  }

  @override
  Future<BackendResult<Object?>> select(String pathAndQuery) {
    if (pathAndQuery != 'app_config?key=eq.gameplay&select=value') {
      return Future.value(const BackendResult.failure(BackendFailure.rejected));
    }
    return _request('/config/gameplay', auth: false);
  }

  Future<BackendResult<Object?>> _request(
    String path, {
    Object? body,
    required bool auth,
    String? expectedUserId,
  }) async {
    if (!isConfigured) {
      return const BackendResult.failure(BackendFailure.notConfigured);
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      String? token;
      if (auth) {
        final result = await ensureSession();
        if (!result.isSuccess) return BackendResult.failure(result.failure!);
        // 재인증으로 사용자가 바뀌었으면 다른 계정으로 보내지 않는다.
        if (expectedUserId != null && result.data!.userId != expectedUserId) {
          return const BackendResult.failure(
            BackendFailure.unauthorized,
            errorCode: BackendGateway.ownerMismatch,
          );
        }
        token = result.data!.token;
      }
      final result = await _send(path, body: body, token: token);
      if (!auth || result.failure != BackendFailure.unauthorized) return result;
      _rejectedToken = token;
      if (attempt == 1) {
        _backoff(BackendFailure.unauthorized);
        return result;
      }
    }
    return const BackendResult.failure(BackendFailure.unauthorized);
  }

  Future<BackendResult<Object?>> _send(
    String path, {
    Object? body,
    String? token,
  }) async {
    final client = _client ?? http.Client();
    try {
      final uri = Uri.parse('${config.baseUrl}/api/stone-match$path');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': ?token,
      };
      final response =
          await (body == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(timeout);
      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        if (status == 204) return const BackendResult.success(null);
        try {
          return BackendResult.success(jsonDecode(response.body));
        } catch (_) {
          return const BackendResult.failure(BackendFailure.server);
        }
      }
      return BackendResult.failure(switch (status) {
        401 => BackendFailure.unauthorized,
        404 => BackendFailure.notFound,
        429 => BackendFailure.rateLimited,
        >= 500 => BackendFailure.server,
        _ => BackendFailure.rejected,
      });
    } catch (_) {
      return const BackendResult.failure(BackendFailure.network);
    } finally {
      if (_client == null) client.close();
    }
  }
}
