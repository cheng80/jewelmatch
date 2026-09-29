# 이전 Supabase 기술 계약 (운영 사용 중단)

2026-09-29 PocketBase 단독화 이전 이력이다. 신규 앱, 빌드, 서버 운영의 정본은 ../03_TECH_SPEC.md와 ADR-010이며 아래 PostgreSQL/RPC 내용은 신규 기능 구현 지침이 아니다.

# Tech Spec

> TRD + Data Model + API Spec을 통합한 기술 Source of Truth다.
> 시스템의 HOW와 기술 계약만 기록한다.

작성 기준일: 2026-08-23, 계약 정합 수정 2026-08-23
근거: pubspec.yaml, lib/, supabase/migrations/, 테스트

## 1. 기술 스택

| 영역 | 기술 | 선택 이유/제약 |
|---|---|---|
| Client | Flutter 3.47.5(stable), Dart SDK ^3.10.8 | 멀티 채널 한 코드베이스 |
| Game | Flame ^1.35.1 | 보드 루프/렌더 |
| Routing | go_router ^17 | / , /game, /setting |
| State | flutter_riverpod ^3 수동 Notifier | codegen 미사용 |
| i18n | easy_localization, ko/en/ja/zh-CN/zh-TW | assets/translations |
| Local store | shared_preferences | 설정, 베스트, 이름 |
| Audio | flame_audio + 웹 HTML Audio 4슬롯 | ADR-004 |
| HTTP | http | 랭킹 |
| Ads | Apps in Toss SDK 3.x (intoss 채널) | AdService 추상화 |
| Ranking backend | Supabase RPC(PostgREST), 익명 로그인 | ADR-009. NAS `ranking.php`는 2026-09-24 폐기 |
| Version | 1.0.0+1 | pubspec.yaml |

## 2. Architecture

    Flutter App Shell
      main.dart (ProviderScope, EasyLocalization, preload)
        App (StarryBackground 싱글톤 + MaterialApp.router)
          TitleView / GameView / SettingView
            GameView → GameWidget<MatchBoardGame>
              viewport: MatchGameHud
              world: MatchBoardRenderer + BoardJuiceLayer + SpecialEffectPool
            MatchBoardLogic: 보드 규칙
            VM: SettingsNotifier, RankingNotifier
            Services: SoundManager, RankingService, AdService, IntossLeaderboardService

### 구조 규칙

- 보드 규칙은 MatchBoardLogic, 렌더는 Renderer, 입력은 HUD. 역할을 섞지 않는다
- 광고 위치/보상 판정은 게임 코드, SDK는 AdService 구현체만
- STORE_CHANNEL dart-define으로 채널을 고른다. 잘못된 값은 기동 실패
- Riverpod annotation / build_runner를 새로 넣지 않는다
- render()/update()에서 Paint, TextPainter, Vector2, 리스트, 문자열 키를 반복 생성하지 않는다
- 임시 산출물은 tmp/ 하위

주요 모듈: lib/game/match_board_*.dart, lib/game/speed_bonus.dart, lib/ads/, lib/services/ranking_service.dart, lib/services/backend/(Supabase), lib/services/event_logger.dart, lib/services/records/(PlayerRecords, CumulativeRank, RecordBadge, RecordsStore), lib/vm/

## 3. 인증 / 권한 / 보안

- 인증 방식: Supabase 익명 로그인(ADR-009). 설치 또는 브라우저 저장소 단위 익명 사용자. 계정, 이메일, 토스 사용자 식별자 없음. 플레이어 이름은 로컬 StorageKeys.playerName이며 랭킹 제출 때만 서버에 간다
- 권한 모델: public 스키마 전 테이블 RLS. 랭킹 조회는 anon, 제출과 보충 광고 기록, 이벤트 삽입은 익명 로그인 사용자 본인 행만. `user_id`는 anon/authenticated에게 공개 조회 권한이 없다(보충 기록의 본인 행 제외). 설정 쓰기와 랭킹 초기화는 대시보드 서비스 권한만
- Secret 관리: Supabase secret/service_role 키는 클라이언트, 저장소, 문서에 두지 않는다. 공개용 키와 URL도 코드에 쓰지 않고 `config/supabase.json`(Git 제외)으로 넣는다. MATCH_DEPLOY_TOKEN은 .env / NAS env. 문서, 로그, URL에 넣지 않는다
- 클라이언트 저장 금지 정보: 관리자 토큰, secret 키, 키스토어 비밀번호, 토스 사용자 식별자, 광고 식별자. 익명 세션 토큰은 로컬 저장하되 로그와 이벤트에 넣지 않는다
- AppConfig.appStoreId는 출시 전 입력. 현재 빈 문자열
- 이전 NAS ranking.php는 CORS * 와 관리자 토큰 헤더(X-Ranking-Admin-Token) 방식이었다. 2026-09-24 폐기

## 4. 데이터 모델

### Entity: GemCell (보드 칸)

