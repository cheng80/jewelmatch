import 'dart:math';

/// 플레이 이벤트를 판과 시도 단위로 묶는 불변 문맥(PLAN-009 Step 2).
///
/// - run_id: 모드 진입 또는 다시 하기마다 새 UUID v4.
/// - round_seq: 같은 run 안의 판 순번. 1부터.
/// - attempt_seq: 같은 판의 시도 순번. 0부터, 광고 이어하기마다 1 증가.
///
/// 전역 현재 문맥은 없다. 호출자가 이 값을 들고 있다가 `EventLogger.logPlay`에 넘긴다.
/// 비동기 응답은 요청 시점의 문맥을 캡처해 쓴다.
class PlayEventContext {
  PlayEventContext({
    required String runId,
    required int roundSeq,
    required int attemptSeq,
  }) : runId = _checkRunId(runId),
       roundSeq = _checkRoundSeq(roundSeq),
       attemptSeq = _checkAttemptSeq(attemptSeq);

  /// 새 run의 첫 판, 첫 시도.
  factory PlayEventContext.startRun() =>
      PlayEventContext(runId: uuidV4(), roundSeq: 1, attemptSeq: 0);

  static const String runIdKey = 'run_id';
  static const String roundSeqKey = 'round_seq';
  static const String attemptSeqKey = 'attempt_seq';

  /// 로거가 호출자 파라미터에서 지우는 예약 필드 이름.
  static const Set<String> reservedKeys = {
    runIdKey,
    roundSeqKey,
    attemptSeqKey,
  };

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final String runId;
  final int roundSeq;
  final int attemptSeq;

  /// 같은 run의 다음 판. 시도 순번은 0으로 돌아간다.
  PlayEventContext nextRound() =>
      PlayEventContext(runId: runId, roundSeq: roundSeq + 1, attemptSeq: 0);

  /// 같은 판의 다음 시도(이어하기).
  PlayEventContext nextAttempt() => PlayEventContext(
    runId: runId,
    roundSeq: roundSeq,
    attemptSeq: attemptSeq + 1,
  );

  Map<String, Object> toParams() => {
    runIdKey: runId,
    roundSeqKey: roundSeq,
    attemptSeqKey: attemptSeq,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayEventContext &&
      other.runId == runId &&
      other.roundSeq == roundSeq &&
      other.attemptSeq == attemptSeq;

  @override
  int get hashCode => Object.hash(runId, roundSeq, attemptSeq);

  @override
  String toString() => 'PlayEventContext($runId, $roundSeq, $attemptSeq)';

  static String _checkRunId(String value) {
    if (!_uuidPattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'runId', 'UUID v4 소문자 형식이어야 한다');
    }
    return value;
  }

  static int _checkRoundSeq(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'roundSeq', '1 이상이어야 한다');
    }
    return value;
  }

  static int _checkAttemptSeq(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'attemptSeq', '0 이상이어야 한다');
    }
    return value;
  }
}

/// 소문자 UUID v4. EventLogger의 event_id와 run_id가 함께 쓴다.
String uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
