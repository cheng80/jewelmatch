# ADR-005 — 스토어 채널은 dart-define 한 값

- Status: Accepted
- Date: 2026-08-14

## Context
App Store, Play, One Store, Apps in Toss를 내야 한다. 레포를 복제하면 보드 규칙이 갈라진다.

## Decision
STORE_CHANNEL=play|appstore|onestore|intoss. 기본 play. 잘못된 값과 intoss 광고 모드 조합 오류는 기동 시 실패. 광고 그룹 ID는 환경 define. flavor/별도 bundle ID는 아직 없음.

## Alternatives Considered
- 대안 A: 채널별 git 레포 또는 flavor 프로젝트
- 대안 B: 런타임 원격 설정으로 채널 전환

## Reason
보드/랭킹/아이템은 공통이고, 광고 SDK와 리뷰 메뉴만 갈린다. 빌드 시점에 고정하는 편이 테스트 매트릭스가 짧다.

## Consequences
- 장점: 한 트리. app_config_test로 값 검증
- 단점/비용: Android product flavor, iOS configuration, Apple ID는 후속. 운영 비밀은 CI/로컬 env
- 후속 영향: TASK-004

## Related
- FR-010, FR-011
- TASK-004
- git: 2026-08-14 feat: 스토어 채널 분기 준비
