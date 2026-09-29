# Stone Match 개인정보처리방침 초안

> 상태: 초안. 법률 검토 전이며 공개 문서가 아니다. [확정 필요] 표시는 출시 전에 값을 정해야 한다.
> 근거: PLAN-013, `pocketbase/pb_migrations/1790680000_stone_match.js`, `pocketbase/pb_hooks/`, `lib/services/backend/pocketbase_gateway.dart`, `lib/services/backend/pocketbase_session_store.dart`, `lib/services/event_logger.dart`, `lib/services/ranking_service.dart`, `lib/ads/`.
> 보관 기간은 PocketBase 구현 계약이다. 운영 적용 상태와 법률상 공개 문구는 출시 전 별도로 확인한다.
> 이전 이력: 최초 초안은 PLAN-006의 Supabase 익명 인증과 PostgreSQL RLS를 기준으로 작성했다. PLAN-013은 새 PocketBase 익명 사용자를 사용하며 기존 Supabase 계정을 연결하지 않는다. 원본 Supabase 데이터는 보존하므로 해당 원본의 접근/보관/파기 정책도 공개 전 확정해야 한다.

---

## 한국어 본문

### 1. 수집하는 항목

| 구분 | 항목 | 저장 위치 |
|------|------|-----------|
| 익명 식별자 | 기기에서 임의 생성한 device_id(32hex), device_secret(64hex), 서버가 발급한 PocketBase 사용자 ID와 인증 토큰 | 기기(URL별 자격정보와 세션), 서버 sm_players(device_id, 사용자 ID, 비밀값의 비밀번호 해시) |
| 랭킹 | 플레이어 이름(1~20자), 점수, 모드(time 또는 level), 제출 시각 | 서버 `sm_rankings` |
| 광고 보충 기록 | 보충한 아이템 이름, 날짜(한국 시간 기준), 시각 | 서버 `sm_ad_claims` |
| 플레이 기록(이벤트) | 이벤트 이름, 앱 세션 단위 임의 ID, 앱 버전, 스토어 채널, 기기 시각, 아래 표의 속성 | 서버 `sm_events` |
| 기기 저장 | 설정, 최고 기록, 플레이어 이름, 기기 자격정보와 로그인 세션, 미전송 이벤트 큐 | 기기 로컬 저장소 |
| 일별 집계 | 날짜/환경/채널/버전/모드별 이벤트 수와 사용자/세션 수, 판 종료 상태 수. 사용자 식별자 원문은 저장하지 않음 | 서버 sm_daily_metrics |

이벤트 속성은 다음과 같다.

| 이벤트 | 속성 |
|--------|------|
| `session_start` | platform |
| `round_start` | mode |
| `round_end` | mode, reason, score, level(레벨 모드), duration_s |
| `level_clear` | level, score, max_combo |
| `stage_continue` | level |
| `ranking_submit` | mode, score, ok, ranked, rank, failure |
| `ad_reward` | placement, result, granted, outcome(보충 광고의 지급 결과), level 또는 item |
| `hyper_swap` | target_kind |
| `speed_bonus_peak` | max_tier, total_bonus |
| `last_hurrah` | specials_count, score_added |
| `badge_earned` | badge, tier |
| `rank_up` | rank |

이름, 이메일, 전화번호, 위치, 연락처, 기기 광고 식별자는 수집하지 않는다. 앱인토스 사용자 식별자도 사용하지 않는다. 플레이어 이름은 이용자가 직접 입력하며 랭킹에서 다른 이용자에게 공개된다. 실명이나 개인정보를 입력하지 않도록 안내한다.

### 2. 이용 목적

- 랭킹 표시와 순위 계산
- 광고 보상 하루 횟수 제한(하루 3회 기본값, 원격 설정)
- 오류와 이용 패턴 파악을 통한 게임 개선
- 과도한 요청 방지(제출 1분 10건, 이벤트 1분 300건 제한)

### 3. 보관 기간 [확정 필요]

| 데이터 | 구현상 보관 기간(운영 적용과 공개 정책 확인 필요) |
|--------|----------------|
| `sm_events` | 90일 지난 기록 정리 |
| 기기 미전송 큐 | 최대 7일, 200행/256KiB. 초과 시 오래된 행 정리 |
| sm_daily_metrics | 자동 만료 없음. 공개 보관 정책 [확정 필요] |
| 랭킹 기록 | 서비스 운영 기간. 삭제 요청 시 삭제 [확정 필요] |
| 광고 보충 기록 | 35일 지난 기록 정리 |
| 익명 사용자 계정 | 90일 비활성 사용자 정리. 랭킹은 보존 |

