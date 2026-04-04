# Jewel Match (jewelmatch)

Flame 기반 **8×8 매치-3** 퍼즐 (`com.cheng80.jewelmatch`).

## 기술 스택

- **Flutter** — UI·라우팅
- **Flame** `^1.35` — 게임 루프·렌더
- **GoRouter** — 화면 전환
- **easy_localization** — ko / en / ja / zh-CN / zh-TW
- **flame_audio** — BGM·SFX
- **get_storage** — 설정·베스트 스코어
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

상세 실행 순서·파일 역할: [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md)  
규칙·플로우 요약: [`docs/game_flow.md`](docs/game_flow.md)

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
| Web | `flutter build web --release --base-href "/jewelmatch/"` |

Web 배포·서브패스 설정: [`docs/web_build.md`](docs/web_build.md)  
스토어용 정적 페이지(소개·약관): [`docs/web/README.md`](docs/web/README.md)

## 문서

| 문서 | 내용 |
|------|------|
| [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md) | 초기화·레이아웃·Flame 계층 |
| [`docs/game_flow.md`](docs/game_flow.md) | 매치-3 플레이 흐름 요약 |
| [`docs/web_build.md`](docs/web_build.md) | Web 빌드·배포 |
| [`docs/STORE_METADATA_PLAY_APPSTORE_2026.md`](docs/STORE_METADATA_PLAY_APPSTORE_2026.md) | 스토어 메타데이터 초안 |
