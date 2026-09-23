# Handoff

> 다음 작업자가 즉시 시작할 정보만 둔다. 프로젝트 전체 상태는 PROJECT_STATUS.md에 둔다.

Updated: 2026-09-24 08:10 KST

## Current State
2026-09-24 08:10: PLAN-008 실험 스위치(T1, Time 보석, Multiplier 보석, 레벨 7색, Last Hurrah 콤보)를 main에 넣고 원격 `app_config.gameplay`를 모두 켰다. 끄려면 대시보드에서 값을 바꾸거나 웹에서 `?exp=none`. URL 실험 판은 랭킹에 올리지 않는다. 검증 스크립트 `tmp/local-verify/s15_plan008.js`.

2026-09-24 05:55: PLAN-005 Step 4(일일 동일 보드, 주간 순위, PLAN-007)와 Step 5(도전 스테이지)를 main `223303e`에 반영하고 NAS에 배포했다. Supabase 마이그레이션 3개(주간 랭킹, 조회 계획 보강, 익명 사용자 정리)를 원격에 적용했다. 워커와 워크트리는 정리했다. 이어서 아이템과 이어하기 이벤트도 연결했다. 남은 것은 D7 플레이테스트와 ISSUE-007(멀티스레드 skwasm 같은 탭 재로드 멈춤, 기존 문제)이다. 폰 검증 스크립트는 `tmp/local-verify/s11_android_p5b.js`, A/B는 `s12_ab.js`, `s13_fps.js`.

2026-09-24 05:40: PLAN-005 1차(하이퍼 교환, Speed Bonus, Last Hurrah, 기록과 장기 목표)를 main `b71ba31`에 반영하고 NAS에 배포했다. 로컬 웹과 실제 백엔드, Android 폰 NAS 검증을 통과했다. 사용자 결정으로 앱 구조 개편 완료가 우선이고 앱인토스 QR 확인과 광고(AdMob)는 그 뒤다. Step 4(일일 동일 보드, 주간 순위)와 Step 5(레벨 도전 스테이지)는 Orca 워커(`plan005b-daily`, `plan005b-challenge`, run `run_588b87db9418`)가 구현 중이다. D8, D9는 권장안으로 정했다(PROJECT_STATUS 하단).

2026-09-24 01:09: Supabase 원격 프로젝트 `stone-match`(ref `irbdozfwptserldnisew`, 서울)에 마이그레이션 2개와 인증 설정을 적용했고, 로컬 웹 빌드로 실제 백엔드 검수를 마쳤다(PLAN-006 Step 2~3). 시험 데이터는 지웠다. 배포는 하지 않았다.

2026-09-24: PLAN-006 로컬 코드의 독립 검수와 두 차례 수정, 보존 마이그레이션 초안, 개인정보처리방침 초안을 마쳤다. 원격 적용은 여전히 Supabase 연결 대기다.

2026-09-23: Supabase 기반 구축(PLAN-006) 1단계 코드와 스키마를 구현했다. 원격 프로젝트 적용은 Codex Supabase 앱 연결 대기다. 아래 게임 방향 기획 상태도 그대로 유효하다.

2026-09-23: 게임 방향 개편을 기획 문서로 정리했다(ADR-008 Proposed, PLAN-005 DRAFT, Product Spec "게임 방향 기획" 절). 사용자 결정 D1~D10 대기 중이며 제품 코드는 바뀌지 않았다. 아래 기존 상태는 그대로 유효하다.

이번 NAS 미러링 검증은 사용자 요청으로 종료했다. Android/iPhone 측정 결과와 한계는 보고서에 보존했고 QA 원시자료는 정리했다. 추가 프로파일링과 미러링 유무 비교를 자동으로 재개하지 않는다.

