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
| 8 | [`docs/web_audio_flutter_flame.md`](docs/web_audio_flutter_flame.md) | Web 오디오 정책 메모 — 현재는 **최소 unlock 정책**, 고급 대응은 참고용 |

---

## 2. 현재 프로젝트 상태 (요약)

- **Jewel Match** — Flame 기반 **8×8 매치-3**, 패키지명 `jewelmatch` (`README.md` 참고).
- **모드:** 심플(무제한) / 타임 어택 — `GoRouter` 쿼리 `mode=simple` · `mode=timed`.
- **입력:** HUD에서 **탭-탭 스왑**와 **스와이프(인접 한 칸)** 모두 지원 (`match_game_hud.dart`).
- **코어:** `MatchBoardLogic`(보드·스왑·매치·낙하) + `MatchBoardRenderer`(그리기) + `MatchGameHud`(HUD·일시정지·타임바 등).
- **오디오:** `SoundManager` — BGM(메뉴/메인), SFX 프리로드. 타임 모드 저시간 `TimeTic`, 무효 스왑 `Fail`, 타임 오버 `TimeUp`, 매치 이벤트 SFX(`ComboHit`·`BigMatch`·`SpecialGem`) 등 (`asset_paths.dart`·`audio_aisfx_prompts.md`). 웹은 **첫 포인터다운 1회 unlock + pending BGM**만 유지하고, 그 이후 SFX/BGM은 네이티브와 같은 `FlameAudio` 경로를 사용.
- **파티클:** 매치 시 `ParticleBurst` Flame 컴포넌트로 방사형 파티클 — 3매치(기본), 4+매치·콤보·특수 보석(화려) 3단계 (`lib/game/components/particle_burst.dart`). 최근 조정으로 입자 수·퍼짐 반경·수명·글로우 강도를 줄여 GPU 부담을 낮췄다.
- **보석 스프라이트 규칙:** `assets/images/sprites/Jewel.png`는 `896×128`(7프레임, 셀당 `128×128`), `assets/images/sprites/Special.png`는 `384×128`(3프레임, 셀당 `128×128`). 현재 렌더 기준은 `Jewel.png` 2번째 프레임이 **하이퍼 보석**, `Special.png`는 순서대로 **col / row / bomb**. `ColorFilter.matrix`는 제거되었고, 특수 보석은 전용 프레임을 직접 사용한다 (`asset_paths.dart`, `match_board_renderer.dart`).
- **렌더 최적화:** `MatchBoardRenderer`는 보드 프레임/슬롯 배경을 `ui.Picture`로 캐싱하고, 보드 `clipRRect`는 낙하·리필·인트로 구간에서만 건다. `MatchGameHud`는 텍스트 레이아웃과 `Paint`를 캐싱해 프레임당 재계산을 줄였다.
- **튜토리얼 프리뷰:** `HowToPlayOverlay`는 공용 [`SpriteSheetFrame`](lib/widgets/sprite_sheet_frame.dart) 위젯으로 스프라이트 시트의 `128×128` 프레임을 원본 픽셀 기준으로 잘라 보여준다.
- **디버그 측정:** 개발 모드에서는 우측 상단에 `PerformanceOverlay` 기반 FPS/프레임 오버레이가 표시된다.
- **타임 모드 랭킹 (서버):** PHP 단일 파일 [`matchranking/ranking.php`](matchranking/ranking.php) — 상위 30명 JSON 저장. **플러터 웹 빌드 출력(`match/` 등)과 분리**해 NAS에 두면 배포 시 랭킹 데이터가 지워지지 않는다. 클라이언트는 `lib/services/ranking_service.dart` (`http`).
- **타임 모드 UX:** 타이틀에서 **이름 입력** 후 진입 (`GameSettings.playerName`, 기본·저장값 `GUEST`). HUD **베스트 영역**에 서버 **1위 이름·점수**. **TimeUp** 시 점수 제출 → 순위 또는 미달 메시지. 심플 모드는 로컬 베스트만.
- **오버레이 (MVVM):** `lib/views/overlays/`에 분리 — `TimeUpOverlay`(ConsumerStatefulWidget, `RankingNotifier` 연동), `PauseMenuOverlay`(ConsumerWidget, `SettingsNotifier` 연동), `NoMovesOverlay`, `HowToPlayOverlay`. 공통 위젯: `LuminaGradientButton`·`LuminaOutlinedButton`·`LuminaOverlayCard` (`lib/widgets/`).
- **MVVM + Riverpod:** `flutter_riverpod` 도입 (코드젠 미사용). `SettingsNotifier`(설정·볼륨·화면 꺼짐), `RankingNotifier`(점수 제출·결과 상태)를 `lib/vm/`에서 관리. View에서 비즈니스 로직 분리.
- **반응형 프레임:** `PhoneFrameScaffold` + `PhoneFrame` — 고정 논리 해상도 `390×750` + `FittedBox` 스케일링. 웹·태블릿에서 비율 유지. `GameView`는 **화면 비율 기반**으로 프레임 적용 여부 결정 (`screenRatio > refRatio`이면 프레임 적용, 일반 폰이면 전체 확장).
- **StarryBackground 싱글톤:** `App` 레벨에서 `StarryBackground.instance`(GlobalKey)를 **1개만** 생성. 모든 화면이 투명 배경으로 이 위에 쌓이므로 전환 시 재생성 비용 0. 각 View·`PhoneFrameScaffold`에서 중복 생성하지 않음.
- **전환 최적화:** 모든 라우트에 `FadeTransition` 적용 (타이틀 400ms, 게임 500ms, 설정 350ms). `GameView`·`TitleView`는 `endOfFrame` 대기 후 콘텐츠 마운트 — 페이드 전환과 무거운 초기화가 같은 프레임에 겹치지 않도록 분리. `PackageInfo` 캐싱으로 `FutureBuilder` 제거.
- **웹:** `flutter build web` 시 **`--base-href`는 실제 서빙 URL과 반드시 일치** (`docs/web_build.md`).
- **웹 UX:** `kIsWeb`이면 설정 **「평점 남기기」** 숨김, 타이틀 **자동 인앱 리뷰 요청** 생략.
- **저장:** `get_storage` — 설정·베스트 스코어·**플레이어 이름** 등 (`GameSettings`, `StorageHelper`, `StorageKeys` in `app_config.dart`).

