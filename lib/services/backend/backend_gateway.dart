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

/// 앱 서비스가 사용하는 최소 백엔드 계약.
abstract interface class BackendGateway {
  bool get isConfigured;
  String? get currentUserId;
  Future<BackendResult<Object?>> ensureSession();
  Future<BackendResult<Object?>> rpc(
    String function,
    Map<String, Object?> params, {
    bool requireAuth = true,
  });

  /// [expectedUserId]가 있으면 모든 요청과 재인증 재시도 직전에 인증 사용자와 비교하고,
  /// 다르면 보내지 않고 unauthorized(errorCode [ownerMismatch])로 끝낸다.
  Future<BackendResult<Object?>> insert(
    String table,
    List<Map<String, Object?>> rows, {
    String? expectedUserId,
  });

  static const String ownerMismatch = 'owner_mismatch';
  Future<BackendResult<Object?>> select(String pathAndQuery);
}