최신 추가 변경: 중력을 제거한 매칭 파편의 초기 속도를 1.4배, 수명을 65%로 조정했다. 보석 위 유휴 반짝임 밝기는 2/3, 대각선 광택 스윕 속도는 80%다(한 칸 0.9초, 반복 10초). 최종 튜닝은 main에 반영하며 같은 제품 코드에서 analyze, 전체279tests, Web release build가 모두 통과했다. 개발 서버는 사용자 요청으로 정상 종료했고 8080 포트 리스너가 없음을 확인했다. 추가 실행 중인 구현/검증 프로세스는 없다.

문서 팩은 대체 가능(REPLACEABLE). 정본은 docs/. 이전 문서는 archive/docs/. F1~T6가 통합됐고 독립 리뷰의 입력 3건, 자원 해제와 릴리즈 퇴장 문제 2건을 수정했다. 검증 공백은 표에 남아 있다. 최종 합본 HUD 글자 중복 가설은 PNG 픽셀과 실제 렌더 진단에서 기각됐으며 기존 confetti 겹침으로 확인했다. 실기기 전체 검증은 미완이며 Android 단기 계측 결과는 아래 보고서를 따른다. E2 hyper/supernova 레이어 통합은 main `c3b64dd`에 병합했고 main 분석, 전체 279 tests, Web release build를 통과했다. `fx-g2-sprites` Worktree와 연결된 Orca 터미널 2개는 정리했다. 기존 Claude main 세션은 사용자 정리 요청으로 종료했고, 재인계 예약도 취소 상태다.

## Last Completed
- 마이그레이션 가이드 기준으로 운영 칸을 이 팩에 맞춤
- 기존 주제 본문과 문서 전용 PNG 31장 이관
- 코드와 어긋나던 점수 산식, HUD 랭킹, 시계, 제출 시점을 문서에 반영
- 2026-08-23 대체 가능성 점검 12항을 표준 팩만으로 통과. 이후 정본 경로를 docs/로 옮기고 이전 문서는 archive/docs/로 둠
- 2026-09-20 F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료. T2가 F1 독립 검수의 입력 회귀 3건을 수정하고 회귀 테스트를 추가했으며 T5가 특수/HUD glow를 baked atlas로 전환
- 과거 합본 검증 `verify_integrated_final.txt`: analyze 0, 262 tests PASS, Web build 0. X2와 bomb 후속 변경으로 HISTORICAL/STALE
- 2026-09-20 다른 계열 교차 리뷰(X2)에서 확정된 결함 6건 수정을 main에 병합: 로딩 오버레이가 1.2초 뒤 멈추던 문제, iOS 15/16 Safari에서 피치 대신 배속만 바뀌던 문제(`webkitPreservesPitch`), 퇴장 고스트 해상도, 광고 결과 배너 위치, 웹 폴백 로그 rate, `CurvedAnimation` 해제
- 2026-09-20 bomb 범위 효과를 16프레임 플립북에서 정지 그림 5장 + 코드 타임라인 + 구운 글로우 밑깔기로 교체(`bomb_layers.png` 1280×256, `bomb_layer_timeline.dart`). 정점 지름 약 3.1칸, 수명 0.52초 그대로, bomb 텍스처 6.00MiB → 1.25MiB. 병합 직전 검증: analyze 0, 274 tests PASS, Web build 0
- G2 hyper/supernova 정지 레이어 PNG 납품과 정량 게이트 PASS를 확인했다. 제품 통합과 실제 Flutter 렌더 검증, main 병합과 병합 후 데스크톱 검증을 완료했다. 실기기 검증은 별도다.