---

## 3. 지금 가장 중요한 작업 (우선순위)

새 세션에서 바로 확인할 것:

1. **[`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md)** 의 미체크 항목 — 특히 Web 배포 경로·`--base-href`·에셋 경로 정합.
2. **랭킹:** NAS `matchranking/` 경로·`ranking_data.json` 쓰기 권한·`RankingService` base URL이 실제 배포와 일치하는지.
3. **`lib/resources/asset_paths.dart`** 와 `assets/audio/` 실제 파일명·확장자(mp3/wav) 불일치 시 런타임 로드 오류.
4. HUD 콤보 스트립(`combo` / `max combo`) 라벨-숫자 세로 간격 미세조정.
5. 큰 기능/리팩터 후 **`docs/code-flow-analysis.md`**, **`docs/game_flow.md`** 동기화 여부.

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
| **오버레이 (분리됨)** | `lib/views/overlays/` — `time_up_overlay.dart`, `pause_menu_overlay.dart`, `no_moves_overlay.dart`, `how_to_play_overlay.dart` |
| **ViewModel (Riverpod)** | `lib/vm/settings_notifier.dart`, `ranking_notifier.dart` |
| **공통 위젯** | `lib/widgets/lumina_buttons.dart`, `lumina_overlay_card.dart`, `phone_frame_scaffold.dart` |
| **배경 싱글톤** | `lib/widgets/starry_background.dart` (`StarryBackground.instance`) |
| **반응형 프레임** | `lib/widgets/phone_frame_scaffold.dart` (`PhoneFrameScaffold` + `PhoneFrame`) |
| Flame 게임 엔트리 | `lib/game/match_board_game.dart` |
| 매치 로직 | `lib/game/match_board_logic.dart` |
| HUD | `lib/game/components/match_game_hud.dart` |
| 렌더 | `lib/game/components/match_board_renderer.dart` |
| 파티클 | `lib/game/components/particle_burst.dart` |
| 사운드 | `lib/resources/sound_manager.dart`, `asset_paths.dart` — 웹 이슈는 [`docs/web_audio_flutter_flame.md`](docs/web_audio_flutter_flame.md) |
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

- **2026-04-13 (3):** MVVM 리팩터링 — `flutter_riverpod` 도입, `SettingsNotifier`·`RankingNotifier`(`lib/vm/`), 오버레이 4개 `lib/views/overlays/`로 분리, 공통 위젯 `LuminaGradientButton`·`LuminaOutlinedButton`·`LuminaOverlayCard`(`lib/widgets/`). `SettingView`를 `ConsumerWidget`으로 전환. `game_view.dart` 909줄→95줄. `StarryBackground`를 `GlobalKey` 싱글톤으로 `App` 레벨에 1개만 배치. 모든 라우트에 `FadeTransition` 적용. `GameView`·`TitleView`에 `endOfFrame` 대기 패턴 적용하여 전환 버벅임 제거. `GameView` 비율 프레임을 `kIsWeb` 대신 화면 비율 기반으로 전환하여 태블릿 지원. `PackageInfo` 캐싱.
- **2026-04-13 (2):** `PhoneFrameScaffold` + `PhoneFrame` 도입 — `390×750` 고정 논리 해상도 + `FittedBox` 스케일링. TitleView·SettingView 적용, GameView는 Flame 자체 `LayoutBuilder` 스케일링 유지. `StarryBackground` 중복 생성 제거. 매치 이벤트 SFX(`ComboHit`·`BigMatch`·`SpecialGem`) 추가, 3단계 `ParticleBurst` 파티클 시스템 구현. 스프라이트시트 사전 로드·FadeTransition 전환으로 장면 전환 최적화.
- **2026-04-13:** 탭+스와이프, 타임 랭킹(`matchranking`·`RankingService`), 이름·HUD 1위·TimeUp 제출, TimeUp 연출, HowToPlay(?)·스크롤 레이아웃·다국어·웹/랭킹 디렉토리 분리.
- **2026-04-04:** `START_HERE.md` / `jewel_match_execution_checklist.md` 도입. 웹에서 평점 메뉴·타이틀 자동 리뷰 비활성화 반영.
- **2026-04-15:** 웹 오디오 정책 단순화. `SoundManager`에서 웹 전용 SFX 풀, `mediaPlayer` 분기, 0볼륨 prime, 드래그 시작 보조 unlock 제거. 현재 기준은 앱 루트 첫 포인터다운의 `unlockForWeb()` 1회 + `_pendingBgm` 재생 보류만 유지.
- **2026-04-16:** 렌더링 최적화 진행. `MatchBoardRenderer` 보드 크롬/슬롯 `ui.Picture` 캐싱, 낙하·리필 시에만 보드 클립, `MatchGameHud` 텍스트/페인트 캐싱, 개발 모드 FPS 오버레이 추가. 파티클은 입자 수·퍼짐 반경·수명·글로우를 줄여 과한 GPU 비용을 완화.
- **2026-04-16:** 보석 에셋 구조 변경. `Juwel.png` → `Jewel.png`로 교체하고 프레임 크기를 `128×128` 기준으로 축소. `Special.png` 3프레임(`col / row / bomb`) 도입. 하이퍼 보석은 `Jewel.png` 2번째 프레임을 그대로 사용하며, 기존 `ColorFilter.matrix` 기반 하이퍼 틴트 경로는 제거. 튜토리얼은 공용 `SpriteSheetFrame`으로 원본 픽셀 기준 프레임 크롭을 사용.

---

## 7. 한 줄 요약

**다음 세션은 `START_HERE.md` → 체크리스트 → `game_flow` / `code-flow-analysis` 순으로 읽고, Web은 `base-href`·에셋 경로·랭킹 API URL·NAS 배포 분리, 네이티브는 스토어·오디오·문서 동기화를 우선 보면 된다.**