| Field | Type | Constraint | 설명 |
|---|---|---|---|
| row, col | int | 0..7 | 8×8 |
| color | enum | normal만 색 매치 | |
| kind | GemKind | normal/bomb/star/hyper/supernova/row/col | row/col은 legacy |

### Entity: MatchBoardGameStats

| Field | Type | 설명 |
|---|---|---|
| validSwaps | int | 유효 스왑 |
| matchGroups | int | 매치 그룹 |
| removedGems | int | 제거 보석 |
| specialGemsCreated / Activated | int | 특수 생성/발동 |
| specialCreatedByKind / ActivatedByKind | map | 종류별 |

### Entity: RunInventory / StageLoadout

| Field | Type | Constraint | 설명 |
|---|---|---|---|
| counts | Map<ItemKind,int> | >=0 | 세션 보유량 |
| slots | 4 | 초기 open 2 | 중복 아이템 없음 |
| locked | bool | index >= openSlotCount | |

영속 PlayerInventory는 미구현.

### Entity: RankingEntry

| Field | Type | Constraint | 설명 |
|---|---|---|---|
| name | string | 필수 | |
| score | int | >0 제출 | 타임=점수, 레벨=완료 레벨 |
| ts | int? | epoch | |

저장소: Supabase `ranking_entries`(id, user_id, mode, name, score, created_at, week_start). 클라이언트에는 name, score, ts(created_at epoch)만 돌아온다. `week_start`는 `date_trunc('week', created_at at time zone 'Asia/Seoul')::date` 생성 열(KST 월요일)이며 클라이언트가 쓸 수 없다. 인덱스 `ranking_entries_mode_week_score_idx`(mode, week_start, score desc, created_at, id). 마이그레이션 `20260924120000_stone_match_weekly_ranking.sql`(BR-095). `20260924160000_stone_match_weekly_ranking_plan.sql`은 두 RPC를 plpgsql로 바꿔 time과 그 밖의 모드를 별도 문장으로 나눈다. PG17은 SQL 함수 본문을 인자 없이 계획해 한 문장 조건으로는 주간 인덱스를 쓰지 못하고 전체 기간 기록을 훑기 때문이다(검수 P2-1, PGlite 강제 generic 계획에서 time 조회 버퍼 1009에서 4).
`user_id`는 null 허용이고 `on delete set null`이다. 익명 사용자를 지워도 공개 랭킹 기록은 남는다. `ad_refill_claims`, `game_events`는 사용자와 함께 지워진다(cascade).
이름 규칙: 1~20자, 앞뒤 공백 없음, 제어 문자와 보이지 않는 서식 문자, 방향 문자, 한글 채움 문자 금지(이모지와 문자 결합에 쓰는 ZWJ, ZWNJ는 허용), 보이는 문자가 하나도 없는 이름 금지. `submit_ranking`은 금지 문자를 지운 뒤 trim과 20자 절단을 한다. 입력은 있었는데 정리 뒤 보이는 문자가 남지 않으면 클라이언트 기본값과 같은 `GUEST`로 저장하고, 입력이 비어 있으면 거부한다. 체크 제약은 직접 삽입을 막는 마지막 방어다.

### Entity: Supabase 테이블 (ADR-009)

| 테이블 | 용도 | 클라이언트 권한 |
|---|---|---|
| app_config | key, value(jsonb) 원격 설정. 현재 `ranking.list_limit`=30, `ads.daily_refill_limit`=3 | anon/authenticated 조회(key, value) |
| ranking_entries | 게임 내 랭킹 기록 | anon/authenticated 조회(user_id 제외), authenticated 본인 삽입 |
| ad_refill_claims | 보충 광고 지급 기록(KST claim_date, item) | authenticated 본인 조회, 본인 삽입 |
| game_events | 이벤트 로그 | authenticated 본인 삽입만 |

실험 스위치(PLAN-008, 원격 적용): `app_config` 키 `gameplay`(`GameplayFlags.toJson` 형식, 마이그레이션 `20260924180000_stone_match_gameplay_flags.sql`). 앱은 시작 때 로컬 캐시(`gameplay_flags`)를 먼저 적용하고 `GET /rest/v1/app_config?key=eq.gameplay&select=value`(anon, `SupabaseGateway.select`)를 백그라운드로 받아 다음 새 판부터 쓴다. 웹 `?exp=`는 항상 마지막에 덮어쓰고 캐시에 남지 않으며, 그렇게 시작한 판은 랭킹 제출을 건너뛴다. 원격 값은 앱 시작 때 한 번만 받는다. `BoardGem.bonus`(`GemBonus`)는 `GemKind`와 별개 속성이고, 배지는 `Gem_Badges.png`(256×128) 한 장에서 보석 atlas 제출 뒤 drawImageRect로 그린다. 보석 atlas는 종류 7 × 색 7로 굽는다. QA: `__jewelMatchDebugPlaceBonus(kind, row, col)`, 상태 `scoreMultiplier`, `bonusGems`, `dailyKey`, `boardSignature`.

