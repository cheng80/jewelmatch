# Tech Spec

> TRD + Data Model + API Spec을 통합한 기술 Source of Truth다.
> 시스템의 HOW와 기술 계약만 기록한다.

작성 기준일: 2026-08-23, 계약 정합 수정 2026-08-23
근거: pubspec.yaml, lib/, matchranking/ranking.php, 테스트

## 1. 기술 스택

| 영역 | 기술 | 선택 이유/제약 |
|---|---|---|
| Client | Flutter, Dart SDK ^3.10.8 | 멀티 채널 한 코드베이스 |
| Game | Flame ^1.35.1 | 보드 루프/렌더 |
| Routing | go_router ^17 | / , /game, /setting |
| State | flutter_riverpod ^3 수동 Notifier | codegen 미사용 |
| i18n | easy_localization, ko/en/ja/zh-CN/zh-TW | assets/translations |
| Local store | shared_preferences | 설정, 베스트, 이름 |
| Audio | flame_audio + 웹 HTML Audio 4슬롯 | ADR-004 |
| HTTP | http | 랭킹 |
| Ads | Apps in Toss SDK 3.x (intoss 채널) | AdService 추상화 |
| Ranking backend | PHP 단일 파일 + JSON | NAS matchranking |
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

주요 모듈: lib/game/match_board_*.dart, lib/ads/, lib/services/ranking_service.dart, lib/services/backend/(Supabase), lib/services/event_logger.dart, lib/vm/

## 3. 인증 / 권한 / 보안

- 인증 방식: Supabase 익명 로그인(ADR-009). 설치 또는 브라우저 저장소 단위 익명 사용자. 계정, 이메일, 토스 사용자 식별자 없음. 플레이어 이름은 로컬 StorageKeys.playerName이며 랭킹 제출 때만 서버에 간다
- 권한 모델: public 스키마 전 테이블 RLS. 랭킹 조회는 anon, 제출과 보충 광고 기록, 이벤트 삽입은 익명 로그인 사용자 본인 행만. `user_id`는 anon/authenticated에게 공개 조회 권한이 없다(보충 기록의 본인 행 제외). 설정 쓰기와 랭킹 초기화는 대시보드 서비스 권한만
- Secret 관리: Supabase secret/service_role 키는 클라이언트, 저장소, 문서에 두지 않는다. 공개용 키와 URL도 코드에 쓰지 않고 `config/supabase.json`(Git 제외)으로 넣는다. MATCH_DEPLOY_TOKEN은 .env / NAS env. 문서, 로그, URL에 넣지 않는다
- 클라이언트 저장 금지 정보: 관리자 토큰, secret 키, 키스토어 비밀번호, 토스 사용자 식별자, 광고 식별자. 익명 세션 토큰은 로컬 저장하되 로그와 이벤트에 넣지 않는다
- AppConfig.appStoreId는 출시 전 입력. 현재 빈 문자열
- 이전 NAS ranking.php는 CORS * 와 관리자 토큰 헤더(X-Ranking-Admin-Token) 방식이었다. 폐기 예정

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

저장소: Supabase `ranking_entries`(id, user_id, mode, name, score, created_at). 클라이언트에는 name, score, ts(created_at epoch)만 돌아온다.
`user_id`는 null 허용이고 `on delete set null`이다. 익명 사용자를 지워도 공개 랭킹 기록은 남는다. `ad_refill_claims`, `game_events`는 사용자와 함께 지워진다(cascade).
이름 규칙: 1~20자, 앞뒤 공백 없음, 제어 문자와 보이지 않는 서식 문자, 방향 문자, 한글 채움 문자 금지(이모지와 문자 결합에 쓰는 ZWJ, ZWNJ는 허용), 보이는 문자가 하나도 없는 이름 금지. `submit_ranking`은 금지 문자를 지운 뒤 trim과 20자 절단을 한다. 입력은 있었는데 정리 뒤 보이는 문자가 남지 않으면 클라이언트 기본값과 같은 `GUEST`로 저장하고, 입력이 비어 있으면 거부한다. 체크 제약은 직접 삽입을 막는 마지막 방어다.

### Entity: Supabase 테이블 (ADR-009)

| 테이블 | 용도 | 클라이언트 권한 |
|---|---|---|
| app_config | key, value(jsonb) 원격 설정. 현재 `ranking.list_limit`=30, `ads.daily_refill_limit`=3 | anon/authenticated 조회(key, value) |
| ranking_entries | 게임 내 랭킹 기록 | anon/authenticated 조회(user_id 제외), authenticated 본인 삽입 |
| ad_refill_claims | 보충 광고 지급 기록(KST claim_date, item) | authenticated 본인 조회, 본인 삽입 |
| game_events | 이벤트 로그 | authenticated 본인 삽입만 |

보존(초안, 원격 미적용): `supabase/migrations/20260924090000_stone_match_retention.sql`이 pg_cron으로 매일 `game_events` 90일, `ad_refill_claims` 35일 지난 행을 지운다(KST 04:00, 04:10). 정리 함수는 `private` 스키마에 있고 클라이언트 역할은 실행할 수 없다. 익명 사용자 정리는 관리자 API로 따로 한다.

### Entity: Settings

StorageKeys: bgm/sfx volume·mute, keepScreenOn, showFps, best scores by mode, playerName, review flags.

### 관계 / 제약

- 특수 보석은 색 매치에 참여하지 않는다
- 레벨 랭킹 score = 완료 레벨 수 (현재 레벨 - 1, 0이면 미제출). HUD top1 fetch는 타임만
- 광고 refill는 inventory 수량 0이고 일 3회 미만일 때만

## 5. API 계약

저장소: Supabase(ADR-009). 프로젝트 URL과 공개용 키는 `config/supabase.json`(Git 제외)에서 dart-define으로 넣는다. 스키마 정본은 `supabase/migrations/20260923142920_stone_match_init.sql`.
호출: `SupabaseGateway`가 `POST {URL}/rest/v1/rpc/{함수}`와 `POST {URL}/auth/v1/...`을 부른다. 헤더 `apikey: <공개용 키>`, 로그인이 필요한 호출은 `Authorization: Bearer <익명 사용자 JWT>`.
관련: FR-009, FR-010, BR-001, BR-002, BR-103
2026-09-23 이전 NAS `ranking.php` 계약(아래 "이전 NAS API")은 새 빌드 배포 뒤 폐기 대상이다. NAS 기록은 이관하지 않는다.

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
- 클라이언트: `RankingService.fetchList(mode:)`

### API-002 1위

`get_ranking(p_mode, 1)`의 첫 행. 빈 배열이면 null 성공.
관련: BR-092. HUD 왕관은 타임 모드만 호출한다. `RankingService.fetchTop1()` 기본 mode=time.

### API-003 제출

RPC `submit_ranking(p_mode text, p_name text, p_score integer)`, 익명 로그인 필요

**Success**
    { "mode": "time"|"level", "ranked": true|false, "rank": n, "score": n }

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
관련 FR-009. 게임 내 목록은 API-001(Supabase)을 쓴다.

### API-006 보충 광고 하루 제한

- RPC `ad_refill_status()` → `{ "daily_limit", "used_today", "remaining", "date" }`
- RPC `claim_ad_refill(p_item text)` → 위 값 + `"granted": true|false`. 사용자별 advisory lock으로 동시 요청을 직렬화한다
- 날짜는 KST(`Asia/Seoul`), 제한은 `app_config.ads.daily_refill_limit`(기본 3, 0~20)
- 익명 로그인 필요. 실패하면 클라이언트는 세션 로컬 제한으로 판단한다

### API-007 이벤트 로그

- `POST /rest/v1/game_events`, `Prefer: return=minimal`, 행 배열. 익명 로그인 필요, 조회 권한 없음
- 행: `session_id`(uuid), `name`(`^[a-z][a-z0-9_]{0,39}$`), `params`(객체, 2KB 이하), `app_version`(32자 이하), `channel`(16자 이하), `client_ts`
- 사용자당 1분 300건 초과는 `game_events_rate_limited`로 거절
- 현재 이벤트: `session_start`(platform), `round_start`(mode), `round_end`(mode, reason, score, level?, duration_s?), `level_clear`(level, score, max_combo), `stage_continue`(level), `ranking_submit`(mode, score, ok, ranked?, rank?, failure?), `ad_reward`(placement, result, granted, outcome?, item?, level?). `outcome`은 보충 광고만 기록하며 `granted`, `adNotCompleted`, `limitReached`, `rejected` 중 하나다(`AdRewardPolicy.grantRefillVerified`의 `RefillGrantOutcome`)

### 이전 NAS API (폐기 예정)

Base: https://cheng80.myqnapcloud.com/matchranking/ranking.php. `?action=list|top1`(GET), `?action=submit`(POST `{name, score, mode}`), `?action=reset`(POST, 헤더 `X-Ranking-Admin-Token`). JSON 파일 두 개에 모드별 상위 30건만 저장했다. 2026-09-23 클라이언트 연결을 끊었다. 파일은 NAS 폐기 결정 전까지 저장소와 NAS에 남긴다.

## 6. 상태 관리 / 캐시 / 동기화

- 상태 관리: Riverpod SettingsNotifier, RankingNotifier. 보드 상태는 Flame 객체
- 로컬 저장: shared_preferences. 베스트 스코어 모드별, Supabase 익명 세션(StorageKeys.supabaseSession)
- 캐시: PackageInfo 1회, 스프라이트 시트 preload, HUD Paint/TextPainter, 배경 Picture
- 동기화 정책: 랭킹은 종료 시 제출. 재제출은 submitted=false일 때. 인벤토리 서버 동기화 없음
- 앱 시작: `BackendBootstrap.start()`를 기다리지 않고 호출해 익명 세션을 준비하고 `session_start`를 남긴다. 미설정 빌드는 아무것도 하지 않는다
- 광고 일일 제한: StageInventory 오버레이가 열릴 때 `ad_refill_status`로 남은 횟수를 맞추고, 광고 완료 후 `claim_ad_refill`로 지급을 기록한다. 서버가 거절하면 지급하지 않고, 서버에 닿지 못하면 AdRewardPolicy 세션 메모리 제한(기본 3회, 날짜 바뀌면 리셋)으로 판단한다

## 7. 오류 / 로깅 / 관측

- 공통 오류 모델: RankingFailure = notFound, loadFailed, saveFailed, unavailable
- 사용자 표시 원칙: 번역 키 rankNotFound 등. 나가기 가능
- 로그 정책: debugLog 기본 false. 웹 SFX는 window.stoneMatchSfx.getState()
- 민감정보 제외: 토큰, 이름 외 PII, 광고 ID를 이벤트에 넣지 않는다. EventLogger는 숫자, bool, 64자 이하 문자열 값만 12개까지 남긴다
- FPS 패널: 현재/30초 AVG/LOW/GAP. 기본 꺼짐
- 내부 이벤트: EventLogger가 Supabase `game_events`로 보낸다(API-007). 20건 또는 5초마다 묶어 보내고, 앱이 백그라운드로 갈 때 남은 이벤트를 보낸다. 네트워크, 서버, 인증 실패는 큐(최대 200건)에 되돌리고 제약 위반과 빈도 제한은 버린다. 외부 분석 SDK는 없다. 광고 정책의 ad_offer_shown 등 나머지 이름은 아직 연결하지 않았다

## 8. 테스트 / 배포

- Unit: test/match_board_logic_test.dart, special_gem_combo_test.dart, stage_reward_test.dart, item_inventory_test.dart, ranking_service_test.dart, supabase_gateway_test.dart, event_logger_test.dart, ad_reward_policy_test.dart, sound_manager_test.dart 등
- Integration: 위젯 오버레이 테스트. 광범위 E2E 없음
- 환경: STORE_CHANNEL=play|appstore|onestore|intoss, INTOSS_AD_MODE=disabled|mock|test|production, QA_SPECIAL_EFFECTS, QA_PERF_AUTORUN, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY(`--dart-define-from-file=config/supabase.json`, 예시는 `config/supabase.example.json`)
- 배포:
  - Web NAS: tools/deploy_match_web.sh, --base-href "/match/". `config/supabase.json`이 있으면 자동으로 넣고, 없으면 Supabase 기능이 꺼진 빌드라고 로그를 남긴다
  - Apps in Toss: npm run build:intoss:test(config 있으면 포함) / build:intoss(config 필수)
  - Android AAB/APK, iOS IPA: flutter build appbundle / ipa, STORE_CHANNEL define
  - Supabase 스키마: `supabase/migrations/`를 원격 프로젝트에 적용. 적용 뒤 보안 권고(advisors) 확인
- 롤백: NAS는 이전 정적 빌드 복원. 랭킹 초기화 복원은 API-004의 백업 테이블에서 다시 넣는다
- ranking.php는 웹 게임 산출물에 넣지 않는다

채널 구현 상태: ADR-005. flavor/Apple ID는 미완.
웹 오디오: ADR-004. HTML Audio 4슬롯, unlock 1회, 웹 같은 BGM은 소스 재설정 play.
성능: 모바일 웹 장시간 사운드 켠 측정은 TASK-001.

## 작성 경계

## 상세정보 보존
아키텍처, 모듈, Data/API 계약, 상태 전이, 명령어, 기술 제약의 세부 수준을 유지한다. 코드 흐름·랭킹·웹 빌드 본문은 이 파일 하단에 흡수되어 있다.


시스템의 HOW와 기술 계약만 기록한다. FR/BR/SCREEN ID로 제품/화면을 참조한다.

---

# 코드 흐름 분석

