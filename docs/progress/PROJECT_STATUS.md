# Project Status

> 프로젝트 전체의 NOW. 다음 작업자 인계 문장은 HANDOFF.md에 둔다. 구현 상태와 검증 상태를 섞지 않는다.

Updated: 2026-09-24 09:40 KST

## Current Phase
Phase 3 — Stabilization (Phase 4 출시 값은 대기)
Phase 5 게임 방향 개편 진행 중. PLAN-005 Step 1a, 1b, 1c, 3을 main에 반영했고 Step 4(일일 동일 보드, 주간 순위), Step 5(레벨 도전 스테이지)도 main에 반영하고 NAS에 배포했다(`223303e`). 이어서 아이템과 이어하기 이벤트도 연결했다. PLAN-005에 남은 것은 사용자 플레이가 필요한 시간 보상 T1(D7)과 플레이테스트 기록뿐이다. 2026-09-24 사용자 결정: 앱 구조 개편 완료가 우선이고 앱인토스 빌드 확인과 광고(AdMob)는 그 뒤로 미룬다.
이관 단계: 대체 가능(REPLACEABLE). 2026-08-23 표준 팩만으로 대체 가능성 점검 12항 통과. 정본은 docs/. 이전 문서는 archive/docs/. 릴리즈 준비와 분리.

## Active Plan
- `PLAN-001` 모바일 웹 오디오/FPS 회귀 — IN_PROGRESS
- `PLAN-004` 보드 연출 보강 — IN_PROGRESS (F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료, T6 및 독립 리뷰 수정 완료, 합본 HUD 잔상 가설은 픽셀 진단으로 기각, 기존 confetti 겹침)
- `PLAN-005` Bejeweled Blitz 계승 게임 방향 개편 — IN_PROGRESS (ADR-008 Accepted. Step 1a, 1b, 1c, 3, 4, 5 main 반영. Step 2 아이템과 이어하기 이벤트, 1d(D7 플레이테스트) 남음. D8, D9 권장안 결정)
- `PLAN-007` 일일 동일 보드와 주간 순위 — DONE
- `PLAN-008` 실험 기능 일괄 도입과 스위치 — DONE(채택 판단은 플레이테스트 뒤)
- `PLAN-006` Supabase 기반 구축 — IN_PROGRESS (Step 1~3 완료, Step 4 NAS 배포 완료(`b71ba31`). 앱인토스 QR 확인은 사용자 결정으로 보류. 남은 것: 익명 사용자 정리 정책, Supabase 요금제와 일시정지 정책)

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
- [x] TASK-004g hyper, supernova 레이어 전환 구현과 데스크톱 검증 완료 (main `c3b64dd` 병합 및 작업 Worktree/Orca 세션 정리 완료)
- [x] TASK-004h 기본 매칭 파편/콤보 별빛의 중력과 위쪽 편향 제거, 방사형 감속/소멸로 조정. 후속 확산1.4배, 수명65%, 유휴 반짝임2/3, 광택 스윕80%/반복10초 (main 반영)
- [ ] TASK-004d 모바일 실기기 FPS 전후 비교, 장시간 WebView와 실제 광고 SDK 확인
- [x] TASK-MIG-001 F1~T6 합본 analyze / test / web build 과거 통과 기록 보존. E2 데스크톱 검증은 완료, 실기기 스모크는 미실행
- [x] TASK-005a 게임 방향 조사와 기획 문서화: Product Spec "게임 방향 기획" 절, ADR-008(Proposed), PLAN-005(DRAFT), ROADMAP Phase 5, 특수 보석 룰 11-1절 원문 대조 정정
- [x] TASK-005b D1~D6 권장안 승인(2026-09-24). D10 해당 없음. D8, D9는 막히면 권장안이라는 사용자 승인에 따라 권장안으로 결정. D7은 플레이테스트 대기
- [x] TASK-005c Step 1a 하이퍼 교환 H1~H3(`f343fad`), 1b Speed Bonus(`936dfee`), 1c Last Hurrah(`a2d78d2`), Step 3 기록과 장기 목표(`baaff7c`), 통합 검수 R-1~R-10 수정(`f8a209d`, `b71ba31`)
- [x] TASK-005d Step 2 아이템, 이어하기 이벤트 연결(Playwright 7/7)과 플레이테스트 기록 양식. 기록 자체는 사용자 플레이 필요
- [x] TASK-005e Step 4 일일 동일 보드와 주간 순위(PLAN-007, `4435ecb`, 조회 계획 보강 `70cad69`, 원격 적용)
- [x] TASK-005f Step 5 레벨 도전 스테이지(`87f50ca`, BR-043)
- [x] TASK-005g 독립 검수 R3(P0 0, P1 1, P2 1, P3 7) 반영(`f2a26ae`, `70cad69`), 비활성 익명 사용자 정리(`cef0acc`)
- [x] TASK-008a 실험 스위치(T1, Time 보석, Multiplier 보석, 7색, Last Hurrah 콤보) 구현, 검수 R4 반영, 원격 적용
- [x] TASK-009a 텍스처 아틀라스 통합: board_atlas, ui_atlas, ui_buttons_atlas(무손실 WebP), 쓰지 않던 레거시 시트 번들 제외(TECH_SPEC 3-1 텍스처 아틀라스)
- [ ] TASK-001g ISSUE-007 멀티스레드 skwasm 같은 탭 재로드 멈춤 대응
- [x] TASK-006a Supabase 스키마, 익명 로그인 게이트웨이, 랭킹 이전, 보충 광고 서버 확인, 이벤트 로거 구현과 테스트
- [x] TASK-006b Supabase 원격 프로젝트 준비, 마이그레이션 적용, 원격 스모크, NAS 배포(`b71ba31`)