## In Progress
- Plan: `PLAN-004` 보드 연출 보강. F1, T1, T2, T3, T4a, T4b, T5, T6 구현과 통합 완료. 2026-09-20 통합 브랜치를 커밋해 main에 fast-forward 병합했다(로컬). push 여부는 `git status`로 확인한다
- Task: 실기기 검증. 합본 HUD 진단은 glyph 중복 근거 없음으로 마감했다.
- Task: E2는 main 병합 및 작업 세션 정리 완료. Claude 재인계는 취소됐으며 Codex가 현재 main에서 계속한다.
- 주의: T2의 균등 gem atlas 제출은 batch지만 여러 행의 착지 squash는 `drawImageRect` fallback으로 draw call이 9회를 넘을 수 있다. T5 special glow는 약 4.5MiB 공유 이미지이며 T4a HUD interactions와 painters 구조를 유지한다
- 주의: T4b 타임업은 reduced motion에서도 결과를 즉시 읽히게 하되 1900ms 제출과 버튼 활성 시점을 유지한다. ego 캡처 문자 중복은 headless에서 재현되지 않아 원인 미확정
- 주의: Android Chrome 단기 FPS 계측과 iPhone NAS 미러링 검증을 수행했다. 폰 단독 iPhone 성능, 장시간 WebView, 실제 광고 SDK, 실제 기기 오디오 청취는 미검증이다
- E2 검증: 전체279tests와 Web build exit0, 최종 analyze exit0. 독립 관련78회귀와 별도픽셀4회귀 PASS. 고정pivot, tier, 풀 재사용, 종료, bomb 초기픽셀 및 supernova 외곽번개 보존 확인.
- Plan: `PLAN-001`
- Task: TASK-001c 실기기 30초 이상 카운터 보존

## Next Task
1. 이번 NAS 미러링 검증은 종료했다. 추가 프로파일링은 진행하지 않으며 아래 검증 공백은 별도 요청 전까지 남겨 둔다. Claude 재인계는 취소 상태다. 완료된 E2를 재적용하거나 정리된 Worktree를 재생성하지 않는다.
2. 실기기 FPS, 가독성, 오디오와 광고 흐름 확인. iOS 15/16 기기에서 연쇄와 저시간 틱의 피치가 실제로 오르는지 듣는다
3. `?fps=1`로 모바일 실기기 FPS 전후 비교와 장시간 WebView 확인
4. PLAN-001 실기기 장시간 측정 (원문부터 INCOMPLETE. 별도 승인 작업)
5. 이전 문서는 archive/docs/에 있음. 삭제 여부는 별도 결정
6. STALE AIT 재검증과 PLAN-001 실측은 이관 밖 별도 작업
7. 게임 방향 개편: 코드 작업 완료. D7과 플레이테스트 기록은 사용자 플레이 판단. ISSUE-007은 PLAN-001에서 다룬다
8. Supabase: NAS 배포 완료. 앱인토스 QR 확인은 구조 개편 뒤. 원격 검증 뒤에는 시험 데이터를 지운다(game_events, ad_refill_claims, ranking_entries, 익명 auth.users)
9. 광고는 구조 작업을 끝낸 뒤 손본다(ADR-003 개정). 웹(NAS)은 테스트 전용이라 광고를 넣지 않고, Play와 App Store는 이후 Google AdMob을 `AdService` 구현으로 붙인다. 그 전에는 광고 SDK를 추가하지 않는다

## Blocked
- PLAN-002, TASK-004: 외부 값/정책

## Known Issues
- ISSUE-001, ISSUE-002: 모바일 웹 오디오/FPS. PLAN-001
- ISSUE-003: 광고 3회 세션 로컬
- ISSUE-004: 인벤토리 비영속 (2차 허용)
- ISSUE-005: 빈 App Store ID
- ISSUE-006: 외부 지표 없음(미출시), GA4와 Firebase와 내부 로거 미연동. PLAN-005 Step 2
- PLAN-006: 원격 적용과 검수 완료, 배포 전. 현재 NAS와 앱인토스 배포본은 여전히 NAS 랭킹을 쓴다. `config/supabase.json` 없는 빌드는 랭킹 연결 불가