보존(원격 적용): `supabase/migrations/20260924090000_stone_match_retention.sql`이 pg_cron으로 매일 `game_events` 90일, `ad_refill_claims` 35일 지난 행을 지운다(KST 04:00, 04:10). 익명 사용자 정리(원격 적용, 2026-09-24): `20260924140000_stone_match_anon_cleanup.sql`의 `private.purge_inactive_anonymous_users(p_inactive_days default 90, p_dry_run default false)`가 KST 04:20에 돈다. 가입, 마지막 로그인, 세션 생성과 갱신이 모두 90일보다 오래된 익명 사용자만 지운다(30일 미만 값은 30일로 보정). Supabase 익명 로그인 공식 문서의 SQL과 pg_cron 방식이다. 랭킹 행은 이름과 점수가 남고, 이벤트와 보충 기록은 함께 지워진다. 지워진 사용자의 클라이언트는 토큰 갱신이 거절되면 새 익명 사용자로 가입한다. 정리 함수는 모두 `private` 스키마에 있고 클라이언트 역할은 실행할 수 없다.

### Entity: Settings

StorageKeys: bgm/sfx volume·mute, keepScreenOn, showFps, best scores by mode, playerName, review flags.

### Entity: PlayerRecords (PLAN-005 R1)

로컬 키 `player_records` 하나에 JSON(`v`=1). 누적 점수, 누적 랭크, 모드별 최고, 최고 한 수, 최장 연쇄, 누적 제거, 특수 보석 누적(bomb, star, hyper, supernova), hyperSwaps(H2 누적), 배지 등급. 손상값은 빈 기록으로 초기화한다. 반영 지점은 `MatchBoardGame.commitRecords`(판 종료 `logRoundEnd`, 레벨 클리어)이며 같은 스테이지의 재반영은 앞서 반영한 통계를 빼고 더한다.

### 관계 / 제약

- 특수 보석은 색 매치에 참여하지 않는다
- 레벨 랭킹 score = 완료 레벨 수 (현재 레벨 - 1, 0이면 미제출). HUD top1 fetch는 타임만
- 광고 refill는 inventory 수량 0이고 일 3회 미만일 때만

## 5. API 계약

### PocketBase 현재 계약 (ADR-010, PLAN-013)

새 빌드의 기본 서버는 PocketBase다. 배포 상태는 PROJECT_STATUS 기준이며 아래 Supabase RPC 설명은 구 빌드/복구용 계약이다. 제품의 응답 형식과 점수, 제출 시점은 유지한다.

