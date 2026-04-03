# Jewel Match 코드 흐름 분석

이 문서는 현재 프로젝트의 구조와 실행 흐름을 정리한 분석본이다.  
목표는 `lib/main.dart`를 시작점으로 앱이 어떻게 올라오고, 어떤 위젯과 Flame 게임 객체가 어떤 순서로 연결되는지 빠르게 따라갈 수 있게 정리하는 것이다.  
게임 코어는 **8×8 매치-3** (`MatchBoardGame` / `MatchBoardLogic`)이다.

## 1. 프로젝트 구조 요약

이 프로젝트는 크게 4개 층으로 나뉜다.

1. 앱 시작/부트스트랩
   - `lib/main.dart`
   - `lib/app.dart`
2. 라우팅/화면 전환
   - `lib/router.dart`
   - `lib/views/title_view.dart`
   - `lib/views/game_view.dart`
   - `lib/views/setting_view.dart`
3. 게임 코어
   - `lib/game/match_board_game.dart`
   - `lib/game/match_board_logic.dart`
   - `lib/game/components/match_board_renderer.dart`
   - `lib/game/components/match_game_hud.dart`
   - `lib/game/components/space_bg.dart`
4. 공통 서비스
   - `lib/resources/sound_manager.dart`
   - `lib/services/game_settings.dart`
   - `lib/utils/storage_helper.dart`

핵심 구조는 다음과 같다.

```text
Flutter App Shell
├─ main.dart
├─ App(MaterialApp.router)
├─ GoRouter
│  ├─ TitleView
│  ├─ GameView
│  └─ SettingView
└─ GameView 내부
   └─ Flame GameWidget
      └─ MatchBoardGame
         ├─ camera.backdrop
         │  └─ SpaceBg
         ├─ camera.viewport
         │  └─ MatchGameHud
         │     └─ 일시정지 / 스코어·콤보·타임 UI
         └─ world
            └─ MatchBoardRenderer (보석 스프라이트)
```

보드 데이터·매치/낙하/스왑 로직은 `MatchBoardLogic`에 있고, 렌더만 `MatchBoardRenderer`가 담당한다.

## 2. main.dart부터 시작하는 전체 실행 순서

### 2-1. 큰 흐름

```text
main()
├─ WidgetsFlutterBinding.ensureInitialized()
├─ EasyLocalization.ensureInitialized()
├─ StorageHelper.init()
├─ InAppReviewService.saveFirstLaunchDateIfNeeded()
├─ SoundManager.preload()
├─ _applyKeepScreenOn()
└─ runApp(EasyLocalization(child: App()))
   └─ App.build()
      └─ MaterialApp.router(...)
         └─ appRouter
            └─ initialLocation = "/"
               └─ TitleView.build()
                  ├─ _StarryBackground
                  ├─ "심플" -> context.go("/game?mode=simple")
                  ├─ "타임" -> context.go("/game?mode=timed")
                  └─ "설정" -> context.push("/setting")
                     └─ SettingView
```

게임 시작 시 흐름은 다음과 같다.

```text
GameView.initState()
└─ SoundManager.playBgm(AssetPaths.bgmMain)

GameView.build()
└─ GameWidget<MatchBoardGame>.controlled(...)
   └─ gameFactory()
      └─ MatchBoardGame(gameMode, safeAreaPadding) + setLocaleStrings(...)
         └─ MatchBoardGame.onLoad()
            ├─ await super.onLoad()
            ├─ camera.viewfinder anchor = topLeft, position = (0,0)
            ├─ camera.backdrop.add(SpaceBg())
            ├─ camera.viewport.add(MatchGameHud(...))
            └─ world.add(MatchBoardRenderer(logic: board))
         (이후 첫 onGameResize에서 layoutRef 확정)
            └─ _syncLayout()
                ├─ board.setGeometry(...)
                └─ 최초 1회만 board.generateFreshBoard()
```

카운트다운 오버레이는 매치-3 버전에서는 사용하지 않는다. 입력 가능 여부는 `MatchBoardLogic.state`와 오버레이(일시정지/노무브/타임업)로 제한된다.

### 2-2. 실제 역할 기준 해석

- `main.dart`
  - 앱 실행 전 필요한 전역 초기화를 담당한다.
- `app.dart`
  - `MaterialApp.router`, 테마, 다국어 설정을 담는 앱 루트다.