원문 제목 키: 이 팩 Tech Spec의 코드 흐름 분석 절 (이 파일에 흡수됨)

# Stone Match 코드 흐름 분석

이 문서는 현재 프로젝트의 구조와 실행 흐름을 정리한 분석본이다.
목표는 `lib/main.dart`를 시작점으로 앱이 어떻게 올라오고, 어떤 위젯과 Flame 게임 객체가 어떤 순서로 연결되는지 빠르게 따라갈 수 있게 정리하는 것이다.
게임 코어는 **8×8 매치-3** (`MatchBoardGame` / `MatchBoardLogic`)이고, 현재 모드는 **Simple / Progression / Timed** 3종이다.

## 1. 프로젝트 구조 요약

이 프로젝트는 크게 6개 층으로 나뉜다.

1. 앱 시작/부트스트랩
   - `lib/main.dart`
   - `lib/app.dart` — `StarryBackground.instance`를 앱 루트에 1개만 배치
2. 라우팅/화면 전환
   - `lib/router.dart` — 모든 라우트에 `FadeTransition` 적용
   - `lib/views/title_view.dart`
   - `lib/views/game_view.dart`
   - `lib/views/setting_view.dart` — `ConsumerWidget` (Riverpod)
   - `lib/views/overlays/` — `pause_menu_overlay.dart`, `no_moves_overlay.dart`, `time_up_overlay.dart`, `how_to_play_overlay.dart`, `level_celebration_overlay.dart`, `level_up_overlay.dart`, `ranking_overlay.dart`
3. ViewModel (Riverpod)
   - `lib/vm/settings_notifier.dart` — 설정 상태·SoundManager·WakelockPlus
   - `lib/vm/ranking_notifier.dart` — Timed 점수 / Progression 레벨 랭킹 제출·결과 상태
4. 게임 코어
   - `lib/game/match_board_game.dart`
   - `lib/game/match_board_game_*.dart` — Flame 셸의 레이아웃, 모드 규칙, 타이밍, 진행 모드, VFX extension
   - `lib/game/match_board_logic.dart`
   - `lib/game/match_board_*.dart` — 보드 규칙의 생성, 입력, 매칭, 특수 보석, 해소, 업데이트 extension/helper
   - `lib/game/components/match_board_renderer.dart`
   - `lib/game/components/match_game_hud.dart`
   - `lib/game/components/special_effect_pool.dart`
   - `lib/game/components/space_bg.dart`
5. 공통 위젯
   - `lib/widgets/lumina_buttons.dart` — `LuminaGradientButton`, `LuminaOutlinedButton`, `LuminaRoundButton`
   - `lib/widgets/lumina_overlay_card.dart` — 오버레이 공통 카드 프레임
   - `lib/widgets/phone_frame_scaffold.dart` — 반응형 프레임
   - `lib/widgets/starry_background.dart` — GlobalKey 싱글톤 배경
6. 공통 서비스
   - `lib/resources/sound_manager.dart`
   - `lib/services/game_settings.dart`
   - `lib/services/ranking_service.dart`
   - `lib/utils/storage_helper.dart`

핵심 구조는 다음과 같다.

```text
Flutter App Shell
├─ main.dart (ProviderScope → EasyLocalization → App)
├─ App
│  └─ Directionality → Stack
│     ├─ StarryBackground.instance (GlobalKey 싱글톤 — 앱 전역 1개)
│     └─ MaterialApp.router
│        └─ GoRouter (모든 라우트 FadeTransition)
│           ├─ TitleView (endOfFrame 대기 후 마운트)
│           ├─ GameView (endOfFrame 대기 후 GameWidget 마운트)
│           └─ SettingView (ConsumerWidget → SettingsNotifier)
├─ lib/vm/ (ViewModel)
│  ├─ SettingsNotifier
│  └─ RankingNotifier
└─ GameView 내부
   └─ Flame GameWidget
      └─ MatchBoardGame
         ├─ camera.viewport → MatchGameHud
         └─ world → MatchBoardRenderer
            ├─ BoardJuiceLayer
            └─ SpecialEffectPool
```

보드 데이터·매치/낙하/스왑 로직은 `MatchBoardLogic`에 있고, 렌더는 `MatchBoardRenderer`, HUD 입력은 `MatchGameHud`, 특수효과 연출은 `SpecialEffectPool`과 관련 helper가 담당한다.

## 2. main.dart부터 시작하는 전체 실행 순서

### 2-1. 큰 흐름

```text
main()
├─ WidgetsFlutterBinding.ensureInitialized()
├─ if (kIsWeb) usePathUrlStrategy()
├─ EasyLocalization.ensureInitialized()
├─ StorageHelper.init()
├─ InAppReviewService.saveFirstLaunchDateIfNeeded()
├─ Future.wait([
│  ├─ SoundManager.preload()
│  ├─ Flame.images.load(AssetPaths.jewelSpriteSheet)
│  ├─ Flame.images.load(AssetPaths.specialSpriteSheet)
│  ├─ Flame.images.load(AssetPaths.specialActionSpriteSheet)
│  ├─ SpriteSheetFrame.precache(...)
│  └─ SpriteSheetFrame.precache(...)
│  ])
├─ _applyKeepScreenOn()
└─ runApp(ProviderScope → EasyLocalization → App)
   └─ App.build()
      └─ MaterialApp.router(...)
         └─ appRouter
            └─ initialLocation = "/"
               └─ TitleView.build()
                  ├─ 앱 공통 StarryBackground 위의 타이틀 콘텐츠
                  ├─ 심플 -> context.go("/game?mode=simple")
                  ├─ 진행 -> player name 저장 후 context.go("/game?mode=progression")
                  ├─ 타임 -> player name 저장 후 context.go("/game?mode=timed")
                  ├─ 랭킹 -> RankingListPopup
                  ├─ 튜토리얼 -> HowToPlayOverlay(dialog)
                  └─ 설정 -> context.push("/setting")
```

게임 시작 시 흐름은 다음과 같다.

```text
GameView.initState()
├─ SoundManager.playBgm(AssetPaths.bgmMain)
└─ endOfFrame 뒤 GameWidget 마운트, 최소 350ms 로딩 오버레이 유지

GameView.build()
└─ GameWidget<MatchBoardGame>.controlled(...)
   └─ gameFactory()
      └─ MatchBoardGame(gameMode, safeAreaPadding) + setLocaleStrings(...)
         └─ MatchBoardGame.onLoad()
            ├─ await super.onLoad()
            ├─ camera.viewfinder anchor = topLeft, position = (0,0)
            ├─ camera.viewport.add(MatchGameHud(...))
            ├─ world.add(MatchBoardRenderer(logic: board))
            ├─ world.add(BoardJuiceLayer())
            ├─ SpecialEffectPool(world)
            ├─ installMatchBoardQaBridge(this)
            └─ Timed 모드면 RankingService.fetchTop1()
         (이후 첫 onGameResize에서 layoutRef 확정)
            └─ _syncLayout()
                ├─ board.setGeometry(...)
                └─ 최초 1회만 board.generateFreshBoard()
```

카운트다운 오버레이는 매치-3 버전에서는 사용하지 않는다. 입력 가능 여부는 `MatchBoardLogic.state`, `inputLocked`, `introFillInProgress`, 그리고 오버레이(일시정지/노무브/타임업/레벨업/랭킹)로 제한된다.

### 2-2. 실제 역할 기준 해석

- `main.dart`
  - 앱 실행 전 필요한 전역 초기화를 담당한다.
- `app.dart`
  - `MaterialApp.router`, 테마, 다국어 설정을 담는 앱 루트다.
- `router.dart`
  - 어떤 경로가 어떤 화면을 여는지 정의한다.
- `title_view.dart`
  - 모드 선택, 플레이어 이름 입력, 튜토리얼, 랭킹, 설정 이동을 담당하는 첫 진입 화면이다.
- `game_view.dart`
  - Flame 게임을 Flutter 위젯 트리에 마운트하고 오버레이를 연결한다.
- `match_board_game.dart`
  - Flame 게임 셸: 레이아웃·타이머(Simple/Progression/Timed)·오버레이 제어·첫 레이아웃에서 보드 시드.
- `match_board_logic.dart`
  - 8×8 보드, 스왑/매치/특수 보석/낙하/리필, 점수·콤보.

## 3. 파일별 역할 정리

### 3-1. `lib/main.dart`

앱의 진입점이다.

- Flutter 엔진 초기화
- 웹 path URL 전략 적용 (`/#/game` 대신 `/game`)
- 다국어 초기화
- 로컬 저장소 초기화
- 인앱 리뷰 기준일 저장
- 사운드 프리로드
- 보석/특수 보석 스프라이트 시트와 튜토리얼 프리뷰 캐시 프리로드
- 화면 꺼짐 방지 설정 적용
- `ProviderScope` + `EasyLocalization` + `App` 실행

즉, 게임 화면을 만드는 파일이 아니라 앱이 돌아갈 환경을 먼저 준비하는 파일이다.

### 3-2. `lib/app.dart`

`MaterialApp.router`를 생성하는 앱 루트다.

- `Directionality` + `Stack`으로 `StarryBackground.instance`를 앱 최상단에 1개만 배치
- `MaterialApp.router` 위에 깔리므로 모든 화면에서 별 배경이 비쳐 보임
- `kDebugMode`에서는 우상단 `_DebugFpsPanel` 표시
- 앱 제목·디버그 배너·다국어·테마·라우터 설정
- 웹에서 포인터다운 시 `SoundManager.unlockForWeb()` 호출
- `unlockForWeb()`는 웹 오디오 잠금을 풀고, 잠금 전 요청된 BGM이 있으면 재생한다
- 현재 웹 기준점에서는 SFX만 Web Audio를 우회하고 HTML 오디오 요소 4개를 재사용하며, 화면이 숨겨졌다 복귀한 후 첫 포인터 입력에서 다시 해제한다

### 3-3. `lib/router.dart`

라우팅 테이블이다.

- `/` -> `TitleView`
- `/game` -> `GameView`
- `/setting` -> `SettingView`

`/game`은 query parameter `mode`를 읽는다 (`JewelGameMode.fromQuery`).

- `mode=simple` 또는 생략: 심플(무제한)
- `mode=progression`: 진행 모드
- `mode=timed`: 타임 어택
- QA용 query parameter: `qaVfx=1`, `qaLevelUp=1`, `qaNoMoves=1`

같은 `GameView`·`MatchBoardGame`을 쓰고 모드만 바꾼다.

### 3-4. `lib/views/title_view.dart`

첫 진입 화면이다.

- 우주 배경 렌더링
- 타이틀 / 부제목 표시
- 심플 모드 버튼 → `context.go('.../game?mode=simple')`
- 진행 모드 버튼 → 플레이어 이름 저장 후 `context.go('.../game?mode=progression')`
- 타임 모드 버튼 → 플레이어 이름 저장 후 `context.go('.../game?mode=timed')`
- 랭킹 버튼 → `RankingListPopup`
- 튜토리얼 버튼 → `HowToPlayOverlay` dialog
- 설정 버튼 → `context.push('/setting')`
- 하단 버전 텍스트 표시
- 모바일 타이틀 진입 후 조건이 맞으면 인앱 리뷰 요청

### 3-5. `lib/views/game_view.dart`

Flame을 Flutter에 연결하는 핵심 화면이다.

- `initState()`: 게임 BGM 시작 + `endOfFrame` 대기 후 GameWidget 마운트 예약
- `didChangeDependencies()`: `GameWidget` 1회만 생성·캐싱 (`build`에서 매번 생성하지 않음)
- `build()`: `_gameMounted` 전까지 빈 화면, 최소 350ms `GameLoadingOverlay` 표시
- `overlayBuilderMap`으로 분리된 오버레이 연결: `IntroBlock`, `PauseMenu`, `NoMoves`, `LevelCelebration`, `LevelUp`, `TimeUp`, `HowToPlay`, `RankingList`
- `PhoneFrame` 안에 `GameWidget`을 넣어 390×750 기준 프레임을 유지한다. 웹에서는 둥근 모서리 clip을 적용하고, 모바일 안전영역은 `MatchBoardGame.safeAreaPadding`으로 전달한다.
- QA query가 있으면 웹에서 특수효과/레벨업/노무브 프리뷰를 지연 실행한다.

### 3-6. `lib/game/match_board_game.dart`

Flame 게임 셸이다.

- `FlameGame` 상속
- `MatchBoardLogic`를 생성자에서 생성(타이머·빈 격자 준비), `onLoad`보다 먼저 올 수 있는 리사이즈에도 안전
- `onLoad`: `MatchGameHud`(viewport) → `MatchBoardRenderer`(world) → 파티클/특수효과 풀 → QA bridge 순 추가
- `onGameResize` → `_syncLayout`: `layoutRef`·타일 크기 유효성 검사 후 `setGeometry`, **`_boardSeededFromLayout`가 false일 때만** `generateFreshBoard()` (이후 리사이즈는 idle 시 좌표 스냅)
- Simple/Progression/Timed 모드별 타이머·베스트 저장 연동
- Timed 모드에서는 서버 1위(`RankingService.fetchTop1`)를 가져와 HUD에 표시할 수 있다.
- Progression 모드에서는 목표 점수 도달 시 `LevelCelebration` → `LevelUp` → 다음 보드 보너스 적용 흐름을 실행한다.

### 3-7. `lib/game/match_board_logic.dart`

보드 규칙과 상태 머신이다.

