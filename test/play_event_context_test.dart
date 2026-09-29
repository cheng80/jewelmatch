import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/services/play_event_context.dart';

void main() {
  const goodRun = '00000000-0000-4000-8000-000000000000';

  test('startRun은 UUID v4, round 1, attempt 0이고 매번 다른 run이다', () {
    final a = PlayEventContext.startRun();
    final b = PlayEventContext.startRun();

    expect(a.roundSeq, 1);
    expect(a.attemptSeq, 0);
    expect(uuidV4(), matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(
      () => PlayEventContext(runId: a.runId, roundSeq: 1, attemptSeq: 0),
      returnsNormally,
    );
    expect(a.runId, isNot(b.runId));
  });

  test('nextRound는 round 증가와 attempt 초기화, nextAttempt는 attempt만 증가', () {
    final c = PlayEventContext.startRun().nextAttempt().nextAttempt();
    expect(c.attemptSeq, 2);

    final r = c.nextRound();
    expect((r.runId, r.roundSeq, r.attemptSeq), (c.runId, 2, 0));

    final t = r.nextAttempt();
    expect((t.runId, t.roundSeq, t.attemptSeq), (c.runId, 2, 1));
    // 원본은 변하지 않는다.
    expect((c.roundSeq, c.attemptSeq), (1, 2));
  });

  test('toParams는 run_id, round_seq, attempt_seq 세 필드다', () {
    final c = PlayEventContext(runId: goodRun, roundSeq: 3, attemptSeq: 1);

    expect(c.toParams(), {'run_id': goodRun, 'round_seq': 3, 'attempt_seq': 1});
  });

  test('값이 같으면 동등하다', () {
    final a = PlayEventContext(runId: goodRun, roundSeq: 1, attemptSeq: 0);
    final b = PlayEventContext(runId: goodRun, roundSeq: 1, attemptSeq: 0);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.nextAttempt()));
  });

  test('잘못된 UUID와 범위 밖 순번은 생성에서 거절한다', () {
    PlayEventContext make(String run, int round, int attempt) =>
        PlayEventContext(runId: run, roundSeq: round, attemptSeq: attempt);

    for (final bad in [
      '',
      'not-a-uuid',
      '00000000-0000-1000-8000-000000000000', // v1
      '00000000-0000-4000-c000-000000000000', // variant
      '00000000-0000-4000-8000-00000000000G',
      '00000000-0000-4000-8000-00000000000A', // 대문자
      ' $goodRun',
      '$goodRun\n',
    ]) {
      expect(() => make(bad, 1, 0), throwsArgumentError, reason: bad);
    }
    expect(() => make(goodRun, 0, 0), throwsArgumentError);
    expect(() => make(goodRun, -1, 0), throwsArgumentError);
    expect(() => make(goodRun, 1, -1), throwsArgumentError);
    expect(() => make(goodRun, 1, 0), returnsNormally);
  });
}
