# ADR-003 — 선택형 보상 광고와 무한 모드 배너만

- Status: Accepted
- Date: 2026-08-14

## Context
Apps in Toss, Play, One Store, App Store를 한 정책으로 가야 한다. 강제 전면은 스토어/토스 가이드와 플레이 방해 위험이 있다.

## Decision
placement는 continueStage, refillItem, infiniteBanner 세 개만. 보상은 rewarded 완료에서만. 정책/횟수/복원은 게임 코드, SDK는 AdService. 일일 3회는 현재 세션 로컬.

## Alternatives Considered
- 대안 A: 스테이지 시작/종료 전면 광고
- 대안 B: 채널마다 다른 위치

## Reason
아이템 루프를 먼저 검증하고 광고를 붙이려는 수익화 순서와 같다. 토스 게임 가이드의 일시 화면 광고 금지를 공통 규칙으로 올린다.

## Consequences
- 장점: 채널 SDK를 바꿔도 위치가 안 흔들린다
- 단점/비용: 세션 로컬 제한은 재시작에 풀림. TASK-002
- 후속 영향: 운영 광고 그룹은 dart-define. 비밀은 소스에 안 넣음

## Related
- FR-010
- BR-100 ~ BR-103
- TASK-002
- git: 2026-08-14 광고 정책, 2026-08-15 앱인토스 광고