- 8×8 `cells`, 스왑·매치 판정·제거·낙하·리필
- `setGeometry`: `cells` 크기 불일치 시 조기 반환으로 RangeError 방지
- `BoardGem` 오브젝트 풀로 제거된 보석 인스턴스를 재사용
- 상태 전이: `idle → removing → falling → refilling → checking → idle`
- 초기/재시작/셔플 보드는 즉시 매치가 없고 유효 수가 1개 이상 있는 레이아웃이 나올 때까지 재생성
- 특수 보석: `row`, `col`은 legacy 호환, 현재 생성 규칙은 `bomb`, `star`, `hyper`, `supernova` 중심
- 힌트: 현재 유효 스왑 후보 목록을 후보 변경 시점에 한 번 셔플해 저장하고, 힌트 버튼을 누를 때마다 저장된 순서를 0→1→... 순서로 순환해 한 쌍을 흰색 펄스로 표시
- 한 판 통계: `MatchBoardGameStats`가 유효 스왑 수, 매치 그룹 수, 제거 보석 수, 종류별 제거, 생성 특수 보석 수, 종류별 생성, 발동 특수 보석 수, 종류별 발동을 누적한다. 재시작/새 보드/다음 레벨은 리셋하고, 노무브 셔플은 이어서 누적한다.

### 3-8. `lib/game/components/match_board_renderer.dart`

`MatchBoardLogic`의 보석을 그리는 `world` 컴포넌트.

- 보드 프레임/슬롯 배경을 `ui.Picture`로 캐싱해 재사용
- 기본 보석은 `assets/images/sprites/Jewel_Arcane.png`를 사용한다.
- 특수 보석 생성 규칙: T/L은 `star`, 6개 이상 일렬은 `supernova`, 5개 일렬은 `hyper`, 4개 일렬은 `bomb`.
- `row`/`col`은 legacy 종류로 남아 있고 `Special_Arcane.png` 앞 2프레임을 사용한다.
- `bomb`/`star`/`hyper`/`supernova`는 `Special_Action_Arcane.png`의 4프레임 전용 스프라이트를 사용한다.
- `star`는 전용 액션 시트 로딩 실패 시 기존 `star_overlay.png` 합성 렌더를 fallback으로 사용할 수 있다. `bomb`은 일반 flame 이미지와 혼동을 줄이기 위해 전용 액션 시트의 보라색 코어 프레임만 사용한다.
- `supernova`는 bomb과 구분되는 8방향 별 폭발형 전용 프레임을 사용하며, 더 이상 일반 보석 위 오버레이 합성으로 렌더하지 않는다.
- 현재 스프라이트 기준 셀 크기는 모두 `128×128`.
- 일반 보석에는 현재 렌더러의 `ColorFilter.matrix`가 적용되어 전체 톤을 맞춘다. 전용 특수 스프라이트에는 일반 보석 색상 필터를 적용하지 않는다.
- 범위형 발동 이펙트는 `special_area_effects.json` manifest가 지정한다. E2에서 `bomb`, `hyper`, `supernova` 모두 1280×256 RGBA 정지 레이어 아틀라스(256px 정수 셀 5칸)와 코드 타임라인을 사용한다. 고정 pivot은 각 셀의 (128,128)이며 프레임별 중심 재보정은 하지 않는다. `row`/`col`/`star`는 기존 절차형 렌더를 유지하고 supernova의 십자 번개도 유지한다.
- bomb은 `bomb_layer_timeline.dart`의 기존 곡선과 배율을 유지한다. hyper/supernova는 `area_layer_timeline.dart`의 개별 곡선으로 크기, 알파, 회전을 계산한다. 잔광 회전은 작게 제한하고 t=1에서 모든 레이어가 사라진다. 구운 글로우 뒤 정지 낱장 5칸을 `drawRawAtlas` 1회(`BlendMode.plus`)로 그린다. typed 버퍼와 Paint는 컴포넌트에서 재사용한다. 숨긴 칸은 alpha 0과 가역 변환을 사용하여 CPU Skia에서 후속 칸이 사라지는 문제를 방지한다. supernova 번개는 별도 그리므로 전체 draw call을 2회로 단정하지 않는다.
- 로더는 효과 종류별 캐시에 저장하며 256px 정수 셀, 5칸 및 실제 이미지 치수를 검사한다. 잘못된 아틀라스나 로딩 실패는 해당 효과의 기존 절차형 렌더로만 폴백하며 다른 효과 캐시는 유지한다. 세 종류 모두 pool warm에서 준비한다. 이미지 소유는 `Flame.images`이고 glow lease 해제 계약은 유지한다. 기존 `Special_Area_*.png`는 보존하지만 현재 manifest는 로드하지 않는다. 새 hyper/supernova 두 장의 디코드 RGBA 크기는 합계 2.5MiB이며 GPU 실측은 아니다.

#### 보드 연출 (PLAN-004)

규칙 판정과 분리된 렌더 전용 연출이다. 모바일 웹 예산(PLAN-001 5.3, 5.4) 때문에 `render()`/`update()`에서 `Paint`, `TextPainter`, 리스트를 만들지 않고 blur와 `saveLayer`를 쓰지 않는다.

- `BoardGem.landT` / `popT` / `airborne`: 렌더 전용 타이머. `MatchBoardLogic._tickGemJuice`가 진행한다. 반 칸 넘게 떨어지던 보석이 목표까지 `tileSize * 0.12` 안으로 들어오면 `landT`를 시작한다(`landSquashDuration` 0.24초). 풀 재사용 시 `reset()`에서 초기화된다.
- 착지 스쿼시: `_drawGem`이 셀 바닥 기준으로 세로 최대 약 15% 눌렀다가 되튕긴다. 인트로 낙하에도 적용된다.
- 제거 팝: 제거 진행 30%까지 1.2배로 부풀고 이후 0.3배, 알파 0.08까지 수축한다. `removeDelay`(0.18초)는 그대로다.
- 특수 보석 탄생: `_convergeOnSpawns`가 특수 보석을 만든 매치 그룹의 제거 예정 보석 `targetX/Y`를 생성 칸으로 바꿔 빨려 들게 하고, 생성된 보석의 `popT`를 시작한다(`spawnPopDuration` 0.34초, 1.5배에서 복귀 + 확장 링). 제거 집합에 없는 보석의 목표는 건드리지 않는다.
- 무효 스왑 범프: `_trySwapImpl` 무효 분기에서 두 보석을 서로 쪽으로 30% 밀어 두고 기존 트윈으로 복귀시킨다. 목표 좌표는 바꾸지 않는다.
- 상시 연출: 선택 보석 맥동, 힌트 쌍이 서로 쪽으로 끌림, 특수 보석 호흡(id 위상차), 저시간(10초 이하) 보드 테두리 붉은 맥동(타임 틱과 같은 박자).
- `BoardJuiceLayer`(world, priority 130): 파티클 192슬롯 링 버퍼를 `Float32List`/`Int32List`로 들고, 종류가 달라도 프레임당 `drawRawAtlas` 1회(`BlendMode.plus`)로 그린다. 아틀라스는 마운트 때 64px 칸 4개(별, 섬광, 충격파 링, 파편)를 `toImageSync`로 한 번 굽고 광륜도 여기에 구워 런타임 blur가 없다. `drawRawAtlas` 원본 사각형은 LTRB다. 제거 칸마다 링 1 + 섬광 1은 항상, 파편(속도 방향 정렬)과 별(회전)은 단계별 10/12/14개를 버스트당 150개 예산 안에서 낸다. 매칭 제거 및 콤보 별빛은 중력 0, 위쪽 발사 편향 없이 방사형으로 감속하며 축소/페이드아웃한다. 매칭 제거의 파편/콤보 별빛 초기 속도는 1.4배이며 링/섬광/파편/콤보 별빛 수명은 0.65배다(파편 약 0.36~0.52초). 점수 팝업/콜아웃 및 busy 타이밍은 유지한다. 중력은 슬롯마다 저장하고 재사용 때 초기화하며 특수 생성/발동 및 리필 입자는 기존 620을 유지한다. 유휴 상태에서는 0.22~0.32초마다 보석 하이라이트 위치에 반짝임 1개를 내며 알파에 2/3를 곱해 밝기를 줄인다.
- T2 보석 배치: `MatchBoardRenderer`는 64px 셀 8열의 512×640 gem atlas를 마운트 시 준비한다. 기본/특수/legacy 보석과 baked sheen, 선택 광륜을 typed buffer로 일괄 `drawRawAtlas`한다. 비균등 착지 squash는 atlas `drawImageRect` fallback으로 flush하므로 여러 행에서 동시에 발생하면 draw call이 9회를 넘을 수 있다. atlas와 색 보정 이미지는 onRemove에서 해제하고 remount에서 재생성한다.
- CustomPainter는 쓰지 않는다. Flame `Component.render(Canvas)`가 받는 것이 CustomPainter와 같은 `dart:ui` Canvas라 표현력과 비용이 같고, 별도 위젯 레이어만 늘어난다.
- 점수 팝업과 콤보 콜아웃: 이벤트당 `TextPainter` 1개, 슬롯 6개(0번은 콜아웃 전용). 알파 페이드 대신 스케일로 사라진다. 점수는 `MatchBoardLogic.lastRemovalScore`를 쓴다. 콜아웃 문구는 콤보 2부터 GOOD, GREAT, AWESOME, AMAZING, UNBELIEVABLE 순이며 번역하지 않는다.
- 콤보 셰이크: 특수 발동이 없는 4개 이상 매치 또는 콤보 3 이상에서 `min(1.6 + combo * 0.7, 5.0)` 세기, 0.2초. 특수 발동은 기존 셰이크만 쓴다.
- `hasActiveVisualEffects`는 `BoardJuiceLayer.busy`(버스트와 텍스트만, 유휴 반짝임 제외)와 특수효과 풀을 본다. 유휴 반짝임을 포함하면 레벨업 판정이 영원히 대기하므로 포함하지 않는다.
- HUD: 점수는 약 0.045초 간격으로 남은 차이의 28%(최소 7)씩 굴러 올라가고 확대 펀치가 붙는다. 점수가 줄면(재시작) 즉시 맞춘다. 현재 콤보 값도 오를 때 펀치가 붙는다. 저장되는 점수와 랭킹 점수는 `board.score` 그대로다.
- 이전 `ParticleBurst`/`ParticlePool`은 67a2417에서 스폰이 빠진 뒤 warm-up만 남아 있었고, 이번에 삭제했다.

현재 렌더 에셋 매핑은 다음과 같다.

| 용도 | 파일 | 프레임/규칙 |
|:---|:---|:---|
| 일반 보석 | `assets/images/sprites/Jewel_Arcane.png` | 7프레임, 각 `128×128` |
| Legacy 특수 보석 `col` | `assets/images/sprites/Special_Arcane.png` | 1번째 프레임 |
| Legacy 특수 보석 `row` | `assets/images/sprites/Special_Arcane.png` | 2번째 프레임 |
| Bomb 특수 보석 `bomb` | `assets/images/sprites/Special_Action_Arcane.png` | 1번째 프레임 |
| Star 특수 보석 `star` | `assets/images/sprites/Special_Action_Arcane.png` | 2번째 프레임 |
| Hyper 특수 보석 `hyper` | `assets/images/sprites/Special_Action_Arcane.png` | 3번째 프레임 |
| Supernova 특수 보석 `supernova` | `assets/images/sprites/Special_Action_Arcane.png` | 4번째 프레임 |
| Bomb 범위 발동 VFX | `assets/images/sprites/bomb_layers.png` | `special_area_effects.json`의 `bomb` 설정, 256px 셀 가로 5칸 레이어 아틀라스 |
| Hyper 범위 발동 VFX | `assets/images/sprites/hyper_layers.png` | `special_area_effects.json` hyper, 256px 셀 가로 5칸, 고정 pivot, 코드 타임라인 |
| Supernova 범위 발동 VFX | `assets/images/sprites/supernova_layers.png` | `special_area_effects.json` supernova, 256px 셀 가로 5칸, 십자 번개 유지 |

참고:

- `AssetPaths.jewelSpriteSheet` → `sprites/Jewel_Arcane.png`
- `AssetPaths.specialSpriteSheet` → `sprites/Special_Arcane.png`
- `AssetPaths.specialActionSpriteSheet` → `sprites/Special_Action_Arcane.png`
- `AssetPaths.specialAreaEffectManifest` → `sprites/special_area_effects.json`
- `AssetPaths.specialAreaEffectBombLayers` → `sprites/bomb_layers.png`. `specialAreaEffectBomb`(`Special_Area_Bomb.png`)는 상수와 파일만 남아 있고 로드하지 않는다.
- `AssetPaths.starOverlay` → 전용 액션 시트 로딩 실패 시 사용할 수 있는 독립 오버레이 PNG. `flameOverlay`와 `supernovaOverlay`는 레거시 상수로 남아 있으나 메인 보드 렌더에서는 사용하지 않는다.
- 튜토리얼 오버레이(`HowToPlayOverlay`)와 `SpriteSheetFrame`도 같은 원본 픽셀 기준(`128×128`) 프리뷰 원칙을 사용한다.
- 생성 우선순위, 발동 조건, 연쇄 처리, Bejeweled 참고 룰과의 차이는 **`special_gems_rules.md`**에 별도로 정리한다.

### 3-9. `lib/game/components/match_game_hud.dart`

상단 패널(일시정지·힌트·랭킹·튜토리얼, 스코어·베스트·콤보·타임/레벨 바)과 보드 입력을 담당한다. `camera.viewport`에 올린다.