### 4. 처리 위탁과 국외 이전

| 수탁자 | 위탁 업무 | 서버 지역 |
|--------|-----------|-----------|
| 자체 운영 PocketBase | 익명 인증, 랭킹, 광고 보충과 이벤트 저장 | [확정 필요: 실제 서버 위치와 운영 주체] |

PocketBase는 사용 소프트웨어 이름이며 그 자체로 수탁자를 뜻하지 않는다. 실제 운영 주체, 호스팅/네트워크 제공자, 관리 접근, 백업 위치와 국외 이전 여부는 [확정 필요]다. 서버 주소만으로 저장 국가나 법률상 이전 여부를 단정하지 않는다.

### 5. 광고

게임은 보상형 광고를 보여 줄 수 있다. 광고 표시 중 광고 SDK가 수집하는 정보는 각 플랫폼의 광고 제공자(앱인토스, Google, Apple 등)가 처리하며 이 방침의 범위 밖이다. 게임은 광고 시청 결과(성공 여부)와 보충 아이템 이름만 서버에 남긴다. 광고 SDK 표기는 채널별로 [확정 필요].

### 6. 이용자 권리와 삭제 방법

- 기기 또는 브라우저 저장소의 기기 자격정보가 삭제되면 다음 인증에서 새 익명 식별자가 만들어진다. 토큰만 만료되면 저장된 기기 자격정보로 다시 인증한다. 90일 비활성 정리로 서버 사용자가 삭제된 경우 같은 기기 자격정보로 새 사용자 ID를 받을 수 있다. 재설치 시 저장소 유지 여부는 플랫폼별로 다르다.
- 이미 서버에 저장된 랭킹과 이벤트의 삭제나 열람은 문의처로 요청한다. 익명이라 본인 확인이 어려워 플레이어 이름, 제출 시각, 점수로 대상을 특정한다. [확정 필요: 처리 절차와 기한]
- 이용자는 처리 정지, 정정, 삭제를 요청할 수 있다.

### 7. 아동

만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않는다. 이름과 연락처를 받지 않는다. 법정대리인 동의 절차와 연령 등급은 [확정 필요].

### 8. 안전성 확보 조치

PocketBase 계약은 전송 구간 암호화(HTTPS), 일반 컬렉션 CRUD 차단, 전용 API의 사용자 인증과 최소 권한을 사용한다. 기기 비밀값은 서버에서 비밀번호 해시로 저장하며 클라이언트에 관리자 자격정보를 포함하지 않는다. 다른 이용자의 식별자는 조회할 수 없다.

### 9. 문의처

- 책임자 또는 담당 부서: [확정 필요]
- 이메일: [확정 필요]
- 개정일과 시행일: [확정 필요]

---

## English

> Draft for legal review. Not for publication. Items marked [TBD] must be decided before release. Retention values reflect the PocketBase implementation contract; deployment and legal disclosures require confirmation. Earlier drafts described Supabase. Existing Supabase accounts are not linked to the new PocketBase identity; source data remains preserved and its retention and deletion policy is [TBD].

### 1. Data we collect

| Category | Data | Where stored |
|----------|------|--------------|
| Anonymous ID | Random device_id (32 hex characters), device_secret (64 hex characters), a server-issued PocketBase user ID and auth token | Device (URL-scoped credentials and session); sm_players (device_id, user ID and password hash of the secret) |
| Ranking | Player name (1 to 20 characters), score, mode (time or level), submission time | Server table `sm_rankings` |
| Ad refill record | Refilled item name, date (Korea time), time | Server table `sm_ad_claims` |
| Play events | Event name, a random per-launch session ID, app version, store channel, device time, and the properties below | Server table `sm_events` |
| On device | Settings, best records, player name, device credentials, sign-in session and pending event queue | Local device storage |
| Daily aggregates | Counts of events, users, sessions and round outcomes grouped by date/environment/channel/version/mode; no raw user identifiers | sm_daily_metrics |

| Event | Properties |
|-------|------------|
| `session_start` | platform |
| `round_start` | mode |
| `round_end` | mode, reason, score, level (level mode), duration_s |
| `level_clear` | level, score, max_combo |
| `stage_continue` | level |
| `ranking_submit` | mode, score, ok, ranked, rank, failure |
| `ad_reward` | placement, result, granted, outcome (refill grant result), level or item |
| `hyper_swap` | target_kind |
| `speed_bonus_peak` | max_tier, total_bonus |
| `last_hurrah` | specials_count, score_added |
| `badge_earned` | badge, tier |
| `rank_up` | rank |