## Completed
- Phase 1 Foundation, Phase 2 Core Features
- 문서 계약을 코드 기준으로 맞춤
- Standard 구조: ROADMAP / PLAN / STATUS
- 기존 주제 본문·문서 자산 Detailed Migration

## Blocked / Known Issues
- PLAN-002: 토스 사용자 식별과 서버 저장 정책 없음
- 앱인토스 QR 확인: 연결된 Android 폰에 토스 앱이 없고, 사용자 결정으로 구조 개편 뒤로 보류. 테스트 빌드는 업로드됨(deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`)
- TASK-004: Apple ID, 개인정보 URL, INTOSS 운영 광고 그룹은 제품 외부 결정
- ISSUE-001: 모바일 웹 오디오 끊김 이력, 장시간 카운터 없음 → PLAN-001
- ISSUE-002: 앱인토스 iPhone FPS 급락, GC 단정 금지 → PLAN-001
- ISSUE-003: refill 3회 → Supabase 익명 사용자 기준으로 원격 적용과 NAS 배포 완료(PLAN-006). 저장소 삭제나 재설치 시 새 사용자라 제한이 새로 시작된다(BR-103)
- ISSUE-004: RunInventory 비영속 → PLAN-003 (2차 범위로는 허용)
- ISSUE-005: 빈 App Store ID
- ISSUE-007: 같은 탭에서 게임 문서를 다시 불러오면 멀티스레드 skwasm(격리 헤더 있음)이 "memory access out of bounds", "table index is out of bounds", "divide by zero"로 멈춘다. `b71ba31`에서도 재현되는 기존 문제다. 새 Chrome 첫 로드는 NAS 3회와 로컬 10회 모두 정상. 단일 스레드 skwasm(격리 헤더 없음)은 같은 탭 재로드 4회 모두 정상이지만 FPS가 약 89에서 45로 떨어진다 → PLAN-001
- ISSUE-006: 미출시로 외부 사용 지표 없음. GA4, Firebase Analytics 미연동. 내부 이벤트 로거는 Supabase `game_events`로 동작한다. 시험 데이터는 매 검증 뒤 지워 현재 수집 데이터는 없다 → PLAN-006, PLAN-005 Step 2

## Implementation Status
- 주요 기능: 3모드 매치-3, 특수 보석 탭 발동, 레벨 런 인벤토리 2차, 선택형 광고, 랭킹, 다국어. F1, T1, T2, T3, T4a, T4b, T5 연출 통합 상태. hyper/supernova 레이어 후속 E2는 main `c3b64dd`에 반영했고 병합 후 데스크톱 검증을 통과했다. 버전 1.0.0+1
- Release Readiness: 스토어 문서 초안과 채널 define은 있음. 운영 광고 그룹, Apple ID, URL, flavor 미입력. 장시간 모바일 웹 회귀 미완

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2 회귀 테스트가 안착/제거 중 드래그, 범프 잔류, geometry stale bump 3건과 pointer flow를 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1/T1/T2/T3/T4a/T4b/T5 근거. T4b ego 문자 중복은 headless에서 재현되지 않아 원인 미확정 |
| PLAN-004 mobile device UI / FPS | PARTIAL | RECHECKED | 2026-09-20 22:09 KST | `99622e9` | INCOMPLETE | Android Chrome35초 rAF 평균63.94FPS/GAP55.94ms. iPhone NAS 미러링 탭/드래그 매치, Safari 특수효과6회/30초 AVG46.3/LOW35.3/GAP53ms, 같은 보드 대기47.7/44.1/28ms. Instruments 분석은 디스크 부족으로 미완. 22:20 사용자 요청으로 원시 기록 정리, 결과 문서 보존. 폰 단독/토스/광고A/B/장시간 미완. [iPhone 상세](IPHONE_NAS_FPS_2026-09-20.md), [Android 상세](ANDROID_NAS_FPS_2026-09-20.md) |
| T6 level celebration | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | 일반 3000ms / reduced motion 즉시, 점수/시간/보상 불변 테스트와 합본 화면 확인 |
| Independent review fixes | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1 입력 3건, 게임 이탈 자원 해제와 release snapshot P2 수정 및 재검증. 합본 HUD 추가 진단은 기존 confetti 겹침으로 마감 |
| NAS Web smoke | PASS | RECHECKED | 2026-09-20 21:20 KST | 제품 main `99622e9` | CURRENT | `tmp/nas-deploy-20260920/`: Wasm 배포 HTTP200, index/bootstrap/wasm/MP3 원격 해시 일치, deep route200, 격리 헤더, 두 모드 랭킹 조회 통과. Android 게임 로드 확인 |
| Apps in Toss 재배포 | PASS | HISTORICAL | 2026-08-15 | d777cf0 | STALE | git 문서: 일반 AIT 재배포. 이후 오디오 수정. 현재 리비전 미재검증 |
| Web 장시간 오디오/FPS | INCOMPLETE | HISTORICAL | 2026-08-23 이전 | PLAN-001 / ADR-004 원문 | UNKNOWN | 짧은 수동 확인만 통과. 장시간 카운터 없음. 원문부터 미완 |
| Android/iOS store device | NOT_RUN | NONE | UNKNOWN | UNKNOWN | UNKNOWN | 출시 체크리스트 미완 |
| Release build F1-T6 revision | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | integrated_final Web build exit=0. 이후 X2와 bomb 후속 변경, 모바일/스토어 실기기 스모크는 별도 미실행 |
| E2 hyper/supernova layer integration | PASS | HISTORICAL | 2026-09-20 19:54 KST | main `c3b64dd` (후속 문서 갱신만 추가) | STALE | `verify_main_after_E2_merge.txt`: main 병합 후 analyze exit=0, 전체 279 tests PASS, Web release build exit=0. 병합 전 독립 78회귀+픽셀4회귀와 실제 보드 캡처도 확인. 실기기 미검증 |
| 매칭 파편 방사형 소멸 | PASS | HISTORICAL | 2026-09-20 20:24 KST | main `9137895` + 미커밋 파편 수정 | STALE | `tmp/match-radial-fx/analyze.log`: analyze exit0, `test.log`: 전체 279 tests PASS. 웹 릴리즈 재빌드와 새 브라우저 캡처는 미실행 |
| 매칭 속도/반짝임/광택 스윕 튜닝 | PASS | RECHECKED | 2026-09-20 21:06 KST | 이 문서를 포함한 main 튜닝 커밋과 동일 제품 코드 | CURRENT | `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_main_tuning_before_commit.txt`: analyze exit0, 전체279tests PASS, Web release build exit0. 앞선 debug hot reload와 화면 유지 확인. 실기기 미검증 |
| 게임 방향 기획 문서화 | PASS | RECHECKED | 2026-09-23 23:17 KST | 문서만 변경, 제품 코드 `b6a949e`와 동일 | CURRENT | 문서 전용 변경. 변경 문서 8개의 상대 링크 전수 확인(깨진 링크 0), 추가 줄 중간점 0, `git diff --check` 통과. 코드 테스트 대상 아님 |
| Supabase 1단계 analyze / test / wasm build | PASS | RECHECKED | 2026-09-23 23:40 KST | `b6a949e` + 미커밋 PLAN-006 변경 | CURRENT | analyze 0건, 전체 300 tests PASS, `flutter build web --release --wasm`(가짜 연결 값) exit 0. 원격 Supabase 미적용이라 실제 서버 동작은 미검증 |
| Supabase 검수 수정 analyze / test / wasm / SQL | PASS | RECHECKED | 2026-09-24 00:30 KST | `b6a949e` + 미커밋 PLAN-006 변경 | CURRENT | `flutter analyze lib test` 0건, 전체 310 tests PASS, `--wasm` 릴리즈 빌드 exit 0. PGlite 하네스 58건, 20건, 보존 OK(`tmp/orca-plan006/`). 전체 `flutter analyze`는 `tmp/fx-prompt-builder`의 기존 info 1건만 보고. 원격, 브라우저 두 탭 미검증 |
| Supabase 원격 스모크 / RLS (로컬 웹 + 실제 백엔드) | PASS | RECHECKED | 2026-09-24 01:05 KST | `e1a75c5` | CURRENT | Playwright 헤드리스, `tmp/local-verify/live.log` 25항목, `live_edge.log` R-1, R-2, RLS. 백엔드 없는 빌드 흐름 3개 시나리오 통과. 시험 데이터 정리 후 0건. 실기기, 토스 WebView 미검증 |
| PLAN-005 1차 통합 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 04:30 KST | `b71ba31` | CURRENT | `flutter analyze lib test` 0건, 전체 373 tests PASS, `--wasm` 릴리즈 빌드 exit 0 |
| PLAN-005 1차 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 04:40 KST | `b71ba31` | CURRENT | Playwright `tmp/local-verify/s8_plan005.js` 15/15(하이퍼 교환, Speed Bonus, Last Hurrah, 기록 화면, 랭킹 제출 1회) |
| Supabase 원격 스모크 재실행(최종 점수 비교) | PASS | RECHECKED | 2026-09-24 05:30 KST | `b71ba31` | CURRENT | `s4_live.js`를 판 도중 점수 대신 제출한 최종 점수와 TimeUp 점수로 비교하게 고친 뒤 26/26 PASS. 시험 데이터 정리 후 사용자, 랭킹, 이벤트, 광고 기록 0건 |
| Android NAS PLAN-005 1차 FPS | PASS | RECHECKED | 2026-09-24 04:50 KST | NAS `b71ba31` | CURRENT | SM-A245N, Android 16, Chrome 153, 90Hz. CDP rAF 20초 플레이 평균 89fps, p95 11.2ms, Last Hurrah 중 약 88fps, 랭킹 제출 200 1회. 장시간, 토스 WebView, 실제 광고 SDK는 미검증 |
| NAS 배포와 캐시 헤더 | PASS | RECHECKED | 2026-09-24 04:45 KST | `b71ba31` | CURRENT | `.htaccess`에 html, js, mjs, wasm, json `Cache-Control: no-cache`. 이전 캐시 파일이 섞여 skwasm이 "function signature mismatch"로 멈추던 문제를 폰에서 재현 뒤 해결 |
| PLAN-005 Step 4, 5 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 05:30 KST | `f2a26ae` | CURRENT | `flutter analyze lib test` 0건, 전체 392 tests PASS, `--wasm` 릴리즈 빌드 exit 0 |
| PLAN-005 Step 4, 5 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 05:40 KST | `f2a26ae` | CURRENT | `s10_plan005b.js` 20/20(두 사용자 같은 시작 보드, 같은 이동 4번 뒤 같은 보드와 점수, 지난주 기록 제외 순위, 레벨 전체 기간, 도전 스테이지 판정과 클리어, `daily_key`, `challenge` 이벤트). 회귀 `s8_plan005.js` 14/14, `s4_live.js` 26/26. HUD 스크린샷 확인 |
| 주간 랭킹 SQL과 익명 사용자 정리 | PASS | RECHECKED | 2026-09-24 05:35 KST | 마이그레이션 4개 원격 적용 | CURRENT | PGlite 주간 27/27, 회귀 60/60, 강제 generic 계획에서 time 조회 주간 인덱스 버퍼 4. 익명 정리는 원격 트랜잭션 안에서 가짜 사용자 5명으로 확인 후 되돌림. advisor는 기존 익명 로그인 경고만 |
| Android NAS PLAN-005 Step 4, 5 | PARTIAL | RECHECKED | 2026-09-24 05:50 KST | NAS `223303e` | CURRENT | 폰 시작 보드가 데스크톱과 같음, 20초 평균 89.3~89.6fps, p95 11.2ms, 주간 제출 200 1회, 도전 스테이지 상태 정상. 같은 탭 재로드 뒤 skwasm 멈춤(ISSUE-007, 기존 문제) 확인. 최종 `2889d7e` 배포 뒤 새 Chrome에서 8/8(이번 회차 평균 76.3fps, p95 22.4ms로 앞선 89fps보다 낮아 발열이나 첫 로드 영향 가능성, 장시간 측정은 PLAN-001) |
| PLAN-008 실험 스위치 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 08:00 KST | `4ed725e` | CURRENT | `flutter analyze lib test` 0건, 전체 431 tests PASS, `--wasm` 빌드 exit 0. 스위치 꺼짐은 8c703a6과 날짜 3개 × 120 입력에서 보드, 점수, 시간이 바이트 단위로 같음(검수 R4) |
| PLAN-008 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 08:05 KST | `4ed725e` | CURRENT | `s15_plan008.js` 13/13(원격 조회와 캐시, Time +5초, 배율 ×2, exp 이벤트, URL 판 랭킹 제외, exp=none 기존 동작, 레벨 7색, 타임 6색). 회귀 s10 20/20, s8 14/14, s14 7/7. 배지와 7색 스크린샷 확인 |

## Next
1. 사용자 플레이테스트: PLAN-005 하단 양식으로 기록하고 D7(시간 보상 T1)을 정한다. 구조 작업 중 코드로 남은 항목은 없다
2. ISSUE-007(PLAN-001): 멀티스레드 skwasm 같은 탭 재로드 멈춤. 권장 순서는 Flutter 업그레이드 뒤 재현 확인, 그래도 나면 Flutter 이슈 보고. 임시 대안(격리 헤더 제거)은 FPS가 절반이라 적용하지 않았다
3. 플레이테스트 때 PLAN-008 스위치를 켜고 끄며 비교한다(원격은 모두 켜짐, `?exp=none`으로 기존 동작). Supabase는 무료 요금제 유지(2026-09-24 사용자 결정)
4. 구조 개편 뒤: 앱인토스 QR 확인(토스 앱이 있는 폰 필요), Play와 App Store용 Google AdMob 연결(ADR-003 개정). 웹(NAS)은 테스트 전용이라 광고 없음
5. 출시 값(운영 광고 그룹, Apple ID, URL)이 오면 TASK-004. PLAN-003 영속 인벤토리는 코인 경제 전 단계로 Phase 6
6. PLAN-001 장시간 모바일 웹 오디오/FPS 측정은 별도 승인 작업

- 합본 HUD 최종 진단(16:08 KST): 무손실 PNG의 추가 밝은 glyph 픽셀 0, 변한 픽셀은 confetti 색 합성으로 설명됐다. pause 150프레임 동안 game render/update 증가 0. 제품 소스 변경 없이 가설 기각. 근거: `_fx_orchestration/reports/T6_integrated_visual_fix.md`.

## 최신 NAS 배포와 Android 계측 (2026-09-20 21:20 KST)
- main `99622e9` 푸시, 로컬 웹 산출물 정리, NAS Wasm 배포 완료. 로컬 개발 서버와 scrcpy 미러링은 종료했다.
- 사용자 첫 이펙트 멈춤 제보를 개발자 도구로 조사 중. 35초/유효 입력34회 측정에서 큰 멈춤은 재현되지 않았으나 90Hz 기기 평균63.94FPS/p95 33.57ms로 성능 검증은 미완. GPU/워커 추적을 포함한 원인 확정이 다음 우선 작업이다.
- 원시자료와 제한은 `tmp/android-fps-20260920/RESULT.md`와 `profile.json`. 초기 화면 GAP280ms와 재측정 GAP55.94ms는 조건이 달라 개선 수치로 비교하지 않는다.

## 재접속 확인과 인계 취소 (2026-09-20 21:26 KST)
- 게임 탭 완전 종료 후 재접속 및 첫 매치/특수효과를 재측정했다. 로딩 최대190.2ms, 첫 매치22.4ms, 첫 bomb/hyper/supernova33.6/44.8/44.8ms. 긴 작업은 첫 매치 이전 Wasm 초기화/초기 렌더 구간에 집중됐다. 최초 사용자 멈춤의 동일 원인 여부는 미확정.
- 상세 근거와 한계: [Android NAS FPS 검증](ANDROID_NAS_FPS_2026-09-20.md). 제품 코드 수정 없음.
- 사용자 요청으로 Claude 인계 예약을 취소(PAUSED)했고 현재 Codex가 계속한다. 기존 Claude에 재개 프롬프트를 보내지 않았다.

## 사용 종료 세션과 브랜치 정리 (2026-09-20 21:31 KST)
- jewelmatch Orca Claude main 세션 `term_15b04b61-db10-4b8c-a439-b4a5739056b8`을 닫았다. 개별 close의 ptyKilled=true, 후속 terminal list의0개, 해당 Claude와 자식 프로세스 부재로 종료를 확인했다. 최초 bulk close의 완료 확인 오류는 개별 종료와 후속 검증으로 해소했다.
- Git/Orca 워크트리는 main1개뿐이며 잔여 작업 워크트리나 prune 대상이 없다. main에 조상으로 포함된 `codex/intoss-level-leaderboard-ui`(643781d) 로컬 브랜치를 `git branch -d`로 삭제했다. 로컬 브랜치는 main만 남는다. 원격 브랜치는 변경하지 않았다.
- main 사용자 변경과 미추적 파일 없음. 원본 에셋/보고서/Android 원시 계측/이전 Worktree 백업 보존. 정리 전 터미널 메타데이터/화면과 브랜치/Worktree 목록은 `_fx_orchestration/backups_pre_cleanup/main-session-20260920/`에 보관했다.
- 기존 Claude 재개 기록을 현재 작업의 인계 대상으로 사용하지 않는다. 취소한 인계 예약은 PAUSED 유지. 현재 Codex 작업과 다른 프로젝트 세션은 유지했다.

## QA 임시 산출물 정리 (2026-09-20 22:20 KST)

- 사용자 요청으로 QA 이미지/렌더 결과, Android/iPhone 계측과 압축 추적, 검증 로그, 제출 ZIP 검사본/패키징 중간본, Flutter 테스트 캐시와 이번 Instruments 잔여물533파일(할당 크기797,634,560바이트)을 정리했다. 과거 기록의 해당 임시 경로는 현재 존재하지 않는다.
- 결과 보고서, 소스/에셋, NAS 배포본과 `match.zip`, 인계 백업, 설계 산출물은 보존했다. 원본 경로가 확인되지 않는 BRICK ZERO 참고 PDF2개는 `tmp/qa/` 아래에 남겼다. 측정 재개 시 원시 기록을 새로 수집한다.

## 이번 미러링 검증 종료 (2026-09-20 22:44 KST)

- 사용자 결정으로 미러링 검증을 마감하고 추가 Instruments/CPU/GPU 프로파일링을 진행하지 않는다. 앞선 정밀 분석 재개와 미러링 유무 비교 제안은 이번 작업의 후속 실행 대상에서 제외한다.
- 기존 FPS 수치와 미검증 범위는 그대로 남긴다. 검증 종료를 전체 성능 검증 통과로 바꾸지 않는다. 실행 중인 iPhone 미러링, scrcpy, Instruments, xctrace 프로세스가 없음을 확인했다.


## 게임 방향 기획 정리 (2026-09-23 23:10 KST)

- 사용자 요청으로 게임 방향 조사 결과를 기획 문서로 정리했다. 조사 범위는 요즘 사가형 공식 도움말, Bejeweled 3 원문 PDF 2종(PopCap 공략집 2010, DS 매뉴얼 2011), Fandom 문서 21개, Reddit 스레드다. 제품 코드, 테스트, 배포 변경은 없다.
- 제안 방향: Bejeweled Blitz식 60초 점수 경쟁을 지금 방식으로 다시 만든다. 타임 모드는 얼굴과 실력 경쟁, 레벨 모드는 진행과 수익, 무한 모드는 휴식 모드로 유지한다. 재화보다 재화 없는 장기 목표(누적 랭크, 배지, 기록)를 먼저 넣는다. 특수 보석 탭 발동은 유지한다.
- 산출물: [Product Spec 게임 방향 기획](../01_PRODUCT_SPEC.md), [ADR-008](../decisions/ADR-008-game-direction-blitz-modernized.md)(Proposed), [PLAN-005](../plans/PLAN-005-blitz-modernized-direction.md)(DRAFT), ROADMAP Phase 5 추가와 Economy의 Phase 6 이동, docs/AGENTS.md 제품 계약 1줄, README 문서 구조의 PLAN-004와 PLAN-005 누락 보완.
- 원문 대조로 특수 보석 룰 11절의 비교 대상 오류를 정정했다. 기존 표의 스왑 조합은 Bejeweled 3가 아니라 Bejeweled Stars 규칙이다. 현재 동작은 바뀌지 않는다.
- GA4 확인: 미연동. `pubspec.yaml`에 분석 SDK가 없고, `web/index.html`에 GA 태그가 없으며, Firebase 설정 파일과 Git 이력상 추가 기록도 없다. 내부 이벤트 로거도 미구현이다. NAS 배포 서버 파일은 따로 열어 보지 않았다.
- 조사 원자료(Fandom 수집본, Reddit 수집본, PDF 페이지 렌더링, 요약)는 `tmp/bejeweled-research/`에 있고 Git 추적 대상이 아니다. 원본 PDF는 저작권 자료라 저장소에 넣지 않았다.
- 커밋과 푸시는 하지 않았다.


## Supabase 기반 구축 1단계 (2026-09-23 23:47 KST)

- 사용자 요청으로 랭킹, 원격 설정, 보충 광고 하루 제한, 이벤트 로그를 Supabase로 옮기는 코드를 구현했다. 결정은 [ADR-009](../decisions/ADR-009-supabase-backend.md), 절차는 [PLAN-006](../plans/PLAN-006-supabase-backend.md).
- 사용자 결정: 랭킹을 Supabase로 옮기고 NAS 기록은 유지하지 않는다. Supabase 연결은 Codex의 Supabase 앱을 대상 조직 권한으로 다시 연결하는 방식으로 한다.
- 구현: 익명 로그인 REST 게이트웨이, 랭킹 서비스 교체(공개 API와 실패 유형 유지), 보충 광고 서버 확인과 세션 로컬 대체, EventLogger와 이벤트 7종 연결, 마이그레이션 SQL(테이블 4개, RPC 5개, 빈도 제한 트리거 2개, 전 테이블 RLS), `config/supabase.json`(Git 제외) 빌드 연결, NAS 배포 스크립트와 앱인토스 빌드 스크립트 반영.
- 검증: `flutter analyze` 0건, 전체 `flutter test` 300건 통과, `--wasm` 릴리즈 웹 빌드 통과(가짜 연결 값, 출력은 `tmp/supabase-wasm-check/`). 배포 스크립트 `bash -n` 통과.
- 차단: Codex Supabase 앱 연결 계정에서 조직 목록이 비어 있고 대상 조직은 권한 오류다. 로컬 CLI는 로그인하지 않았다. 원격 프로젝트 생성, 마이그레이션 적용, 익명 로그인 활성화, 원격 스모크는 연결 복구 뒤 진행한다.
- 커밋과 배포는 하지 않았다. 현재 NAS와 앱인토스 배포본은 여전히 NAS 랭킹을 쓴다.

## Supabase 검수, 보존, 개인정보 (2026-09-24 00:34 KST, Orca 오케스트레이션)

- 원격 없이 할 수 있는 PLAN-006 항목을 Orca 워커로 나눠 처리했다. 워커 9개(Opus 5.5 high 검수 3회, Opus 구현 2회, Sonnet 5 medium 구현 4회), 모두 같은 작업 트리에서 파일 소유를 나눴다.
- 독립 검수 결과 P0, P1은 없었다. P2 4건과 주요 P3를 두 차례 수정했다. 핵심은 웹 다중 탭 세션 충돌, 403 처리, 인증 실패 대기, 익명 사용자 삭제 시 랭킹 보존(`on delete set null`), anon 쓰기 RPC 권한 회수, 이름 문자 규칙이다. 순위 계산 비용과 점수 상한 강화는 실측 뒤로 보류했다.
- 새 파일: `supabase/migrations/20260924090000_stone_match_retention.sql`(game_events 90일, ad_refill_claims 35일 pg_cron 정리 초안), `docs/release/PRIVACY_POLICY_DRAFT.md`(법률 검토 전 초안). PRODUCT_SPEC 스토어 문구 4블록을 Supabase 기준으로 바꿨다.
- 검증: 위 표의 "Supabase 검수 수정" 행. 커밋, 원격 적용, 배포는 하지 않았다.

## 이펙트 프롬프트 빌더 (2026-09-24 01:29 KST 갱신)

- 사용자 요청으로 X 글(도트 마법사 프롬프트)과 Claude 공유 대화를 분석해, 단계별 선택으로 Flutter용 이펙트 제작 프롬프트를 만드는 정적 웹 도구 `tools/fx_prompt_builder/`를 만들었다. 첫 버전은 다른 세션 커밋 `e1a75c5`에 함께 들어갔다.
- 01:29 개편(미커밋): 사용자 피드백에 따라 카드 보상 공개와 Stone Match 전용 맥락을 빼고 범용 구조로 바꿨다. 이펙트 17종(마법과 액션, 퍼즐, 공통), 발동 방식 11가지, 범위 9가지, 시점 4가지. 기본 스타일은 도트, 데모 장면은 마법사 글 구성. 퍼즐 이펙트는 Bejeweled(`tmp/bejeweled-research/`), 캔디크러시 공식 도움말, Tetris Effect 자료를 참고했다. 결과 코드는 source, target, hits, unit 좌표만 받는다.
- 검증: 프롬프트 생성 3,114개 조합에서 빈 값과 중간점 없음. 헤드리스 Chromium으로 11단계 이동, 17개 이펙트 전부 최상위 단계 재생(영향 지점 전부 발동), 발동과 범위와 시점 교차 조합, 길게 누르기 충전, 복사, JSON 내보내기와 불러오기, 새로고침 후 유지, 390px 모바일 가로 넘침 0을 확인했고 페이지 오류는 0건이다. 프롬프트가 지시하는 Flutter와 Flame API(새 `play` 시그니처, `onHit`, `GlobalKey`, `Overlay` 포함)는 점검용 Dart 파일로 `dart analyze` 문제 0건을 확인했다. 이 파일이 전체 `flutter analyze`에 남기던 info 1건도 없앴다.
- 한계: 이 도구로 만든 프롬프트를 실제 AI에 넣어 Dart 이펙트를 생성하고 실행해 보는 끝단 확인은 하지 않았다. 점검 스크립트와 스크린샷은 `tmp/fx-prompt-builder/`(Git 제외). 제품 코드는 바꾸지 않았다.


## PLAN-005 구조 개편 1차 (2026-09-24 05:00 KST, Orca 오케스트레이션)

- 사용자가 D1~D6 권장안을 승인했고, 막히면 권장안으로 진행하라고 했다. 앱인토스 빌드 확인과 광고는 구조 개편 뒤로 미뤘다.
- main 반영: 하이퍼 교환 H1~H3(`f343fad`), Speed Bonus(`936dfee`, BR-052), Last Hurrah(`a2d78d2`, ADR-007 개정), 기록과 장기 목표(`baaff7c`, SCREEN-016), QA 특수 보석 배치 훅(`23d64fb`), 통합 검수 R-1~R-10 수정(`f8a209d`, `b71ba31`). 새 이벤트: `hyper_swap`, `speed_bonus_peak`, `last_hurrah`, `badge_earned`, `rank_up`, `round_end`의 reason `restart`.
- 배포: NAS `b71ba31`. `.htaccess`에 코드 파일 no-cache 헤더를 추가했다. `ranking.php`는 저장소에서 지웠고 NAS 사본 삭제는 사용자 수동 작업이다. 공모전 ZIP 스킬은 `config/supabase.json`을 넣고 Supabase 호스트를 검사한다.
- 앱인토스: `.ait` 테스트 빌드를 올렸고(deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`) QR 확인은 보류했다.
- 검증: 위 표의 PLAN-005 1차 행들. 원격 시험 데이터는 모두 지웠다.
- 이어서 Step 4(C1)와 Step 5(V1)를 Orca 워커 2개(`plan005b-daily`, `plan005b-challenge`)가 별도 워크트리에서 구현 중이다. 결정: D8은 앱인토스 공식 리더보드를 레벨 완료 수로 유지하고 주간 타임 순위는 Supabase가 맡는다. D9는 이동 제한 없이 4의 배수 레벨에 시간 제한 도전 목표(색 보석, 특수 보석 발동, 보석 수)를 섞는다.