## Changed Contracts
- PLAN-004: `ParticleBurst`/`ParticlePool` 삭제, `BoardJuiceLayer`로 대체. `hasActiveVisualEffects`는 유휴 반짝임을 포함하지 않음. HUD 점수는 롤업 표시값이고 저장/랭킹은 `board.score` 그대로. F1~T6 통합과 T2 입력 회귀 및 독립 리뷰 P2 수정 완료
- PLAN-004 시각 계약: gem atlas 512×640, 64px 셀, baked sheen, squash fallback, special glow 약 4.5MiB 공유 이미지, T4a HUD 구조 유지
- PLAN-004 화면 계약: T4b 공통 카드/exit/reduced motion, TimeUp 1900ms 제출 및 입력 시점, 레벨 축하 일반 3000ms, reduced motion 즉시 완료
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
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2의 3개 회귀 테스트와 pointer flow 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T1~T5의 ego/headless, 위젯, 픽셀 근거. T4b ego 문자 중복은 headless 재현 없음, 원인 미확정 |
| PLAN-004 mobile device UI / FPS | PARTIAL | RECHECKED | 2026-09-20 22:09 KST | `99622e9` | INCOMPLETE | Android Chrome35초 rAF 평균63.94FPS, p95 33.57ms, GAP55.94ms. iPhone 미러링 특수효과30초 AVG46.3/LOW35.3/GAP53ms. 첫 멈춤 원인과 폰 단독/토스/광고A/B/장시간 미확인. 원시자료는 정리했고 보고서를 보존했다. [Android 상세](ANDROID_NAS_FPS_2026-09-20.md), [iPhone 상세](IPHONE_NAS_FPS_2026-09-20.md) |
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

## Files to Read First
1. progress/PROJECT_STATUS.md
2. 이 파일
3. plans/PLAN-004-board-juice.md
4. plans/PLAN-001-mobile-web-audio-fps.md
5. decisions/ADR-004-web-html-audio-sfx.md
6. 01_PRODUCT_SPEC.md 의 FR-003, FR-010
7. 게임 방향 작업 시: decisions/ADR-008-game-direction-blitz-modernized.md, plans/PLAN-005-blitz-modernized-direction.md, 01_PRODUCT_SPEC.md 의 "게임 방향 기획" 절
8. Supabase 작업 시: decisions/ADR-009-supabase-backend.md, plans/PLAN-006-supabase-backend.md, 03_TECH_SPEC.md 5절

## Resume Commands
이 팩만 보고 실행한다. 비밀은 넣지 않는다.

    flutter test
    flutter analyze

웹 측정이 필요하면 PLAN-001의 웹 빌드 절과 FPS 패널(`?fps=1` 또는 `?qaPerf=1`)을 쓴다.

## Open Questions
- STALE 배포 증거를 현재 리비전에서 재검증할지는 이관 밖 결정
- 21:20 KST Claude 재인계 예약은 사용자 요청으로 PAUSED 처리했다. 인계 프롬프트 전송 없음.
- PLAN-002 식별 저장 정책
- 게임 방향 개편 미결정 사항 D1~D10 (Product Spec "게임 방향 기획" 9절)

## Constraints / Do Not Change
- BR-001, BR-002
- 특수 보석 탭 발동, 스왑 조합 비활성 (ADR-008 Accepted와 D2, D4 결정 전까지 유지)
- 강제 전면 광고 없음
- ranking.php를 웹 빌드/제출 ZIP에 넣지 않음
- Riverpod codegen 금지
- 사용자 문구 중간점 금지
- ADR-004: Web Audio로 되돌리지 말 것
- STALE/INCOMPLETE를 숨기지 말 것. 이전 문서는 archive/docs/
- 정본 docs/와 archive/docs/를 서로 링크로 묶지 말 것
- 현재 작업 폴더는 `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/jewelmatch`의 main이다. 정리된 `fx-g2-sprites`나 이전 통합 Worktree를 사용하지 말 것
- 삭제 전 자료 148파일의 SHA256을 확인했고 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/backups_pre_cleanup/fx-g2-sprites-20260920-e2`에 보존했다. 보고서와 보드 PNG는 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration`에도 유지한다.
- 제품 main `99622e9`는 origin/main 푸시 및 NAS 배포 완료. Android 단기 계측과 iPhone 미러링 검증을 수행했으며 전체 실기기 검증 완료로 오인하지 말 것

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

