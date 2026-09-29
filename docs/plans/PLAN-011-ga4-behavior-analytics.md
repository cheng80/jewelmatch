# PLAN-011 GA4와 상세 행동 분석

## Metadata
- Plan ID: `PLAN-011`
- Status: `IN_PROGRESS` (2026-09-30 NAS Step2 배포 및 검증 완료. Step3 분석 보고서와 native/intoss 연결은 후속 범위)
- Related Requirement: 활성 사용자, 재방문, 유입, 퍼널과 게임 패턴
- Related ADR: ADR-010(PocketBase 내부 이벤트), PLAN-010에서 확정할 식별 결정
- Owner: 분석 연동 작업자와 독립 검수자
- Updated: 2026-09-29

## 1. 목표
기존 EventLogger를 통해 GA4에 필요한 행동을 전달하고, PocketBase `sm_events`의 판 요약과 연결해 해석 가능한 보고서를 만든다.

## 2. 범위
- 포함: 전송 어댑터, 이벤트/필드 사전, 채널과 환경 구분, 보고서와 수집 검증.
- 제외: 현재 실행의 SDK 설치/외부 프로젝트 생성/콘솔 설정, 모든 프레임/보석 입력 전수 전송, 이메일/닉네임/토스 원본키 전송.

## 3. 현재 상태 / 전제
- 외부 분석 SDK 없음(`pubspec.yaml`). 내부 이벤트는 EventLogger가 PocketBase 전용 API `POST /api/stone-match/events`로 보내 `sm_events`에 저장한다. 백엔드 미설정(`BackendGateway.isConfigured` 거짓)이면 내부 수집을 하지 않으므로 GA4 활성화 조건은 독립시켜야 한다.
- 내부 이벤트 schema_version 3: 예약 필드 event_id, event_seq, schema_version, run_id, round_seq, attempt_seq, telemetry_env, collection, sample_rate. 사용자 필드는 이벤트당 12개 이하(TECH_SPEC PLAN-009 Step 1~3).
- PLAN-009 판 단위와 시간 정의는 확정됐다. PLAN-010 식별 계약 중 analytics_id 규칙(원본 식별값 비전송)은 확정, 발급 방식은 미정이다.
- GA4 자동 세션과 내부 앱 실행 session_id는 같은 개념이 아니다. 예약명 session_start, ad_reward를 그대로 전달하지 않는다.
- NAS 웹은 `Cross-Origin-Embedder-Policy: require-corp`, `Cross-Origin-Opener-Policy: same-origin`을 보낸다(`tools/deploy_match_web.sh`). 외부 스크립트 로드가 막힐 수 있어 PoC에서 확인한다.

## 4. 측정 사전 (NAS 최소 연결 반영, 상세 보고서는 후속)

