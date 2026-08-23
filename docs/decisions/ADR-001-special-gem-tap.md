# ADR-001 — 특수 보석은 탭 발동, 스왑 조합 비활성

- Status: Accepted
- Date: 2026-06-23

## Context
초기에 Bejeweled식 특수 보석과 스왑 조합을 참고했다. 보드 VFX, 힌트, 색 매치가 겹치면서 조합 규칙이 플레이와 구현 모두에서 비용이 컸다.

## Decision
특수 보석은 색 매치 토큰이 아니다. 해당 칸을 탭하면 발동한다. bomb+star 같은 스왑 조합은 끄고, 효과 범위에 들어간 non-hyper만 연쇄한다. hyper는 범위에 있어도 제거만 한다.

## Alternatives Considered
- 대안 A: Bejeweled식 스왑 조합 전부 구현
- 대안 B: 특수 보석도 같은 색 3매치에 포함해 발동

## Reason
탭 발동이 규칙이 짧고, 힌트 후보를 일반 스왑만으로 제한할 수 있다. 교차/4/5/6 생성 우선순위와 VFX 풀을 조합 폭발과 분리할 수 있다.

## Consequences
- 장점: 규칙과 테스트가 짧다. 특수 보석이 일반 3매치를 깨지 않는다
- 단점/비용: Bejeweled 유저의 조합 기대와 다르다
- 후속 영향: 재도입 시 special_gems_rules.md, match_board_input/specials/special_combos와 테스트를 함께 수정. TASK-008

## Related
- FR-002
- BR-020, BR-021, BR-022
- git: 2026-06-13 Implement Bejeweled-style special gems, 2026-06-23 특수 보석 탭 발동