- `TextPainter`와 다수의 `Paint`를 캐싱해 프레임당 텍스트 레이아웃/객체 재생성을 줄인다
- 콤보 스트립(`combo` / `max combo`)은 별도 그라데이션 박스로 렌더한다
- 탭 입력: UI 버튼 영역이면 해당 액션, 보드 영역이면 `MatchBoardGame.handleBoardTap`
- 드래그 입력: 14px 이상 이동하면 방향을 판정해 `MatchBoardGame.handleBoardSwipe`
- Timed 모드에서 랭킹 버튼이 있으면 게임을 일시정지하고 `RankingOverlay`를 띄운다.

### 3-10. `lib/game/components/space_bg.dart`

Flame 배경 컴포넌트다. 현재 `MatchBoardGame.onLoad()`에서는 직접 추가되지 않는다. 필요 시 `camera.backdrop`에 올릴 수 있도록 유지된 컴포넌트다.

- 그라데이션 배경을 `ui.Picture`로 1회 녹화·캐싱
- 별 120개를 3 그룹으로 나눠 각 그룹을 `ui.Picture`로 1회 녹화·캐싱
- 매 프레임 `render()`에서는 `drawPicture` 4회 + 그룹별 `saveLayer` alpha 변경만 수행
- 깜빡임은 그룹 단위 sin alpha로 처리 (기존 drawCircle 240회/프레임 → drawPicture 4회/프레임)

### 3-11. 설정/사운드/저장소

- `game_settings.dart`
  - 설정값 getter / setter 제공
  - 베스트 스코어 저장
- `sound_manager.dart`
  - BGM / 효과음 / 웹 unlock 처리
- `storage_helper.dart`
  - `shared_preferences` 래퍼

현재 Riverpod 연결 원칙은 다음과 같다.

- `SettingView`와 `PauseMenuOverlay`는 `settingsProvider` 전체를 보지 않고 `select`로 필요한 필드만 구독한다
- BGM / SFX 슬라이더는 draft 상태를 즉시 UI에 반영하고, `onChangeEnd`에서만 `GameSettings`에 commit한다
- `TimeUpOverlay`는 `rankingProvider` 전체 대신 `isSubmitting`, `rankMessage`만 선택 구독해 랭킹 문구 영역만 다시 그린다

### 3-12. `lib/views/overlays/how_to_play_overlay.dart` / `lib/widgets/sprite_sheet_frame.dart`

튜토리얼 오버레이와 스프라이트 프레임 미리보기다.

- `HowToPlayOverlay`는 특수 보석/생성 예시를 별도 카드로 보여준다
- `SpriteSheetFrame` 위젯은 원본 PNG를 `ui.Image`로 읽고, `drawImageRect`로 고정 크기 프레임을 정확히 잘라 보여준다
- 현재 튜토리얼 프리뷰는 `Jewel_Arcane.png`, `Special_Arcane.png`, `Special_Action_Arcane.png`와 legacy 오버레이 PNG를 사용하며, `128×128` 프레임 경계를 화면 비율이 아니라 원본 픽셀 기준으로 유지한다

구조는 다음과 같다.

```text
UI / Game
└─ GameSettings
   └─ StorageHelper
      └─ shared_preferences
```

## 4. 매치-3 규칙과 보드 배치 (8×8)

- 인접 보석 두 칸을 스왑해 3개 이상 직선 매치를 만든다.
- 매치 제거 → 중력 낙하 → 빈 칸 리필. 연쇄 시 콤보.
- **Simple**: 제한 시간 없음. 움직일 수 없을 때 `NoMoves` 오버레이 등.
- **Progression**: 60초 제한 안에서 레벨별 목표 점수에 도달하면 레벨업 오버레이를 거쳐 새 보드로 진행한다. 레벨업 직전 `maxCombo`와 다음 레벨 번호에 따라 다음 보드 중앙에 보너스 특수 보석을 배치한다.
- **Timed**: 60초 제한 안에서 점수를 올린다. 매치 제거 단계마다 `raw = (기준합) * timeRewardScaleForMode` 후 정수화한다. `raw > 0`이면 `max(1, round(raw))`로 0초 보상을 막고, `raw <= 0`이면 보상 콜백이 없다. 가산은 `min(보상, 상한까지 여유)`로 초과분을 제외한다.
- Timed/Progression 모두 시간 상한은 90초이고, 남은 시간이 10초 이하로 내려갈 때 정수 초마다 `TimeTic` SFX를 낸다.
- 베스트 기록은 `GameSettings`가 모드별 키로 저장한다. Progression은 최고 레벨과 해당 점수를 함께 비교한다.

보드 픽셀 배치는 `MatchBoardGame._syncLayout`에서 `layoutRef`로 타일 크기를 구하고, `MatchBoardLogic.setGeometry`로 각 보석의 목표 좌표를 갱신한다. **초기 보석 채우기**는 레이아웃이 유효해진 뒤 **한 번만** `generateFreshBoard()`로 수행한다.

## 5. 게임 화면 진입 뒤 Flame 내부 생성 순서

`GameView`에서 `GameWidget.controlled`가 만들어진 다음, `gameFactory`가 `MatchBoardGame`을 생성한다.  
Flame이 `MatchBoardGame.onLoad()`를 호출한다.

`onLoad()`의 실제 순서는 다음과 같다.

```text
MatchBoardGame.onLoad()
├─ await super.onLoad()
├─ camera.viewfinder.anchor = Anchor.topLeft
├─ camera.viewfinder.position = (0, 0)
├─ _hud = MatchGameHud(onPausePressed: ...)
├─ camera.viewport.add(_hud)
├─ world.add(MatchBoardRenderer(logic: board))
├─ world.add(_juiceLayer)  // BoardJuiceLayer
├─ _specialEffectPool = SpecialEffectPool(world)
├─ installMatchBoardQaBridge(this)
└─ if (isTimedMode) RankingService.fetchTop1()
```

그 다음 프레임에서 크기가 정해지면 `onGameResize`가 호출되고, `_syncLayout()`에서:

```text
_syncLayout()
├─ hasLayout, size, layoutRef, tile 유효성 검사
├─ board.setGeometry(x, y, tile)
└─ if (!_boardSeededFromLayout)
│     board.generateFreshBoard(); _boardSeededFromLayout = true
   else if (board.state == 'idle')
        기존 보석 좌표를 target에 스냅
```

해석하면:

1. 좌표계를 top-left 기준으로 고정한다.
2. HUD를 `viewport`에 올린다 (`MatchGameHud`).
3. 보드를 `world`에 올린다 (`MatchBoardRenderer`).
4. 파티클 풀, 특수효과 풀, QA bridge를 설치한다.
5. **보드 데이터 채우기**는 `onLoad` 직후가 아니라, **첫 유효 레이아웃**에서만 수행한다 (리사이즈만 반복되는 환경에서도 안전).

즉 현재 게임 구조는 다음과 같다.

```text
MatchBoardGame
├─ camera.viewport
│  └─ MatchGameHud
└─ world
   └─ MatchBoardRenderer
      + BoardJuiceLayer / SpecialEffectPool
```

## 6. 좌표계와 safe area 기준

현재 프로젝트는 좌표계를 3개 층으로 나눠서 본다.

```text
1) Flutter 화면 좌표
   - MediaQuery, SafeArea, Web LayoutBuilder가 사용하는 좌표

2) Flame 게임 레이아웃 좌표
   - camera.viewfinder를 topLeft로 맞춘 뒤
   - (0, 0) = 게임 프레임의 좌상단

3) HUD / Viewport 좌표
   - 화면에 고정된 UI 좌표
   - 타임 패널, 힌트, pause 버튼이 여기서 그려짐
```

일반적인 Flame 예제(world 중심 카메라)와 다른 점은 다음과 같다.

- 현재는 `world 중심 원점`을 쓰지 않는다.
- `camera.viewfinder.anchor = Anchor.topLeft`로 맞춘다.
- 그래서 `world`와 `viewport` 모두 사실상 화면 상단 기준 좌표를 공유한다.
- 다만 의미상으로는 여전히 구분한다.
  - `world`
    - 게임 오브젝트
  - `viewport`
    - 화면 고정 UI

### 6-1. safe area를 어떻게 쓰는가

현재 프로젝트에서 safe area는 디버그 선을 그리기 위한 값이 아니다.  
오직 "게임 UI와 게임 오브젝트가 침범하지 않아야 하는 배치 기준"으로만 사용한다.

즉:

- 배경
  - safe area를 무시하고 전체 화면 사용
- 딤 배경
  - safe area를 무시하고 전체 화면 사용
- 실제 게임 요소
  - safe area 안쪽에만 배치

현재 레이아웃 기준은 다음과 같다.

```text
safeContentLeft   = safeArea.left + 화면가로의 3%
safeContentRight  = 화면너비 - safeArea.right - 화면가로의 3%
safeContentWidth  = safeContentRight - safeContentLeft
safeContentCenter = safeContentLeft + safeContentWidth / 2
```

상단 HUD와 그리드도 이 내부 영역을 기준으로 계산한다.

### 6-2. HUD와 그리드 배치 기준

상단 배치 기준:

```text
hudScale = min(width, height) * 0.2
topChromeHeight =
  safeArea.top
  + 10
  + hudTopBarHeight
  + hudMainScoreBlockHeight
  + hudGapScoreToCombo
  + hudComboStripHeight
  + hudGapComboToTimeBar
  + hudBottomTimeBarHeight
  + hudGapTimeBarToBoard
gridTopY = topChromeHeight
```

그리드 크기 기준:

```text
availW = safeContentWidth
maxGridH = 화면높이 - safeArea.bottom - gridTopY - bottomChromeHeight - 12
layoutRef = min(availW, maxGridH)
tile = layoutRef / (cols + spacingRatio * (cols + 1))
spacingRatio = 0.06
```

즉 현재 기준은:

- 상단 HUD는 safe area 아래에 둔다.
- 좌우 버튼과 힌트는 safe area 안쪽에 둔다.
- 그리드는 safe area 안쪽 직사각형에 들어가는 최대 정사각형으로 계산한다.

## 7. 게임 진행 흐름

### 7-1. 플레이 중 매 프레임

```text
MatchBoardGame.update(dt)
├─ board.update(dt)  // 인트로·트윈·제거·낙하·리필·체크 상태 전이
├─ _spawnSpecialEffectEvents()
├─ _updateCameraShake(dt)
├─ _updateTimedModeClock(dt)     // Timed/Progression
├─ _updateProgressionMode()      // Progression 목표 달성 감지
├─ _saveBestScoreIfChanged()
└─ super.update(dt)
```

### 7-2. 입력 (탭 / 드래그)

```text
MatchGameHud
├─ UI 버튼 영역
│  ├─ pause → MatchBoardGame.pauseGame()
│  ├─ hint → MatchBoardGame.requestHint()
│  ├─ ranking → MatchBoardGame.pauseForRankingPopup()
│  └─ tutorial → MatchBoardGame.showHowToPlay()
└─ 보드 영역
   ├─ tap → MatchBoardGame.handleBoardTap()
   │  ├─ 특수 보석 탭 → triggerSpecialCell() → activateSpecials()
   │  └─ 일반 보석 탭 → 선택/인접 두 번째 탭 스왑
   └─ drag → MatchBoardGame.handleBoardSwipe()
      └─ MatchBoardLogic.trySwap()
         ├─ 유효 스왑 → resolveMatchCascade()
         └─ 무효 스왑 → 되돌림 + input lock + Fail SFX
```

카운트다운 오버레이는 매치-3 버전에서 사용하지 않는다.

## 8. 일시정지 / 라운드 종료

### 8-1. 일시정지

```text
Pause 버튼 탭
└─ MatchBoardGame.pauseGame()
   ├─ SoundManager.pauseBgm()
   ├─ pauseEngine()
   └─ overlays.add('PauseMenu')
```

재개: BGM 재개, `resumeEngine()`, `PauseMenu` 제거.

### 8-2. 라운드 종료 (매치-3)

- **NoMoves**: 더 이상 유효한 스왑이 없을 때 오버레이. 표시 중에는 일시정지와 동일하게 `isPlaying=false`, BGM pause, `pauseEngine()` 상태가 되며, 셔플/새 보드를 선택하면 BGM과 엔진을 재개한다. 베스트 갱신은 모드별 점수 저장 API 사용.
- **TimeUp**: Timed/Progression 모드 시간 소진 시 오버레이. Timed는 점수 랭킹, Progression은 레벨 랭킹으로 제출한다.
- **GameStats**: TimeUp/NoMoves 게임 오버 화면, PauseMenu, LevelUp의 통계 버튼에서 열리는 별도 팝업. 현재 판의 점수, 스왑/매치/제거/특수 보석 생성·발동 누계를 보여준다.
- **LevelCelebration / LevelUp**: Progression에서 목표 점수를 넘으면 게임을 멈추고 축하 연출 후 다음 레벨 확인 팝업을 표시한다.
- **RankingList**: Timed 모드 HUD 랭킹 버튼에서 게임을 일시정지하고 표시한다.

## 9. 반응형 프레임 — PhoneFrameScaffold

모든 주요 화면은 `PhoneFrameScaffold` 또는 `PhoneFrame`을 통해 **고정 논리 해상도 `390×750`** 안에서 레이아웃한다.

### 9-1. 위젯 구조

```text
App (app.dart)
└─ Stack
   ├─ StarryBackground.instance (GlobalKey 싱글톤 — 앱 전역 1개)
   └─ MaterialApp.router
      └─ PhoneFrameScaffold (각 View에서 사용)
         └─ Scaffold(backgroundColor: transparent)  ← 투명이라 앱 배경이 비침
            └─ SafeArea
               └─ Center
                  └─ PhoneFrame
                     └─ LayoutBuilder
                        ├─ fittedScale = min(가로비, 세로비)
                        ├─ SizedBox(390*scale, 750*scale)
                        └─ FittedBox(contain)
                           └─ SizedBox(390, 750) + MediaQuery(size override)
                              └─ 실제 화면 콘텐츠
```

