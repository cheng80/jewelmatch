# PLAN-006 Supabase 기반 구축

## Metadata
- Plan ID: `PLAN-006`
- Title: 랭킹, 원격 설정, 보충 광고 제한, 이벤트 로그를 Supabase로 옮긴다
- Status: `IN_PROGRESS`
- Related Requirement: `FR-009`, `FR-010`, `BR-103`
- Related ADR: `ADR-009`, `ADR-003`, `ADR-007`
- Owner:
- Updated: 2026-09-24

## 1. 목표
서버 저장이 필요한 기능을 사용자 조직의 Supabase 프로젝트로 옮긴다. 게임은 설정이 없는 빌드와 서버 장애에서도 지금처럼 플레이된다.

## 2. 범위
### 포함
- 스키마: `supabase/migrations/20260923142920_stone_match_init.sql` (`app_config`, `ranking_entries`, `ad_refill_claims`, `game_events`, RPC 5개, 트리거 2개)
- 클라이언트: `SupabaseConfig`, `SupabaseGateway`, `BackendBootstrap`, `EventLogger`, `AdRefillLimitBackend`, `RankingService` 교체, `AdRewardPolicy` 서버 확인
- 빌드: `config/supabase.json`(Git 제외), `package.json` 앱인토스 스크립트, `tools/deploy_match_web.sh`
- 원격: 프로젝트 준비, 마이그레이션 적용, 익명 로그인 활성화, 공개용 키 발급, 원격 스모크와 RLS 음성 확인

### 제외
- NAS 랭킹 기록 이관(사용자 결정: 유지 불필요)
- 영속 인벤토리(PLAN-003), 기록과 배지(PLAN-005 R1), 일일 동일 보드(PLAN-005 C1)
- 외부 분석 SDK
- 토스 사용자 식별자 사용

## 3. 현재 상태 / 전제
- NAS `ranking.php`는 인증 없는 JSON 파일 저장(모드별 상위 30건). 기록 유지 불필요.
- 보충 광고 제한은 세션 메모리(BR-103).
- 웹은 `--wasm` 빌드. 앱인토스도 같은 웹 빌드.
- 2026-09-23 기준 Codex의 Supabase 앱 연결 계정에서 대상 조직이 보이지 않는다(조직 목록 빈 값, 대상 조직 권한 오류). 로컬 CLI는 로그인하지 않았다. 원격 작업은 연결 복구 뒤 진행한다.
- 반드시 유지할 계약: BR-001, BR-002, BR-090~BR-093, ADR-003 광고 위치 3개, ADR-007 제출 시점, 사용자 문구 중간점 금지, secret 키 비노출.

## 4. 구현 계획
### Step 1 — 로컬 준비 (완료 2026-09-23)
- [x] `supabase init`, 마이그레이션 작성, 로컬 `config.toml` 익명 로그인 허용
- [x] REST 게이트웨이(익명 가입, 갱신, 401 1회 재시도, 동시 인증 단일화, 오류 분류)
- [x] 랭킹 서비스 교체(공개 API와 실패 유형 유지)
- [x] 보충 광고 서버 확인과 세션 로컬 대체, 인벤토리 오버레이 동기화
- [x] 이벤트 로거와 연결 지점: `session_start`, `round_start`, `round_end`(time_up, exit), `level_clear`, `stage_continue`, `ranking_submit`, `ad_reward`
- [x] 테스트: 게이트웨이 9건, 랭킹 7건, 이벤트 로거 5건, 보충 광고 서버 5건 추가. 전체 300건 통과, analyze 0건, `--wasm` 릴리즈 빌드 통과