## iPhone NAS 미러링 제어 확인 (2026-09-20 21:41 KST)

- 제품 `99622e9` NAS Wasm 빌드. iPhone14 Pro Max/iOS26.6.2, 사용자가 미리 연 홈 화면 웹 앱을 Mac iPhone 미러링에서 제어했다. 토스 앱 검증은 아니다. 가설은 미러링으로 실제 게임 입력이 가능하다는 것이며, 진입과 매칭 후 보드/점수 변화로 확인했다. 제품/사운드 설정 변경 없음. 배너 없음, 효과 켜짐, 실제 청취 미검증.
- 무한 모드 진입, 인접 보석을 두 번씩 탭하는 교환2회, 첫 매칭 및 후속 연쇄 동작을 확인했다. 점수0→100→4050, 최대 콤보3. 입력/대기가 섞인 약1분 확인이며 마지막30초 내부 패널은 AVG40.2/LOW31.3/GAP75ms. 진입 직후 GAP1375ms는 로딩이 섞인 창으로 별도 취급한다. 마지막 화면은 이 Codex 대화의 21:38 미러링 캡처에 있으며, 연속 프레임 로그/영상 파일은 수집하지 않았다. 미러링 부하를 분리하지 않았으므로 폰 단독 FPS나 원래 제보한 멈춤의 원인으로 일반화하지 않는다.
- Xcode27.0, USB connected/paired, Developer Mode Enabled, DDI contentIsCompatible=true/isUsable=true 확인. `xctrace list devices`는 처음 Offline, 재조회에서 Devices로 변경됐으나 실제 Animation Hitches 5초 기록 시도는 `Timed out waiting for device to boot`(exit13)로 실패했다. 이후 CoreDevice는 booted/connected를 유지했다. 기기가 꺼진 것으로 해석하지 않으며 Instruments 준비 상태 불일치 원인은 미확정. 유효한 trace/CPU/100ms 이상 이벤트 수/프로세스별 분석 결과 없음.
- 다음 비교는 동일 NAS 무한 모드에서 미러링을 끄고 사용자가 직접 같은 입력을 하는30초 측정이다. 먼저 Instruments 실제 기록 가능 상태를 확인해야 한다. 이번에는 제품 코드/배포 변경 없이 문서만 갱신했으며, 프로파일 명령은 종료됐다. 미러링과 게임은 사용자가 이어 볼 수 있게 유지했다.

## iPhone 후속 반복 테스트 (2026-09-20 22:09 KST)

- 위21:41 기록 이후 테스트를 재개했다. 일반 매칭 탭/드래그와 연쇄를 확인했고, 별도 Safari NAS 진단 보드에서 특수효과를5초 간격6회/30.274초 재생했다. 내부 패널 AVG46.3/LOW35.3/GAP53ms. 같은 보드30.404초 대기는47.7/44.1/28ms. 미러링이 켜진 조건이며 폰 단독/토스 결과로 일반화하지 않는다.
- Instruments GUI에서는30초 기록과 원시3.4GiB 생성을 확인했다. 후처리 중 Mac 디스크 부족과 앱 종료로 분석 실패. 축소 추출도 공간 부족으로 중단하고 이번 실행의 임시 캐시만 정리했다. 원시 기록은 압축526MB, SHA256 왕복 검증 후 보존했다. 긴 멈춤 건수/CPU/GPU 분석 완료로 표시하지 않는다.
- [iPhone NAS 검증](IPHONE_NAS_FPS_2026-09-20.md)에 조건, 결과, 차단 상태와 복구 경로를 기록했다. 측정 탭/추적 프로세스 정리, 기존 Safari 탭과 홈 화면 앱 보존. 제품 코드/배포/커밋/푸시 변경 없음.
- 22:11 원래 홈 화면 앱 복귀 시 재로딩 후 타이틀 표시. 이전 보드 복원은 확인되지 않았으며, 백그라운드 복귀/메모리 상황을 분리한 추가 확인 대상으로 남긴다.

