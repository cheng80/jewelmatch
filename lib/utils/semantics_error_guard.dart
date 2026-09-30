import 'package:flutter/widgets.dart';

/// 바인딩 초기화 직후 한 번 설치한다. Sentry 설정 유무와 관계없이 입력을 보호한다.
///
/// Flutter 웹의 접근성 탭 콜백이 예외를 엔진까지 던지면 ClickDebouncer의
/// reset이 생략되어 이후 탭도 실패한다. 원래 콜백과 인자를 보존하면서
/// 예외를 FlutterError로 넘기고 정상 반환해 엔진이 입력 상태를 정리하게 한다.
void installSemanticsErrorGuard(WidgetsBinding binding) {
  final dispatcher = binding.platformDispatcher;
  final previous = dispatcher.onSemanticsActionEvent;
  if (previous == null) return;
  dispatcher.onSemanticsActionEvent = (action) {
    try {
      previous(action);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Stone Match',
          context: ErrorDescription('while handling a semantics action'),
        ),
      );
    }
  };
}