We do not collect your real name, email, phone number, location, contacts, or device advertising ID. We do not use Apps in Toss user identifiers. The player name is typed by you and is visible to other players in the ranking. Do not enter your real name or personal information.

### 2. Purposes

- Show rankings and compute ranks
- Limit rewarded refills per day (default 3, remotely configured)
- Improve the game through error and usage analysis
- Prevent excessive requests (10 ranking submissions and 300 events per minute)

### 3. Retention [TBD]

| Data | Implementation retention (deployment and policy TBD) |
|------|-------------------|
| `sm_events` | Records older than 90 days are cleaned up |
| Pending device queue | Up to 7 days and 200 rows/256KiB; oldest rows removed on overflow |
| sm_daily_metrics | No automatic expiry; published retention policy [TBD] |
| Ranking entries | While the service runs; deleted on request [TBD] |
| Ad refill records | Records older than 35 days are cleaned up |
| Anonymous users | Deleted after 90 days of inactivity; rankings are preserved |

### 4. Processors and international transfer

| Processor | Task | Server region |
|-----------|------|---------------|
| Self-hosted PocketBase | Anonymous authentication, ranking, ad refill and event storage | [TBD: actual hosting location and operator] |

PocketBase names the software, not a processor. The operator, hosting and network providers, administrative access, backup locations and any international transfer are [TBD]. A server URL does not establish a storage country or a legal conclusion.

### 5. Ads

The game may show rewarded ads. Information collected by the ad SDK while an ad plays is handled by the platform ad provider (Apps in Toss, Google, Apple, and others) and is outside this policy. The game stores only the ad result (success or not) and the refilled item name. Ad SDK disclosures per channel are [TBD].

### 6. Your rights and deletion

- Removing stored device credentials causes a new anonymous identity at the next authentication. Token expiry alone reuses the same credentials. After a server user is deleted for 90 days of inactivity, those credentials may receive a new user ID. Storage survival after reinstallation depends on the platform.
- To view or delete ranking entries and events already on the server, contact us. Because data is anonymous, we identify entries by player name, submission time, and score. [TBD: procedure and response time]
- You may request to stop processing, correct, or delete your data.

### 7. Children

We do not knowingly collect personal information from children under 14. We do not ask for names or contact details. Parental consent procedure and age rating are [TBD].

### 8. Security

The PocketBase contract uses HTTPS, locked standard collection CRUD, authenticated dedicated APIs and least privilege. Device secrets are stored as password hashes on the server; client builds contain no administrator credentials. Other users' IDs cannot be read.

### 9. Contact

- Responsible person or team: [TBD]
- Email: [TBD]
- Revision and effective dates: [TBD]

---

## 부록 A. Apple App Privacy 표기표 (초안)

추적(Tracking)은 모든 항목에서 아니오다. 서드파티 광고 SDK 항목은 채널별 SDK 확정 후 [확정 필요].

| 데이터 유형 | 수집 | 사용자에 연결 | 추적 | 목적 |
|-------------|------|---------------|------|------|
| User ID (PocketBase 사용자 ID와 임의 기기 ID) | 예 | 예 | 아니오 | App Functionality, Analytics |
| Gameplay Content 또는 Other User Content (플레이어 이름) | 예 | 예 | 아니오 | App Functionality (랭킹 공개) |
| Product Interaction (이벤트: 판 시작, 종료, 점수, 광고 결과) | 예 | 예 | 아니오 | Analytics, App Functionality |
| Diagnostics (앱 버전, 플랫폼, 채널) | 예 | 예 | 아니오 | Analytics |
| Advertising Data / Device ID | 광고 ID는 게임 자체 수집 없음. 임의 기기 ID는 위 User ID 행 참고. 광고 SDK는 [확정 필요] | [확정 필요] | [확정 필요] | Third Party Advertising [확정 필요] |
| 이름, 이메일, 위치, 연락처, 구매 | 아니오 | 해당 없음 | 해당 없음 | 해당 없음 |

## 부록 B. Google Play Data safety 표기표 (초안)

| 항목 | 값 |
|------|-----|
| 데이터 수집 여부 | 예 |
| 전송 중 암호화 | 예(HTTPS) |
| 삭제 요청 수단 | 있음(문의처. 앱 데이터 삭제 시 익명 식별자 초기화) [확정 필요: 삭제 요청 URL] |
| 제3자와 공유 | [확정 필요: 실제 운영/네트워크 제공자와 광고 SDK 확인 후 스토어 기준에 따른 공유 여부 판단] |