- `router.dart`
  - 어떤 경로가 어떤 화면을 여는지 정의한다.
- `title_view.dart`
  - 모드 선택과 설정 이동을 담당하는 첫 진입 화면이다.
- `game_view.dart`
  - Flame 게임을 Flutter 위젯 트리에 마운트하고 오버레이를 연결한다.
- `match_board_game.dart`
  - Flame 게임 셸: 레이아웃·타이머(Simple/Timed)·오버레이 제어·첫 레이아웃에서 보드 시드.
- `match_board_logic.dart`
  - 8×8 보드, 스왑/매치/낙하/리필, 점수·콤보.

## 3. 파일별 역할 정리

### 3-1. `lib/main.dart`

앱의 진입점이다.

- Flutter 엔진 초기화
- 다국어 초기화
- 로컬 저장소 초기화
- 인앱 리뷰 기준일 저장
- 사운드 프리로드
- 화면 꺼짐 방지 설정 적용
- `App` 실행

즉, 게임 화면을 만드는 파일이 아니라 앱이 돌아갈 환경을 먼저 준비하는 파일이다.

### 3-2. `lib/app.dart`

`MaterialApp.router`를 생성하는 앱 루트다.

- 앱 제목 설정
- 디버그 배너 제거
- 다국어 delegate / locale 연결
- 기본 다크 테마 설정
- `appRouter` 주입
- 웹에서 첫 포인터 입력 시 `SoundManager.unlockForWeb()` 호출

### 3-3. `lib/router.dart`

라우팅 테이블이다.

- `/` -> `TitleView`
- `/game` -> `GameView`
- `/setting` -> `SettingView`

`/game`은 query parameter `mode`를 읽는다.

- `mode=0`
  - 숫자 모드
- `mode=1`
  - 알파벳 모드

즉 같은 게임 화면을 재사용하되, 모드만 바꾸는 구조다.

### 3-4. `lib/views/title_view.dart`

첫 진입 화면이다.

- 우주 배경 렌더링
- 타이틀 / 부제목 표시
- 심플 모드 버튼 → `context.go('.../game?mode=simple')`
- 타임 모드 버튼 → `context.go('.../game?mode=timed')`
- 설정 버튼 → `context.push('/setting')`
- 하단 버전 텍스트 표시

### 3-5. `lib/views/game_view.dart`

Flame을 Flutter에 연결하는 핵심 화면이다.

- `initState()`
  - 게임 BGM 재생 시작
- `build()`
  - `GameWidget<MatchBoardGame>.controlled(...)` 생성
  - `gameFactory`로 `MatchBoardGame` 인스턴스 생성 및 `setLocaleStrings`로 HUD 문구 주입
  - `overlayBuilderMap`으로 `PauseMenu`, `NoMoves`, `TimeUp` 연결

또한 웹에서는 전체 화면에 게임을 직접 늘리지 않고:

- 세로형 기준 크기 `390×750`
- 최소/최대 스케일 범위 적용
- 중앙 정렬된 게임 프레임
- 남는 좌우는 우주 배경

구조로 처리한다.

### 3-6. `lib/game/match_board_game.dart`

Flame 게임 셸이다.

- `FlameGame` 상속
- `MatchBoardLogic`를 생성자에서 생성(타이머·빈 격자 준비), `onLoad`보다 먼저 올 수 있는 리사이즈에도 안전
- `onLoad`: `SpaceBg` → `MatchGameHud`(viewport) → `MatchBoardRenderer`(world) 순 추가 (1~50 시절과 동일한 레이어 순서 철학)
- `onGameResize` → `_syncLayout`: `layoutRef`·타일 크기 유효성 검사 후 `setGeometry`, **`_boardSeededFromLayout`가 false일 때만** `generateFreshBoard()` (이후 리사이즈는 idle 시 좌표 스냅)
- Simple/Timed 모드별 타이머·베스트 저장 연동

### 3-7. `lib/game/match_board_logic.dart`

보드 규칙과 상태 머신이다.

- 8×8 `cells`, 스왑·매치 판정·제거·낙하·리필
- `setGeometry`: `cells` 크기 불일치 시 조기 반환으로 RangeError 방지

### 3-8. `lib/game/components/match_board_renderer.dart`

`MatchBoardLogic`의 보석을 그리는 `world` 컴포넌트.

### 3-9. `lib/game/components/match_game_hud.dart`