## PLAN-005 구조 개편 2차 (2026-09-24 05:55 KST, Orca 오케스트레이션)

- Step 4(C1): 타임 모드는 KST 날짜 시드로 같은 날 같은 시작 보드와 난수 흐름을 쓴다(BR-053). 타임 랭킹은 KST 월요일 0시 기준 주간(BR-095)이며 기록은 지우지 않는다. D8은 앱인토스 리더보드를 레벨 완료 수로 유지. [PLAN-007](../plans/PLAN-007-daily-board-weekly-ranking.md)
- Step 5(V1): 4의 배수 레벨은 색 보석, 특수 발동, 보석 수 목표로 클리어하는 도전 스테이지(BR-043). D9는 이동 제한 미혼합.
- PLAN-006: 90일 비활성 익명 사용자 매일 정리(pg_cron, KST 04:20) 원격 적용.
- 진행: Orca 워커 3개(구현 Opus high와 medium, 독립 검수 Opus high). 검수 P1(NoMoves 새 보드가 판 통계를 지움, 기존 타임 모드 결과 통계에도 영향)과 P2(PG17에서 주간 인덱스 미사용)를 고쳤고, P3는 코드 수정(색 목표 순환, Last Hurrah 난수 날짜 시드, 다시 하기 때 1위 재조회)과 명세 기록(비율 보상 없음, 무제한 재도전, 제출 시각 기준 주)으로 처리했다. QA 훅이 릴리즈에서 `?qaPerf=1`로 열리는 기존 패턴(P3-3)은 앱인토스 WebView에서 URL을 바꾸기 어려워 유지했다.
- 배포와 정리: main `223303e` 푸시, NAS 배포, 워커 해제, 워크트리와 브랜치 정리, 원격 시험 데이터 0건.
- 폰 검증 중 ISSUE-007을 찾았다. 같은 조건의 A/B로 `b71ba31`에서도 재현돼 이번 변경의 회귀가 아님을 확인했다.
- 시험 데이터를 지운 직후 1시간 안에는 폰에 남은 옛 세션이 저장을 409로 거절받는다(지워진 사용자의 토큰이 아직 유효). 운영의 90일 정리는 토큰이 만료된 뒤라 새 가입으로 넘어간다. 폰 검증 전에는 `flutter.supabase_session`을 지운다.

