# ADR-006 — 진행 모드 목표 점수는 레벨 6부터 완화

- Status: Accepted
- Date: 2026-06-16 (산식 도입), 코드 완화는 JewelRankProgression.relaxedStageStartLevel

## Context
초기 문서는 모든 레벨을 `level * 7500`으로 적었다. 고레벨에서 60초 안에 선형 목표를 채우기 어려워 코드가 레벨 6부터 증가폭을 5000으로 낮췄다. 문서가 따라오지 않았다.

## Decision
`JewelRankProgression.scoreTargetForLevel`을 단일 기준으로 삼는다. 레벨 1~5는 선형 7500, 레벨 6부터는 37500 + (level-5)*5000. 예: 레벨 6 = 42500, 레벨 10 = 62500.

## Alternatives Considered
- 대안 A: 전 레벨 선형 7500 유지
- 대안 B: 별도 데이터 테이블

## Reason
상수와 한 함수로 테스트 가능하고, 고레벨 압박만 낮춘다. 테이블을 늘리지 않는다.

## Consequences
- 장점: 레벨 6 = 42500처럼 테스트로 고정
- 단점/비용: HUD 레벨과 체감 난이도 곡선이 문서 선형표와 달라질 수 있음. 문서는 코드를 따른다
- 후속 영향: 밸런스 재조정 시 함수와 테스트, 이 ADR, Product Spec BR-040을 같이 바꾼다

## Related
- FR-004, BR-040
- test/jewel_rank_progression_test.dart
