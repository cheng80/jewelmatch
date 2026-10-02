# PLAN-013 PocketBase 이전

## Metadata
- Plan ID: `PLAN-013`
- Status: `DONE`
- Owner: Codex
- Updated: 2026-09-29
- Related: ADR-009, API-000~007, PLAN-006, PLAN-009

## 1. 목표와 범위

사용자 요청에 따라 Supabase 대신 자체 운영 PocketBase를 사용한다. 기존 PLAN보다 우선한다. 게임 규칙과 표시 화면을 유지하며 익명 인증, 랭킹, 광고 보충 제한, 이벤트 수집, 원격 설정과 보존 작업을 이전한다.

PLAN-009 Step 4, GA4/Sentry, 가입 UI와 영속 인벤토리는 이 작업에 포함하지 않는다. 이번 이전을 이유로 서버 이벤트 중복 제거와 영속 전송 큐를 구현 완료로 표시하지 않는다. 커밋/push는 요청 시 별도로 수행한다.

## 2. 확인한 현재 상태

- 앱은 `http` 기반 `SupabaseGateway`를 사용한다. 랭킹만이 아니라 `BackendBootstrap`, `EventLogger`, `GameplayConfigService`, `SupabaseAdRefillLimitBackend`가 의존한다.
- PocketBase 주소는 `https://stonematch-pb.fastmake.net`, 관리자 정보는 Git 제외 `.env.pocketbase`다. 클라이언트는 관리자 자격정보를 사용하지 않는다.
- 기존 PocketBase 일반 컬렉션은 `users`, `tasks`다. 기존 데이터와 설정을 삭제하거나 용도를 바꾸지 않는다.
- 관리 화면 JS에 `PocketBase v0.39.7` 표시를 확인했다. 실행 파일의 실제 `--version`과 설치 경로, 실행/재시작 방식은 서버 접근 후 확인한다. 공식 문서의 최신 버전을 원격 서버 버전으로 간주하지 않는다.
- 2026-09-29 원본 조회: ranking_entries 11행(time 10, level 1), game_events 353행, ad_refill_claims 0행, app_config 3행(ads/gameplay/ranking), 익명 사용자 38명. 이 수치는 조사 시점이며 실제 이전 직전 다시 조회한다.
- 기존 Supabase 공개 랭킹 조회는 time/level 각각 HTTP 200, 각 1행이었다. 모바일 웹 장애 원인은 아직 재현하지 않았으며 프로젝트 정지로 단정하지 않는다.
- PocketBase의 NAS 출처 OPTIONS 요청은 HTTP 204이며 authorization/content-type과 POST가 허용됐다. 실제 모바일 UI 검증을 대신하지 않는다.
- 근거: `tmp/pocketbase-migration-20260929/`, 앞선 연결 조사 `tmp/pocketbase-discovery-20260929/`, 도메인 변경 `tmp/pocketbase-domain-20260929/`.

## 3. 이전 계약

### 데이터와 인증

- 기존 `users`, `tasks`와 충돌하지 않게 Stone Match 전용 컬렉션을 사용한다. 예: `sm_players`, `sm_rankings`, `sm_ad_claims`, `sm_events`, `sm_config`. 최종 이름은 마이그레이션에서 고정한다.
- Supabase UUID와 PocketBase record ID를 같다고 가정하지 않는다. 원본 ID를 별도 보존하고 가져오기 재실행에서 중복을 막는 매핑을 둔다.
- 공개 랭킹은 원본 이름, 점수, 등록 시각과 동점 순서를 유지한다. 이전 과정에서 과거 순위 시각을 현재 시각으로 바꾸지 않는다.
- 익명 사용자에게 이메일/가입 화면을 새로 요구하지 않는다. PocketBase 토큰 만료 후에도 같은 설치 사용자를 복구할 방법을 구현 전 확정한다. Supabase refresh_token을 PocketBase 토큰으로 취급하지 않는다.
- 구 사용자와 새 사용자를 UUID 문자열만으로 연결하지 않는다. 기존 토큰의 서버 검증에 기반한 연결 또는 기록 보존 후 새 익명 식별 정책을 명시해야 한다. 검증 불가능하면 광고 제한과 이벤트 사용자 연속성의 영향을 사용자에게 설명하고 결정한다.
- 관리자 토큰으로 플레이하지 않는다. 비공개 사용자 ID와 이벤트는 공개 조회에 노출하지 않는다. 일반 사용자, 비인증 요청의 권한 테스트를 따로 수행한다.