- `StarryBackground`는 `App` 레벨에서 `GlobalKey` 싱글톤으로 **1개만** 생성. 화면 전환 시 재생성 비용 없음.
- `PhoneFrameScaffold`의 `Scaffold`는 `backgroundColor: transparent` — 앱 배경이 비쳐 보임.
- 콘텐츠는 **항상 390×750 기준**으로 레이아웃 → 폰트·간격·버튼 비율 유지.
- `FittedBox`가 통째로 스케일링 → 웹·태블릿에서 비율이 변하지 않는다.

### 9-2. GameView

```text
GameView
└─ Scaffold(backgroundColor: transparent)  ← 앱 배경이 비침
   └─ Center
      └─ PhoneFrame
         └─ ClipRRect(kIsWeb ? 28 : 0)
            └─ Stack
               ├─ GameWidget<MatchBoardGame>
               ├─ GameLoadingOverlay
               ├─ SfxPlayLogPanel(debug simple)
               └─ QA tap layer(qaVfx web)
```

- `endOfFrame` 대기 후 `GameWidget`을 마운트하여 페이드 전환과 Flame 초기화 프레임을 분리한다.
- 로딩 오버레이는 최소 350ms 유지해 첫 프레임의 급격한 전환을 숨긴다.
- 모바일 safe area는 `MatchBoardGame.safeAreaPadding`에 전달되며, 웹은 `EdgeInsets.zero`를 사용한다.

### 9-3. 적용 현황

| 화면 | 방식 | StarryBackground | 전환 최적화 |
|------|------|-----------------|------------|
| TitleView | `PhoneFrameScaffold(child: Column)` | App 레벨 싱글톤 공유 | `endOfFrame` 대기 후 콘텐츠 마운트 |
| SettingView | `PhoneFrameScaffold(child: Scaffold+AppBar)` (`ConsumerWidget`) | App 레벨 싱글톤 공유 | FadeTransition 350ms |
| GameView | `PhoneFrame` + `GameWidget` | App 레벨 싱글톤 공유 | `endOfFrame` 대기 + `GameLoadingOverlay` |

## 10. 화면별 요약

### 10-1. TitleView

- `PhoneFrameScaffold` 안의 `Column` + `Spacer` 비율 배치
- `390×750` 고정 해상도에서 제목/아이콘/모드 버튼/버전 텍스트의 간격·크기 유지
- Simple / Progression / Timed / Ranking / Settings / HowToPlay 진입점
- 메뉴 BGM 재생

### 10-2. SettingView

- `PhoneFrameScaffold` 안의 `Scaffold` + `AppBar`
- SafeArea 안의 스크롤 설정 목록
- BGM / SFX / 화면 꺼짐 방지 / 언어 설정

### 10-3. GameView

- `PhoneFrame` 안의 Flame `GameWidget`
- `GameLoadingOverlay`로 초기 마운트 시각 충격 완화
- 오버레이:
  - IntroBlock
  - PauseMenu
  - NoMoves
  - LevelCelebration
  - LevelUp
  - TimeUp
  - HowToPlay
  - RankingList

## 11. 성능 최적화 — 우주 배경

우주 배경은 두 종류가 있다. Flutter 위젯 배경은 `App` 레벨에서 `GlobalKey` 싱글톤으로 **앱 전역 1개만** 생성된다.

| 파일 | 용도 | 컨텍스트 |
|------|------|----------|
| `lib/widgets/starry_background.dart` | Flutter 위젯 배경 | `App.build()` → `StarryBackground.instance` (GlobalKey 싱글톤, 앱 전역 1개) |
| `lib/game/components/space_bg.dart` | Flame 컴포넌트 배경 | 현재 직접 장착되지 않음. 필요 시 `camera.backdrop`용 |

`StarryBackground`의 생성자는 `private`이므로 외부에서 새 인스턴스를 만들 수 없다. `StarryBackground.instance`만 사용해야 한다.

### 11-1. 문제점 (리팩터 전)

두 파일 모두 매 프레임 `paint()` / `render()`에서 별 120개를 개별 `drawCircle`로 그리고 있었다.

```text
매 프레임 비용 (리팩터 전)
├─ LinearGradient 셰이더 생성 + drawRect
├─ drawCircle × 120 (별 본체)
├─ drawCircle × ~40 (큰 별 글로우, MaskFilter.blur)
└─ sin 계산 × 120 (깜빡임 alpha)
   → 총 ~240 draw 호출/프레임
```

### 11-2. 최적화 전략

**공통 원칙**: 정적인 그리기를 캐싱하고, 깜빡임은 alpha 변경만으로 처리한다.

#### `StarryBackground` (Flutter 위젯)

```text
Stack
├─ _GradientPainter (RepaintBoundary) → 1회 paint, 래스터 캐시
├─ FadeTransition (그룹 0) → RepaintBoundary → _StarGroupPainter (1회 paint)
├─ FadeTransition (그룹 1) → RepaintBoundary → _StarGroupPainter (1회 paint)
└─ FadeTransition (그룹 2) → RepaintBoundary → _StarGroupPainter (1회 paint)
```

- 별을 3 그룹으로 나눠 각각 `RepaintBoundary`로 래스터 캐싱
- 깜빡임은 `FadeTransition`(GPU 컴포지터 alpha)으로만 처리
- **paint() 재호출 0회/프레임**, draw 호출 0회/프레임
- 별 좌표는 정규화(0~1)로 저장 → 리사이즈 시 데이터 재생성 불필요

#### `SpaceBg` (Flame 컴포넌트)

```text
render()
├─ drawPicture(_bgPicture)        → 캐싱된 그라데이션
├─ saveLayer + drawPicture(그룹0) → 캐싱된 별 + alpha
├─ saveLayer + drawPicture(그룹1) → 캐싱된 별 + alpha
└─ saveLayer + drawPicture(그룹2) → 캐싱된 별 + alpha
```

- Flame에서는 `FadeTransition`을 쓸 수 없으므로 `ui.Picture`로 녹화·캐싱
- 매 프레임 `drawPicture` 4회 + `saveLayer` alpha 변경 3회
- 깜빡임은 그룹 단위 sin alpha로 처리

### 11-3. 결과 비교

| 항목 | 리팩터 전 | 리팩터 후 |
|------|----------|----------|
| draw 호출/프레임 | ~240회 | **4회** (Picture) |
| sin 계산/프레임 | 120회 | **3회** (그룹 단위) |
| paint()/render() 빌드 비용 | drawCircle 120+ | drawPicture 4 |
| 별 데이터 재생성 | 리사이즈 시 | 리사이즈 시 (동일) |
| 시각적 차이 | 별마다 개별 깜빡임 | 그룹 단위 깜빡임 (3그룹이면 충분히 자연스러움) |

## 12. 정리

현재 프로젝트의 핵심은 다음 네 가지다.

1. 앱 셸 구조는 Flutter 표준 방식 유지
   - `main -> App -> Router -> View`
2. 게임 내부는 Flame 레이어를 명확히 분리
   - `viewport(HUD) / world(보드와 효과)`
3. 좌표계는 top-left 기반 화면형 레이아웃으로 단순화
   - safe area는 침범 금지 기준으로만 사용
4. 배경 렌더링은 캐싱 기반 최적화 적용
   - 정적 페인트를 래스터/Picture로 캐싱하고 깜빡임은 alpha만 변경

현재 구조를 한 줄로 요약하면 다음과 같다.

```text
모바일 세로형 매치-3 게임
+ Flutter 라우팅 셸
+ Flame 기반 렌더링
+ viewport(HUD) / world(보드와 효과) 분리
+ 첫 유효 레이아웃에서만 보드 시드
+ safe area 기반 배치
+ `PhoneFrame`으로 중앙 세로 프레임 유지
+ 배경 캐싱 최적화 (RepaintBoundary / ui.Picture)
```

다음에 구조를 더 발전시킬 때도 아래 원칙을 유지하면 파악이 쉽다.

- 앱 공통 배경은 `App` 레벨 `StarryBackground.instance`
- 게임 오브젝트는 `world`
- 화면 고정 UI는 `viewport`
- 오버레이 팝업은 Flutter overlay
- safe area는 "게임 요소 배치 기준"으로만 사용


---

# 랭킹 클라이언트 계약

원문 제목 키: `ranking_client_contract.md` (이 파일에 흡수됨)

# 랭킹 클라이언트 계약

서버 API는 **`ranking_server.md`**, PHP는 `matchranking/ranking.php`다.
이 문서는 Flutter 클라이언트가 언제 무엇을 보내는지만 적는다. 코드: `lib/game/match_board_game.dart`의 `rankingScore`, `lib/vm/ranking_notifier.dart`, `lib/views/overlays/pause_menu_overlay.dart`, `lib/views/overlays/time_up_overlay.dart`.

## 제출값

| 모드 | RankingMode | score | 0 이하 |
|---|---|---|---|
| 타임 | time | `board.score` | 제출하지 않음 |
| 레벨 | level | 완료 레벨 수 = `progressionLevel > 1 ? progressionLevel - 1 : 0` | 제출하지 않음 |
| 무한 | 없음 | 없음 | |

레벨 4 진입 중이면 3을 보낸다. HUD의 현재 레벨을 그대로 보내지 않는다.

Apps in Toss는 레벨 제출값을 공식 리더보드에도 보낸다. 게임 내 목록은 기존 랭킹 서버를 유지한다.

## 제출 시점

| 화면 | 동작 |
|---|---|
| TimeUp 진입 | `submit()` fire-and-forget. 결과 패널에 메시지/재제출 |
| TimeUp 나가기 | 제출 완료를 기다리지 않고 타이틀 |
| 일시정지 나가기 | 타임/레벨이면 `submit()`를 await한 뒤 타이틀. 제출 중 재탭 차단 |
| 일시정지 재시도 | 제출하지 않음 |
| 레벨 클리어 | 제출하지 않음. 런이 끝나야 완료 레벨이 확정된다 |

## HUD

- 왕관 버튼과 `RankingService.fetchTop1()`는 타임 모드만. 기본 query mode=time
- 레벨/무한 HUD에는 랭킹 버튼이 없다
- 타이틀 랭킹 팝업에서 타임/레벨 목록을 본다

## 실패

서버 없음, 404, load/save 실패는 문구와 재제출만 제공한다. 보드 진행과 타이틀 복귀를 막지 않는다.


---

# 랭킹 서버 운영

원문 제목 키: `ranking_server.md` (이 파일에 흡수됨)

# 랭킹 서버 운영

랭킹 초기화는 NAS에서 JSON을 백업한 뒤 한 모드씩 실행한다. 관리자 토큰은 `/share/Web/.match_deploy.env`의 `MATCH_DEPLOY_TOKEN`을 재사용하며 URL, 요청 body, 로그에 넣지 않는다.

## 사전 백업

NAS 파일 관리 도구에서 초기화할 파일을 웹 루트 밖의 접근 제한된 백업 폴더로 복사한다.

- 타임 랭킹: `/share/Web/matchranking/ranking_data.json`
- 레벨 랭킹: `/share/Web/matchranking/ranking_level_data.json`

예: 백업 폴더의 `ranking_level_data.backup-20260809.json`

## 건수 확인

로컬 `.env`의 토큰을 셸 환경에 불러온 뒤 dry-run을 실행한다. 출력이나 셸 기록에 토큰 값을 직접 적지 않는다.

```bash
set -a
source .env
set +a

curl -sS -X POST \
  'https://cheng80.myqnapcloud.com/matchranking/ranking.php?action=reset' \
  -H 'Content-Type: application/json' \
  -H "X-Ranking-Admin-Token: $MATCH_DEPLOY_TOKEN" \
  --data '{"mode":"level","dryRun":true}'
```

응답의 `count`가 백업한 JSON의 항목 수와 다르면 실행을 중단한다. 실제 요청의 `expectedCount`에는 이 값을 그대로 사용한다. 타임 랭킹은 body의 `mode`를 `time`으로 바꾼다.

## 실제 초기화

건수와 백업을 확인한 뒤 한 모드만 초기화한다.

```bash
curl -sS -X POST \
  'https://cheng80.myqnapcloud.com/matchranking/ranking.php?action=reset' \
  -H 'Content-Type: application/json' \
  -H "X-Ranking-Admin-Token: $MATCH_DEPLOY_TOKEN" \
  --data '{"mode":"level","expectedCount":0,"confirm":"RESET level"}'
```

예시의 `expectedCount` 0은 dry-run 응답의 실제 `count`로 바꾼다. 그 사이 건수가 달라지면 서버는 409 `ranking_count_changed`로 중단한다. 타임 랭킹은 `mode`를 `time`, 확인 문자열을 `RESET time`으로 함께 바꾼다. 성공 응답의 `removed`를 확인하고 `action=list&mode=level` 또는 `action=list&mode=time`이 빈 목록인지 확인한다. 다른 모드의 목록도 변경되지 않았는지 확인한다.

## 수동 복원

문제가 있으면 랭킹 요청을 중단하고 백업 파일을 원래 파일명으로 되돌린다. 파일 소유자와 쓰기 권한이 기존 JSON과 같은지 확인한 뒤 목록 API의 건수와 상위 기록을 재확인한다. 복원 API와 전체 모드 동시 초기화 기능은 제공하지 않는다.


---

