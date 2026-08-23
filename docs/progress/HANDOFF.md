# Handoff

> 다음 작업자가 즉시 시작할 정보만 둔다. 프로젝트 전체 상태는 PROJECT_STATUS.md에 둔다.

Updated: 2026-08-23

## Current State
문서 팩은 대체 가능(REPLACEABLE). 정본은 docs/. 이전 문서는 archive/docs/. 검증 공백은 표에 남아 있다. 게임 다음 작업은 PLAN-001.

## Last Completed
- 마이그레이션 가이드 기준으로 운영 칸을 이 팩에 맞춤
- 기존 주제 본문과 문서 전용 PNG 31장 이관
- 코드와 어긋나던 점수 산식, HUD 랭킹, 시계, 제출 시점을 문서에 반영
- 2026-08-23 대체 가능성 점검 12항을 표준 팩만으로 통과. 이후 정본 경로를 docs/로 옮기고 이전 문서는 archive/docs/로 둠

## In Progress
- Plan: `PLAN-001`
- Task: TASK-001c 실기기 30초 이상 카운터 보존

## Next Task
1. PLAN-001 실기기 장시간 측정 (원문부터 INCOMPLETE. 별도 승인 작업)
2. 이전 문서는 archive/docs/에 있음. 삭제 여부는 별도 결정
3. STALE NAS/AIT 재검증과 PLAN-001 실측은 이관 밖 별도 작업

## Blocked
- PLAN-002, TASK-004: 외부 값/정책

## Known Issues
- ISSUE-001, ISSUE-002: 모바일 웹 오디오/FPS. PLAN-001
- ISSUE-003: 광고 3회 세션 로컬
- ISSUE-004: 인벤토리 비영속 (2차 허용)
- ISSUE-005: 빈 App Store ID

## Changed Contracts
- BR-040: 레벨 1~5는 level*7500, 6부터 37500+(level-5)*5000. ADR-006
- BR-092: HUD 랭킹/top1은 타임 전용
- BR-073: 시계는 인트로, 즉시형 확인, 프리즘 색 선택 중 정지
- BR-093: Pause 나가기는 제출 await, TimeUp 나가기는 기다리지 않음. ADR-007
- BR-072: 하이퍼 큐브는 일반 보석만

## Important Decisions
- ADR-001 특수 보석 탭 발동
- ADR-002 진행 랭킹 = 완료 레벨 수
- ADR-003 선택형 광고만
- ADR-004 웹 HTML Audio 4슬롯
- ADR-005 STORE_CHANNEL define
- ADR-006 목표 점수 완화
- ADR-007 제출 시점과 HUD 범위

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

## Files to Read First
1. progress/PROJECT_STATUS.md
2. 이 파일
3. plans/PLAN-001-mobile-web-audio-fps.md
4. decisions/ADR-004-web-html-audio-sfx.md
5. 01_PRODUCT_SPEC.md 의 FR-003, FR-010

## Resume Commands
이 팩만 보고 실행한다. 비밀은 넣지 않는다.

    flutter test
    flutter analyze

웹 측정이 필요하면 PLAN-001의 웹 빌드 절과 FPS 패널(`?fps=1` 또는 `?qaPerf=1`)을 쓴다.

## Open Questions
- STALE 배포 증거를 현재 리비전에서 재검증할지는 이관 밖 결정
- PLAN-002 식별 저장 정책

## Constraints / Do Not Change
- BR-001, BR-002
- 특수 보석 탭 발동, 스왑 조합 비활성
- 강제 전면 광고 없음
- ranking.php를 웹 빌드/제출 ZIP에 넣지 않음
- Riverpod codegen 금지
- 사용자 문구 중간점 금지
- ADR-004: Web Audio로 되돌리지 말 것
- STALE/INCOMPLETE를 숨기지 말 것. 이전 문서는 archive/docs/
- 정본 docs/와 archive/docs/를 서로 링크로 묶지 말 것