상단 패널(스코어·베스트·콤보·타임)·일시정지 버튼. `camera.viewport`에 올린다.

### 3-10. `lib/game/components/space_bg.dart`

배경 컴포넌트다.

- 우주 배경 그라데이션
- 별 위치 생성
- 별 반짝임 갱신
- 화면 전체 배경 렌더링

이 컴포넌트는 `camera.backdrop`에 올라간다.

### 3-11. 설정/사운드/저장소

- `game_settings.dart`
  - 설정값 getter / setter 제공
  - 베스트 스코어 저장
- `sound_manager.dart`
  - BGM / 효과음 / 웹 unlock 처리
- `storage_helper.dart`
  - `GetStorage` 래퍼

구조는 다음과 같다.

```text
UI / Game
└─ GameSettings
   └─ StorageHelper
      └─ GetStorage
```

## 4. 게임 규칙과 보드 배치

### 4-0. 현재 매치-3 (8×8)

- 인접 보석 두 칸을 스왑해 3개 이상 직선 매치를 만든다.
- 매치 제거 → 중력 낙하 → 빈 칸 리필. 연쇄 시 콤보.
- **Simple**: 제한 시간 없음. 움직일 수 없을 때 `NoMoves` 등 종료/UI 처리.
- **Timed**: 라운드 시간(예: 120초) 종료 시 `TimeUp` 등.
- 베스트 스코어는 모드별 키(`best_match_simple` / `best_match_timed`)로 저장.

보드 픽셀 배치는 `MatchBoardGame._syncLayout`에서 `layoutRef`로 타일 크기를 구하고, `MatchBoardLogic.setGeometry`로 각 보석의 목표 좌표를 갱신한다. **초기 보석 채우기**는 레이아웃이 유효해진 뒤 **한 번만** `generateFreshBoard()`로 수행한다.

---

> **보관:** 아래 **4-1 ~ 4-5**는 과거 **1~50 / 알파벳** 그리드 모드 분석 원문이다. 구현 파일은 제거되었으나 좌표·셔플 개념 참고용으로 남긴다.

### 4-1. (레거시) 게임 규칙

- 숫자 모드
  - `1`부터 `50`까지 순서대로 누른다.
- 알파벳 모드
  - `A`부터 `Z`까지 순서대로 누른다.
- 정답을 누르면
  - 큐브가 회전하며 사라진다.
  - 다음 목표 값으로 진행한다.
- 오답을 누르면
  - 큐브가 좌우로 흔들린다.
  - 진행 상태는 유지된다.
- 5초 동안 정답을 누르지 못하면
  - 현재 정답 큐브가 깜박여 힌트를 준다.
- 마지막 값을 누르면
  - 게임이 종료된다.
  - 결과 시간과 베스트 스코어를 보여준다.

즉 사용자는 "현재 힌트에 적힌 값"을 계속 찾아서 순서대로 제거해야 한다.

### 4-2. 1차 / 2차 테이블 개념

현재 게임은 전체 값을 한 번에 25칸에 다 올리지 않는다.

```text
숫자 모드
├─ 1차 테이블: 1 ~ 25
└─ 2차 테이블: 26 ~ 50

알파벳 모드
├─ 1차 테이블: A ~ Y (1 ~ 25에 대응)
└─ 2차 테이블: Z (26에 대응)
```

초기 화면에는 항상 1차 테이블만 25칸에 셔플되어 보인다.  
이후 정답을 맞출 때마다 같은 칸에 2차 테이블 값이 순서대로 보충된다.

### 4-3. 실제 배치 절차

그리드를 준비할 때 순서는 다음과 같다.

```text
_prepareGrid()
├─ currentNumber = 1
├─ 타이머 / 힌트 상태 초기화
├─ shuffledFirst = shuffle(1차 테이블)
├─ shuffledSecond = shuffle(2차 테이블)
└─ _createGrid()
   ├─ 5×5 칸 인덱스 0~24 순회
   ├─ 각 칸에 shuffledFirst[i]를 배치
   └─ CubeButton(gridIndex = i) 생성
```

즉 처음 25칸은 모두 1차 테이블 값이다.

```text
gridIndex 0  -> shuffledFirst[0]
gridIndex 1  -> shuffledFirst[1]
...
gridIndex 24 -> shuffledFirst[24]
```

### 4-4. 정답 큐브가 사라진 뒤 교체 방식

