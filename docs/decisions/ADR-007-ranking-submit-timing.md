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
- FR-009, BR-001, BR-092, BR-093
- 03_TECH_SPEC.md API-002, API-003, BR-092, BR-093