### 서버 기능

기존 응답 형태를 유지하는 전용 `/api/stone-match/...` API를 우선 검토한다. 클라이언트에 PostgreSQL RPC 구조를 흉내 내는 광범위한 호환 서버를 만들지 않는다.

| 기능 | 보존할 계약 | PocketBase 구현 방향 |
|---|---|---|
| 랭킹 목록/1위 | time은 KST 월요일 기준 이번 주, level은 전체 기간. 점수 내림차순, 등록 시각과 기존 ID 순 | 공개 전용 응답과 맞는 인덱스 |
| 랭킹 제출 | 이름 정제 20자, level 10000/time 1000000000 상한, 양의 정수, 사용자당 분당 10건 | 인증 API, 서버 검증, 트랜잭션 |
| 광고 상태/지급 | KST 오늘, 기본 하루 3회(설정 0~20), 동시 요청에서 한도 초과 금지 | 인증 API와 SQLite 트랜잭션 |
| 이벤트 | schema_version 3 및 기존 예약 필드 보존, 사용자당 분당 300건, 클라이언트 조회 금지 | 인증 배치 API와 전체 배치 검증 |
| 원격 설정 | ads/ranking/gameplay의 현재 원격 값 유지, 앱은 조회만 가능 | 제한된 공개 조회와 관리자 쓰기 |
| 보존 작업 | 이벤트 90일, 광고 35일, 비활성 익명 사용자 90일. 랭킹은 사용자 정리 후에도 보존 | cronAdd 및 삭제 영향 검증 |

- SQLite 저장 크기와 PostgreSQL jsonb 내부 저장 크기는 다르다. JSON 유효성, 객체 여부와 UTF-8 바이트 제한을 명시하고 기존 payload 표본으로 확인한다.
- JS 훅은 Node.js가 아니다. 핸들러 외부 변수에 의존하지 않으며 공통 함수는 `require()` 모듈로 둔다. 트랜잭션 내부에서는 `txApp`을 사용한다.
- 기존 네트워크 실패 처리, 인증 재시도 대기, 랭킹 나가기 대기 상한, 광고 장애 시 로컬 제한과 게임 진행 보장을 유지한다.

## 4. 실행 단계

### Step 1: 조사와 배포 기반
- [x] 의존 코드, SQL 계약과 원본 데이터 규모 확인
- [x] 대상 관리자 연결, 기존 컬렉션, 새 주소와 CORS 확인
- [x] 데이터 보존과 인증 전환의 결정 지점 정리
- [x] 실행 폴더, 바이너리 버전, 실행/재시작 방식과 서버 파일 배포 경로 확인
- [x] 익명 사용자 연속성 계약 확정(사용자 승인: 새 계정 발급), ADR-010 작성

### Step 2: 로컬 서버 구현과 검증
- [x] 실제 서버 버전에 맞춘 `pocketbase/pb_migrations`, `pocketbase/pb_hooks` 작성
- [x] 별도 로컬 데이터 폴더에서 마이그레이션 적용과 재시작 검증
- [x] 인증/권한, 순위/동점/KST 경계, 동시 광고 요청, 이벤트 크기/빈도 제한, 보존 작업 검증
- [x] 비밀정보 없는 배포 패키지와 백업/복구 절차 준비

### Step 3: Flutter 연결과 데이터 이전 준비
- [x] 기존 서비스에 필요한 최소 공통 gateway 계약과 PocketBase 구현
- [x] PocketBase 전용 세션 저장과 공개 연결 설정. 기존 로컬 기록과 별도 사용자 변경 보존
- [x] 원본 export, ID 매핑, dry-run, 가져오기 재실행 검증 도구
- [x] 관련 테스트, analyze, release Wasm/JS 빌드 검증

### Step 4: 배포와 전환
- [x] 실행 중인 PocketBase의 일관된 백업 확보 후 훅/마이그레이션 배포
- [x] 원본 데이터 재조회와 백업, 가져오기와 건수/내용 검증. 원본 Supabase는 삭제하지 않는다
- [x] 이전 중 기존 클라이언트가 추가한 행을 반영할 최종 차이 수집 절차 수행
- [x] NAS 배포 후 ego에서 랭킹 UI 조회, 브라우저 인증 API 제출과 실제 앱 이벤트 적재 확인(점수 획득부터 전체 UI 제출은 아래 한계 참조)
- [x] 재시작 후 로그인/데이터 유지와 모바일 검증 한계 기록
- [x] 제품/기술/개발 절차/상태 문서와 개인정보 안내의 실제 변경 범위 동기화