### Step 1b — 독립 검수와 수정 (2026-09-24, Orca 오케스트레이션)
- [x] 1차 독립 검수(Opus 5.5 high, 읽기 전용, PGlite 하네스): P0, P1 없음. P2 4건(웹 다중 탭 refresh 회전 충돌, 403을 만료로 처리, 인증 실패 대기 없음, 익명 사용자 삭제 시 랭킹 연쇄 삭제), P3 9건
- [x] 1차 수정: `ranking_entries.user_id` null 허용과 `on delete set null`, anon의 쓰기 RPC 실행 권한 회수, 빈도 제한 트리거 사용자별 advisory lock, 이름 금지 문자 제약, 403은 재시도 없이 `rejected`, 인증 실패 대기(60초부터 2배, 상한 10분), `expires_in` 우선, 보충 광고 대기 중 닫힘 처리, 제출 대기 상한 8초, 로컬 보충 날짜 KST
- [x] 재검수(Opus 5.5 high): 웹 다중 탭 문제 미해결(저장소가 탭별 캐시만 읽음), 이름 제약이 ZWJ 이모지를 막는 회귀, 제출 상한 16초 경로 등
- [x] 2차 수정: 웹은 인증 직전과 새 가입 직전에 `SharedPreferences.reload()` 뒤 저장된 세션을 다시 읽음, 저장된 refresh 토큰이 다르면 만료여도 그 토큰으로 갱신, 제출 8초 단일 마감, 네트워크 실패 대기 10초 고정, 시계 역행 시 대기 해제, 갱신 뒤에도 401이면 인증 대기, 이름 규칙에서 ZWJ와 ZWNJ 허용과 금지 문자 추가, `submit_ranking`은 금지 문자를 지우고 보이는 문자가 없으면 `GUEST`
- [x] 2차 확인 검수(Opus 5.5 high): R-1~R-8 해결. 새 P3 2건(ZWJ만 있는 이름, 정리 뒤 빈 이름)은 총괄이 반영하고 PGlite로 확인
- [x] 최종 검증: `flutter analyze lib test` 0건, 전체 `flutter test` 310건 통과, `flutter build web --release --wasm` 종료 0. PGlite 하네스: 1차 검수 기준 58건, 재검수 기준 20건, 보존 마이그레이션 OK
- 남은 확인: 실제 브라우저 두 탭에서 세션 공유, 앱인토스 채널의 8초 마감 실측, 원격 GoTrue refresh 재사용 감지 동작. 8초 상한 뒤 서버 저장이 늦게 성공하면 TimeUp 재제출로 같은 점수가 두 번 기록될 수 있다(BR-090상 허용 범위, 추후 판단)
- 보류: 순위 계산 비용(행 수 비례), 점수 상한 강화. 실측 최대 점수와 행 증가 추이를 본 뒤 정한다

### Step 2 — 원격 프로젝트 준비 (완료 2026-09-24)
- [x] 연결: Codex Supabase 앱은 조직을 보지 못해 Supabase CLI 로그인으로 진행했다
- [x] 프로젝트 생성: 조직 `faewovqniqkzgjqoggwk`, 이름 `stone-match`, ref `irbdozfwptserldnisew`, 서울. 요금제는 CLI로 확인할 수 없어 사용자 승인 뒤 생성. DB 비밀번호는 `tmp/supabase-remote/db-password`(Git 제외, 권한 600)
- [x] 마이그레이션 적용: `supabase db push`로 init, retention 2개. `supabase migration list`에서 로컬과 원격 일치
- [x] 권고: 보안 0건, 성능은 새 DB의 미사용 인덱스 INFO 6건뿐. `cron.job` 2건 활성, anon 실행 권한은 `get_ranking`만
- [x] 인증 설정: 익명 로그인 켬, 이메일 가입 끔. `tmp/supabase-remote/push/supabase/config.toml`에 두 값만 적어 `config push`(나머지 원격 설정은 그대로)
- [x] 공개용 키와 URL로 `config/supabase.json` 작성, Git 제외 확인