| 데이터 유형 | 수집 | 공유 | 필수 여부 | 목적 |
|-------------|------|------|-----------|------|
| 기기 또는 기타 ID (PocketBase 사용자 ID와 임의 기기 ID) | 예 | 아니오 | 필수 | App functionality, Analytics |
| 사용자 이름 이외 사용자 생성 콘텐츠 (플레이어 이름) | 예 | 아니오 | 선택(랭킹 제출 시) | App functionality |
| 앱 활동 (게임 이벤트, 점수) | 예 | 아니오 | 필수 | Analytics, App functionality |
| 앱 정보와 성능 (앱 버전, 플랫폼) | 예 | 아니오 | 필수 | Analytics |
| 위치, 연락처, 개인 정보(이름, 이메일), 금융 정보 | 아니오 | 해당 없음 | 해당 없음 | 해당 없음 |


## 부록 C. PLAN-012 Sentry 오류 수집 구현 기록 (2026-09-29)

공개 문구가 아닌 기술 검토 기록이다. 사용자가 Wasm을 유지한 오류 수집만 연결하도록 승인했고 운영 반영 여부는 PROJECT_STATUS를 따른다.

- 서비스: Sentry, 조직 tk-media-m3. 운영 stone-match와 QA stone-match-qa 프로젝트를 분리한다. CLI 조회의 regionUrl은 de.sentry.io였다. 실제 계약상 저장 지역, 처리 주체, 보관 기간과 국외 이전 공개 사항은 출시 전 확인한다.
- 목표 수집 범위: 오류 종류와 정제한 스택, 앱 release/환경/채널/실행 방식, 허용된 판 문맥, 최근 내부 이벤트명/시각 최대20건. 임의 오류 메시지와 이벤트 params 전체, 입력 이름/이메일/토큰/기기 자격정보/URL query는 전송하지 않는다.
- analytics_id 구현 전 사용자 식별 문맥을 보내지 않는다. 서버가 처리하는 접속 정보와 서비스 자체 보관 정책은 앱 payload의 필드 제거와 별도로 확인한다.
- 성능 tracing/profiling, 화면 녹화/replay는 사용하지 않는다. Wasm 원본 Dart 줄은 복원하지 못하며 JS 경로만 비공개 source map을 사용한다. map 파일은 공개 웹/ZIP에서 제외한다.
- 최종 공개 본문과 영문/스토어 표는 실제 전송 원문 검증 및 운영 설정 확인 뒤 동기화해야 한다. 이 기록만으로 법률 검토나 스토어 표기 검증 완료를 뜻하지 않는다.

- 2026-09-29 실제 NAS 연결 완료: 순수 Dart sentry 9.30.1 사용, 모든 전송은 허용 목록으로 재구성한다. 운영/QA Sentry 프로젝트에 IP 저장 차단과 파생 지역 필드 제거 규칙을 적용하고 새 이벤트에서 확인했다. 실제 사업자/국외이전/보유기간 등 법적 고지 확정 항목은 이 기술 검증으로 확정되지 않는다.


## 부록 D. NAS 웹 GA4 구현 기록 (2026-09-30)

- NAS 웹 설정에서 선택적으로 분석을 허용한 경우에만 Google Analytics 스크립트를 불러오고 방문/게임 행동 이벤트를 전송한다. 기본값은 꺼짐이며 언제든 설정에서 철회 가능하다.
- 쿠키 기반 임의 클라이언트/세션 식별과 브라우저/기기 등 GA가 자동 처리하는 접속 정보가 있다. 따라서 식별자를 전혀 처리하지 않는다고 표시하지 않는다. 이 게임은 이름/이메일/내부플레이어ID/입력토큰을 GA에 추가하지 않는다.
- 광고저장, 광고사용자데이터, 광고개인화는 denied이며 Google signals는 사용하지 않는다. 운영과 QA 속성은 분리한다.
- 쿠키는 host-only /match/의 sm_ga, sm_ga_<측정ID>이고 동의 철회 시 해당 게임 쿠키를 만료시킨다. Google에 이미 수신된 기록의 삭제는 로컬쿠키삭제와 별개다.
- GA와 내부 PocketBase 수집은 별도이며 이 스위치는 GA4만 제어한다. Google의 실제 처리조건/보유기간/국외이전 고지와 공개정책 최종확정은 별도다. 기술기록을 법률검토 완료로 표시하지 않는다.