## QA 임시 산출물 정리 (2026-09-20 22:20 KST)

- 사용자 요청으로 `tmp/qa/`의 임시 파일, `tmp/android-fps-20260920/`, `tmp/nas-deploy-20260920/`, `tmp/match-radial-fx/`, `tmp/match-radial-tuning/`, `tmp/stone_submission_package/`, `build/test_cache/`, `build/unit_test_assets/`와 이번 Instruments 실행의 잔여 임시 폴더를 정리했다. 총533파일, 할당 크기797,634,560바이트. 실행 중인 계측/개발 서버와 대상 파일의 열린 핸들은 없었다.
- `tmp/qa/`에는 원본 위치가 사라진 BRICK ZERO 참고 PDF2개만 남겼다. 사용자 소스/에셋, 제품 빌드/배포본, 제출 ZIP, 인계 백업, 결과 문서는 유지했다. Git 변경은 보고서/상태 문서뿐이다.
- 위 시간별 기록의 원시자료 보존 설명은22:20 정리 이전 상태다. Android 프레임/CPU 기록과 iPhone 압축 추적은 현재 없으며 재분석하려면 새 측정이 필요하다. 확정된 수치와 미검증 범위는 두 실기기 보고서에 남겼다.

## 미러링 검증 종료 결정 (2026-09-20 22:44 KST)

- 사용자가 미러링 검증을 종료하고 추가 프로파일링을 하지 않기로 했다. 위 과거 항목의 Instruments 재개, 원시 추적 재수집, 미러링 유무 비교를 자동으로 이어서 실행하지 않는다.
- 기존 Android/iPhone 측정 수치와 한계만 보존한다. 전체 성능 검증을 통과한 것으로 해석하지 않는다. iPhone 미러링, scrcpy, Instruments, xctrace 프로세스는 모두 실행 중이지 않다. 제품 코드/배포 변경 없음.


## 게임 방향 기획 정리 (2026-09-23 23:10 KST)

- 게임 방향 개편은 제안 단계다. 본문은 [Product Spec 게임 방향 기획](../01_PRODUCT_SPEC.md) 절, 결정은 [ADR-008](../decisions/ADR-008-game-direction-blitz-modernized.md)(Proposed), 구현 단계는 [PLAN-005](../plans/PLAN-005-blitz-modernized-direction.md)(DRAFT)다.
- 다음 작업자는 사용자 결정(D1~D10) 없이 특수 보석 규칙, TimeUp 제출 시점, 랭킹 정책을 바꾸지 않는다. 결정이 오면 PLAN-005 Step 0 게이트를 체크하고 Step 1a(하이퍼 큐브 교환)부터 시작한다.
- 하이퍼 교환의 코드 진입점은 `lib/game/match_board_input.dart`의 `_triggerSpecialSwapImpl`(현재 항상 false)과 같은 파일의 특수 보석 탭 분기, 연쇄 큐는 `match_board_specials.dart`의 `includeHyper` 조건이다.
- 외부 지표는 미출시라 없고 분석 도구도 없다(ISSUE-006). 출시 전 판단은 Product Spec 8-2 플레이테스트 항목으로 하고 결과를 PLAN-005 하단에 기록한다.
- 조사 원자료는 `tmp/bejeweled-research/`(Git 미추적)에 있다. 원본 PDF는 저장소에 넣지 않는다.
- 제품 코드, 테스트, 배포 변경 없음. 커밋하지 않았다.


## Supabase 기반 구축 인계 (2026-09-23 23:47 KST)