# 스토어 채널 분기

원문 제목 키: 이 팩 Tech Spec의 스토어 채널 분기 절 (이 파일에 흡수됨)

# 스토어 채널 분기 가이드

Stone Match는 하나의 프로젝트 루트에서 App Store, Google Play, One Store, Apps in Toss를 빌드한다. 채널별로 프로젝트를 복제하지 않는다.

## 현재 적용 범위

Flutter 코드는 `STORE_CHANNEL` Dart define으로 출시 채널을 선택한다. 선택하지 않으면 기존 Android 배포 흐름과 같은 `play`를 사용한다.

| 값 | 대상 |
|---|---|
| `appstore` | Apple App Store |
| `play` | Google Play |
| `onestore` | One Store |
| `intoss` | Apps in Toss HTML5 |

잘못된 값은 앱 시작 시 실패한다. 채널 선택 확인은 다음 명령으로 한다.

```bash
flutter test test/app_config_test.dart --dart-define=STORE_CHANNEL=play
```

## 현재 빌드 명령

아래 명령은 Flutter 코드의 채널값을 선택한다. Android product flavor와 iOS 별도 bundle ID는 구현 전이다. Apps in Toss는 콘솔 `appName`과 운영 광고 그룹을 확정하기 전까지 테스트 산출물로만 사용한다.

```bash
# Google Play
flutter build appbundle --release --dart-define=STORE_CHANNEL=play

# One Store
flutter build apk --release --dart-define=STORE_CHANNEL=onestore

# Apple App Store
flutter build ipa --release --dart-define=STORE_CHANNEL=appstore

# Apps in Toss 공식 테스트 광고 Web 빌드와 .ait 패키징
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
```

## 채널별 구현 상태

| 항목 | 현재 | 다음 작업 |
|---|---|---|
| 공통 Flutter 채널값 | 적용됨 | 운영 빌드별 값 검증 |
| Google Play | `com.cheng80.stonematch`, `stonematch_key` 사용 예정 | `play` product flavor와 실제 서명 연결 |
| One Store | Google Play와 같은 `com.cheng80.stonematch`, `stonematch_key` 사용 | `onestore` flavor와 One Store 키 등록 |
| App Store | 기존 `com.cheng80.stonematch` 사용 | Apple ID와 Xcode build configuration 연결 |
| Apps in Toss | SDK 3.x 설정, 광고·레벨 리더보드 브리지, 테스트 Web과 `.ait` 빌드 적용 | 콘솔 `appName`, 운영 광고 그룹, 리더보드 QR 실기기 검증 |

## 구현 순서

1. 설정 화면과 인앱 리뷰를 채널별로 분기한다.
2. Android `play`, `onestore` product flavor와 iOS 설정을 추가한다.
3. Apps in Toss 콘솔 값을 확정하고 QR 테스트를 한다.
4. Apps in Toss 레벨 리더보드 연결을 QR 실기기에서 검증한다.

## 출시 전 결정할 값

- App Store Connect Apple ID
- Apps in Toss 콘솔 `appName`, 리더보드 구성, 광고 단위

식별자, 서명키, 콘솔 토큰은 소스에 저장하지 않는다.

Android 공통 JKS 경로는 `/Users/cheng80/android_keystore/stonematch_keystore.jks`이고 별칭은 `stonematch_key`다. 비밀번호는 문서에 기록하지 않는다.

One Store와 Apps in Toss의 등록 자료는 **`store_metadata_onestore_intoss_2026.md`**를 따른다.


---

# 웹 오디오 정책

원문 제목 키: `web_audio_flutter_flame.md` (이 파일에 흡수됨)

# Flutter Web + Flame(`flame_audio`) 오디오 정책 메모

다른 프로젝트에서 **웹(특히 데스크톱 크롬)** 과 **모바일(Safari 등)** 에서 오디오 동작이 다르거나, 효과음만 이상할 때 참고하는 전용 문서다.  
이 저장소의 구현 기준은 `lib/resources/sound_manager.dart` 및 아래에 인용한 파일들이다.

---

## 1. 자주 나오는 증상

| 증상 | 가능한 원인 (요약) |
|------|-------------------|
| 같은 MP3인데 **일부 파일만** 웹에서 묵음 | Web Audio 경로, 브라우저 디코더와 MP3 인코딩 조합 |
| **탭**으로는 효과음이 나오는데 **스와이프/드래그**로는 안 남 | user activation이 끊긴 뒤 `play()` 호출, 또는 제스처 경로 차이 |
| **모바일은 되는데 PC 크롬만** 이상 | 크롬이 오디오와 제스처 정책을 더 엄격하게 적용하는 경우 |
| 효과음을 **연속 재생**하면 앞선 음이 끊김 | **단일 `AudioPlayer`** 에서 새 `play()`가 이전 재생을 덮어씀 |
| `playSfx`에 `try/catch`가 있는데도 묵음 | 재생 실패가 **비동기 Future** 쪽에서 나와 동기 `catch`로 안 잡힘 |

---

## 2. 배경 (짧게)

- **`flame_audio`의 `FlameAudio.play`** 는 기본이 `PlayerMode.lowLatency`(웹에선 Web Audio API에 가깝다). 브라우저와 파일에 따라 특정 MP3만 실패할 수 있다.
- 브라우저는 **사용자 제스처(탭 등)와 같은 “활성화” 구간** 안에서 오디오 재생을 허용하는 경우가 많다. `await` 가 여러 번 끼면 그 구간 밖으로 밀려 **묵음**이 될 수 있다.
- **`AudioPlayer` 하나**는 동시에 하나의 소스만 재생한다. 연쇄 매치처럼 효과음이 겹치면 **풀(여러 개)** 이 필요하다.

---

## 3. 현재 프로젝트 정책

현재 프로젝트는 웹 오디오 대응에서 **고정 4슬롯 SFX 풀 + 필요 시 1회 잠금 해제**를 사용한다.

- 앱 루트 `Listener`의 `onPointerDown` 에서 `SoundManager.unlockForWeb()` 호출
- `unlockForWeb()`는 `_webUnlocked = true`로 전환하고, 잠금 전 요청된 BGM이 있으면 재생한다
- `web/stone_match_sfx.js`에서 Web Audio를 사용하지 않는 HTML 오디오 요소 4개를 생성하고 모든 SFX가 이 슬롯을 공유한다
- 4개가 모두 재생 중이면 새 플레이어를 생성하지 않고 해당 SFX를 건너뛴다
- 브라우저 재생이 실패하면 슬롯을 반환하고 오류 카운터에 기록한다
- 첫 `pointerdown`과 화면이 숨겨졌다 복귀한 후 첫 `pointerdown`에서만 4개 플레이어를 0볼륨으로 해제한다
- 화면이 숨겨지면 진행 중인 SFX 슬롯을 정리하고, 모든 입력마다 반복 프라이밍하지는 않는다
- 웹에서 같은 BGM을 다시 요청했는데 재생 중이 아니면 `resume`만 하지 않고 소스를 다시 설정해 재생한다
- 콤보음(`ComboHit`)은 현재도 웹에서 별도 즉시 재생 분기 없이 기존 지연 재생(`playComboSfxDelayed`)을 유지한다

즉, 현재 저장소의 기준점은 “**Web Audio 우회 + HTML 오디오 고정 4슬롯 + 첫 입력과 화면 복귀 후 1회 잠금 해제 + 포화 시 누락 허용**”이다. iOS Safari에서 효과음별 Web Audio 컨텍스트가 정지하는 경로를 사용하지 않는다.

### 3.1 현재 코드에서 확인할 파일

- `lib/resources/sound_manager.dart`
  - `_webUnlocked`, `_pendingBgm`
  - `_webSfxPool`, `_WebSfxPool`
  - `unlockForWeb()`
  - `playBgm()` / `playBgmIfUnmuted()` / `playSfx()`
- `lib/app.dart`
  - 웹일 때 전역 `Listener`
  - `onPointerDown: (_) => SoundManager.unlockForWeb()`

### 3.2 장단점

- 장점:
  - 드래그 이후에도 탭 없이 사운드가 계속 살아 있을 가능성이 높다.
  - SFX는 Web Audio 컨텍스트를 생성하지 않고 HTML 오디오 요소 4개만 재사용한다.
  - 재생 횟수, 포화 누락, 오류, 활성 슬롯을 `stoneMatchSfx.getState()`로 확인할 수 있다.
- 단점:
  - 최소 unlock 정책보다 구조가 복잡하다.
  - 효과음이 4개를 넘게 완전히 겹치면 초과 SFX는 누락된다.
  - 브라우저별로 안정성이 달라질 수 있어 회귀 테스트가 필요하다.
  - 완전한 해결 상태는 아니며, 드물게 장시간 플레이 후 일부 SFX가 다시 잠길 수 있다.

### 3.3 에셋(MP3) 정규화 (선택)

웹 호환을 위해 `ffmpeg` 로 **44.1 kHz 스테레오, `libmp3lame`** 등으로 통일할 수 있다.
스크립트: `tools/reencode_mp3_web.py` (폴더 단위 일괄 재인코딩).

---

## 4. 문제가 다시 생기면 고려할 고급 대응

현재 저장소에서는 아래 대응 중 일부가 실제 코드에 들어가 있다. 추가 회귀가 생기면 다음 항목을 다시 검토한다.

1. 웹 SFX 풀 구성을 더 줄이거나 늘리기
2. 웹 SFX만 `PlayerMode.mediaPlayer` 로 분기
3. `unlockForWeb()` 호출 시점을 `pointerdown` 외 보조 제스처까지 넓힐지 검토
4. `ComboHit` 같은 지연 재생 SFX를 웹에서만 별도 처리할지 검토

이런 대응은 묵음, 드래그 시 미재생, 동시 재생 끊김이 실제로 재현될 때만 넣는 편이 낫다.

---

## 5. 관련 파일 (이 저장소)

| 파일 | 역할 |
|------|------|
| `lib/resources/sound_manager.dart` | 웹 SFX 고정 슬롯, `playSfx`, pending BGM |
| `lib/resources/web_sfx_bridge_web.dart` | Dart에서 HTML 오디오 브리지 호출 |
| `web/stone_match_sfx.js` | HTML 오디오 4슬롯 재생과 진단 상태 |
| `lib/app.dart` | 웹 `Listener` → `unlockForWeb` |
| `tools/reencode_mp3_web.py` | MP3 일괄 재인코딩 (선택) |

---

## 6. 버전과 의존성 메모

- `flame_audio` → 내부적으로 `audioplayers` 사용. 패키지 메이저 버전이 올라가면 웹 구현 세부가 달라질 수 있다.
- 문제가 **패키지 업데이트 직후**에만 생기면, 해당 버전의 `audioplayers` / `audioplayers_web` 이슈도 함께 본다.

---

*최종 정리: 현재 저장소의 웹 오디오 기준점은 “**첫 포인터다운과 화면 복귀 후 1회 unlock + Web Audio 우회 + HTML 오디오 고정 4슬롯**”이다.*


---

# Android Gradle 설정

원문 제목 키: 이 팩 Tech Spec의 Android Gradle 절 (이 파일에 흡수됨)

# Android Gradle 설정 메모

기준일: 2026-06-16  
대상 앱: Stone Match (`com.cheng80.stonematch`)

이 문서는 이전 Flutter Android 템플릿에서 현재 Stone Match Android 설정으로 맞출 때 확인할 기준값을 정리한다. 현재 저장소는 이미 Kotlin DSL 기반이다.

## 현재 값

| 항목 | 현재 설정 |
|------|-----------|
| Android Gradle Plugin | `8.11.1` (`android/settings.gradle.kts`) |
| Gradle wrapper | `8.14` (`android/gradle/wrapper/gradle-wrapper.properties`) |
| Kotlin Android plugin | `2.2.20` |
| Java | `17` (`android/app/build.gradle.kts`) |
| namespace | `com.cheng80.stonematch` |
| applicationId | `com.cheng80.stonematch` |

AGP 8.11 계열 공식 호환성은 Gradle 8.13 이상과 JDK 17 기준이다. Stone Match는 Gradle 8.14와 Java 17을 쓰므로 이 범위에 있다.

## 파일별 역할

| 파일 | 역할 |
|------|------|
| `android/settings.gradle.kts` | Flutter Gradle plugin include, AGP/Kotlin plugin 버전 관리 |
| `android/build.gradle.kts` | 공통 repository와 build directory 설정 |
| `android/app/build.gradle.kts` | 앱 namespace, applicationId, SDK, Java/Kotlin target, 서명 설정 |
| `android/gradle/wrapper/gradle-wrapper.properties` | Gradle 배포판 버전 |

## 변경 시 체크리스트

1. `namespace`와 `applicationId`는 둘 다 `com.cheng80.stonematch`로 유지한다.
2. Kotlin `MainActivity.kt`의 package도 `com.cheng80.stonematch`와 맞춘다.
3. AGP를 올릴 때는 Gradle wrapper, JDK 요구사항, Flutter stable 호환성을 함께 확인한다.
4. Android SDK가 이 로컬 환경에는 없으므로 Android 빌드는 SDK 설치 환경에서 별도 검증한다.

## 검증 명령

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

릴리즈 서명 검증은 **`../release/release_build.md`**를 따른다.

## 공식 참고

- Android Gradle Plugin 8.11 release notes: https://developer.android.com/build/releases/agp-8-11-0-release-notes
- Gradle compatibility matrix: https://docs.gradle.org/current/userguide/compatibility.html


---

# Web 빌드

원문 제목 키: 이 팩 Tech Spec의 Web 빌드 절 (이 파일에 흡수됨)