정답 큐브를 누르면 그 칸은 그냥 비워지는 것이 아니라, 2차 테이블이 남아 있으면 새 값이 채워진다.

```text
정답 탭
├─ cube.animateCorrect()
└─ onComplete
   ├─ if (_nextSecondIndex < shuffledSecond.length)
   │  ├─ nextId = shuffledSecond[_nextSecondIndex]
   │  ├─ _nextSecondIndex++
   │  └─ 같은 gridIndex 위치에 새 CubeButton 생성
   └─ else
      └─ 더 채울 값이 없으므로 빈 칸 유지
```

중요한 점은 다음과 같다.

- 2차 큐브는 "정답 순서"로 채워지는 것이 아니다.
- 2차 큐브도 별도 셔플된 순서로 공급된다.
- 다만 사용자가 눌러야 하는 목표 값 `currentNumber`는 항상 순차 증가한다.

즉 화면에 새로 등장하는 값의 위치와 등장 순서는 랜덤이지만,  
사용자가 눌러야 하는 값 자체는 항상 순서대로 정해져 있다.

### 4-5. 5×5 배치 수식

그리드는 safe area 안쪽에서 들어갈 수 있는 최대 정사각형 영역을 구한 뒤, 그 안에 5×5로 배치한다.

```text
layoutRef = min(안전영역 내부 가용 너비, 안전영역 내부 가용 높이)
cubeSize  = layoutRef / (5 + spacingRatio * 6)
spacing   = cubeSize * spacingRatio
step      = cubeSize + spacing
```

각 큐브의 좌표는 다음처럼 계산한다.

```text
row = gridIndex ~/ 5
col = gridIndex % 5

x = gridLeft + col * step + cubeSize / 2
y = gridTop  + spacing + row * step + cubeSize / 2
```

즉:

- 큐브 위치는 `gridIndex`만 알면 다시 계산할 수 있다.
- 창 크기가 바뀌어도 `gridIndex`를 기준으로 같은 칸 위치를 재계산한다.
- 그래서 리사이즈 시에도 "배치 순서"는 유지되고, 화면상의 크기와 좌표만 다시 맞춘다.

## 5. 게임 화면 진입 뒤 Flame 내부 생성 순서

`GameView`에서 `GameWidget.controlled`가 만들어진 다음, `gameFactory`가 `MatchBoardGame`을 생성한다.  
Flame이 `MatchBoardGame.onLoad()`를 호출한다.

`onLoad()`의 실제 순서는 다음과 같다 (1~50 시절과 동일한 **backdrop → viewport → world** 레이어 순서).

```text
MatchBoardGame.onLoad()
├─ await super.onLoad()
├─ camera.viewfinder.anchor = Anchor.topLeft
├─ camera.viewfinder.position = (0, 0)
├─ camera.backdrop.add(SpaceBg())
├─ _hud = MatchGameHud(onPausePressed: ...)
├─ camera.viewport.add(_hud)
└─ world.add(MatchBoardRenderer(logic: board))
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
2. 배경을 `backdrop`에 올린다.
3. HUD를 `viewport`에 올린다 (`MatchGameHud`).
4. 보드를 `world`에 올린다 (`MatchBoardRenderer`).
5. **보드 데이터 채우기**는 `onLoad` 직후가 아니라, **첫 유효 레이아웃**에서만 수행한다 (리사이즈만 반복되는 환경에서도 안전).

즉 현재 게임 구조는 다음과 같다.

```text
MatchBoardGame
├─ camera.backdrop
│  └─ SpaceBg
├─ camera.viewport
│  └─ MatchGameHud
└─ world
   └─ MatchBoardRenderer
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

템플릿과 다른 점은 다음과 같다.

- 현재는 `world 중심 원점`을 쓰지 않는다.
- `camera.viewfinder.anchor = Anchor.topLeft`로 맞춘다.
- 그래서 `world`와 `viewport` 모두 사실상 화면 상단 기준 좌표를 공유한다.
- 다만 의미상으로는 여전히 구분한다.
  - `world`
    - 게임 오브젝트
  - `viewport`
    - 화면 고정 UI

### 5-1. safe area를 어떻게 쓰는가

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

### 5-2. HUD와 그리드 배치 기준

상단 배치 기준:

```text
panelCenterY = safeArea.top + gap + panelHeight / 2
hintCenterY  = safeArea.top + 2*gap + panelHeight + hintRadius
gridTopY     = safeArea.top + gap + panelHeight + gap + hintRowHeight + gap
```