## 5. 배포 정보

서버 폴더는 `/Users/cheng80/Servers/stonematch`, Tailscale 주소는 `100.92.43.82`, SSH 계정은 `cheng80`다. 등록된 SSH 키로 배포하며 관리자 API 자격정보와 공개 빌드 설정은 분리한다. `com.fastmake.stonematch.pocketbase` LaunchAgent는 해당 사용자 로그인 후 실행한다. 실제 mac-mini 재부팅은 하지 않았다.

현재 운영 인스턴스에는 사전 조사 이후 외부에서 추가된 삭제 마이그레이션으로 `users`/`tasks`가 없다. 삭제 변경을 되돌리지 않고 배포 직전 상태를 백업했으며 Stone Match 컬렉션 5개만 추가했다. 초기 사전 조사 수치는 실행 이력이다.

## 6. 완료와 복구 기준

완료는 로컬 구현만이 아니라 실제 서버와 NAS 전환 후 검증까지다. 복구 시 기존 Supabase 빌드와 연결 설정을 유지하고 PocketBase 신규 쓰기의 보존/역이관을 먼저 고려한다. 새 기록이 생긴 뒤 단순 DNS 변경만으로 원상복구됐다고 판단하지 않는다. 기존 오디오/포맷 변경과 `test/web/`는 이전 작업에 임의로 포함하거나 되돌리지 않는다.

## 7. 공식 자료
- [컬렉션](https://pocketbase.io/docs/collections/)
- [인증](https://pocketbase.io/docs/authentication/)
- [API Rules](https://pocketbase.io/docs/api-rules-and-filters/)
- [JS 실행 환경](https://pocketbase.io/docs/js-overview/)
- [라우팅](https://pocketbase.io/docs/js-routing/)
- [트랜잭션](https://pocketbase.io/docs/js-database/)
- [마이그레이션](https://pocketbase.io/docs/js-migrations/)
- [주기 작업](https://pocketbase.io/docs/js-jobs-scheduling/)
- [운영과 백업](https://pocketbase.io/docs/going-to-production/)

## 8. 실행 기록

- SSH 키 등록 완료. 실제 바이너리는 PocketBase 0.39.7(arm64), launchd가 KeepAlive/RunAtLoad로 관리한다.
- 사용자 요청으로 서버 폴더를 `/Users/cheng80/Servers/stonematch`, launchd label을 `com.fastmake.stonematch.pocketbase`로 변경했다. 포트 127.0.0.1:8090과 공개 도메인은 유지한다. 서비스 중지 후 전체 14개 파일을 백업하고 SHA-256 일치 확인 후 이동/재기동했으며 로컬 health 200이다. 백업: `/Users/cheng80/Servers/backups/pocketbase-before-stonematch-20260929-211422`.
- 사용자 결정: 기존 익명 사용자 계정은 이전하지 않고 새 PocketBase 계정으로 시작한다. Supabase 인증 의존과 사용자 연결 브리지는 추가하지 않는다. 기존 랭킹/이벤트 원본은 보존하며 로컬 게임 기록은 그대로 유지한다.

### 최종 결과와 검증 한계

운영 서버/API/데이터와 NAS 웹 전환을 완료했다. 상세 결과와 수치는 PROJECT_STATUS/HANDOFF의 완료 기록을 따른다. 컬렉션 규칙은 null(Locked)이며 실제 비로그인/플레이어 권한 거절을 검사했다. 공개 랭킹 두 모드의 원본 일치와 실제 브라우저 인증 제출/앱 이벤트 적재를 확인했다. 점수 획득부터 나가기까지 전체 UI 흐름, 모바일 실기기, 실제 Mac 재부팅과 cron 예약 실행은 검증하지 못했다. 서비스 재시작/토큰 유지와 cron 정리 함수의 로컬 DB 검증으로 범위를 구분한다. 구 탭의 향후 Supabase 쓰기는 자동 동기화하지 않는다.