### Step 3 — 원격 검증 (완료 2026-09-24)
방법: `STORE_CHANNEL=intoss`, `INTOSS_AD_MODE=mock`, `config/supabase.json`을 넣은 `--wasm` 릴리즈 빌드를 로컬 서버로 띄우고 Playwright(헤드리스 Chromium)로 조작했다. 게임 조작은 `qaPerf=1` QA 훅(힌트 수, 남은 시간 설정, 상태 읽기)을 썼고, 서버 값은 `supabase db query --linked`로 대조했다. 스크립트와 로그는 `tmp/local-verify/`(Git 제외).
- [x] 게임 흐름(백엔드 없는 빌드): 타임 모드 시간 종료, 랭킹 연결 불가 문구와 다시 제출 버튼, 보충 광고 3회 뒤 비활성, 일시정지 나가기(토스 제출 무응답 8.3초, 브리지 없음 0.07초), 외부 요청 0건, 페이지 오류 0건
- [x] 실제 백엔드 25항목: 익명 가입 1회, 세션 저장, 시간 종료 제출 200과 순위 문구, 서버 기록 일치, 두 번째 탭 가입 없음, 보충 광고 3회 `claim_ad_refill` 200과 4번째 비활성, 서버 3건, 새 페이지에서 서버 값으로 0회, 다른 사용자는 3회, anon `get_ranking`에 `user_id` 없음, RLS 음성 5건(401), 이벤트 6종 적재, 토큰과 이메일 미포함, 4xx와 5xx 없음
- [x] 경계 조건: 다른 탭이 refresh 토큰을 회전하고 12초 뒤 이 탭이 401을 받아도 새 가입과 옛 토큰 재사용 없이 저장된 세션을 채택해 재제출 200(R-1). 서버와 토스 제출이 모두 무응답이어도 나가기 8.2초(R-2). 인증 사용자도 다른 사용자 보충 기록과 랭킹 `user_id`를 못 봄
- [x] 보존 함수 원격 수동 실행(삭제 0건)
- [x] 시험 기록 정리: 익명 사용자 6명, 랭킹 3건, 보충 6건, 이벤트 44건을 지워 모두 0건
- [x] 발견 후 수정(2026-09-24): 보충 한도에 걸리면 버튼이 "광고 준비 중"으로 보여 한도를 알리지 못했다. 버튼은 비활성 한도 문구, 안내 줄은 다음 충전 시각(KST 0시)으로 바꿨고, 광고를 본 뒤 서버가 한도로 거절한 경우도 한도 문구로 알린다(`RefillGrantOutcome`, 이벤트 `outcome`). 위젯 테스트 2건, 정책 테스트 2건 추가. 로컬 웹에서 영어, 한국어 보충 시나리오 17항목과 실제 백엔드 25항목 재통과

