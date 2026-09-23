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

### Step 2 — 원격 프로젝트 준비 (Supabase 연결 대기)
- [ ] Codex Supabase 앱이 대상 조직을 보는지 확인
- [ ] 프로젝트 선택 또는 생성. 이름 `stone-match`, 지역 `ap-northeast-2`(서울). 생성 전 비용 조회, 비용이 있으면 사용자 확인
- [ ] 마이그레이션 적용(`apply_migration`, 이름 `stone_match_init`, 로컬 파일과 같은 SQL)
- [ ] `get_advisors` 보안, 성능 권고 확인과 수정
- [ ] 익명 로그인 활성화(Authentication > Sign In / Providers). 도구로 바꿀 수 없으면 대시보드에서 한 번 켠다
- [ ] 공개용 키와 URL 조회 → `config/supabase.json` 작성(Git 제외 확인)

### Step 3 — 원격 검증
- [ ] REST 스모크: 익명 가입, `get_ranking` 빈 목록, `submit_ranking` 시험 기록, `ad_refill_status`, `claim_ad_refill` 4회째 거절, `game_events` 삽입
- [ ] RLS 음성 확인: anon의 `user_id` 조회 거부, 다른 사용자의 보충 기록 미노출, anon의 제출 거부, `game_events` 조회 거부
- [ ] 시험 기록 정리: 운영 랭킹에 유효한 시험 기록을 남기지 않는다. 스모크 기록은 확인 직후 SQL로 삭제하고 건수를 남긴다
- [ ] `flutter run -d chrome --dart-define-from-file=config/supabase.json`으로 제출, 목록, 보충 광고(mock), 이벤트 적재 확인

### Step 4 — 배포와 정리
- [ ] NAS 웹 배포(`tools/deploy_match_web.sh`, config 포함)와 원격 확인
- [ ] 앱인토스 테스트 빌드(`npm run build:intoss:test`)와 QR 확인
- [ ] 공모전 ZIP 스킬(`build-stone-match-submission`)이 config를 넣도록 조정할지 결정
- [ ] NAS `ranking.php` 폐기 시점 결정. 폐기 전까지 파일은 NAS와 저장소에 남긴다
- [x] 개인정보처리방침 초안과 스토어 데이터 안내 문구 갱신: [PRIVACY_POLICY_DRAFT.md](../release/PRIVACY_POLICY_DRAFT.md)(한국어, 영어, Apple App Privacy, Google Play Data safety 표), PRODUCT_SPEC 스토어 문구 4블록. 법률 검토, 문의처, 광고 SDK 수집 항목, 보관 기간은 [확정 필요]
- [ ] 요금제와 일시 중지 정책 확인

### Step 5 — 후속
- [x] 보존 기간 정리 마이그레이션 초안: `supabase/migrations/20260924090000_stone_match_retention.sql`. `game_events` 90일, `ad_refill_claims` 35일, 매일 KST 04:00과 04:10 pg_cron, private SECURITY DEFINER 함수, 재실행 안전. PGlite 스텁으로 확인. 원격 pg_cron 동작은 Step 2 뒤 확인
- [ ] 오래된 익명 사용자 정리: SQL로 `auth.users`를 지우지 않고 관리자 API로 처리한다. 랭킹은 `on delete set null`이라 남는다
- [ ] PLAN-003 영속 인벤토리의 서버 백업 여부
- [ ] PLAN-005 기록, 배지, 일일 시드 테이블
- [ ] 클라이언트 원격 설정 읽기(기능 플래그가 생길 때)

## 5. 예상 변경 범위
- 파일/모듈: `lib/services/backend/`, `lib/services/event_logger.dart`, `lib/services/ranking_service.dart`, `lib/ads/ad_reward_policy.dart`, `lib/ads/ad_refill_limit_backend.dart`, `lib/views/game_view.dart`, `lib/views/overlays/stage_inventory_overlay.dart`, `time_up_overlay.dart`, `pause_menu_overlay.dart`, `lib/vm/ranking_notifier.dart`, `lib/game/match_board_game*.dart`, `lib/main.dart`, `lib/app_config.dart`
- DB/API 영향: 랭킹 API가 NAS PHP에서 Supabase RPC로 바뀐다. TECH_SPEC 5절
- UI 영향: 없음(문구와 화면 동일). 보충 광고 남은 횟수가 서버 값으로 맞춰진다
- 배포/마이그레이션 영향: `config/supabase.json` 없이 만든 빌드는 랭킹이 연결 불가로 표시된다. 운영 앱인토스 빌드는 파일이 없으면 실패한다

## 6. 검증 계획
- [x] Unit test(게이트웨이, 랭킹, 이벤트 로거, 보충 광고)
- [x] `flutter analyze`, 전체 `flutter test`, `--wasm` 릴리즈 빌드
- [ ] 원격 REST 스모크와 RLS 음성 확인(Step 3)
- [ ] 브라우저 수동 확인과 NAS, 앱인토스 확인(Step 3, 4)

## 7. 위험 / 미해결 사항
- 익명 사용자는 저장소 삭제로 새로 만들어진다. 보충 제한 우회 가능, 기기 간 기록 연결 없음
- 클라이언트 점수를 그대로 믿는다. 상한과 빈도 제한만 있다
- 무료 요금제 일시 중지, 행 증가
- 앱인토스 WebView에서 `*.supabase.co` 호출 확인 필요(현재 NAS 외부 호출은 동작)

## 8. 완료 조건
- [ ] 원격 프로젝트에 스키마 적용, 권고 확인, 익명 로그인 활성화
- [ ] 원격 스모크와 RLS 음성 확인
- [ ] NAS와 앱인토스 빌드에서 랭킹, 보충 제한, 이벤트 동작 확인
- [ ] PROJECT_STATUS, HANDOFF 갱신