# Web 릴리즈 빌드

## /match/ 서브패스에서 실행

앱을 `https://example.com/match/` 같은 서브패스에서 서비스할 때 사용합니다.

### 빌드 명령어

```bash
flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn
dart run tools/patch_flutter_web_deprecations.dart
```

`patch_flutter_web_deprecations.dart`는 Flutter 3.44.0 web bootstrap이 Chrome에서 deprecated `Intl.v8BreakIterator` feature check를 건드리며 콘솔 경고를 내는 부분만 빌드 산출물에서 제거합니다. 앱 코드나 Flutter SDK는 수정하지 않습니다.

`--wasm`은 지원 브라우저에서 `dart2wasm + skwasm` 렌더러를 사용하고, 미지원 환경에서는 `dart2js + canvaskit`으로 폴백하는 산출물을 만듭니다. `--no-web-resources-cdn`은 CanvasKit/skwasm 런타임을 앱과 같은 출처에서 제공해 COEP 헤더 적용 시 외부 CDN 정책에 의존하지 않도록 합니다.

### Wasm 멀티스레드 헤더

`skwasm`이 멀티스레드 렌더링을 사용하려면 응답이 cross-origin isolated 상태여야 합니다. Apache 계열 서버에서는 배포 패키지의 `.htaccess`에 다음 설정이 포함되어야 합니다:

```apache
<IfModule mod_mime.c>
  AddType application/wasm .wasm
</IfModule>

<IfModule mod_headers.c>
  Header always set Cross-Origin-Opener-Policy "same-origin"
  Header always set Cross-Origin-Embedder-Policy "require-corp"
  Header always set Cross-Origin-Resource-Policy "same-origin"
</IfModule>
```

`tools/deploy_match_web.sh`는 이 `.htaccess`를 자동 생성합니다. 서버에서 `mod_headers`, `mod_mime`, `AllowOverride FileInfo`가 비활성화되어 있으면 헤더나 MIME 타입이 적용되지 않으므로, 배포 후 브라우저 콘솔에서 `window.crossOriginIsolated === true`인지 확인합니다.

### 용량 줄이기 옵션

번들 크기를 줄이려면 다음 옵션을 추가할 수 있습니다:

```bash
flutter build web --release --base-href "/match/" \
  --wasm \
  --no-web-resources-cdn \
  --tree-shake-icons \
  --no-source-maps
dart run tools/patch_flutter_web_deprecations.dart
```

| 옵션 | 설명 |
|------|------|
| `--tree-shake-icons` | 사용하지 않는 Material/Cupertino 아이콘 제거 (기본값일 수 있음) |
| `--no-source-maps` | 소스맵 미생성 → 디버깅용 파일 제외로 용량 감소 |
| `--minify` | JS/CSS 압축 (release 빌드에서 기본 적용) |
| `--wasm` | 지원 브라우저에서 `dart2wasm + skwasm` 사용, 미지원 시 CanvasKit 폴백 |
| `--no-web-resources-cdn` | CanvasKit/skwasm 런타임을 같은 출처에서 제공 |

**용량 분석:**
```bash
flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn --analyze-size
```
빌드 후 `build/web/` 내 `.json` 리포트로 어떤 모듈이 용량을 차지하는지 확인할 수 있습니다.

### 출력 경로

빌드 결과물은 `build/web/` 폴더에 생성됩니다.

### 배포

**방법 A: 정적 호스팅 (GitHub Pages, Netlify 등)**

서버 설정을 할 수 없는 경우, `match` 폴더를 만들고 빌드 결과물을 그 안에 복사합니다:

```bash
# 빌드 후 match 폴더 생성 및 복사
rm -rf build/web match match.zip
flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn
dart run tools/patch_flutter_web_deprecations.dart
mkdir -p match && cp -R build/web/. match/
zip -qry match.zip match
```

`match/` 폴더를 업로드하면 `https://example.com/match/` 에서 서비스됩니다.

**방법 B: Nginx/Apache 등 직접 설정 가능한 서버**

1. `build/web/` 폴더 전체를 웹 서버에 업로드합니다.
2. 서버에서 `/match/` 경로가 `build/web/` 내용을 가리키도록 설정합니다.

**예시 (Nginx):**
```nginx
location /match/ {
    alias /path/to/build/web/;
    add_header Cross-Origin-Opener-Policy "same-origin" always;
    add_header Cross-Origin-Embedder-Policy "require-corp" always;
    add_header Cross-Origin-Resource-Policy "same-origin" always;
    try_files $uri $uri/ /match/index.html;
}
```

**예시 (Apache):**
```apache
Alias /match /path/to/build/web
<Directory /path/to/build/web>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    AddType application/wasm .wasm
    Header always set Cross-Origin-Opener-Policy "same-origin"
    Header always set Cross-Origin-Embedder-Policy "require-corp"
    Header always set Cross-Origin-Resource-Policy "same-origin"
    RewriteEngine On
    RewriteBase /match/
    RewriteRule ^index\.html$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /match/index.html [L]
</Directory>
```

### NAS 자동 배포와 검증

저장소 루트에서 다음 스크립트를 실행한다.

```bash
tools/deploy_match_web.sh
```

스크립트가 실패하면 그 단계에서 중단한다. `.env`, 배포 토큰, 비밀번호 같은 비밀값은 출력하거나 기록하지 않는다.

성공 후 공개 주소가 HTTP 200인지 확인하고, 아래 파일의 로컬 `build/web`과 원격 SHA-256이 모두 같은지 비교한다.

```text
index.html
flutter_bootstrap.js
flutter.js
main.dart.js
manifest.json
version.json
assets/AssetManifest.bin.json
assets/FontManifest.json
```

```bash
base='https://cheng80.myqnapcloud.com/match'
files=(index.html flutter_bootstrap.js flutter.js main.dart.js manifest.json version.json assets/AssetManifest.bin.json assets/FontManifest.json)
for file in "${files[@]}"; do
  local_path="build/web/$file"
  remote_path="/tmp/stone_match_${file//\//_}"
  test -f "$local_path" || { printf 'MISS %s\n' "$file"; continue; }
  curl -L -sS -o "$remote_path" "$base/$file"
  test "$(shasum -a 256 "$local_path" | awk '{print $1}')" = "$(shasum -a 256 "$remote_path" | awk '{print $1}')" \
    && printf 'OK %s\n' "$file" || printf 'DIFF %s\n' "$file"
done

curl -L -sS -o /tmp/stone_match_index_check.html \
  -w 'status=%{http_code} size=%{size_download} final_url=%{url_effective}\n' \
  "$base/"
curl -L -sS -o /tmp/stone_match_zip_check \
  -w 'zip_status=%{http_code} zip_size=%{size_download}\n' \
  'https://cheng80.myqnapcloud.com/match.zip'
```

`match.zip`은 업로드 뒤 공개 서버에서 제거되어 `404`가 나와야 한다. 최종 보고에는 배포 성공 여부, 공개 주소 상태, 해시 불일치 파일, ZIP 제거 결과만 남긴다.

### 로컬 확인

빌드 후 로컬에서 `/match/` 서브패스 동작을 확인하려면, **방법 A**처럼 `match` 폴더를 만든 뒤 그 **부모 디렉터리**에서 정적 서버를 띄웁니다.

```bash
rm -rf build/web match
flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn
dart run tools/patch_flutter_web_deprecations.dart
mkdir -p match && cp -R build/web/. match/
python3 -m http.server 8080   # match 폴더의 부모 디렉터리(예: 프로젝트 루트)에서 실행
```

그 다음 브라우저에서 `http://localhost:8080/match/` 로 접속합니다.

> **참고:** Python http.server는 서브패스 리다이렉트를 완벽히 처리하지 못할 수 있습니다. 실제 배포 환경과 비슷하게 테스트하려면 Nginx/Apache 등으로 확인하는 것이 좋습니다.

### base-href 규칙

- 반드시 `/`로 시작하고 `/`로 끝나야 합니다.
- 예: `"/match/"` ✅
- 예: `"/match"` ❌ (끝에 `/` 없음)
- 루트에서 서비스할 경우: `"/"`

### 관련 파일

- `web/index.html`: `<base href="$FLUTTER_BASE_HREF">` — 빌드 시 `--base-href` 값으로 치환됨
- `lib/router.dart`: GoRouter 경로 설정 (서브패스는 base-href로 자동 처리)


---

# SFX·BGM 프롬프트

원문 제목 키: 이 팩 Tech Spec의 SFX·BGM 프롬프트 절 (이 파일에 흡수됨)

# AISFX 효과음 · Soundverse BGM 생성 가이드 (Stone Match)