### Step 4 — 배포와 정리
- [x] NAS 웹 배포(2026-09-24, `56e55a6`): 데스크톱 Playwright로 익명 가입, 랭킹 제출과 서버 기록, 두 번째 탭 사용자 유지, RLS 음성 5건, 이벤트 적재 확인. 광고가 꺼진 웹 빌드라 보충 광고 항목은 해당 없음. 안드로이드 실기기(SM-A245N, Android 16, Chrome 153)를 ADB 원격 디버깅으로 조작해 로드 4.7초, 익명 가입, 시간 종료 제출 200, 이벤트 적재 확인. 20초 플레이 rAF 평균 68.7fps(90Hz), p95 33.5ms, 최대 101ms. 시험 사용자와 행은 모두 삭제
- [ ] 앱인토스 테스트 빌드: `.ait`(appName `stonematch`, 압축 해제 66.5MB) 빌드와 `ait deploy` 콘솔 업로드 완료(deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`). 토스 앱 QR 실기기 확인은 사용자 결정으로 구조 개편 뒤로 미룸. 참고: 연결한 안드로이드 폰에는 토스 앱이 없다
- [x] 공모전 ZIP 스킬: 권장안대로 `config/supabase.json`을 빌드에 넣고, 검사 기준을 `ranking.php` 주소에서 Supabase 프로젝트 주소로 바꿨다. 설정 파일이 없으면 중단하고 ZIP에 설정 파일은 넣지 않는다. 시험 출력으로 끝까지 통과
- [x] NAS `ranking.php` 폐기(2026-09-24): 새 빌드 모두 호출하지 않음을 확인하고 저장소에서 제거. NAS에 남은 파일과 JSON 삭제는 사용자 수동 작업
- [x] 개인정보처리방침 초안과 스토어 데이터 안내 문구 갱신: [PRIVACY_POLICY_DRAFT.md](../release/PRIVACY_POLICY_DRAFT.md)(한국어, 영어, Apple App Privacy, Google Play Data safety 표), PRODUCT_SPEC 스토어 문구 4블록. 법률 검토, 문의처, 광고 SDK 수집 항목, 보관 기간은 [확정 필요]
- [x] 요금제와 일시 중지 정책 확인(2026-09-24 사용자 결정: 무료 요금제 유지): 조직 요금제는 CLI로 조회되지 않아 대시보드 확인이 필요하다. Free 요금제는 약 7일 동안 활동이 적으면 일시 중지되고, 1주 전 경고 메일이 오며, 대시보드에서 1년 안에 재개할 수 있다(Supabase 문서 Project Pausing). 일시 중지되면 BR-002에 따라 게임은 계속되고 랭킹만 연결 불가로 보인다. 출시 전에 유료 요금제 여부를 정한다(비용 결정)

### Step 5 — 후속
- [x] 보존 기간 정리 마이그레이션 초안: `supabase/migrations/20260924090000_stone_match_retention.sql`. `game_events` 90일, `ad_refill_claims` 35일, 매일 KST 04:00과 04:10 pg_cron, private SECURITY DEFINER 함수, 재실행 안전. PGlite 스텁으로 확인. 원격 pg_cron 동작은 Step 2 뒤 확인
- [x] 오래된 익명 사용자 정리(2026-09-24, 원격 적용): `20260924140000_stone_match_anon_cleanup.sql`. 관리자 API 대신 Supabase 익명 로그인 공식 문서의 SQL과 pg_cron 방식을 따랐다. 가입, 로그인, 세션 갱신이 모두 90일보다 오래된 익명 사용자만 매일 KST 04:20에 지운다. 랭킹은 `on delete set null`이라 남는다. 원격 트랜잭션 안에서 가짜 사용자 5명으로 확인 후 되돌림
- [ ] PLAN-003 영속 인벤토리의 서버 백업 여부
- [x] PLAN-005 기록, 배지, 일일 시드 테이블: 필요 없음. 기록과 배지는 로컬 저장(Product Spec 6-6), 일일 시드는 클라이언트 계산, 주간 순위는 `ranking_entries.week_start`(PLAN-007)
- [ ] 클라이언트 원격 설정 읽기(기능 플래그가 생길 때)

## 5. 예상 변경 범위
- 파일/모듈: `lib/services/backend/`, `lib/services/event_logger.dart`, `lib/services/ranking_service.dart`, `lib/ads/ad_reward_policy.dart`, `lib/ads/ad_refill_limit_backend.dart`, `lib/views/game_view.dart`, `lib/views/overlays/stage_inventory_overlay.dart`, `time_up_overlay.dart`, `pause_menu_overlay.dart`, `lib/vm/ranking_notifier.dart`, `lib/game/match_board_game*.dart`, `lib/main.dart`, `lib/app_config.dart`
- DB/API 영향: 랭킹 API가 NAS PHP에서 Supabase RPC로 바뀐다. TECH_SPEC 5절
- UI 영향: 없음(문구와 화면 동일). 보충 광고 남은 횟수가 서버 값으로 맞춰진다
- 배포/마이그레이션 영향: `config/supabase.json` 없이 만든 빌드는 랭킹이 연결 불가로 표시된다. 운영 앱인토스 빌드는 파일이 없으면 실패한다

## 6. 검증 계획
- [x] Unit test(게이트웨이, 랭킹, 이벤트 로거, 보충 광고)
- [x] `flutter analyze`, 전체 `flutter test`, `--wasm` 릴리즈 빌드
- [x] 원격 REST 스모크와 RLS 음성 확인(Step 3, 2026-09-24 로컬 웹과 실제 백엔드)
- [x] 브라우저 확인(Step 3, Playwright 헤드리스)
- [ ] NAS, 앱인토스 확인(Step 4)

## 7. 위험 / 미해결 사항
- 익명 사용자는 저장소 삭제로 새로 만들어진다. 보충 제한 우회 가능, 기기 간 기록 연결 없음
- 클라이언트 점수를 그대로 믿는다. 상한과 빈도 제한만 있다
- 무료 요금제 일시 중지, 행 증가
- 앱인토스 WebView에서 `*.supabase.co` 호출 확인 필요(현재 NAS 외부 호출은 동작)

## 8. 완료 조건
- [x] 원격 프로젝트에 스키마 적용, 권고 확인, 익명 로그인 활성화
- [x] 원격 스모크와 RLS 음성 확인
- [ ] NAS와 앱인토스 빌드에서 랭킹, 보충 제한, 이벤트 동작 확인(NAS 완료, 앱인토스 QR은 구조 개편 뒤)
- [x] PROJECT_STATUS, HANDOFF 갱신(Step 3까지)
