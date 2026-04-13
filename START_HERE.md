# 작업 세션 시작 — 여기부터 읽기

> **역할:** 새 대화를 열어 작업을 이어갈 때 **가장 먼저** 읽는 문서다.  
> **현재 진행 위치 / 다음에 할 일**은 이 파일과 [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md)가 안내한다. (프로젝트 코딩 규칙은 `.cursor/rules`·`README.md`를 따른다.)

---

## 대화 시작 시 한 줄

**「`START_HERE.md`와 `docs/jewel_match_execution_checklist.md`를 읽고, §1 문서 순서대로 훑은 뒤 §3 우선 작업부터 진행하자.」**

---

## 1. 필수 읽기 순서

| 순서 | 문서 | 할 일 |
|:---:|:---|:---|
| 1 | **이 파일** (`START_HERE.md`) | §2 현재 상태, §3 다음 작업만 먼저 확인 |
| 2 | [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md) | 체크 안 된 항목·보류 항목 확인 |
| 3 | [`README.md`](README.md) | 디렉터리 구조, 라우팅, 빌드 명령 |
| 4 | [`docs/game_flow.md`](docs/game_flow.md) | 매치 규칙·모드·오버레이 플로우 |
| 5 | [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md) | `main` → `GameView` → `MatchBoardGame` 초기화·파일 역할 |
| 6 | [`docs/web_build.md`](docs/web_build.md) | Web `--base-href`·배포 시 주의 (서브패스 `/match/` 등) |
| 7 | [`docs/audio_aisfx_prompts.md`](docs/audio_aisfx_prompts.md) | SFX·BGM 파일명·프롬프트·코드 매핑 변경 시 |

---

## 2. 현재 프로젝트 상태 (요약)

- **Jewel Match** — Flame 기반 **8×8 매치-3**, 패키지명 `jewelmatch` (`README.md` 참고).
- **모드:** 심플(무제한) / 타임 어택 — `GoRouter` 쿼리 `mode=simple` · `mode=timed`.
- **입력:** HUD에서 **탭-탭 스왑**와 **스와이프(인접 한 칸)** 모두 지원 (`match_game_hud.dart`).
- **코어:** `MatchBoardLogic`(보드·스왑·매치·낙하) + `MatchBoardRenderer`(그리기) + `MatchGameHud`(HUD·일시정지·타임바 등).
- **오디오:** `SoundManager` — BGM(메뉴/메인), SFX 프리로드. 타임 모드 저시간 `TimeTic`, 무효 스왑 `Fail`, 타임 오버 `TimeUp`, 매치 이벤트 SFX(`ComboHit`·`BigMatch`·`SpecialGem`) 등 (`asset_paths.dart`·`audio_aisfx_prompts.md`).
- **파티클:** 매치 시 `ParticleBurst` Flame 컴포넌트로 방사형 파티클 — 3매치(기본), 4+매치·콤보·특수 보석(화려) 3단계 (`lib/game/components/particle_burst.dart`).
- **타임 모드 랭킹 (서버):** PHP 단일 파일 [`matchranking/ranking.php`](matchranking/ranking.php) — 상위 30명 JSON 저장. **플러터 웹 빌드 출력(`match/` 등)과 분리**해 NAS에 두면 배포 시 랭킹 데이터가 지워지지 않는다. 클라이언트는 `lib/services/ranking_service.dart` (`http`).
- **타임 모드 UX:** 타이틀에서 **이름 입력** 후 진입 (`GameSettings.playerName`, 기본·저장값 `GUEST`). HUD **베스트 영역**에 서버 **1위 이름·점수**. **TimeUp** 시 점수 제출 → 순위 또는 미달 메시지. 심플 모드는 로컬 베스트만.
- **TimeUp 오버레이:** 스크림 위 **「시간 종료」** 스케일·바운스 연출 후 점수·랭킹 패널 (`game_view.dart` `_TimeUpOverlay`).
- **도움말(?):** `HowToPlay` 오버레이 — 일시정지와 동일하게 엔진·BGM 정지, 보석 스프라이트로 매치 예시, **설명만 스크롤**·하단 **계속하기** 고정 (`showHowToPlay` / `closeHowToPlay`, `match_board_game.dart`).
- **반응형 프레임:** `PhoneFrameScaffold` + `PhoneFrame` — 고정 논리 해상도 `390×750` + `FittedBox` 스케일링. 웹·태블릿에서 비율 유지, 바깥은 `StarryBackground`로 채운다 (`lib/widgets/phone_frame_scaffold.dart`). `GameView`는 Flame 자체 캔버스이므로 `FittedBox` 없이 `LayoutBuilder` 스케일링만 적용.
- **웹:** `flutter build web` 시 **`--base-href`는 실제 서빙 URL과 반드시 일치** (`docs/web_build.md`). 예: `/match/` 또는 배포 정책에 맞는 경로.
- **웹 UX:** `kIsWeb`이면 설정 **「평점 남기기」** 숨김, 타이틀 **자동 인앱 리뷰 요청** 생략 (`setting_view.dart`, `title_view.dart`).
- **저장:** `get_storage` — 설정·베스트 스코어·**플레이어 이름** 등 (`GameSettings`, `StorageHelper`, `StorageKeys` in `app_config.dart`). (루미 프로젝트와 달리 **복잡한 이어하기 세이브 스키마 없음**.)
- **전환 최적화:** `Juwel.png` 스프라이트시트를 `main.dart`에서 `Flame.images`로 사전 로드, `GoRouter`에서 `FadeTransition` 전환 적용 → 타이틀→게임 전환 시 버벅임 제거.

