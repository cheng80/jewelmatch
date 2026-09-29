import 'backend_gateway.dart';
import 'pocketbase_config.dart';
import 'pocketbase_gateway.dart';
import 'pocketbase_session_store.dart';

/// 앱 전역 백엔드. PocketBase 설정이 없으면 모든 호출이 notConfigured이고 게임은 로컬로 진행한다.
class BackendSelector {
  BackendSelector._();
  static final BackendGateway instance = PocketBaseGateway(
    config: PocketBaseConfig.fromEnvironment,
    sessionStore: const PrefsPocketBaseSessionStore(),
  );
}