- 2026-09-24 갱신: 원격 연결은 Supabase CLI 로그인으로 한다(Codex Supabase 앱은 조직을 보지 못함). 저장소는 `supabase link`로 `irbdozfwptserldnisew`에 연결돼 있다(`supabase/.temp`, Git 제외). SQL 확인은 `supabase db query --linked`, 권고는 `supabase db advisors --linked`. DB 비밀번호는 `tmp/supabase-remote/db-password`.
- 원격 인증 설정을 바꿀 때는 저장소 `supabase/config.toml`(로컬 개발용 값 포함)을 밀지 않는다. `tmp/supabase-remote/push/supabase/config.toml`처럼 바꿀 값만 적은 파일로 `supabase config diff` 뒤 `config push`한다.
- 실제 백엔드 재검수: `flutter build web --release --wasm --base-href / --dart-define=STORE_CHANNEL=intoss --dart-define=INTOSS_AD_MODE=mock --dart-define-from-file=config/supabase.json -o tmp/local-verify/web-live`, `cd tmp/local-verify && DIR=web-live PORT=8766 node serve.js`, 다른 터미널에서 `BASE=http://127.0.0.1:8766 node s4_live.js`, `node s5_live_edge.js`. 끝나면 시험 사용자와 행을 SQL로 지운다.
- 아직 확인하지 않은 것: 익명 가입 빈도 제한 값(원격 기본값 유지), 실기기와 앱인토스 WebView, pg_cron의 실제 새벽 실행(`cron.job_run_details`).
- 검수 기록과 PGlite 하네스는 `tmp/orca-plan006/`(Git 제외)에 있다. `review/`, `recheck/`, `recheck2/` 보고서와 `pglite/run_fixed.mjs`, `recheck/sql_recheck_fixed.mjs`, `retention/test.mjs`로 SQL을 다시 확인할 수 있다.
- 개인정보처리방침은 `docs/release/PRIVACY_POLICY_DRAFT.md` 초안이다. 문의처, 광고 SDK 수집 항목, 보관 기간, 국외 이전 해석은 [확정 필요]다.
- `config/supabase.json` 없이 만든 빌드는 랭킹이 연결 불가로 표시된다. 운영 앱인토스 빌드(`npm run build:intoss`)는 파일이 없으면 실패한다. 공모전 ZIP 스킬은 아직 config를 넣지 않는다.
- NAS `ranking.php`는 새 빌드 배포 전까지 기존 배포본이 계속 쓴다. 폐기 시점은 사용자 결정 대기.
- 제품 코드와 문서는 `d102ee3`, `a13b121`, `e1a75c5`로 로컬 커밋됐고 push 전이다. 이 인계 갱신은 그 뒤의 미커밋 변경이다.

## 이펙트 프롬프트 빌더 인계 (2026-09-24 01:29 KST 갱신)

- `tools/fx_prompt_builder/index.html`을 브라우저로 열어 쓴다. 구조와 참고 출처는 같은 폴더 `README.md`.
- 01:29 범용 개편은 미커밋이다. 첫 버전은 `e1a75c5`에 들어가 있다. 저장 키가 `fxPromptBuilder.v2`로 바뀌어 첫 버전의 브라우저 저장값은 읽지 않는다.
- 이펙트 종류를 늘리려면 `data.js`의 `FX.EFFECTS`에 추천값 묶음을 추가한다. 새 발동 방식이나 범위는 `FX.DELIVERIES`, `FX.AREAS`와 `preview.js`의 `buildHits`, `hitTimes`, `drawDelivery`, `prompt.js`의 `deliveryText`, `areaText`를 함께 고친다.
- 재검증: 저장소 루트에서 `node tmp/fx-prompt-builder/smoke.js`(조합 생성), `tmp/fx-prompt-builder`에서 `node e2e2.js`(브라우저, `playwright-core`와 사용자 캐시의 헤드리스 Chromium 필요).