## PLAN-008 실험 기능 일괄 도입 (2026-09-24 08:10 KST, Orca 오케스트레이션)

- 사용자가 지금은 플레이테스트를 할 수 없어 넣을 수 있는 후보를 모두 넣고 나중에 판단하기로 했다. Supabase는 무료 요금제 유지, 앱인토스는 뒤로.
- 스위치 5개: T1 시간 보상, Time 보석, Multiplier 보석, 레벨 7색, Last Hurrah 콤보 배수. 코드 기본값은 꺼짐, 원격 `app_config.gameplay`는 모두 켬(7색은 레벨 10부터). 웹은 `?exp=`로 덮어쓰며 그 판은 랭킹에 올리지 않는다. [PLAN-008](../plans/PLAN-008-experiment-flags.md)
- 그림: Time, Multiplier 배지는 imagegen 내장 도구로 기존 보석 시트를 참고해 만들었다(`assets/images/sprites/Gem_Badges.png`, 원본 `assets/design/gem_badges/`). 숫자는 코드로 그린다. 시계는 Material Icons(Apache 2.0)도 후보였으나 보석 질감과 맞추려고 생성 배지를 썼다. 7번째 색은 시트에 있던 흰 돌이다.
- Orca 워커 3개(gems Opus high, config Opus medium, 검수 Opus high). 검수 P1 2건(7번째 색이 주황으로 그려짐, URL 실험 판 랭킹 반영)과 P2 1건(T1 범위)을 고쳤다. 7번째 색 문제는 검수 전에 브라우저 스크린샷으로도 찾았다.
- 코인 보석은 코인 경제가 없어 제외했다.

