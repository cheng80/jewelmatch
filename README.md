# Stone Match (stonematch)

Flame 기반 **8×8 매치-3** 퍼즐 (`com.cheng80.stonematch`).

## 기술 스택

- **Flutter** — UI·라우팅
- **Flame** `^1.35` — 게임 루프·렌더
- **GoRouter** — 화면 전환
- **easy_localization** — ko / en / ja / zh-CN / zh-TW
- **flame_audio** — BGM·SFX
- **shared_preferences** — 설정·베스트 스코어
- **wakelock_plus** — 화면 켜짐 유지

---

## 다국어

- 번역: `assets/translations/*.json`
- 플랫폼 앱 이름: Android `strings.xml`, iOS `InfoPlist.strings`

---

## 앱 구조

### 디렉터리 (요약)

```text
lib/
├── main.dart
├── app.dart                    # MaterialApp.router, 테마(buildAppTheme)
├── app_config.dart             # 앱명, StorageKeys, RoutePaths
├── router.dart
├── theme/
│   ├── app_theme.dart          # 전역 폰트·Jewel Candy Lumina 색
│   └── jewel_candy_lumina_theme.dart
├── resources/
│   ├── asset_paths.dart
│   └── sound_manager.dart
├── services/
│   └── game_settings.dart
├── utils/
│   └── storage_helper.dart
├── widgets/
│   └── starry_background.dart  # 타이틀·웹 게임 바깥 배경
├── views/
│   ├── title_view.dart
│   ├── game_view.dart          # GameWidget + 오버레이
│   └── setting_view.dart
└── game/
    ├── jewel_game_mode.dart    # simple / timed
    ├── match_board_game.dart   # FlameGame 셸
    ├── match_board_logic.dart  # 보드·매치·스왑
    └── components/
        ├── space_bg.dart
        ├── match_game_hud.dart
        └── match_board_renderer.dart
```

### 라우팅

| 경로 | 화면 | 설명 |
|------|------|------|
| `/` | TitleView | 타이틀·모드 선택 |
| `/game?mode=simple` | GameView | 심플(무제한) |
| `/game?mode=timed` | GameView | 타임 어택 |
| `/setting` | SettingView | 설정 |

`mode` 생략 시 기본은 심플 (`JewelGameMode.fromQuery`).

---

## 게임 개요

- **심플**: 제한 시간 없이 플레이.
- **타임**: 정수 초 보상(배율 적용·반올림). 설계상 양수 보상이면 **최소 1초**, 상한 **초과분 제외**.
- 스왑·매치·낙하·콤보·특수 보석 로직은 `MatchBoardLogic`, 그리기는 `MatchBoardRenderer` + HUD는 `MatchGameHud`.

상세 실행 순서·파일 역할: [`docs/03_TECH_SPEC.md`](docs/03_TECH_SPEC.md)  
규칙·플로우 요약: [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md)

---

## 실행

```bash
flutter pub get
flutter run
```

예: `flutter run -d chrome`, `flutter run -d macos`

## 빌드

| 플랫폼 | 명령 |
|--------|------|
| Android / iOS | `flutter build apk` / `flutter build ios` |
| Web | `flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn && dart run tools/patch_flutter_web_deprecations.dart` |

Web 배포·서브패스 설정: [`docs/03_TECH_SPEC.md`](docs/03_TECH_SPEC.md)

## Apps in Toss 광고 테스트

Node.js 24 이상 환경을 권장한다.

```bash
npm install
npm run dev:ads
npm run test:ads
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
```

Chrome에서는 모의 보상과 테스트 배너를 확인하고, 공식 테스트 광고는 생성된 `.ait`를 콘솔 QR로 토스 앱에서 확인한다. 상세 정책과 운영 광고 그룹 설정은 [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md)를 따른다.

## 문서

정본은 [`docs/README.md`](docs/README.md)다. 이전 주제별 문서는 [`archive/docs/`](archive/docs/)에 있다.

| 문서 | 내용 |
|------|------|
| [`docs/README.md`](docs/README.md) | 문서 맵, 이관 단계 |
| [`docs/AGENTS.md`](docs/AGENTS.md) | 작업 진입, 읽기 순서 |
| [`docs/progress/PROJECT_STATUS.md`](docs/progress/PROJECT_STATUS.md) | 현재 상태와 작업 |
| [`docs/progress/HANDOFF.md`](docs/progress/HANDOFF.md) | 인수인계 |
| [`docs/01_PRODUCT_SPEC.md`](docs/01_PRODUCT_SPEC.md) | 제품 규칙, 광고, 스토어 문구 |
| [`docs/02_UI_UX.md`](docs/02_UI_UX.md) | 화면, 디자인 원칙 |
| [`docs/03_TECH_SPEC.md`](docs/03_TECH_SPEC.md) | 구조, API, 웹 빌드 |
| [`docs/04_DEVELOPMENT_WORKFLOW.md`](docs/04_DEVELOPMENT_WORKFLOW.md) | 테스트, 배포, 릴리즈 절차 |
| [`docs/plans/PLAN-001-mobile-web-audio-fps.md`](docs/plans/PLAN-001-mobile-web-audio-fps.md) | 모바일 웹 성능 계획 |
