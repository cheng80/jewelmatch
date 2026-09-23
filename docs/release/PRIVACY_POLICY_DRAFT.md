# Stone Match 개인정보처리방침 초안

> 상태: 초안. 법률 검토 전이며 공개 문서가 아니다. [확정 필요] 표시는 출시 전에 값을 정해야 한다.
> 근거: `supabase/migrations/20260923142920_stone_match_init.sql`, `lib/services/event_logger.dart`, `lib/services/ranking_service.dart`, `lib/services/backend/supabase_gateway.dart`, `lib/ads/`, PLAN-006.
> 보관 기간은 트랙 B 초안 기준이라 모두 예정값이다.

---

## 한국어 본문

### 1. 수집하는 항목

| 구분 | 항목 | 저장 위치 |
|------|------|-----------|
| 익명 식별자 | 앱 최초 실행 시 Supabase 익명 로그인으로 만든 사용자 ID(UUID)와 인증 토큰 | 서버(인증), 기기(토큰) |
| 랭킹 | 플레이어 이름(1~20자), 점수, 모드(time 또는 level), 제출 시각 | 서버 `ranking_entries` |
| 광고 보충 기록 | 보충한 아이템 이름, 날짜(한국 시간 기준), 시각 | 서버 `ad_refill_claims` |
| 플레이 기록(이벤트) | 이벤트 이름, 판 단위 임의 세션 ID, 앱 버전, 스토어 채널, 기기 시각, 아래 표의 속성 | 서버 `game_events` |
| 기기 저장 | 설정, 최고 기록, 플레이어 이름, 로그인 토큰 | 기기 로컬 저장소 |

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

이름, 이메일, 전화번호, 위치, 연락처, 기기 광고 식별자는 수집하지 않는다. 앱인토스 사용자 식별자도 사용하지 않는다. 플레이어 이름은 이용자가 직접 입력하며 랭킹에서 다른 이용자에게 공개된다. 실명이나 개인정보를 입력하지 않도록 안내한다.

### 2. 이용 목적

- 랭킹 표시와 순위 계산
- 광고 보상 하루 횟수 제한(하루 3회 기본값, 원격 설정)
- 오류와 이용 패턴 파악을 통한 게임 개선
- 과도한 요청 방지(제출 1분 10건, 이벤트 1분 300건 제한)

### 3. 보관 기간 [확정 필요]

| 데이터 | 보관 기간(예정) |
|--------|----------------|
| `game_events` | 90일 뒤 삭제 [확정 필요] |
| 랭킹 기록 | 서비스 운영 기간. 삭제 요청 시 삭제 [확정 필요] |
| 광고 보충 기록 | 하루 제한 확인에 필요한 기간, 이후 정리 [확정 필요] |
| 익명 사용자 계정 | 오래 사용하지 않으면 정리 [확정 필요] |

### 4. 처리 위탁과 국외 이전

| 수탁자 | 위탁 업무 | 서버 지역 |
|--------|-----------|-----------|
| Supabase, Inc. | 익명 인증, 데이터베이스 저장 | ap-northeast-2(서울) [확정 필요: 프로젝트 생성 후 지역 확인] |

서버가 서울 지역이면 국외 이전은 없다. 다만 수탁자의 관리 접근이나 지원 과정에서 국외 이전이 있는지는 [확정 필요]이다. 수탁자 국적과 이전 항목은 법률 검토에서 확정한다.

### 5. 광고

게임은 보상형 광고를 보여 줄 수 있다. 광고 표시 중 광고 SDK가 수집하는 정보는 각 플랫폼의 광고 제공자(앱인토스, Google, Apple 등)가 처리하며 이 방침의 범위 밖이다. 게임은 광고 시청 결과(성공 여부)와 보충 아이템 이름만 서버에 남긴다. 광고 SDK 표기는 채널별로 [확정 필요].

### 6. 이용자 권리와 삭제 방법

- 앱 데이터를 삭제하거나 앱을 지우면 기기의 로그인 토큰이 사라져 새 익명 식별자가 만들어진다. 이전 식별자와 연결은 끊긴다.
- 이미 서버에 저장된 랭킹과 이벤트의 삭제나 열람은 문의처로 요청한다. 익명이라 본인 확인이 어려워 플레이어 이름, 제출 시각, 점수로 대상을 특정한다. [확정 필요: 처리 절차와 기한]
- 이용자는 처리 정지, 정정, 삭제를 요청할 수 있다.

### 7. 아동

만 14세 미만 아동의 개인정보를 의도적으로 수집하지 않는다. 이름과 연락처를 받지 않는다. 법정대리인 동의 절차와 연령 등급은 [확정 필요].

### 8. 안전성 확보 조치

전송 구간 암호화(HTTPS), 데이터베이스 행 단위 접근 제어(RLS), 최소 권한 부여를 적용한다. 다른 이용자의 식별자는 조회할 수 없다.

### 9. 문의처

- 책임자 또는 담당 부서: [확정 필요]
- 이메일: [확정 필요]
- 개정일과 시행일: [확정 필요]

---

## English

> Draft for legal review. Not for publication. Items marked [TBD] must be decided before release. Retention periods are planned values.

### 1. Data we collect