- 선택: `BackendSelector`는 `config/pocketbase.json`의 `POCKETBASE_URL`을 우선한다. 없으면 기존 Supabase 설정을 사용한다. 실행 중 장애로 저장소를 자동 전환하지 않는다.
- 주소: `/api/stone-match`. 비공개 호출은 `Authorization: <PocketBase token>`이다. 앱에는 관리자 이메일/비밀번호/토큰이 들어가지 않는다.
- 인증: `POST /auth/guest`에 안전한 난수 `device_id`(32자리 hex), `device_secret`(64자리 hex)를 전달한다. 응답 `{token, record:{id}, expires_in:604800}`. 처음 발급 후 같은 자격정보로 재인증한다. 기기에 먼저 영속 저장하며 URL별 저장 키를 분리한다. Supabase의 refresh token은 사용하지 않는다.
- 기존 Supabase 사용자는 사용자 승인에 따라 연결하지 않는다. 기존 랭킹/이벤트의 ID와 등록 시각은 이력으로 보존한다. 새 계정 발급은 로컬 게임 기록 초기화와 다르다.
- 권한: `sm_*` 컬렉션 직접 CRUD는 관리자 전용이다. 플레이어는 전용 API만 사용한다. 공개 응답에는 사용자 ID나 설치 비밀값을 넣지 않는다.
- API Rules: `sm_players`, `sm_rankings`, `sm_ad_claims`, `sm_events`, `sm_config`의 `listRule/viewRule/createRule/updateRule/deleteRule`은 전부 `null`(Locked)이다. 빈 문자열은 공개 허용이므로 사용하지 않는다. `sm_players.authRule/manageRule`도 `null`이며 password/OAuth2/OTP 인증은 비활성화한다. 익명 복구는 전용 guest API만 사용한다.
- 컬렉션 규칙은 superuser와 서버 내부 DB 호출을 제한하지 않는다. 따라서 전용 훅은 플레이어 컬렉션 인증을 별도로 검사하고 사용자 관계/시각을 서버에서 지정한다. 광고/점수/이벤트 검증을 컬렉션 규칙으로 대체하지 않는다. 공개 랭킹은 이름/점수/초 단위 시각만 반환하고 원본 식별자는 숨긴다.
- 권한 근거: [공식 API Rules](https://pocketbase.io/docs/api-rules-and-filters/), [인증](https://pocketbase.io/docs/authentication/). 문서 최신판과 별개로 실제 0.39.7 및 운영 인스턴스의 규칙과 접근 거절을 검증한다.

| 호출 | 인증 | 응답/계약 |
|---|---|---|
| `GET /health` | 불필요 | Stone Match 서버/스키마 상태 |
| `POST /ranking/list` | 불필요 | `{p_mode,p_limit?}` → 기존 `[{name,score,ts}]` |
| `POST /ranking/submit` | 필요 | `{p_mode,p_name,p_score}` → 기존 `{mode,ranked,rank,score,week_start?}` |
| `POST /ads/status` | 필요 | 기존 `{daily_limit,used_today,remaining,date}` |
| `POST /ads/claim` | 필요 | `{p_item}` → 상태와 `granted` |
| `POST /events` | 필요 | 기존 EventLogger 행 배열, 성공 204 |
| `GET /config/gameplay` | 불필요 | 기존 `[{value:...}]` |

랭킹은 KST 이번 주(time)/전체 기간(level), 점수 내림차순/등록 시각/순번 오름차순이다. 기존 ID는 `legacy_id`, 동점 순번은 `order_seq`로 보존한다. 신규 쓰기의 소유자와 시각은 서버가 정한다. 광고 한도 검사와 삽입, 이벤트 300건/분 제한과 배치 삽입은 각각 한 트랜잭션으로 수행한다. 랭킹 제한은 10건/분이다.

이벤트 `params`는 객체와 UTF-8 JSON 2048바이트 상한으로 검사한다. 기존 jsonb 내부 저장 크기와 같은 개념이 아니다. 클라이언트 1500바이트 예산과 schema_version 3, 표본/QA 규칙은 유지한다. 영속 큐/서버 event_id 중복 제거는 미구현이다.

보존 작업은 이벤트 90일, 광고 35일, 비활성 플레이어 90일이다. 플레이어 정리 후 공개 랭킹은 남는다. 비활성 계정이 정리된 기기는 다음 인증에서 새 서버 사용자로 복구될 수 있다. 원본 Supabase 자체는 삭제하지 않는다.

### Supabase 이전 계약 (구 빌드와 복구용)

저장소: Supabase(ADR-009). 프로젝트 URL과 공개용 키는 `config/supabase.json`(Git 제외)에서 dart-define으로 넣는다. 스키마 정본은 `supabase/migrations/20260923142920_stone_match_init.sql`.
호출: `SupabaseGateway`가 `POST {URL}/rest/v1/rpc/{함수}`와 `POST {URL}/auth/v1/...`을 부른다. 헤더 `apikey: <공개용 키>`, 로그인이 필요한 호출은 `Authorization: Bearer <익명 사용자 JWT>`.
관련: FR-009, FR-010, BR-001, BR-002, BR-103
2026-09-23 이전 NAS `ranking.php` 계약(아래 "이전 NAS API")은 2026-09-24 새 빌드 배포와 함께 폐기했다. NAS 기록은 이관하지 않았다.

### API-000 익명 인증

- 가입: `POST /auth/v1/signup` body `{"data":{}}` → `access_token`, `refresh_token`, `expires_in`/`expires_at`, `user.id`
- 갱신: `POST /auth/v1/token?grant_type=refresh_token` body `{"refresh_token": "..."}`
- 세션은 `StorageKeys.supabaseSession`(shared_preferences, 웹은 localStorage)에 저장한다. 만료 60초 전부터 갱신한다.
- 만료 시각은 `expires_in`이 있으면 로컬 시각 기준으로 계산한다(기기 시계 차이 대응). 없으면 `expires_at`을 쓴다.
- 인증 직전과 새 가입 직전에 저장소의 최신 세션을 다시 읽는다. 웹은 `SharedPreferences.reload()` 뒤 읽어 다른 탭이 회전한 refresh 토큰을 쓴다. 저장된 refresh 토큰이 메모리와 다르면 만료 전이면 바로 쓰고, 만료면 그 토큰으로 갱신한다.
- 갱신이 네트워크 문제로 실패하면 새 사용자를 만들지 않는다. refresh 토큰이 거절될 때만 새로 가입한다.
- 서버가 401을 주면 한 번만 갱신 후 다시 보낸다. 갱신 뒤에도 401이면 인증 대기로 넘긴다. 403은 권한 문제라 갱신하지 않고 `rejected`로 처리한다. 동시 인증 요청은 하나로 합친다.
- 인증 실패 뒤 대기: 거절, 빈도 제한, 서버 오류는 60초부터 실패마다 2배, 상한 10분. 네트워크 실패는 10초 고정. 대기 중에는 요청 없이 바로 실패를 돌려준다. 성공하면 초기화하고, 대기 끝 시각이 지금보다 10분 넘게 미래면(시계 역행) 대기를 끝낸 것으로 본다.
- 랭킹 제출 대기 상한은 Supabase 제출과 토스 리더보드 제출을 합쳐 8초다(BR-093). 넘기면 기존 실패 문구로 처리한다. 요청은 취소되지 않으므로 늦게 저장될 수 있다.

### API-001 목록

RPC `get_ranking(p_mode text, p_limit integer default null)`, anon 호출(로그인 불필요)

**Success**
    [ { "name": "...", "score": 123, "ts": 1790000000 } ]

- `p_limit`가 null이면 `app_config.ranking.list_limit`(기본 30), 1~100으로 제한
- 정렬: score 내림차순, 같은 점수는 먼저 등록한 기록이 위
- `time`은 이번 주(KST 월요일 00:00 시작, `week_start`) 기록만 돌려준다. `level`은 전체 기간(BR-095). 시그니처와 반환 열은 주간 변경 전과 같다
- 클라이언트: `RankingService.fetchList(mode:)`

### API-002 1위

`get_ranking(p_mode, 1)`의 첫 행. 빈 배열이면 null 성공.
관련: BR-092. HUD 왕관은 타임 모드만 호출한다. `RankingService.fetchTop1()` 기본 mode=time.

### API-003 제출

RPC `submit_ranking(p_mode text, p_name text, p_score integer)`, 익명 로그인 필요

**Success**
    { "mode": "time"|"level", "ranked": true|false, "rank": n, "score": n, "week_start": "YYYY-MM-DD"(time만) }

- `time` 순위는 방금 넣은 행과 같은 주 안에서 센다

- 동일 이름 다중 기록 허용(BR-090). 모든 기록을 저장하고 `rank <= list_limit`이면 ranked=true
- 이름은 앞뒤 공백 제거 후 1~20자. score는 1 이상, 레벨 10,000 이하, 타임 1,000,000,000 이하
- 사용자당 1분 10건 초과는 `ranking_rate_limited`(P0001)로 거절
- 클라이언트는 score<=0이면 호출하지 않는다(BR-091)

**Errors (RankingFailure 매핑)**
- 404(함수 없음) → notFound
- 조회의 5xx, 제약 위반, 빈도 제한 → loadFailed / 제출의 같은 오류 → saveFailed
- 미설정 빌드, 네트워크, 인증 실패, 잘못된 응답 → unavailable

### API-004 운영 랭킹 초기화

클라이언트 API가 아니다. Supabase 대시보드 SQL 편집기(서비스 권한)에서만 한다. 사용자 승인 뒤 다음 순서를 지킨다.

1. 백업: `create table private.ranking_entries_backup_YYYYMMDD as select * from public.ranking_entries where mode = '<mode>';`
2. dry-run: `select count(*) from public.ranking_entries where mode = '<mode>';` 결과를 예상 건수로 고정
3. 삭제: 같은 트랜잭션에서 건수를 다시 확인하고 예상 건수와 같을 때만 `delete from public.ranking_entries where mode = '<mode>';`
4. 사후 조회: `get_ranking` 빈 목록 확인, 백업 건수 기록

### API-005 Apps in Toss 레벨 리더보드

JS bridge stoneMatchLeaderboard.submitLevelScore(score)
관련 FR-009. 새 빌드의 게임 내 목록은 위 PocketBase 계약을 쓰며 구 빌드는 API-001(Supabase)을 쓴다.

### API-006 보충 광고 하루 제한

- RPC `ad_refill_status()` → `{ "daily_limit", "used_today", "remaining", "date" }`
- RPC `claim_ad_refill(p_item text)` → 위 값 + `"granted": true|false`. 사용자별 advisory lock으로 동시 요청을 직렬화한다
- 날짜는 KST(`Asia/Seoul`), 제한은 `app_config.ads.daily_refill_limit`(기본 3, 0~20)
- 익명 로그인 필요. 실패하면 클라이언트는 세션 로컬 제한으로 판단한다

### API-007 이벤트 로그

- `POST /rest/v1/game_events`, `Prefer: return=minimal`, 행 배열. 익명 로그인 필요, 조회 권한 없음
- 행: `session_id`(uuid), `name`(`^[a-z][a-z0-9_]{0,39}$`), `params`(객체, 2KB 이하), `app_version`(32자 이하), `channel`(16자 이하), `client_ts`
- 사용자당 1분 300건 초과는 `game_events_rate_limited`로 거절
- PLAN-009 Step 3(2026-09-29): params 예약 필드는 `event_id`(UUID v4), `event_seq`(EventLogger 인스턴스 내 1부터 증가), `schema_version`(3)이다. 최초 enqueue 때 생성하고 재전송 시 보존한다. 호출자가 같은 이름으로 덮어쓸 수 없고 기존 사용자 파라미터 12개와 별도로 센다. Step 1의 버전 1, Step 2의 버전 2와 구분한다.
- `PlayEventContext`는 불변 값이다. `EventLogger.logPlay(name, context, params)`에 명시적으로 전달하면 `run_id`(UUID v4), `round_seq`(1부터), `attempt_seq`(0부터)를 예약 필드로 함께 보낸다. 일반 `log`는 판 문맥을 붙이지 않는다. 전역 현재 판 문맥과 변경 가능한 로거 싱글턴은 두지 않는다. 문맥 예약 필드도 사용자 입력으로 덮어쓸 수 없고 사용자 12개 한도에 세지 않는다.
- `event_seq`는 session_id와 함께 해석한다. 앱 재시작/다른 탭에서는 다시 시작하며 GA4 세션 ID와 동일하지 않다. 잘못된 이벤트 이름은 순번을 소비하지 않지만 큐 초과 등으로 버린 이벤트는 순번 공백을 남길 수 있다.
- 구버전 행에 `schema_version`이 없으면 legacy v0으로 해석한다. `event_id`가 없는 구버전 행은 새 ID 기반 중복 제거 대상으로 간주하지 않는다.
- event_id는 현재 params 값이며 DB 유니크 제약이 아니다. 서버 중복 제거와 영속 재전송은 PLAN-009 Step 4 전까지 제공하지 않는다. 종료 이벤트 누락만으로 충돌로 판정하지 않는다.

- 게임 흐름(PLAN-005): `SpeedBonus`(lib/game/speed_bonus.dart)는 `MatchBoardLogic.trySwap`에서 가산한다. `LastHurrah`(lib/game/last_hurrah.dart)가 마무리 발동 시점과 상한을 정하고 보드 해소는 기존 `MatchBoardLogic.update`를 쓴다. 시간 0은 `_triggerTimeUpImpl`, 판 종료 확정은 `_finalizeRound()`. 첫 자동 발동 때 `MatchBoardLogic.beginLastHurrahRules`가 마무리 규칙을 걸고(`lastHurrahRules`: 연쇄 매치의 특수 보석 생성 생략과 Multiplier 배율 동결, `lastHurrahCascadeBudget`: 자연 연쇄 `LastHurrah.maxCascadeSteps` 20단계, `comboScoreMultiplier`: `GameplayFlags.lastHurrahComboMultiplier` 기본 꺼짐), 마무리 완료와 다시 하기에서 `endLastHurrahRules`로 푼다. QA 상태 `lastHurrahActive`, QA 훅 `__jewelMatchDebugPlaceSpecial(kind, row, col)`(qaPerf 전용).
- 현재 이벤트: `session_start`(platform), `round_start`(mode), `round_end`(mode, reason, score, level?, duration_s, active_s, system_s, paused_s, background_s), `level_clear`(level, score, max_combo), `stage_continue`(level), `ranking_submit`(mode, score, ok, ranked?, rank?, failure?), `ad_reward`(placement, result, granted, outcome?, item?, level?). `outcome`은 보충 광고만 기록하며 `granted`, `adNotCompleted`, `limitReached`, `rejected` 중 하나다(`AdRewardPolicy.grantRefillVerified`의 `RefillGrantOutcome`). PLAN-005 추가: `hyper_swap`(target_kind), `speed_bonus_peak`(max_tier, total_bonus), `last_hurrah`(specials_count, score_added), `badge_earned`(badge, tier), `rank_up`(rank). round_end의 reason은 `time_up`, `exit`, `restart`, `level_clear`다(schema_version 2부터)

#### PLAN-009 Step 2 판과 시간 계약

| 상황 | 식별과 이벤트 |
|---|---|
| 모드 진입, 다시 하기 | 새 run_id, round_seq 1, attempt_seq 0, round_start 1회. 진행 중 재시작이면 이전 round_end(restart) 1회 |
| 다음 레벨 | 같은 run_id, round_seq +1, attempt_seq 0, round_start 1회. 시간 누적 초기화 |
| 레벨 클리어 | 기존 level_clear 유지, 해당 시도 round_end(level_clear) 1회 |
| 시간 종료 | Last Hurrah 완료 후 해당 시도 round_end(time_up) 1회 |
| 광고 이어하기 | 같은 run_id/round_seq, attempt_seq +1, stage_continue. round_start는 반복하지 않음 |
| 정상 나가기 | 미종료 시도만 round_end(exit) 1회 |
| NoMoves 새 보드 | 판과 시도 유지, 새 round_start 없음 |
| 강제 종료, 탭 닫기, 브라우저 뒤로가기 | 새 종료/로컬 기록 처리를 만들지 않음. 누락을 충돌로 단정하지 않음 |

`round_end`의 점수와 시간은 같은 판 안에서 누적 값이다. 이어하기 전후 결과를 합산하지 않고 `(run_id, round_seq)`의 마지막 시도 결과를 선택한다. 랭킹과 광고 응답은 비동기 요청 전의 문맥을 캡처하여 기록한다. 레벨 클리어 뒤 다음 레벨 시작 전의 아이템 장착과 보충 광고 등 준비 이벤트는 직전 판 문맥에 붙는다. 실제 다음 판 사용량으로 집계할 때는 이 준비 구간을 구분한다. 로컬 누적 기록의 기존 차감 방식과 광고 보상 식별자 `_stageAttemptSerial`은 관측 순번과 별개다.

강제 화면 해제 중 Last Hurrah가 진행 중이면 기존 Flame 생명주기 처리에 따라 즉시 마무리되어 round_end(time_up)과 기록 반영이 발생할 수 있다. 일반 강제 이탈의 종료 누락과 이 기존 예외를 구분한다.

`RoundTiming`은 주입 가능한 단조 시계(기본 Stopwatch)만 사용한다. 프레임 dt와 DateTime 경과를 혼합하지 않는다. 출력은 초 단위 double이며 내부 마이크로초 정수를 합산한다.

| 필드 | 정의 |
|---|---|
| duration_s | 해당 판 시작부터 이벤트까지의 총 경과 |
| active_s | 게임 전경 플레이 구간. 힌트와 아이템 대상 선택, 확인/프리즘 색 선택 포함 |
| system_s | 인트로와 Last Hurrah 자동 마무리 |
| paused_s | 일시정지, 도움말, 랭킹, NoMoves, 결과 화면과 전경 광고 대기 |
| background_s | hidden/paused 상태부터 resumed까지. 다른 분류보다 우선 |

네 분류는 동시에 누적하지 않으며 합은 duration_s다(부동소수 표현 오차 제외). inactive는 기존 게임 동작을 유지한다. 게임이 끝난 뒤에도 시간 누적은 paused/background로 이어져, 광고 이어하기 후 다음 round_end에는 결과 대기 시간이 포함된다. 다음 레벨과 새 게임은 초기화한다. round_end는 기존 최대 사용자 필드 7개와 시간 필드 5개로 12개 한도 안에 둔다. 실제 사용자 조작 횟수나 매 프레임 원격 전송은 이 단계에서 추가하지 않는다. QA 전용 `qaSixRewards`는 정상 클리어/종료 이벤트 없이 다음 판으로 갈 수 있으므로 정상 플레이 집계로 해석하지 않는다. 운영/QA 수집 분리는 아래 Step 3 계약을 따른다. 인트로/마무리 전이는 프레임 경계의 오차가 있을 수 있고, 기기 절전 중 Stopwatch 경과 특성은 실기기에서 미검증이다.

#### PLAN-009 Step 3 수집 정책과 요약

`log`와 `logPlay`는 전수 대상이다. `logBehavior(name, params, {context})`만 세션 기준 10% 표본에 적용하며 EventLogger 인스턴스당 최대 40건을 큐에 넣는다. 표본 여부는 비개인 session_id의 고정 해시로 결정하고 재전송은 표본 판정을 반복하지 않는다. 잘못된 이름과 백엔드 미설정 호출은 표본 상한을 소비하지 않는다. 전수는 기록 대상의 의미이며 전송 성공/보존 보장이 아니다.

| 예약 필드 | 값과 의미 |
|---|---|
| telemetry_env | production, qa, development, test. 집계 필터이며 DB 물리 분리는 아니다 |
| collection | full 또는 sampled |
| sample_rate | full은 1.0, sampled는 기본 0.1. 이벤트 확률이 아니라 선택된 세션 비율 |

예약 필드는 호출자 값으로 덮어쓰지 못하며 사용자 필드 12개 예산과 별도로 센다. 전체 params의 UTF-8 JSON 상한 1500바이트와 DB jsonb 2048바이트 계약을 유지한다. 표본의 세션당 40건 이후는 빠지므로 행동 횟수를 단순히 10배하여 전체 사용량으로 해석하지 않는다. 표본은 사용자당이 아니라 앱 실행 세션당 선택되며, 40건 상한을 타이틀/이름/게임 메뉴가 공유한다. 반복 실행과 긴 세션의 후반 메뉴 누락을 고려해야 한다. 판 단위 수치는 전수 요약을 쓴다. 신뢰성/서버 중복 제거와 장기 집계는 Step 4다.

환경은 `TELEMETRY_ENV=production|qa|development` 빌드 정의로 정한다. 비어 있으면 release는 production, debug/profile은 development다. 알 수 없는 값은 development로 분류하며 test는 테스트 생성자 주입으로만 사용한다. `TelemetryPolicy.fromBuild()`는 enqueue 시 query와 hash 라우트 query의 `qa*=1`, 빌드 정의 `QA_PERF_AUTORUN`, `QA_SPECIAL_EFFECTS`, `QA_SPECIAL_EFFECTS_CHAIN`, 비어 있지 않은 `QA_PERF_LABEL`을 검사한다. 한 번 QA가 감지되면 해당 EventLogger 세션의 이후 이벤트는 qa로 유지한다. 앞서 큐에 들어간 이벤트와 재전송 메타데이터는 변경하지 않는다. QA 진입 이전 이벤트까지 포함해 QA 세션 전체를 제외할 때는 session_id 기준으로도 필터링한다. 명시적 `TelemetryPolicy(env: test)`는 외부 QA 감지 없이 테스트를 격리한다.

판 요약은 round_end와 동일한 시도별 종료 가드에서 생성한다. `(run_id, round_seq, attempt_seq)`로 연결하며 이어하기 전후는 판 시작 기준 누적값이다. 최신 시도값을 택하고 시도들을 합산하지 않는다. 새 게임과 다음 레벨은 초기화하며 NoMoves 셔플은 보존한다. 레벨 클리어 요약은 기존 commitRecords와 같은 클리어 순간을 기준으로 하므로 진행 중인 연쇄의 나중 결과는 포함하지 않을 수 있다. 각 요약이 별도 이벤트이므로 네트워크 유실로 일부만 존재할 수 있다. 없는 요약은 0으로 간주하지 않는다.

필드 사전(판 시작 기준 누적 정수, 시간 필드만 초 단위 double):

| 이벤트 | 사용자 필드 | 의미 |
|---|---|---|
| round_summary | valid_swaps, match_groups | 유효 교환 수, 검출한 매치 그룹 수 |
| round_summary | removed_gems, removed_specials | 전체 제거 수, 그중 특수 보석 제거 수 |
| round_summary | specials_created, specials_activated, hyper_swaps | 특수 생성/발동 수, H2 하이퍼끼리 교환 수 |
| round_summary | best_move, max_combo | 한 입력의 연쇄 최고 점수, 판의 최고 콤보 |
| round_specials | created_{kind}, activated_{kind} | kind=row,col,bomb,star,hyper,supernova. 각 생성/발동 수, 0도 포함한 12필드 |
| round_input | invalid_swaps | 실제 매치 불성립으로 원위치한 교환. 입력 차단/바깥 좌표/안정 구역 거절 제외 |
| round_input | tap_swaps, drag_swaps, special_taps | 인접 칸 누름 교환, 스와이프 교환, 직접 특수 발동의 성공 횟수 |
| round_input | hints_used, items_used | 성공한 수동 힌트 표시, 실제 아이템 사용 횟수 |
| round_input | first_success_active_s | 첫 유효 교환 또는 직접 특수 발동 순간의 active_s. 성공이 없으면 필드 생략 |

제거/특수/매치/콤보는 기존 보드 통계를 재사용하므로 Last Hurrah 자동 마무리도 포함한다. best_move는 기존 trackMoves 규칙으로 이를 제외한다. 종료 직전 finishMove로 진행 중인 한 수를 확정하여 직후 commitRecords와 같은 수치를 사용한다. 입력 계수는 사용자 처리 경로에서만 증가한다. tap_swaps는 실제 교환을 일으킨 입력 경로 기준이다. 이미 칸을 선택한 상태에서 인접 칸을 누르고 드래그하면 누름 순간 성립한 교환은 tap_swaps에 속한다. 모든 포인터 누름 횟수와 제스처 시도 횟수는 수집하지 않는다. hints_used는 자동 힌트와 힌트 아이템을 제외하고, 힌트 아이템 성공은 items_used로 센다.

표본 UI 행동 사전:

| 이벤트 | 필드와 허용 값 |
|---|---|
| title_menu_action | action=settings, records, help, mode_simple, mode_progression, mode_timed, ranking |
| game_menu_action | action=pause, help, ranking. mode는 현재 게임 모드, 현재 판 문맥 포함. HUD 버튼 누름 시도만 기록하여 백그라운드 자동 정지를 제외. Last Hurrah 중 실제 메뉴가 열리지 않아도 누름은 기록 |
| player_name_dialog | step=open, confirm, cancel. mode=progression/timed(호출자가 생략하면 필드 없음) |

이름 입력의 확인/취소는 다이얼로그 결과로 판단하며 바깥 탭 취소와 키보드 제출도 포함한다. round_specials는 현재 사용자 필드 12개를 모두 사용하므로 GemKind 종류가 늘어나면 이벤트 분리와 필드 사전을 함께 갱신한다.

입력한 이름, 문자열, 길이는 남기지 않는다. 단순 화면 재렌더링은 메뉴 이벤트를 만들지 않는다. mode_progression/mode_timed는 진입 의도이며 이름창 confirm/cancel로 후속 선택을 구분한다. 실제 게임 진입은 전수 round_start로 확인한다.

### 이전 NAS API (2026-09-24 폐기, 기록용)

Base: https://cheng80.myqnapcloud.com/matchranking/ranking.php. `?action=list|top1`(GET), `?action=submit`(POST `{name, score, mode}`), `?action=reset`(POST, 헤더 `X-Ranking-Admin-Token`). JSON 파일 두 개에 모드별 상위 30건만 저장했다. 2026-09-23 클라이언트 연결을 끊었다. 파일은 NAS 폐기 결정 전까지 저장소와 NAS에 남긴다.