---

## 3. 지금 가장 중요한 작업 (우선순위)

새 세션에서 바로 확인할 것:

1. **[`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md)** 의 미체크 항목 — 특히 Web 배포 경로·`--base-href`·에셋 경로 정합.
2. **랭킹:** NAS `matchranking/` 경로·`ranking_data.json` 쓰기 권한·`RankingService` base URL이 실제 배포와 일치하는지.
3. **`lib/resources/asset_paths.dart`** 와 `assets/audio/` 실제 파일명·확장자(mp3/wav) 불일치 시 런타임 로드 오류.
4. 큰 기능/리팩터 후 **`docs/code-flow-analysis.md`**, **`docs/game_flow.md`** 동기화 여부.

단기적으로 자주 나오는 작업:

- Web 릴리즈: `docs/web_build.md` 명령으로 빌드 → `build/web/` 업로드 경로와 `base-href` 일치 검증. **`matchranking/`는 플러터 웹 빌드 업로드와 별도 경로에 두기 (배포 시 JSON 유실 방지).**
- 오디오 교체: 파일 추가 후 `AssetPaths`·`SoundManager.preload`·`audio_aisfx_prompts.md` 함께 수정.
- 번역·도움말 문구 추가 시 `assets/translations/*.json` 다국어 동시 반영.

---

## 4. 핵심 코드 위치 (빠른 점프)

| 영역 | 경로 |
|:---|:---|
| 라우팅 | `lib/router.dart` |
| 타이틀·게임·설정 화면 | `lib/views/title_view.dart`, `game_view.dart`, `setting_view.dart` |
| **반응형 프레임** | `lib/widgets/phone_frame_scaffold.dart` (`PhoneFrameScaffold` + `PhoneFrame`) |
| Flame 게임 엔트리 | `lib/game/match_board_game.dart` |
| 매치 로직 | `lib/game/match_board_logic.dart` |
| HUD | `lib/game/components/match_game_hud.dart` |
| 렌더 | `lib/game/components/match_board_renderer.dart` |
| 파티클 | `lib/game/components/particle_burst.dart` |
| 사운드 | `lib/resources/sound_manager.dart`, `asset_paths.dart` |
| 랭킹 API·클라이언트 | `lib/services/ranking_service.dart`, 서버 `matchranking/ranking.php` |

---

## 5. 세션 종료 전 갱신 규칙

작업을 끊기 전에 최소한 아래를 갱신한다.

1. 끝낸 일이 있으면 [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md) 체크박스 갱신.
2. 플로우·초기화·큰 책임 변경이 있으면 [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md) 또는 [`docs/game_flow.md`](docs/game_flow.md) 중 해당 부분 수정.
3. 오디오 파일명·용도를 바꿨으면 [`docs/audio_aisfx_prompts.md`](docs/audio_aisfx_prompts.md) 수정.
4. Web 배포 절차·URL 정책이 바뀌었으면 [`docs/web_build.md`](docs/web_build.md) 수정.
5. **다음에 이어질 수 있게 이 파일의 §2·§3을 최신 상태로 유지.**

---

## 6. 최근 메모 (수동 갱신)

> 작업할 때마다 한두 줄씩 추가·정리한다. (날짜는 ISO 형식 권장.)

- **2026-04-13 (2):** `PhoneFrameScaffold` + `PhoneFrame` 도입 — `390×750` 고정 논리 해상도 + `FittedBox` 스케일링. TitleView·SettingView 적용, GameView는 Flame 자체 `LayoutBuilder` 스케일링 유지. `StarryBackground` 중복 생성 제거. 매치 이벤트 SFX(`ComboHit`·`BigMatch`·`SpecialGem`) 추가, 3단계 `ParticleBurst` 파티클 시스템 구현. 스프라이트시트 사전 로드·FadeTransition 전환으로 장면 전환 최적화.
- **2026-04-13:** 탭+스와이프, 타임 랭킹(`matchranking`·`RankingService`), 이름·HUD 1위·TimeUp 제출, TimeUp 연출, HowToPlay(?)·스크롤 레이아웃·다국어·웹/랭킹 디렉토리 분리.
- **2026-04-04:** `START_HERE.md` / `jewel_match_execution_checklist.md` 도입. 웹에서 평점 메뉴·타이틀 자동 리뷰 비활성화 반영.

---

## 7. 한 줄 요약

**다음 세션은 `START_HERE.md` → 체크리스트 → `game_flow` / `code-flow-analysis` 순으로 읽고, Web은 `base-href`·에셋 경로·랭킹 API URL·NAS 배포 분리, 네이티브는 스토어·오디오·문서 동기화를 우선 보면 된다.**