| Category | Data | Where stored |
|----------|------|--------------|
| Anonymous ID | A user ID (UUID) created by Supabase anonymous sign-in on first launch, and auth tokens | Server (ID), device (tokens) |
| Ranking | Player name (1 to 20 characters), score, mode (time or level), submission time | Server table `ranking_entries` |
| Ad refill record | Refilled item name, date (Korea time), time | Server table `ad_refill_claims` |
| Play events | Event name, a random per-launch session ID, app version, store channel, device time, and the properties below | Server table `game_events` |
| On device | Settings, best records, player name, sign-in token | Local device storage |

| Event | Properties |
|-------|------------|
| `session_start` | platform |
| `round_start` | mode |
| `round_end` | mode, reason, score, level (level mode), duration_s |
| `level_clear` | level, score, max_combo |
| `stage_continue` | level |
| `ranking_submit` | mode, score, ok, ranked, rank, failure |
| `ad_reward` | placement, result, granted, outcome (refill grant result), level or item |

We do not collect your real name, email, phone number, location, contacts, or device advertising ID. We do not use Apps in Toss user identifiers. The player name is typed by you and is visible to other players in the ranking. Do not enter your real name or personal information.

### 2. Purposes

- Show rankings and compute ranks
- Limit rewarded refills per day (default 3, remotely configured)
- Improve the game through error and usage analysis
- Prevent excessive requests (10 ranking submissions and 300 events per minute)

### 3. Retention [TBD]

| Data | Planned retention |
|------|-------------------|
| `game_events` | Deleted after 90 days [TBD] |
| Ranking entries | While the service runs; deleted on request [TBD] |
| Ad refill records | As long as needed for the daily limit, then cleaned up [TBD] |
| Anonymous users | Cleaned up when unused for a long time [TBD] |

### 4. Processors and international transfer

| Processor | Task | Server region |
|-----------|------|---------------|
| Supabase, Inc. | Anonymous authentication and database storage | ap-northeast-2 (Seoul) [TBD: confirm after project creation] |

With a Seoul region server, data is not transferred abroad for storage. Whether processor support or administrative access involves a cross-border transfer is [TBD] and will be settled in legal review.

### 5. Ads

The game may show rewarded ads. Information collected by the ad SDK while an ad plays is handled by the platform ad provider (Apps in Toss, Google, Apple, and others) and is outside this policy. The game stores only the ad result (success or not) and the refilled item name. Ad SDK disclosures per channel are [TBD].

### 6. Your rights and deletion

- Clearing app data or uninstalling removes the sign-in token from your device, and a new anonymous ID is created. The link to the old ID is broken.
- To view or delete ranking entries and events already on the server, contact us. Because data is anonymous, we identify entries by player name, submission time, and score. [TBD: procedure and response time]
- You may request to stop processing, correct, or delete your data.

### 7. Children

We do not knowingly collect personal information from children under 14. We do not ask for names or contact details. Parental consent procedure and age rating are [TBD].

### 8. Security

We use HTTPS in transit, row level security in the database, and least privilege grants. Other users' IDs cannot be read.

### 9. Contact

- Responsible person or team: [TBD]
- Email: [TBD]
- Revision and effective dates: [TBD]

---

## 부록 A. Apple App Privacy 표기표 (초안)

추적(Tracking)은 모든 항목에서 아니오다. 서드파티 광고 SDK 항목은 채널별 SDK 확정 후 [확정 필요].

| 데이터 유형 | 수집 | 사용자에 연결 | 추적 | 목적 |
|-------------|------|---------------|------|------|
| User ID (익명 UUID) | 예 | 예 | 아니오 | App Functionality, Analytics |
| Gameplay Content 또는 Other User Content (플레이어 이름) | 예 | 예 | 아니오 | App Functionality (랭킹 공개) |
| Product Interaction (이벤트: 판 시작, 종료, 점수, 광고 결과) | 예 | 예 | 아니오 | Analytics, App Functionality |
| Diagnostics (앱 버전, 플랫폼, 채널) | 예 | 예 | 아니오 | Analytics |
| Advertising Data / Device ID | 게임 자체는 아니오. 광고 SDK는 [확정 필요] | [확정 필요] | [확정 필요] | Third Party Advertising [확정 필요] |
| 이름, 이메일, 위치, 연락처, 구매 | 아니오 | 해당 없음 | 해당 없음 | 해당 없음 |

## 부록 B. Google Play Data safety 표기표 (초안)

| 항목 | 값 |
|------|-----|
| 데이터 수집 여부 | 예 |
| 전송 중 암호화 | 예(HTTPS) |
| 삭제 요청 수단 | 있음(문의처. 앱 데이터 삭제 시 익명 식별자 초기화) [확정 필요: 삭제 요청 URL] |
| 제3자와 공유 | 게임 데이터는 공유하지 않음. 처리 위탁(Supabase)은 공유에 해당하지 않음. 광고 SDK는 [확정 필요] |

| 데이터 유형 | 수집 | 공유 | 필수 여부 | 목적 |
|-------------|------|------|-----------|------|
| 기기 또는 기타 ID (익명 UUID) | 예 | 아니오 | 필수 | App functionality, Analytics |
| 사용자 이름 이외 사용자 생성 콘텐츠 (플레이어 이름) | 예 | 아니오 | 선택(랭킹 제출 시) | App functionality |
| 앱 활동 (게임 이벤트, 점수) | 예 | 아니오 | 필수 | Analytics, App functionality |
| 앱 정보와 성능 (앱 버전, 플랫폼) | 예 | 아니오 | 필수 | Analytics |
| 위치, 연락처, 개인 정보(이름, 이메일), 금융 정보 | 아니오 | 해당 없음 | 해당 없음 | 해당 없음 |
