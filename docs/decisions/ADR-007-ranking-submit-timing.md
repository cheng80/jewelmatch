# ADR-007 — 랭킹 제출 시점과 HUD 범위

- Status: Accepted
- Date: 2026-08-09 (완료 레벨), 2026-08-16 (재제출)

## Context
레벨 HUD는 현재 진입 레벨을 보여 주고, 결과 화면과 일시정지가 둘 다 종료 지점이다. 제출을 모든 나가기에 동기화하면 TimeUp 나가기가 네트워크에 묶인다. HUD 왕관을 레벨에도 붙이면 top1 API 기본값이 타임 점수라 레벨 완료 수와 섞인다.

## Decision
제출값은 타임 점수 / 레벨 완료 수. HUD 왕관과 fetchTop1은 타임만. TimeUp은 진입 시 제출하고 나가기는 기다리지 않는다. 일시정지 나가기만 await한다.

## Alternatives Considered
- 대안 A: 모든 나가기에서 제출 완료 대기
- 대안 B: 레벨 HUD에도 왕관, mode=level top1

## Reason
완료 레벨은 런이 끝나야 확정된다. 타임 HUD 1위는 점수 경쟁용이다. TimeUp은 이미 제출을 시작했으므로 나가기를 막지 않는다.

## Consequences
- 장점: BR-001과 화면 책임이 갈린다
- 단점/비용: TimeUp에서 제출이 끝나기 전에 나가면 결과를 못 볼 수 있다. 재제출은 TimeUp에 남아 있다
- 후속 영향: 레벨 HUD 랭킹을 붙이려면 fetchTop1(mode=level)과 표시 단위를 따로 정한다

## Related

## 개정 2026-09-24 — Last Hurrah 뒤 제출 (ADR-008, PLAN-005 1c)

사용자 승인(D6 권장안)으로 타임 모드는 시간이 0이 되면 Last Hurrah(남은 특수 보석 순차 발동)를 먼저 끝내고 최종 점수를 확정한 뒤 TimeUp 결과로 넘어간다. 제출은 그 TimeUp 진입 시점에 한다. "TimeUp 진입 시 제출, 나가기는 기다리지 않음, 일시정지 나가기만 await"는 유지한다. 레벨 모드는 Last Hurrah가 없어 기존과 같다. 세부 흐름(연출 상한, reduced motion 즉시 계산, 마무리 중 일시정지 처리)은 PLAN-005 1c와 TECH_SPEC에 둔다.

- FR-009, BR-001, BR-092, BR-093
- 03_TECH_SPEC.md API-002, API-003, BR-092, BR-093
