# Jewel Match (jewelmatch)

Flame 엔진 기반 퍼즐 게임 (`com.cheng80.jewelmatch`).

## 기술 스택

- **Flutter** - UI 프레임워크
- **Flame** `v1.35.1` - 게임 엔진
- **GoRouter** - 화면 라우팅
- **easy_localization** - 다국어 (ko, en, ja, zh-CN, zh-TW)
- **flame_audio** - BGM·효과음
- **get_storage** - 로컬 저장 (설정, 베스트 스코어)
- **wakelock_plus** - 화면 켜짐 유지

---

## 다국어

- **지원 언어**: 한국어(ko), 영어(en), 일본어(ja), 중국어 간체(zh-CN), 중국어 번체(zh-TW)
- **번역 파일**: `assets/translations/*.json`
- 앱 이름은 Android `strings.xml`, iOS `InfoPlist.strings`로 플랫폼별 표시됩니다.

---

## 앱 구조

Flutter 레이어: 라우팅, 화면(뷰), 리소스, 설정 등 앱 전반의 구조를 담당합니다.

### 디렉터리 구조

```
lib/
├── main.dart                 # 앱 진입점 (SoundManager.preload 등)
├── app.dart                  # MaterialApp.router 설정
├── app_config.dart           # 상수 (앱 제목, 라우트 경로, StorageKeys)
├── router.dart               # GoRouter 라우팅 설정
├── resources/                # 리소스
│   ├── asset_paths.dart      #   에셋 경로 상수
│   └── sound_manager.dart    #   BGM·효과음 재생
├── services/
│   └── game_settings.dart    #   게임 설정 (볼륨, 베스트 스코어)
├── utils/
│   └── storage_helper.dart  #   GetStorage 래퍼 (로컬 저장)
└── views/                    # Flutter 뷰 (화면)
    ├── title_view.dart       #   타이틀 화면 (모드 선택, 설정 진입)
    ├── game_view.dart        #   게임 화면 (GameWidget + 오버레이)
    └── setting_view.dart     #   설정 화면 (BGM/SFX 볼륨, 음소거, 화면 꺼짐 방지)
```

### 라우팅

| 경로 | 화면 | 설명 |
|------|------|------|
| `/` | TitleView | 타이틀 화면 (진입점) |
| `/game?mode=0` | GameView | 숫자 모드 (1~50) |
| `/game?mode=1` | GameView | 알파벳 모드 (A~Z) |
| `/setting` | SettingView | 설정 화면 |

### 뷰 역할

| 뷰 | 역할 |
|----|------|
| **TitleView** | 모드 선택(숫자/알파벳), 설정 버튼, 메뉴 BGM 재생 |
| **GameView** | `GameWidget`에 `OneToFiftyGame` 마운트, Countdown/PauseMenu/Clear 오버레이 빌더 |
| **SettingView** | BGM/SFX 볼륨 슬라이더, 음소거 스위치, 화면 꺼짐 방지 |

---

## 게임 로직

Flame 레이어: 게임 상태, 규칙, 컴포넌트 렌더링 등 게임 자체의 로직을 담당합니다.

### 디렉터리 구조

```
lib/game/
├── one_to_fifty_game.dart    # FlameGame 메인 (규칙, 상태, 이벤트)
└── components/
    ├── space_bg.dart         # 우주 배경 (별 깜빡임)
    ├── grid_bg.dart          # 그리드 배경
    ├── game_hud.dart         # 상단 HUD (타임, 힌트, 일시정지, 베스트 스코어)
    └── cube_button.dart      # 5×5 그리드의 개별 큐브 (탭, 애니메이션)
```

### 게임 흐름

1. **카운트다운** → 3, 2, 1, Start 후 게임 시작
2. **1차 테이블** → 1\~25(또는 A~Y) 셔플 후 5×5 그리드 배치
3. **플레이** → `currentNumber`에 맞는 큐브 탭 시 정답 처리
4. **2차 테이블** → 정답 큐브 자리에 26~50(또는 Z) 셔플 후 순서대로 등장
5. **클리어** → 50(또는 Z) 탭 시 결과 화면, 베스트 스코어 갱신

### 주요 클래스 역할

| 클래스 | 역할 |
|--------|------|
| **OneToFiftyGame** | 게임 상태(currentNumber, elapsedTime), 셔플·그리드 생성, 탭 이벤트, 라이프사이클(백그라운드 일시정지) |
| **CubeButton** | 숫자/알파벳 표시, 정답 시 회전·페이드아웃, 오답 시 흔들림, 힌트 시 깜빡임 |
| **GameHud** | 타임 패널, 힌트 말풍선, 일시정지 버튼, 베스트 스코어 표시 |

### 상세 플로우

`docs/game_flow.md`에 Mermaid 플로우차트로 정리되어 있습니다.

---

## 조작법

- **화면 탭** - 해당 큐브 선택 (정답/오답 처리)
- **일시정지 버튼** - PauseMenu 오버레이
- **백그라운드 진입** - 자동 일시정지 (BGM 포함)

## 실행

```bash
flutter run
```

플랫폼 지정: `flutter run -d chrome` (웹), `flutter run -d macos` (macOS) 등

## 빌드

| 플랫폼 | 명령어 |
|--------|--------|
| Android/iOS | `flutter build apk` / `flutter build ios` |
| Web | `flutter build web --release --base-href "/jewelmatch/"` |

Web 빌드 시 용량 줄이기: `--tree-shake-icons --no-source-maps` 옵션 추가.  
정적 호스팅 배포 시 `jewelmatch` 폴더 생성 후 `build/web/*` 복사.  
→ 상세: [`docs/web_build.md`](docs/web_build.md)

## 문서

- [`docs/game_flow.md`](docs/game_flow.md) - 게임 플로우 Mermaid 차트
- [`docs/web_build.md`](docs/web_build.md) - Web 빌드·배포 가이드