### 4.1 GA4 제약 (공식 문서 2026-09-29 조회)
| 항목 | 한도 | 근거 |
|---|---|---|
| 이벤트 이름 | 40자, 문자로 시작, 영문자/숫자/밑줄만, 대소문자 구분 | [이벤트 이름 규칙](https://support.google.com/analytics/answer/13316687), [수집 한도](https://support.google.com/analytics/answer/9267744) |
| 이벤트당 파라미터 | 25개 | 수집 한도 |
| 파라미터 이름/값 | 40자 / 100자 | 수집 한도 |
| 사용자 속성 | 속성당 25개, 이름 24자, 값 36자 | 수집 한도 |
| User-ID 값 | 256자 | 수집 한도 |
| 고유 이벤트 이름 수 | 웹 스트림 제한 없음, 앱 스트림 앱 사용자당 500 | 수집 한도 |
| 예약 이벤트(웹) | session_start, first_visit, page_view, user_engagement, error, click, scroll 등 | 이벤트 이름 규칙 |
| 예약 이벤트(앱) | ad_reward, session_start, error, first_open, app_update 등 | 이벤트 이름 규칙 |
| 예약 접두사 | 이벤트/파라미터 `_`, `firebase_`, `ga_`, `google_`, `gtag.` | 이벤트 이름 규칙 |
| 예약 파라미터 이름(맞춤 측정기준 불가) | session_id, user_id, uid, cid, sid 등 | 이벤트 이름 규칙 |
| PII | 이메일, 전화번호 등 전송 금지 | [PII 전송 방지](https://support.google.com/analytics/answer/6366371) |

- 파라미터 예산: 이벤트당 사용자 정의 파라미터를 20개 이하로 제한하고 나머지는 자동 파라미터와 공통 문맥 몫으로 남긴다(보수적 운영 규칙, 공식 한도 아님).
- 맞춤 측정기준 등록 한도는 속성 등급에 따라 다르므로 콘솔 생성 뒤 확인한다(미확인). event_id, run_id 같은 고유값은 맞춤 측정기준으로 등록하지 않는다.
- 타입: GA4 파라미터는 문자열 또는 숫자로 보낸다. 추천 이벤트가 boolean을 정의한 경우(level_end.success)는 그 형식을 따르고, 맞춤 이벤트의 내부 bool(ok, granted)은 정수 0/1로 바꾼다. 100자 초과 문자열은 잘라서 보내지 않고 해당 파라미터를 생략한다.

### 4.2 공통 문맥 파라미터 (매핑한 게임 이벤트)
| GA4 파라미터 | 내부 원천 | 비고 |
|---|---|---|
| app_channel | row.channel | NAS GA4 경로는 web으로 구분한다. PocketBase 원본 채널은 변경하지 않는다. 다른 앱 채널 연결은 후속 범위다. |
| app_ver | row.app_version | app_version은 앱 스트림 자동 파라미터와 충돌할 수 있어 다른 이름 사용 |
| schema_ver | schema_version | 3 |
| exp | round_start/round_end의 exp | 실험 스위치 표시, 있을 때만 |
| round_key | 비전송 | 내부 고유 식별자를 GA4에 넣지 않는다 |

session_id, event_id, player_id, device_id는 GA4로 보내지 않는다. 현재 사용자 단위 조인도 하지 않는다. analytics_id는 PLAN-010 후속 결정이며 이벤트 단위 정합은 기대하지 않는다.

### 4.3 내부 이벤트 → GA4 이름 매핑
| 내부 이벤트 | GA4 이벤트 | 파라미터(예산) | 결정 |
|---|---|---|---|
| session_start | 보내지 않음 | GA4 자동 session_start 사용 | 예약명 |
| round_start | level_start(추천 이벤트) | level_name=mode(또는 progression_L{level}), mode, daily_key | 권장안 |
| round_end | level_end(추천 이벤트) | level_name, success(boolean, level_clear만 true), reason, score, duration_s, active_s, paused_s, background_s, attempt_seq | 권장안 |
| level_clear | 보내지 않음 | level_end success=1로 대체 | 권장안 |
| stage_continue | stage_continue | level, attempt_seq | 권장안 |
| ranking_submit | post_score(추천 이벤트) | score, level, mode, ok, ranked, rank | 권장안. 실패 사유 failure는 내부만 |
| ad_reward | rewarded_ad_result | placement, result, granted, outcome, item | 앱 예약명 ad_reward 회피 |
| round_summary | round_summary | 9필드 전부 | 권장안 |
| round_input | round_input | invalid_swaps, tap_swaps, drag_swaps, special_taps, hints_used, items_used, first_success_active_s | 권장안 |
| round_specials | 보내지 않음 | 12필드는 내부 분석 전용 | 권장안 |
| badge_earned | unlock_achievement(추천 이벤트) | achievement_id={badge}_{tier} | 권장안 |
| rank_up | level_up(추천 이벤트) | level=rank, character=cumulative | 권장안 |
| hyper_swap, speed_bonus_peak, last_hurrah | 보내지 않음 | 빈도와 해석 목적상 내부 전용 | 권장안 |
| title_menu_action, game_menu_action, player_name_dialog | 같은 이름 | action 또는 step, mode | NEEDS-DECISION: 내부는 10% 표본, GA4는 전수 권장 |

추천 게임 이벤트와 파라미터는 [GA4 추천 이벤트 참조](https://developers.google.com/analytics/devguides/collection/ga4/reference/events)를 따른다: level_start(level_name), level_end(level_name, success boolean), post_score(score 필수, level, character), unlock_achievement(achievement_id 필수), level_up(level, character). 맞춤 파라미터는 같은 이벤트에 추가로 붙인다.

### 4.4 지표 정의
- 활성 플레이 사용자(일/주): 기간(KST) 안에 production 환경 round_start가 1회 이상인 사용자. 내부는 player 기준, GA4는 analytics_id 또는 GA4 기기 기준. 두 수치를 같은 값으로 기대하지 않는다.
- D1/D7 재방문: 첫 round_start가 있는 KST 날짜를 코호트 0일로 두고 N일째 round_start가 있으면 재방문. GA4 기본 리텐션(first_visit 기준, 참여 기준)과 정의가 달라 보고서에 정의를 함께 표기한다.
- 첫 플레이 퍼널: session_start(내부) → title_menu_action(mode_*) → player_name_dialog confirm(진행/타임) → round_start → round_end. 메뉴 단계는 표본 이벤트라 절대값이 아니라 비율로만 해석한다.
- 판 완료율: `(run_id, round_seq)`의 마지막 시도 기준. completed = round_end reason level_clear 또는 time_up. abandoned = exit 또는 restart. unknown = round_start는 있으나 종료 이벤트가 없음. 완료율 = completed / (completed + abandoned). unknown은 분모에 넣지 않고 비율을 따로 보고한다. unknown을 실패나 충돌로 표시하지 않는다(PLAN-009).
- 레벨 재시도: 같은 레벨의 round_start 수와 attempt_seq 최대값. 이어하기와 다시 하기를 구분한다.
- 아이템 활용: round_input.items_used, 판별 hints_used. 판 요약이 유실되면 0으로 간주하지 않는다.
- 숙련도: first_success_active_s, invalid_swaps 비율, best_move. 최신 시도값만 쓴다.

### 4.5 환경, QA, 동의
- production 빌드만 운영 속성으로 보낸다. QA/development/test는 별도 테스트 측정ID가 설정된 경우 그 속성과 debug_mode를 사용하고, 없으면 비활성이다. NAS 이외 native/intoss는 현재 비활성이다.
- `?exp=` URL 실험 판과 `qa*=1` 세션은 qa로 분류한다. 초기 운영 전송 뒤 QA로 전환되면 운영 GA를 멈춘다. QA를 운영 속성으로 보내지 않는다.
- 설정의 분석 동의 기본off. 동의 전에는 외부 태그도 로드하지 않는다. 동의 후 analytics_storage granted, 광고 목적 저장/개인화(ad_storage, ad_user_data, ad_personalization)는 denied, Google signals off. [동의 모드](https://developers.google.com/tag-platform/security/guides/consent) 명령은 config 이전이다.
- 앱인토스 외부 분석 허용 여부와 native SDK는 후속 범위다. 허용으로 추정하지 않는다.
- 설정 스위치를 끄면 전송을 차단하고 게임전용 쿠키만 만료시킨다. 내부 PocketBase 수집은 별도 경로이며 이 설정으로 중단되지 않는다.

### 4.6 어댑터 경계
게임 코드 → EventLogger(공통 이벤트) → 내부 전송(PocketBase)과 GA4 어댑터. GA4 어댑터는 4.3 표만 적용하는 순수 매핑 함수와 전송 함수로 나눈다. 한 전송 경로의 실패가 다른 전송이나 게임을 막지 않는다. 공통 로거는 한 명만 수정한다.

## 5. 구현 계획
### Step 1: 측정 사전
- [x] 지표 정의 초안(4.4): 활성 플레이 사용자, D1/D7, 퍼널, 완료율과 unknown, 레벨 재시도, 아이템 활용.
- [x] GA4 이벤트 매핑과 파라미터 예산, 타입 변환 초안(4.1~4.3). 콘솔 등록 전이라 확정 아님.
- [x] round_id/event_id 같은 고유값을 맞춤 측정기준에 등록하지 않는 규칙.
- [x] 게임 코드 → 공통 이벤트 → PocketBase/GA4 어댑터 경계(4.6).
- [x] NAS 범위 확정: round_key 비전송, GA 메뉴 전수, 선택동의 기본off, QA 속성 분리. 앱인토스는 후속 범위.

### Step 2: 한 채널의 최소 연결
- [x] NAS 웹 우선, 운영 속성556597456과 QA 속성556615844 분리, 운영/QA 측정 ID 설정 완료.
- [x] NAS 웹은 gtag.js 직접 연동. native/intoss는 이번 최소 연결 범위 밖이며 비활성이다.
- [x] release Wasm/JS 빌드, COEP require-corp 태그 로드와 전송, 실제게임 Wasm/JS 설정 동의 전후 수집, 외부태그차단 시 게임 진입 확인.
- [x] 메뉴/게임 진입/판 종료와 allowlist 판 요약 연결. 선택 동의 기본off, 운영과 QA 프로젝트 분리, user_id 비전송.
- [x] QA DebugView에서 명시적 page_view, title_menu_action, level_start, level_end 각1회 확인. GA 자체 first_visit/session_start 각1회는 정상 자동 이벤트다. 향상된 측정은 운영/QA 모두off.

### Step 3: 상세 행동과 보고서
- [ ] 판 요약 기반 숙련도/전략/재시도/아이템 지표.
- [ ] 활성/대기 시간 구분, guest/연결 계정/채널 구분.
- [ ] 리텐션, 퍼널, 레벨별 실패/재시도, 버전/실험별 비교 보고서.
- [ ] 첫 방문과 재방문, 차단/오프라인 누락을 포함해 내부 수집과 차이가 나는 이유 문서화.

## 6. 병렬 작업과 변경 범위
- 계약 확정 뒤 GA4 어댑터와 보고서 설계는 독립 가능하다. 공통 로거는 한 명만 수정한다.
- PLAN-012는 공통 식별/동의 계약 이후 별도 단계로 착수 가능하지만 동시에 출시하지 않는다.
- 예상: lib/services 분석 어댑터, app/main 초기화, 채널 빌드 설정, 배포 헤더, 개인정보처리방침.

## 7. 검증 계획
- Mock 기반 매핑/예약명/100자 초과/파라미터 수/bool 변환/수집 비활성/제공자 장애 회귀.
- flutter analyze, 관련 test, Wasm build, 실제 DebugView와 채널별 수집.
- 실제 콘솔 수집 확인 전 GA4 연동 완료로 표시하지 않는다.

## 8. 위험 / 미해결 사항
- 운영/QA 계정과 선택동의는 확정. 보존/공개 고지의 최종 확정과 GA4/내부 데이터 정의 차이에 따른 보고서 해석은 후속으로 남는다.
- COEP require-corp 그대로 실제 Wasm 태그 로드와 전송을 확인했다. 네트워크 차단/동의거부/오프라인에서 누락이 생기므로 전수 수집으로 해석하지 않는다.
- 매 입력 전송 부하를 피하고 필요한 상세 입력은 표본화한다.

## 9. 완료 조건
- 사전, 코드, 실제 수집과 보고서가 일치하고 개인정보처리 안내와 Spec/Status가 갱신된다.
- 자료: [이벤트 이름 규칙](https://support.google.com/analytics/answer/13316687), [수집 제한](https://support.google.com/analytics/answer/9267744), [PII 전송 방지](https://support.google.com/analytics/answer/6366371), [동의 모드](https://developers.google.com/tag-platform/security/guides/consent), [화면 측정](https://firebase.google.com/docs/analytics/screenviews).

## 10. NAS 웹 최소 연결 실행 (2026-09-29)

- 사용자가 운영 측정 ID `G-1D8SDVLZQX`를 제공했다. 로그인된 Google Analytics에서 계정378565797 / 속성556597456 `Stone Match`와 ID 일치를 확인했다.
- 사용자는 Google 설정을 에이전트가 직접 진행하도록 요청했다. Search Console/BigQuery/성과 개선안은 수행 요청이 아닌 예시라고 명시했으므로 이번 범위에서 추가하지 않는다.
- 선택: NAS 웹만 먼저 직접 gtag 연동, 순수 mapper 분리, QA 별도 속성. 앱/네이티브/토스는 이번 범위 제외. analytics_id 연결은 PLAN-010 이후, 현재 user_id를 보내지 않는다.
- 분석 수집은 기존 게임 설정의 선택 동의 기본off로 시작한다. 동의 전 외부 스크립트와 전송 없음, 해제 후 전송 차단. 광고 저장/광고 사용자 데이터/광고 개인화는 denied, Google signals 비활성. 분석 기능 없이 기존 게임과 PocketBase는 동작한다.
- 메뉴 단계는 GA4 경로에서 전수, PocketBase10% 표본은 유지한다. round_key와 내부 고유 식별자는 비전송, 채널 web 사용. 페이지조회는 정제된 URL로1회, 자동 페이지조회/향상된 측정 중복을 끈다.
- 2026-09-30 QA Wasm 실제수집/DebugView 확인 완료. 실제 게임/NAS 배포 검증은 아래 최신 기록을 따른다.


## 11. 최소 연결 검증 (2026-09-30)

- QA 속성556615844 `Stone Match QA`, 스트림15867249716, ID `G-E942CQ3ZBL`. 운영 ID `G-1D8SDVLZQX`와 별도다. Git 제외 config/ga4.json 사용.
- 광고 목적 저장/개인화는 거부, Google signals off. 분석 동의 전에는 태그/Google 요청이 없고, 동의한 뒤만 analytics_storage granted로 시작한다.
- GA 쿠키는 cookie_prefix=sm, cookie_domain=none, cookie_path=/match/. 동의 철회는 이 게임의 sm_ga와 측정ID별 sm_ga_*만 지우며 공유 _ga나 다른 앱 쿠키는 건드리지 않는다. 실제 cookie 이름과 삭제, 비관련시험쿠키 보존 확인.
- actual Wasm/COEP QA에서 명시적4이벤트 각1회, query/referrer 정제와 sentinel제거, 운영속성 미전송을 확인했다. DebugView에4이벤트+GA자동 first_visit/session_start가 표시됐다. 요청의 ep.debug_mode 표기도 실제 DebugView 인식됨을 확인했다.
- 이벤트 수집은 동의율/차단/오프라인에 영향을 받는다. 내부 PocketBase 사용자/세션/표본 메뉴와 GA4의 쿠키 기반 사용자/세션/전수 메뉴를 같은 정의로 비교하지 않는다.
- 전체 Flutter622, 관련 mapper20/adapter15 통과. QA 증거는 tmp/ga4-integration-20260929/browser-consent.json, debugview.json, cookie-tests.log, full-test-final.log.
- Step3 상세 보고서, 네이티브/토스, Search Console, BigQuery는 미완료/범위 밖이다. 이 Step2 결과로 전체 PLAN 완료를 선언하지 않는다.


### 11.1 NAS 운영 반영
- 2026-09-30 NAS 업로드 HTTP200/OK. release `stone-match@1.0.0+1-6c84d928ff14`, ZIP SHA256 `5de3ded63a459b25fc8e3ea7708345016a75112d73c92bdc732249e88627a6b2`.
- index/bootstrap/main JS/MJS/Wasm/SFX/skwasm 핵심7파일 원격해시 일치, COOP/COEP/Wasm MIME/no-cache, /match/game deep link 통과.
- 실제 NAS QA설정에서 동의전hits0/tag없음/저장값없음, 켜기후 QA page_view1회와 정제된페이지주소 확인. 로컬동일빌드 Wasm은실제포인터스위치로동의철회와쿠키삭제, JS fallback도동의전후검증통과.
- Google태그/수집차단 상태 실제Wasm게임보드 확인. 전체Flutter622, 변경7파일analyze clean. 기존 사용자4파일해시불변, 게임커밋/push없음.
- Sentry 기존오류수집을함께유지하고 새JS source map을운영/QA에올린뒤 공개패키지에서제외했다.
- 브라우저환경초기viewport130x89로 screenshot timeout이 발생했으나 viewport조정후 실제게임보드와설정화면확인. 자동화실패를제품오류로단정하지않는다. 모바일실기기/토스/장시간성능은미검증.
