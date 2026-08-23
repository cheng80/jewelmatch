# Project Status

> 프로젝트 전체의 NOW. 다음 작업자 인계 문장은 HANDOFF.md에 둔다. 구현 상태와 검증 상태를 섞지 않는다.

Updated: 2026-08-23

## Current Phase
Phase 3 — Stabilization (Phase 4 출시 값은 대기)
이관 단계: 대체 가능(REPLACEABLE). 2026-08-23 표준 팩만으로 대체 가능성 점검 12항 통과. 정본은 docs/. 이전 문서는 archive/docs/. 릴리즈 준비와 분리.

## Active Plan
- `PLAN-001` 모바일 웹 오디오/FPS 회귀 — IN_PROGRESS

## Current Tasks
- [x] TASK-001a HTML Audio 4슬롯/경로/unlock/웹 BGM replay
- [x] TASK-001b 짧은 수동 확인 (복귀 SFX, 다시 하기 BGM)
- [ ] TASK-001c 실기기 30초 이상 카운터 보존 — IN_PROGRESS
- [ ] TASK-001d 무한 모드 배너 표시/미표시 A/B
- [ ] TASK-001e 특수효과 표시/미표시 A/B
- [ ] TASK-001f 결과로 Status/Handoff 갱신
- [x] TASK-MIG-001 flutter test / analyze 통과. 릴리즈 빌드·실기기 스모크는 미실행

## Completed
- Phase 1 Foundation, Phase 2 Core Features
- 문서 계약을 코드 기준으로 맞춤
- Standard 구조: ROADMAP / PLAN / STATUS
- 기존 주제 본문·문서 자산 Detailed Migration

## Blocked / Known Issues
- PLAN-002: 토스 사용자 식별과 서버 저장 정책 없음
- TASK-004: Apple ID, 개인정보 URL, INTOSS 운영 광고 그룹은 제품 외부 결정
- ISSUE-001: 모바일 웹 오디오 끊김 이력, 장시간 카운터 없음 → PLAN-001
- ISSUE-002: 앱인토스 iPhone FPS 급락, GC 단정 금지 → PLAN-001
- ISSUE-003: refill 3회 세션 로컬 → PLAN-002
- ISSUE-004: RunInventory 비영속 → PLAN-003 (2차 범위로는 허용)
- ISSUE-005: 빈 App Store ID

## Implementation Status
- 주요 기능: 3모드 매치-3, 특수 보석 탭 발동, 레벨 런 인벤토리 2차, 선택형 광고, 랭킹, 다국어. 버전 1.0.0+1
- Release Readiness: 스토어 문서 초안과 채널 define은 있음. 운영 광고 그룹, Apple ID, URL, flavor 미입력. 장시간 모바일 웹 회귀 미완

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Unit / Widget | PASS | RECHECKED | 2026-08-23 | 현재 작업트리 (코드 HEAD 0cd1d00 + 문서 이관) | CURRENT | Resume Commands로 flutter test --no-pub 133 passed |
| Analyze | PASS | RECHECKED | 2026-08-23 | 동일 | CURRENT | flutter analyze --no-pub No issues found |
| NAS Web smoke | PASS | HISTORICAL | 2026-08-15 | a821b19 | STALE | git 문서: NAS 웹 재배포 성공. 이후 0cd1d00 오디오 수정. 현재 리비전 미재검증 |
| Apps in Toss 재배포 | PASS | HISTORICAL | 2026-08-15 | d777cf0 | STALE | git 문서: 일반 AIT 재배포. 이후 오디오 수정. 현재 리비전 미재검증 |
| Web 장시간 오디오/FPS | INCOMPLETE | HISTORICAL | 2026-08-23 이전 | PLAN-001 / ADR-004 원문 | UNKNOWN | 짧은 수동 확인만 통과. 장시간 카운터 없음. 원문부터 미완 |
| Android/iOS store device | NOT_RUN | NONE | UNKNOWN | UNKNOWN | UNKNOWN | 출시 체크리스트 미완 |
| Release build this revision | NOT_RUN | NONE | - | 현재 | UNKNOWN | 대체 가능성 점검을 채우려고 새로 돌리지 않음 |

## Next
1. PLAN-001 장시간 측정은 원문부터 INCOMPLETE. 별도 승인 작업이지 이관 공백 메우기가 아님
2. STALE NAS/AIT를 현재 리비전으로 볼지는 별도 Task. 이관 완료 조건이 아님
3. 출시 값이 오면 TASK-004. 식별 정책이 오면 PLAN-002를 READY
