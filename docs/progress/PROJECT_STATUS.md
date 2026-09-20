# Project Status

> 프로젝트 전체의 NOW. 다음 작업자 인계 문장은 HANDOFF.md에 둔다. 구현 상태와 검증 상태를 섞지 않는다.

Updated: 2026-09-20 19:00 KST

## Current Phase
Phase 3 — Stabilization (Phase 4 출시 값은 대기)
이관 단계: 대체 가능(REPLACEABLE). 2026-08-23 표준 팩만으로 대체 가능성 점검 12항 통과. 정본은 docs/. 이전 문서는 archive/docs/. 릴리즈 준비와 분리.

## Active Plan
- `PLAN-001` 모바일 웹 오디오/FPS 회귀 — IN_PROGRESS
- `PLAN-004` 보드 연출 보강 — IN_PROGRESS (F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료, T6 및 독립 리뷰 수정 완료, 합본 HUD 잔상 가설은 픽셀 진단으로 기각, 기존 confetti 겹침)

## Current Tasks
- [x] TASK-001a HTML Audio 4슬롯/경로/unlock/웹 BGM replay
- [x] TASK-001b 짧은 수동 확인 (복귀 SFX, 다시 하기 BGM)
- [ ] TASK-001c 실기기 30초 이상 카운터 보존 — IN_PROGRESS
- [ ] TASK-001d 무한 모드 배너 표시/미표시 A/B
- [ ] TASK-001e 특수효과 표시/미표시 A/B
- [ ] TASK-001f 결과로 Status/Handoff 갱신
- [x] TASK-004a PLAN-004 Step 1, 2 구현 (보석 물리감, BoardJuiceLayer, HUD 롤업)
- [x] TASK-004b 화면/오버레이 연출, 보석 피드백, 사운드 계층 및 blur 제거 통합, UI_UX 반영
- [x] TASK-004c T6 레벨 클리어 시각 연출, reduced motion 즉시 완료 및 독립 리뷰 수정
- [x] TASK-004d 합본 HUD 잔상 가설 진단: 추가 glyph 없음, 기존 confetti 겹침, 제품 수정 없음
- [x] TASK-004e 다른 계열 교차 리뷰(X2) 결함 6건 수정과 main 병합
- [x] TASK-004f bomb 범위 효과를 정지 그림 + 코드 타임라인 + 구운 글로우로 교체, main 병합
- [ ] TASK-004g hyper, supernova 범위 효과를 같은 방식으로 교체 (낱장 생성 진행 중)
- [ ] TASK-004d 모바일 실기기 FPS 전후 비교, 장시간 WebView와 실제 광고 SDK 확인
- [x] TASK-MIG-001 최신 합본 analyze / test / web build 통과. 실기기 스모크는 미실행

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
- 주요 기능: 3모드 매치-3, 특수 보석 탭 발동, 레벨 런 인벤토리 2차, 선택형 광고, 랭킹, 다국어. F1, T1, T2, T3, T4a, T4b, T5 연출 통합 상태. 버전 1.0.0+1
- Release Readiness: 스토어 문서 초안과 채널 define은 있음. 운영 광고 그룹, Apple ID, URL, flavor 미입력. 장시간 모바일 웹 회귀 미완

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | RECHECKED | 2026-09-20 15:53 KST | F1~T6 통합 커밋과 같은 내용의 작업트리 (병합 직전) | CURRENT | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2 회귀 테스트가 안착/제거 중 드래그, 범프 잔류, geometry stale bump 3건과 pointer flow를 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1/T1/T2/T3/T4a/T4b/T5 근거. T4b ego 문자 중복은 headless에서 재현되지 않아 원인 미확정 |
| PLAN-004 mobile device UI / FPS | NOT_RUN | NONE | - | 동일 | UNKNOWN | 실기기 FPS 전후 비교와 장시간 WebView 미실행 |
| T6 level celebration | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | 일반 3000ms / reduced motion 즉시, 점수/시간/보상 불변 테스트와 합본 화면 확인 |
| Independent review fixes | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1 입력 3건, 게임 이탈 자원 해제와 release snapshot P2 수정 및 재검증. 합본 HUD 추가 진단은 기존 confetti 겹침으로 마감 |
| NAS Web smoke | PASS | HISTORICAL | 2026-08-15 | a821b19 | STALE | git 문서: NAS 웹 재배포 성공. 이후 0cd1d00 오디오 수정. 현재 리비전 미재검증 |
| Apps in Toss 재배포 | PASS | HISTORICAL | 2026-08-15 | d777cf0 | STALE | git 문서: 일반 AIT 재배포. 이후 오디오 수정. 현재 리비전 미재검증 |
| Web 장시간 오디오/FPS | INCOMPLETE | HISTORICAL | 2026-08-23 이전 | PLAN-001 / ADR-004 원문 | UNKNOWN | 짧은 수동 확인만 통과. 장시간 카운터 없음. 원문부터 미완 |
| Android/iOS store device | NOT_RUN | NONE | UNKNOWN | UNKNOWN | UNKNOWN | 출시 체크리스트 미완 |
| Release build this revision | PASS | RECHECKED | 2026-09-20 15:53 KST | F1~T6 통합 커밋과 같은 내용의 작업트리 (병합 직전) | CURRENT | integrated_final Web build exit=0. 모바일/스토어 실기기 스모크는 별도 미실행 |

## Next
1. 실기기 FPS, 가독성, 오디오와 광고 흐름 확인
2. 모바일 실기기 `?fps=1` 전후 비교, 장시간 WebView 오디오/FPS와 실제 광고 SDK 확인
3. PLAN-001 장시간 측정은 원문부터 INCOMPLETE. 별도 승인 작업이지 이관 공백 메우기가 아님
4. STALE NAS/AIT를 현재 리비전으로 볼지는 별도 Task. 이관 완료 조건이 아님
5. 출시 값이 오면 TASK-004. 식별 정책이 오면 PLAN-002를 READY

- 합본 HUD 최종 진단(16:08 KST): 무손실 PNG의 추가 밝은 glyph 픽셀 0, 변한 픽셀은 confetti 색 합성으로 설명됐다. pause 150프레임 동안 game render/update 증가 0. 제품 소스 변경 없이 가설 기각. 근거: `_fx_orchestration/reports/T6_integrated_visual_fix.md`.