## 텍스처 아틀라스 통합 (2026-09-24 09:40 KST, Orca 오케스트레이션)

- 사용자 요청: 쓰는 텍스처는 되도록 한 장으로 묶어 드로우콜을 줄이고 쓰지 않는 것은 뺀다.
- 결과: 보드와 이펙트 30칸은 `board_atlas.webp`, UI 24장은 `ui_atlas.webp`와 `ui_buttons_atlas.webp`. 레거시 시트(Special_Area 3장, flame, supernova 오버레이 등)와 원본 PNG는 `assets/design/legacy/`로 옮겨 번들에서 뺐다. 번들에 남은 이미지는 아틀라스 3장과 타이틀, 스플래시, 배경뿐이다.
- 수치는 TECH_SPEC 3-1 텍스처 아틀라스 절. 텍스처 수와 전환은 크게 줄었고, 보드 그리기 호출은 7회에서 5회. HUD는 작은 아이콘이 흐려지지 않게 호출을 묶지 않아 수는 그대로다(같은 텍스처라 GPU에서 합쳐짐).
- 검증: analyze 0, 전체 437 tests, 작업 전 빌드와 스크린샷 픽셀 비교, 회귀 s15 13/13, s10 20/20, s8, s14 통과. 도구 `tools/pack_atlas.py`와 설정 `tools/atlas/*.json`.

