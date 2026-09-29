# PLAN-010 최소 사용자 식별과 기록 연결

## Metadata
- Plan ID: `PLAN-010`
- Status: `DRAFT` (선행 계약 작성. 제공자 선택과 채널 설정은 사용자 답변 대기)
- Related Requirement: 닉네임 입력 개선, 플랫폼별 사용자 식별, 기록 복구
- Related ADR: ADR-010(현재 PocketBase 설치 단위 guest). 제공자 추가 시 별도 ADR 필요. ADR-009는 구 빌드 이력
- Owner: 조정자와 인증/UI 작업자
- Updated: 2026-09-29

## 1. 목표
이메일과 실명 수집을 기본으로 강제하지 않고, 게임 표시명과 인증 계정을 분리해 기록을 안정적으로 연결한다.

## 2. 범위
- 포함: 공통 player_id, 자동 닉네임과 변경 UI, 게스트 기록 연결, 채널별 인증 설계.
- 제외: 이번 실행의 제품 변경, 보상/광고/랭킹 규칙 변경, 기존 이름만으로 계정 병합, 외부 콘솔 등록, SDK 설치, 원격 스키마 변경.

## 3. 현재 상태 / 전제 (2026-09-29 코드 기준)
- 서버는 PocketBase 전용 API다(PLAN-013, ADR-010). Supabase 익명 로그인은 새 빌드에서 쓰지 않는다.
- 현재 식별은 설치 단위 guest다. 앱이 안전한 난수로 `device_id`(32 hex)와 `device_secret`(64 hex)을 만들어 네트워크 요청 전에 저장하고 `POST /api/stone-match/auth/guest`로 토큰을 받는다. 서버는 `sm_players.device_id` 유니크와 비밀값 비밀번호 해시로 같은 설치를 재인증한다(`pocketbase/pb_hooks/stone_match.js`, `pocketbase/pb_migrations/1790680000_stone_match.js`).
- 저장 키는 서버 URL별 `pocketbase.identity.v1.<scope>`다(`lib/services/backend/pocketbase_session_store.dart`). 저장소 삭제, 재설치, 다른 브라우저는 새 guest가 된다. 90일 비활성 정리 뒤에는 같은 기기 자격정보로 새 서버 사용자가 생길 수 있다.
- `sm_players`는 password/OAuth2/OTP 인증이 모두 비활성이고 컬렉션 직접 접근 규칙은 null(Locked)이다. 로그인 제공자를 붙이려면 이 설정 변경과 새 ADR이 필요하다.
- 이름 입력은 표시명이며 로컬 `StorageKeys.playerName`에만 있다. 랭킹 제출 때만 서버에 간다. 로컬 배지/누적 기록은 서버 저장이 아니다.
- 기존 Supabase 익명 사용자 38명은 사용자 결정으로 이전하지 않았다. 과거 ID는 비공개 이력(`legacy_user_id`)으로만 남고 새 계정과 연결하지 않는다.
- 최소 보관 후보: 내부 player_id, 표시명, 인증 제공자와 제공자 식별값, 생성/최근 이용 시각, 필요한 동의 설정과 버전.
- 이메일은 이메일 인증을 선택한 경우에만 필요하다. 실명/전화번호/생년월일/성별은 기본 가입 필드로 추가하지 않는다.

## 4. 선행 계약 (답변 없이 확정 가능한 범위)

### 4.1 식별자 층
| 식별자 | 생성 | 범위 | 외부 전송 |
|---|---|---|---|
| device_id, device_secret | 클라이언트 난수 | 서버 URL별 설치 | PocketBase 인증 요청만. 분석/오류 도구 금지 |
| player_id | PocketBase record id | 서버 사용자 | 자체 서버만. GA4/Sentry에 원본 전송 금지 |
| 제공자 식별값(토스 hash, OAuth sub) | 제공자 | 제공자 계정 | 서버 검증 입력으로만. 저장 시 서버 측 보관, 클라이언트 이벤트 금지 |
| analytics_id | 4.4 규칙 | 분석 도구별 | GA4 user_id 후보. 원본 복원 불가해야 한다 |
| session_id, run_id | 클라이언트 UUID | 앱 실행, 판 | 내부 이벤트. 개인 식별값 아님(PLAN-009) |

### 4.2 현재 설치 guest 계약 유지
- 제공자가 정해져도 guest는 기본 경로로 남는다. 연결 실패나 미지원 채널은 guest로 계속 플레이한다(BR-002와 같은 원칙).
- guest 자격정보는 실패를 이유로 재생성하지 않는다. 재생성은 저장소 삭제나 명시적 로그아웃 뒤뿐이다.
- 계정 연결은 guest player에 제공자 식별값을 붙이는 방식이 기본이다. 이미 다른 player에 붙은 제공자면 충돌로 처리하고 자동 병합하지 않는다(6절).

