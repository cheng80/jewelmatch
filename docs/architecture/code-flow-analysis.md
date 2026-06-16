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
            ├─ ParticlePool
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
            ├─ ParticlePool(world)
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
- 웹에서 첫 포인터다운 시 `SoundManager.unlockForWeb()` 호출
- `unlockForWeb()`는 웹 오디오 잠금을 풀고, 잠금 전 요청된 BGM이 있으면 재생한다
- 현재 웹 기준점에서는 `SoundManager`가 웹 SFX `AudioPool`을 유지하고, `unlockForWeb()`에서 re-prime을 수행한다

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
- `bomb`/`star`/`supernova`는 일반 보석 위에 독립 오버레이 PNG를 얹는다.
- 하이퍼 보석은 `Jewel_Arcane.png`의 2번째 프레임(인덱스 1)을 사용한다.
- 현재 스프라이트 기준 셀 크기는 모두 `128×128`.
- 일반 보석에는 현재 렌더러의 `ColorFilter.matrix`가 적용되어 전체 톤을 맞춘다.

현재 렌더 에셋 매핑은 다음과 같다.

| 용도 | 파일 | 프레임/규칙 |
|:---|:---|:---|
| 일반 보석 | `assets/images/sprites/Jewel_Arcane.png` | 7프레임, 각 `128×128` |
| 하이퍼 보석 | `assets/images/sprites/Jewel_Arcane.png` | 2번째 프레임 |
| Legacy 특수 보석 `col` | `assets/images/sprites/Special_Arcane.png` | 1번째 프레임 |
| Legacy 특수 보석 `row` | `assets/images/sprites/Special_Arcane.png` | 2번째 프레임 |
| Bomb 특수 보석 `bomb` | `Jewel_Arcane.png` + `flame_overlay.png` | 보석 색 + 불꽃 오버레이 |
| Star 특수 보석 `star` | `Jewel_Arcane.png` + `star_overlay.png` | 보석 색 + 별 오버레이 |
| Supernova 특수 보석 `supernova` | `Jewel_Arcane.png` + `supernova_overlay.png` | 보석 색 + 초신성 오버레이 |

참고:

- `AssetPaths.jewelSpriteSheet` → `sprites/Jewel_Arcane.png`
- `AssetPaths.specialSpriteSheet` → `sprites/Special_Arcane.png`
- `AssetPaths.flameOverlay` / `starOverlay` / `supernovaOverlay` → 독립 오버레이 PNG
- 튜토리얼 오버레이(`HowToPlayOverlay`)와 `SpriteSheetFrame`도 같은 원본 픽셀 기준(`128×128`) 프리뷰 원칙을 사용한다.
- 생성 우선순위, 발동 조건, 연쇄 처리, Bejeweled 참고 룰과의 차이는 [`special_gems_rules.md`](special_gems_rules.md)에 별도로 정리한다.

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
- 현재 튜토리얼 프리뷰는 `Jewel_Arcane.png`, `Special_Arcane.png`와 독립 오버레이 PNG를 사용하며, `128×128` 프레임 경계를 화면 비율이 아니라 원본 픽셀 기준으로 유지한다

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
├─ _particlePool = ParticlePool(world)
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
      + ParticlePool / SpecialEffectPool
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
   └─ drag → MatchBoardGame.handleBoardSwipe()
      └─ MatchBoardLogic.trySwap()
         ├─ hyper 또는 non-hyper 특수 조합 스왑 → resolveSpecialSwap()
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
