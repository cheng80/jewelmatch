import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseSession {
  const PocketBaseSession({
    required this.token,
    required this.userId,
    required this.expiresAt,
  });
  final String token;
  final String userId;
  final DateTime expiresAt;
  bool isExpiredAt(DateTime now) =>
      !now.isBefore(expiresAt.subtract(const Duration(seconds: 60)));
  Map<String, Object?> toJson() => {
    'token': token,
    'user_id': userId,
    'expires_at': expiresAt.millisecondsSinceEpoch,
  };
  static PocketBaseSession? fromJson(Map<String, dynamic> value) {
    final token = value['token'];
    final id = value['user_id'];
    final expiry = value['expires_at'];
    // Unix epoch부터 9999년까지만 허용해 DateTime 범위 오류도 방지한다.
    if (token is! String ||
        token.trim().isEmpty ||
        token.contains(RegExp(r'[\s\x00-\x1f\x7f]')) ||
        id is! String ||
        id.trim().isEmpty ||
        expiry is! int ||
        expiry < 0 ||
        expiry > 253402300799999) {
      return null;
    }
    return PocketBaseSession(
      token: token,
      userId: id,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiry, isUtc: true),
    );
  }
}

/// 자격정보와 토큰을 한 값으로 저장하여 부분 저장된 기기로 인증하지 않는다.
class PocketBaseIdentity {
  const PocketBaseIdentity({
    required this.deviceId,
    required this.deviceSecret,
    this.session,
  });
  final String deviceId;
  final String deviceSecret;
  final PocketBaseSession? session;
  factory PocketBaseIdentity.generate() {
    final random = Random.secure();
    String hex(int bytes) => List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return PocketBaseIdentity(deviceId: hex(16), deviceSecret: hex(32));
  }
  PocketBaseIdentity withSession(PocketBaseSession value) => PocketBaseIdentity(
    deviceId: deviceId,
    deviceSecret: deviceSecret,
    session: value,
  );
  Map<String, Object?> get credentials => {
    'device_id': deviceId,
    'device_secret': deviceSecret,
  };
  Map<String, Object?> toJson() => {
    ...credentials,
    'session': session?.toJson(),
  };
  static PocketBaseIdentity fromJson(Map<String, dynamic> value) {
    final id = value['device_id'];
    final secret = value['device_secret'];
    if (id is! String ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(id) ||
        secret is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(secret)) {
      throw const FormatException('Invalid stored device credentials');
    }
    final session = value['session'];
    return PocketBaseIdentity(
      deviceId: id,
      deviceSecret: secret,
      session: session is Map<String, dynamic>
          ? PocketBaseSession.fromJson(session)
          : null,
    );
  }
}

abstract interface class PocketBaseSessionStore {
  Future<PocketBaseIdentity?> readLatest(String scope);
  Future<void> write(String scope, PocketBaseIdentity identity);
}

class MemoryPocketBaseSessionStore implements PocketBaseSessionStore {
  final _identities = <String, PocketBaseIdentity>{};
  @override
  Future<PocketBaseIdentity?> readLatest(String scope) async =>
      _identities[scope];
  @override
  Future<void> write(String scope, PocketBaseIdentity identity) async {
    _identities[scope] = identity;
  }
}

class PrefsPocketBaseSessionStore implements PocketBaseSessionStore {
  const PrefsPocketBaseSessionStore();
  static String keyFor(String scope) =>
      'pocketbase.identity.v1.${Uri.encodeComponent(scope)}';
  @override
  Future<PocketBaseIdentity?> readLatest(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(keyFor(scope));
    if (raw == null) return null;
    // 손상된 저장값은 새 사용자 생성으로 이어지지 않게 실패한다.
    return PocketBaseIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(String scope, PocketBaseIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(keyFor(scope), jsonEncode(identity.toJson()))) {
      throw StateError('Device identity was not persisted');
    }
  }
}