### 4.3 토스 식별키 위험과 서버 검증 조건
공식 문서 기준(2026-09-29 조회):
- `getUserKeyForGame`은 게임 카테고리 전용이며 `{type:'HASH', hash}`를 반환한다. 토스앱 5.232.0 미만은 `undefined`, 비게임에서는 `INVALID_CATEGORY`다. 미니앱별로 고유하고 앱 삭제나 기기 변경에도 같은 사용자면 같은 값이다. 샌드박스는 mock이다([사용자 식별키 발급](https://developers-apps-in-toss.toss.im/documentation/common/authentication/hash-key.md)).
- 이 hash를 클라이언트가 서버로 보내는 것만으로는 위조와 재사용을 막을 수 없다. 공식 문서도 식별키 노출 시 제3자가 같은 사용자처럼 요청할 수 있다고 설명한다([사용자 식별키 인증 코드 발급](https://developers-apps-in-toss.toss.im/guide/authentication/anonymous-key-auth-code.md)).
- 서버 검증 경로는 `User.createAnonymousKeyAuthCode()`(SDK 3.6.0 이상, 300초 1회용 코드) → 파트너 서버가 mTLS로 `POST /api-partner/v1/apps-in-toss/users/anon-key/exchange` → `anonKey`다([User.createAnonymousKeyAuthCode](https://developers-apps-in-toss.toss.im/documentation/sdk/domains-api/user/user.createanonymouskeyauthcode.md), [파트너 API 사용자 식별 키](https://developers-apps-in-toss.toss.im/api/user-key.md)). `anon-key/verify`는 키가 발급된 키인지만 확인하며 요청자가 그 사용자임을 증명하지 않으므로 로그인에 쓰지 않는다.
- 확인되지 않은 점: 문서는 인증 코드를 "웹 미니앱"에서 쓸 수 있다고만 적고, 교환 결과가 `getAnonymousKey`의 hash와 같다고 명시한다. 게임 카테고리에서 호출 가능 여부와 `getUserKeyForGame` hash와의 동일성은 문서에 없다. 현재 앱의 `@apps-in-toss/web-framework`는 3.0.3이라 3.6.0 요건에 미달한다(`package.json`).
- 계약: 토스 연결은 인증 코드 교환이 게임 카테고리에서 실제 토스 QR로 동작하고 mTLS 인증서가 준비된 뒤에만 서버 권한에 반영한다. 그 전에는 토스 hash를 서버 인증 입력으로 쓰지 않는다. 클라이언트 전달 hash만으로 다른 player에 접근시키지 않는다.
- 운영 제약: PocketBase JS 훅에서 mTLS 클라이언트 인증서 호출이 가능한지 미확인이다. 불가하면 교환 전용 소형 프록시가 필요하며 배포 구조 결정 대상이다(NEEDS-DECISION).
- 기존 토스 게임 리더보드 제출(`intoss_leaderboard_service`)은 식별키 없이 토스가 처리하며 이 계약과 별개다.

### 4.4 분석 ID와 개인정보 비노출
- GA4/Sentry로 보내는 사용자 식별은 analytics_id 하나다. 원본 device_id, device_secret, player_id, 토스 hash, 이메일, 표시명, 이름 입력 문자열은 보내지 않는다. GA4 정책상 이메일 등 PII 전송은 금지다([PII 전송 방지](https://support.google.com/analytics/answer/6366371)).
- 권장안: analytics_id는 서버가 player_id와 서버 비밀 salt로 만든 HMAC-SHA256의 앞부분(예 32 hex)을 인증 응답에 포함한다. 클라이언트 해시는 salt가 노출되므로 쓰지 않는다. GA4 User-ID 길이 상한 256자 안이다([수집 한도](https://support.google.com/analytics/answer/9267744)). NEEDS-DECISION: guest 단계에서도 user_id를 보낼지, 제공자 연결 사용자에게만 보낼지.
- salt 교체, 계정 삭제 시 analytics_id는 새로 계산되어 과거 분석 기록과 끊긴다. 이 한계를 개인정보 안내에 적는다.

### 4.5 로그아웃과 계정 전환 시 큐 소유자 분리
- 이벤트 큐 항목은 enqueue 시점 owner(서버 scope와 player_id)를 가진다. 전송 시 현재 owner와 다르면 보내지 않고 버린다. 다른 계정으로 재전송하지 않는다(PLAN-009 Step 4 계약과 동일).
- 로그아웃 순서: (1) 현재 owner 큐를 가능하면 flush, (2) 실패분은 owner 태그 유지 상태로 폐기 또는 보관 기간 경과 후 삭제, (3) 토큰과 제공자 연결 상태 삭제, (4) GA4 user_id 해제와 Sentry user 문맥 초기화, (5) 새 guest 또는 다음 계정 로그인.
- guest 자격정보를 로그아웃 때 지울지는 NEEDS-DECISION이다. 권장안: 제공자 연결 계정의 로그아웃은 새 guest를 만들고, 원래 guest 자격정보는 삭제한다(같은 기기에서 연결 계정 데이터가 guest로 새지 않도록).
- 로컬 기록(`player_records`, 배지)과 표시명은 계정 전환 시 소유자 기준을 정해야 한다. 서버 저장이 없는 동안은 기기 로컬로 유지하고 계정별 분리를 약속하지 않는다.

## 5. 구현 계획
### Step 1: 계약과 채널별 인증 검증
- [x] 현재 PocketBase guest와 이벤트 문맥 연결 계약(4.1, 4.2, 4.5). ADR 문서화는 제공자 결정 후
- [ ] NEEDS-DECISION 앱인토스: 인증 코드 교환의 게임 카테고리 지원과 hash 동일성을 실제 토스 QR에서 확인. mTLS 인증서 발급과 교환 서버 위치 결정. 미지원이면 guest 유지
- [ ] NEEDS-DECISION 웹: guest + 선택적 Google 또는 이메일 인증 중 선택. 앱: Google/Apple 연결 후보. 콘솔 정보는 사용자 제공 대기
- [x] 채널 간 연결은 양쪽 계정의 소유권 확인을 거친다. 같은 닉네임이나 이메일 문자열만으로 자동 병합하지 않는다
- [x] 분석/오류 보고에 원본 토스키, 이메일, 표시명을 보내지 않는 매핑 원칙(4.4). analytics_id 발급 방식은 NEEDS-DECISION

### Step 2: 공통 프로필과 진입 UI
- [ ] 게스트 player_id와 자동 닉네임, 반복 이름 입력 제거, 프로필에서 변경.
- [ ] 현재 로컬 누적 기록을 보존하고 신규 가입으로 오인해 초기화하지 않는다.
- [ ] 랭킹 이름 변경이 과거 점수 행에 미치는 정책과 표시명을 확정한다(NEEDS-DECISION. 권장안: 과거 행은 제출 당시 이름 유지).

### Step 3: 계정 연결과 서버 기록
- [ ] 하나의 채널부터 연결해 게스트 → 연결 계정 전환, 기존 계정 충돌, 로그아웃과 계정 전환을 검증한다.
- [ ] 점수/배지/아이템의 병합 규칙과 중복 지급 방지, 동시 기기 충돌을 먼저 정의한다.
- [ ] 기록 서버 저장과 복구, 연결 해제/탈퇴/비활성 정리와 이벤트 보존 정책을 검증한다.

## 6. 병렬 작업과 변경 범위
- 토스 공식 규격 확인과 웹/네이티브 인증 조사는 독립 가능하다. 결정 전 제품 인증 코드를 병렬 구현하지 않는다.
- 공통 계약 후 프로필 UI와 서버 훅/권한은 파일 소유권을 나눠 개발하고 통합 검수한다.
- 예상 경로: `lib/services/backend/pocketbase_*`, `lib/services/records`, `lib/views/title`, 프로필 UI, `pocketbase/pb_hooks`, 새 `pocketbase/pb_migrations` 파일(적용된 마이그레이션은 수정하지 않음).
- 충돌 규칙 초안: 제공자 식별값 유니크. 이미 다른 player에 붙어 있으면 연결 거절 후 사용자에게 선택을 요구한다. 자동 병합 없음.
- 외부 서비스 등록, 원격 마이그레이션, 배포는 후속 작업에서 범위를 확정한다.

## 7. 검증 계획
- 게스트 재방문/저장소 삭제/재설치, 기존 사용자 업그레이드, 연결 충돌과 재시도.
- 계정 A/B 전환 시 프로필/이벤트 큐/세이브 누출 없음, owner 불일치 이벤트 미전송, 컬렉션 권한, 삭제와 복원.
- 토스 hash 직접 전달 요청의 거절, 만료/재사용 인증 코드 거절.
- 실제 토스 QR, 웹, Android/iOS에서 각각 확인. 한 채널 성공을 다른 채널 성공으로 일반화하지 않는다.

## 8. 위험 / 미해결 사항
- NEEDS-DECISION: 기본 로그인 제공자, 채널 간 통합 계정 제공 여부, analytics_id 전송 범위, 로그아웃 시 guest 처리, 자동 닉네임 중복 정책.
- 토스 키 수신은 서버 인증 완료가 아니다. 인증 코드 교환 경로 확보 전 원격 권한 설계를 배포하지 않는다.
- 게임 카테고리 인증 코드 지원이 없으면 토스 사용자도 설치 guest로 남아 기기 변경 시 기록이 끊긴다.

## 9. 완료 조건
- 채널별 계정 소유권, 기존 기록 보존, 복구/삭제 검증과 ADR/Spec/Status 동기화.
- 관련 자료: [토스 사용자 식별키 발급](https://developers-apps-in-toss.toss.im/guide/authentication/anon-key.md), [토스 인증 코드 발급](https://developers-apps-in-toss.toss.im/guide/authentication/anonymous-key-auth-code.md), [토스 사용자 식별 예제](https://github.com/toss/apps-in-toss-examples/tree/main/user-identification), [PocketBase 인증](https://pocketbase.io/docs/authentication/).