그리드 크기 기준:

```text
availW  = safeContentWidth
maxGridH = 화면높이 - safeArea.bottom - gridTopY - gap
layoutRef = min(availW, maxGridH)
```

즉 현재 기준은:

- 상단 HUD는 safe area 아래에 둔다.
- 좌우 버튼과 힌트는 safe area 안쪽에 둔다.
- 그리드는 safe area 안쪽 직사각형에 들어가는 최대 정사각형으로 계산한다.

## 7. 게임 진행 흐름

### 7-1. 플레이 중 매 프레임

```text
MatchBoardGame.update(dt)
├─ Timed 모드일 때 timeRemaining 감소, HUD 반영
├─ board.update(dt)  // 낙하·매치 애메이션·상태 전이
└─ 종료 조건 시 오버레이 표시 (NoMoves / TimeUp)
```

### 7-2. 입력 (탭 / 드래그)

```text
MatchBoardRenderer 또는 게임 레벨 제스처
└─ MatchBoardLogic 에 스왑 요청
   ├─ 유효 스왑 → 매치 처리 파이프라인
   └─ 무효 → 스왑 되돌림
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

- **NoMoves**: 더 이상 유효한 스왑이 없을 때 오버레이. 베스트 갱신은 모드별 점수 저장 API 사용.
- **TimeUp**: Timed 모드 시간 소진 시 오버레이.

과거 **Clear** 오버레이(1~50 클리어)는 현재 빌드에 없다.

## 9. 웹 레이아웃 정책

웹에서는 게임이 전체 브라우저에 맞춰 자유롭게 늘어나지 않는다.  
현재 정책은 "세로형 모바일 게임 프레임"을 중앙에 유지하는 것이다.

```text
브라우저 전체
├─ 바깥 배경 = StarryBackground()
└─ 중앙 게임 프레임
   ├─ 기준 크기 = 390 x 750
   ├─ fittedScale = min(가로비, 세로비)
   ├─ 최소 스케일 = 0.83
   ├─ 최대 스케일 = 1.5
   └─ SizedBox(width: 390*scale, height: 750*scale)
```

의미는 다음과 같다.

- 큰 화면
  - 게임 프레임은 최대 스케일까지 커진다.
- 작은 화면
  - 프레임이 전체적으로 줄어든다.
- 남는 좌우 영역
  - 우주 배경만 확장된다.

즉 웹에서도 "세로형 모바일 게임처럼 보이는 느낌"을 유지하려는 구조다.

## 10. 화면별 요약

### 9-1. TitleView

- 전체 화면 우주 배경
- SafeArea 안에 제목/버튼/버전 텍스트 배치
- 메뉴 BGM 재생

### 9-2. SettingView

- `AppBar`
- SafeArea 안의 스크롤 설정 목록
- BGM / SFX / 화면 꺼짐 방지 / 언어 설정

### 9-3. GameView

- 앱에서는 전체 화면 게임
- 웹에서는 중앙 세로 프레임 게임
- 오버레이:
  - PauseMenu
  - NoMoves
  - TimeUp

## 11. 정리

현재 프로젝트의 핵심은 다음 세 가지다.

1. 앱 셸 구조는 Flutter 표준 방식 유지
   - `main -> App -> Router -> View`
2. 게임 내부는 Flame 레이어를 명확히 분리
   - `backdrop / viewport / world`
3. 좌표계는 top-left 기반 화면형 레이아웃으로 단순화
   - safe area는 침범 금지 기준으로만 사용

즉 이 프로젝트는 템플릿과 같은 출발점에서 왔지만, 현재는 다음에 더 가깝다.

```text
모바일 세로형 매치-3 게임
+ Flutter 라우팅 셸
+ Flame 기반 렌더링
+ backdrop / viewport(HUD) / world(보드) 분리
+ 첫 유효 레이아웃에서만 보드 시드
+ safe area 기반 배치
+ 웹에서는 중앙 세로 프레임 유지
```

다음에 구조를 더 발전시킬 때도 아래 원칙을 유지하면 파악이 쉽다.

- 배경은 `backdrop`
- 게임 오브젝트는 `world`
- 화면 고정 UI는 `viewport`
- 오버레이 팝업은 Flutter overlay
- safe area는 "게임 요소 배치 기준"으로만 사용