이 문서는 `assets/audio/sfx/` **효과음**에 대응하는 목록과, [AISFX](https://aisfx.org/)용 **영문 프롬프트**, 그리고 `assets/audio/music/` **BGM**은 [Soundverse.ai](https://www.soundverse.ai)용 **영문 프롬프트**를 정리한 것이다.  
게임 톤: **캐주얼 매치-3**, 밝은 캔디/주얼 느낌. SFX는 과하지 않은 길이(0.3~1.5초 전후 권장).

---

## 1. 효과음 파일·코드 매핑 (전체)

| 파일명 | `AssetPaths` | 게임 내 용도 (현재 코드) |
|--------|--------------|---------------------------|
| `BtnSnd.mp3` | `sfxBtnSnd` | 타이틀·게임 오버레이 등 **UI 버튼** 탭 |
| `Start.mp3` | `sfxStart` | 인트로 보드 채움 완료 후 **라운드 시작** (`roundStart`) |
| `Collect.mp3` | `sfxCollect` | 유효한 스왑으로 **매치 연출 시작**할 때 |
| `TimeUp.mp3` | `sfxTimeUp` | **타임 오버** (`TimeUp` 오버레이) — 클리어/승리 팡파르 아님 |
| `TimeTic.mp3` | `sfxTimeTic` | **타임 모드**에서 남은 시간이 **10초 이하**일 때, 정수 초가 줄어들 때마다 1회 |
| `Fail.mp3` | `sfxFail` | **무효 스왑**(매치 없이 되돌아갈 때) |

※ 저시간 틱 상한(초)은 `MatchBoardGame.timedLowTimeTickMaxSeconds`(기본 10)로 조절.

---

## 2. 파일별 AISFX 프롬프트 (영문)

AISFX는 짧고 구체적인 영문 설명이 잘 맞는 경우가 많다. 아래는 **무음 구간 없이** 내보내기 쉽게 짧게 잡았다.

### `BtnSnd.mp3` — UI 버튼

- **프롬프트:**  
  `Short soft UI click for mobile puzzle game, light plastic or glass tap, bright and friendly, no harsh attack, 0.2 seconds, mono or subtle stereo, no music`
- **보조 키워드 (옵션):** casual game, jewel theme, positive

---

### `Start.mp3` — 라운드 시작

- **프롬프트:**  
  `Cheerful magical sparkle “go” stinger for match-3 puzzle game start, rising chime with soft bell and glitter shimmer, cute and energetic, about 0.8 seconds, no voice, no drums`
- **톤:** 스타트 알림 느낌, 과한 팡파르는 피함.

---

### `Collect.mp3` — 매치(유효 스왑)

- **프롬프트:**  
  `Satisfying gem pop and soft crystalline chime when gems match in a casual puzzle game, bright glassy tone, quick decay, roughly 0.4 to 0.7 seconds, playful, no explosion, no harsh noise`
- **톤:** “보석이 맞았다”는 보상감.

---

### `TimeUp.mp3` — 타임 오버 (시간 종료)

- **의도:** 스테이지 클리어·성공 스팅이 **아니다**. “시간이 다 됐다”는 **라운드 종료** 알림.
- **프롬프트:**  
  `Time ran out sting for casual puzzle game, soft neutral tone-out or gentle downward bloop, slightly disappointing but not celebratory, no victory fanfare, no sparkle explosion, about 0.8 to 1.2 seconds, no alarm siren, no voice`
- **피할 것:** triumphant brass, level-clear chime, bright success sparkle — **클리어 SFX와 혼동되면 안 됨**.

---

### `TimeTic.mp3` — 저시간 카운트다운 틱

- **재생:** 남은 시간이 `timedLowTimeTickMaxSeconds`(기본 10) 이하일 때, **매 정수 초**가 줄어들 때마다 1회(10→9→…→1).
- **프롬프트:**  
  `Very short soft digital tick or light clock tick for countdown timer in puzzle game, subtle and non-annoying, 0.1 to 0.15 seconds, low volume character, no echo`
- **톤:** 짧고 반복 들어도 부담 없게.

---

### `Fail.mp3` — 무효 스왑

- **재생:** 스왑 후 매치가 없어 **보드가 원위치**일 때.
- **프롬프트:**  
  `Soft negative feedback blip for invalid move in puzzle game, gentle rubber bounce or dull glass clink, slightly lower pitch, about 0.25 seconds, not harsh, not buzzer`
- **톤:** 벌점 느낌 최소화, **가벼운 거절** 정도.

---

## 3. 생성 후 체크리스트

1. **포맷:** 프로젝트는 현재 **MP3** 경로(`*.mp3`)로 연결되어 있다. AISFX가 WAV만 주면 변환하거나 `asset_paths`·프리로드를 WAV로 통일한다.  
2. **길이:** 너무 긴 파일은 페이드 아웃·트림 권장.  
3. **볼륨:** 게임 내 `GameSettings.sfxVolume`과 함께 들어보고, 클립 피크가 심하면 노멀라이즈.  
4. **라이선스:** AISFX 플랜에 따른 상업 이용·크레딧 조건을 [공식 사이트](https://aisfx.org/)에서 확인한다.

---

## 4. BGM — [Soundverse.ai](https://www.soundverse.ai)용 프롬프트

메뉴·인게임 루프는 `assets/audio/music/`의 **WAV**로 연결된다 (`AssetPaths.bgmMenu`, `bgmMain`).  
생성·내보내기는 [Soundverse.ai](https://www.soundverse.ai) 등에 아래 **영문 프롬프트**를 넣어 쓰면 된다.

**공통 믹스 팁:** 효과음(AISFX)과 겹칠 때를 대비해 BGM은 **과한 베이스·킥**을 피하고, **중·고역 위주의 밝은 패드·벨** 쪽이 SFX와 섞기 쉽다. 루프 트랙이면 **시작·끝이 자연스럽게 이어지게** 편집하거나, Soundverse에서 “seamless loop”를 요청한다.

---

### `Menu_BGM.wav` — 타이틀·메뉴

- **역할:** 타이틀·설정 등 **비플레이** 화면. 차분하고 환영하는 느낌, 플레이 압박 없음.
- **Soundverse 프롬프트 (영문):**  
  `Relaxing loopable background music for casual stone match-3 puzzle game main menu, soft sparkly synth pads and gentle bell-like tones, warm and inviting, light and airy, no heavy bass, no drums, medium slow tempo around 90 BPM, seamless loop, no vocals, family friendly`

---

### `Main_BGM.wav` — 인게임(보드)

- **역할:** 매치 플레이 중 **집중을 방해하지 않는** 업비트 루프. 메뉴보다 살짝 더 리듬감 있어도 됨.
- **Soundverse 프롬프트 (영문):**  
  `Upbeat loopable instrumental background for mobile match-3 gem puzzle gameplay, playful plucks and soft chimes, subtle light percussion if any, energetic but not chaotic, bright candy-jewel mood, avoid loud kicks and sub bass, around 100 to 115 BPM, seamless loop, no vocals, no sudden drops, casual game OST`

---

### 내보내기 후

1. 파일명을 `Menu_BGM.wav`, `Main_BGM.wav`로 맞추거나 `asset_paths.dart`와 동일한 경로로 둔다.  
2. **라이선스:** Soundverse 플랜에 따른 상업 이용·크레딧은 [공식 사이트](https://www.soundverse.ai) 기준으로 확인한다.


---

# Supertonic TTS SFX

원문 제목 키: `supertonic_tts_sfx.md` (이 파일에 흡수됨)

# Supertonic TTS 임시 SFX 생성 가이드

Supertonic은 효과음/징글 생성기가 아니라 TTS다. 그래서 최종 게임 SFX를 만들기보다는 `Start!`, `Clear!`, `Level up!` 같은 짧은 음성 콜아웃을 임시 자산으로 만들 때 사용한다. 나중에 전용 SFX를 받으면 같은 파일명으로 덮어쓰거나 코드 상수만 새 파일명으로 바꾼다.

## 준비

```bash
python3 -m venv /tmp/supertonic-sfx
/tmp/supertonic-sfx/bin/python -m pip install --upgrade pip
/tmp/supertonic-sfx/bin/python -m pip install supertonic
```

첫 실행 때 Hugging Face에서 `Supertone/supertonic-3` 모델을 내려받는다. 네트워크가 필요하고, 비로그인 상태에서는 속도 제한이 걸릴 수 있다.

## 생성 스크립트

아래 스크립트는 Flutter/Flame에서 바로 쓸 수 있는 44.1kHz, 16bit, mono WAV를 만든다. `LevelUp.wav`는 첫 어택이 잘리지 않도록 앞에 120ms 무음을 붙인다.

```bash
/tmp/supertonic-sfx/bin/python - <<'PY'
from pathlib import Path
import wave
import numpy as np
from supertonic import TTS

out_dir = Path("assets/audio/sfx")
out_dir.mkdir(parents=True, exist_ok=True)

tts = TTS(model="supertonic-3")

items = {
    "Start.wav": ("Start!", "F3", 1.18, 0.08, 0),
    "Clear.wav": ("Clear!", "F3", 1.18, 0.08, 0),
    "LevelUp.wav": ("Next level!", "F5", 1.06, 0.24, 120),
}

def save_padded(path, audio, sample_rate, lead_ms):
    flat = audio.squeeze().astype(np.float32)
    lead = np.zeros(int(sample_rate * lead_ms / 1000), dtype=np.float32)
    padded = np.concatenate([lead, flat])
    pcm16 = (np.clip(padded, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm16.tobytes())

for filename, (text, voice, speed, silence, lead_ms) in items.items():
    style = tts.get_voice_style(voice)
    wav, duration = tts.synthesize(
        text,
        voice_style=style,
        total_steps=8,
        speed=speed,
        silence_duration=silence,
        lang="en",
    )
    path = out_dir / filename
    if lead_ms:
        save_padded(path, wav, tts.sample_rate, lead_ms)
    else:
        tts.save_audio(wav, str(path))
    print(f"{path} {duration[0] + lead_ms / 1000:.3f}s")
PY
```

## Flutter/Flame 연결

`AssetPaths`에 경로를 둔다.

```dart
static const String sfxStart = 'sfx/Start.wav';
static const String sfxClear = 'sfx/Clear.wav';
static const String sfxLevelUp = 'sfx/LevelUp.wav';
```

`SoundManager.preload()`에 추가한다.

```dart
FlameAudio.audioCache.load(AssetPaths.sfxStart),
FlameAudio.audioCache.load(AssetPaths.sfxClear),
FlameAudio.audioCache.load(AssetPaths.sfxLevelUp),
```

웹에서는 `FlameAudio.createPool`에도 등록한다.

```dart
SoundManager._webSfxPools[AssetPaths.sfxLevelUp] =
    await FlameAudio.createPool(
      AssetPaths.sfxLevelUp,
      minPlayers: 1,
      maxPlayers: 1,
    );
```

사용 지점에서는 전용 상수를 재생한다.

```dart
SoundManager.playSfx(AssetPaths.sfxLevelUp);
```

## 확인

```bash
file assets/audio/sfx/Start.wav assets/audio/sfx/Clear.wav assets/audio/sfx/LevelUp.wav
flutter analyze
flutter test
flutter build web --release
```

웹에서 확인할 때는 네트워크 요청에 `assets/assets/audio/sfx/LevelUp.wav`가 200으로 뜨는지 본다.

## 교체 전략

- 임시 TTS를 유지: 현재 파일 그대로 사용한다.
- 전문 SFX로 교체: 같은 파일명(`Start.wav`, `Clear.wav`, `LevelUp.wav`)으로 덮어쓴다.
- 파일명을 바꾸는 경우: `AssetPaths` 상수만 새 경로로 변경한다.

Supertonic은 음성 콜아웃용으로만 사용하고, 보석 폭발/버튼/징글 같은 비언어 효과음은 별도 SFX 소스에서 보충한다.


### 2026-09-20 F1 상태 전이와 렌더 보완
유효 스왑은 swapSettle(0.12초) → 기존 매치 판정 → removing(0.18초) 순서다. 프리즘 변환 및 특수 탭은 기존 직접 제거 경로를 유지한다. 무효 스왑의 보석별 bumpT는 렌더 전용 0.18초이며 inputLock은 기존 0.04초다. 제거 시작 알림 onRemovalStarted는 BoardJuiceLayer의 0.12초 섬광만 방출한다.

BoardJuiceLayer는 onMount에서 아틀라스를 확보하고 onRemove에서 해제하며, 살아 있는 파티클을 typed 버퍼 앞쪽에 압축한다. 0~192 길이 뷰는 마운트 때 캐시하여 render에서 생성하지 않는다. busy는 마지막 버스트와 텍스트 수명 전체를 기다리되 유휴 반짝임은 제외한다. 점수 팝업은 상단 콜아웃 영역 아래에서 떠오른다.

### 2026-09-20 T1, T2, T3, T4a, T4b, T5 통합 계약

- T1의 보드 이벤트는 원래 매치 패턴, 특수 보석 생성 및 실제 발동, 콤보 단계, 착지와 리필 경계를 `BoardJuiceLayer`에 전달한다. 점수 글리프는 마운트당 한 번 만든 숫자 아틀라스를 사용하며 숫자 이벤트가 있을 때 파티클 아틀라스 draw에 추가 draw 1회를 사용한다. 시간 보너스는 적용된 값이 0.1초 단위 이상일 때만 `+Ns`로 표시한다.
- T2의 보석 아틀라스는 64px 셀 8열, 512×640 이미지로 기본 및 특수 보석, 6프레임 baked sheen, 선택 광륜을 공유한다. 대각선 광택 스윕은 `_animTime * 0.8`과 위상 주기 8을 사용해 보석 한 칸 통과 0.9초, 반복 10초로 재생한다. 행/열 위상차와 기존 아틀라스는 유지한다. 색 보정과 typed buffer는 마운트 시 준비하고 onRemove에서 해제한다. 균등한 보석은 일괄 `drawRawAtlas`로 제출하지만 비균등 착지 squash는 같은 아틀라스의 `drawImageRect` fallback을 사용한다. 따라서 squash가 여러 행에 흩어진 프레임에서는 draw call이 9회를 넘을 수 있으며 모든 프레임을 1~9회로 보장하지 않는다.
- 특수 보석 제거는 첫 0.07초에 1에서 0.78로 수축한 뒤 기존 제거 팝을 따른다. `removeDelay` 0.18초와 `swapSettle` 0.12초, 발동과 점수 시점은 변하지 않는다. 무한 모드의 5초 유휴 자동 힌트는 `showHint()`를 재사용하고 `hasActiveVisualEffects`에는 포함하지 않는다.
- F1 독립 검수에서 발견된 세 입력 회귀는 T2가 수정했다. 안착 또는 제거 중 드래그 시작과 갱신을 차단하고, 무효 드래그 범프를 시작 시 취소하며, geometry 변경 시 이전 타일 크기의 범프와 드래그 상태를 취소한다. 새 유효 스왑은 같은 보석의 잔여 무효 드래그 복귀를 취소한다. `test/t2_f1_input_regression_test.dart`, `test/t2_pointer_flow_test.dart`, `test/t2_gem_feedback_test.dart`가 이를 고정한다.
- T3는 콤보 및 매치 등급, T/L, 저시간 틱을 기존 에셋의 웹 피치로 매핑한다. 웹은 HTML Audio 고정 4슬롯과 unlock 정책을 유지하고, 네이티브 피치는 실기기 확인 전까지 고정 폴백이다.
- T4a HUD는 목표, 콤보, 타임바, 시간 보너스, 저시간, 버튼, 힌트 배지 및 아이템 소모 피드백을 HUD 상태로만 관리한다. T4b 화면 계층은 공통 카드 240ms, exit 잔상 160ms, 다이얼로그 200ms, 타이틀 70ms 간격, 인벤토리 12% 상승, 타임업 점수 800ms 롤업을 사용한다. `MediaQuery.disableAnimations`에서는 시각 모션을 끝내지만 타임업 제출 및 입력 가능 시점은 1900ms를 유지한다. 레벨 축하는 일반 3000ms, reduced motion 즉시 완료다.
- T5는 특수 burst와 HUD의 직접 런타임 `MaskFilter.blur`를 baked atlas로 바꾼다. 특수 atlas는 1536×768 RGBA 공유 이미지 약 4.5MiB이며 lease를 유지해 풀에서 재사용하고 마지막 소유자 제거 후 해제한다. HUD glow atlas는 실제 레이아웃 크기에서 생성하며 같은 크기에서는 재생성하지 않고 크기 변경과 remount에서 갱신한다. T4a의 HUD interactions와 painters 구조는 유지한다.
- 현재 합본의 근거였던 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_integrated_final.txt`는 2026-09-20 15:53 KST 기준 `analyze exit=0`, 전체 `262 tests` 통과, Web build exit=0인 HISTORICAL 기록이다. 이후 X2와 bomb 후속 변경으로 STALE이며, bomb 해당 리비전은 analyze 0, `274 tests PASS`, Web build 0을 기록했다. E2는 전체 279 tests, 최종 analyze, Web build와 실제 Flutter 픽셀/보드 캡처를 통과했다. 병합 전 근거는 `reports/verify_E2_final.txt`의 테스트/빌드 종료코드와 `reports/E2_review.md`의 최종 analyze 0이다. main `c3b64dd` 병합 후에도 analyze 0, 전체 279 tests PASS, Web release build 0을 재확인했다. 최신 근거는 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_main_after_E2_merge.txt`다. 실기기 FPS, 장시간 모바일 WebView, 실제 광고 SDK, 실제 기기 오디오 청취는 미검증이다. T4b ego 캡처의 일부 문자 중복은 headless에서 재현되지 않아 원인을 확정하지 않았다.

### 최종 종료와 레벨 클리어 수명
- GameWidget 최종 이탈은 `removeAll(children)`와 `processLifecycleEvents()`로 atlas/ticker 종료를 완료한다. 공유 이미지 캐시는 유지한다. 다음 GameView는 새 게임을 만든다.
- 퇴장 snapshot의 `debugNeedsPaint`는 assert 내부에서만 읽고, 캡처 실패도 즉시 action을 막지 않는다.
- T6는 별도 BoardJuiceLayer를 overlay ticker로 구동한다. 120ms부터 대각선 90ms 간격 charge, 70ms 뒤 burst이며 실제 보드를 제거하거나 점수/보상을 갱신하지 않는다. stage attempt와 active overlay로 오래된 완료를 차단한다.
