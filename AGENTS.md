# AGENTS.md

## Cursor Cloud specific instructions

### Overview
Stone Match는 Flutter + Flame 기반 8×8 매치-3 퍼즐 게임이다. 기본 명령어는 `README.md` 참조.

### Communication
- 항상 한국어로 대화한다.

### Flutter SDK
- 현재 로컬 검증 기준은 Flutter `3.44.0` (Dart `3.12.0`)이다.
- Flutter/Dart 실행 파일은 현재 셸의 `PATH`에서 해석한다. 검증 전 `command -v flutter`와 `command -v dart`가 기대한 SDK를 가리키는지 확인한다.
- Android SDK는 `/Users/cheng80/Library/Android/sdk`에 설치되어 있다.

### 주요 명령어
| 작업 | 명령어 |
|------|--------|
| 의존성 설치 | `flutter pub get` |
| 정적 분석 | `flutter analyze` |
| 테스트 | `flutter test` |
| 웹 빌드 | `flutter build web --release` |
| 웹 개발 서버 | `flutter run -d chrome` 또는 빌드 후 `python3 -m http.server 8080 --directory build/web` |
| Android 빌드 | `flutter build apk --release` 또는 `flutter build appbundle --release` |
| iOS 빌드 | `flutter build ipa --release` |

### 주의사항
- Android SDK와 Xcode가 설치되어 있으며 Android, iOS, Web 타겟을 사용할 수 있다.
- 연결 가능한 기기는 실행 시점의 `flutter devices` 결과를 기준으로 판단한다. iOS 실기기/무선 디바이스는 잠금 해제, 케이블 연결 또는 동일 네트워크, Developer Mode 설정이 필요할 수 있다.
- `pubspec.lock`이 커밋되어 있지 않으므로 `flutter pub get` 실행 시 의존성이 새로 resolve된다.
- `flutter analyze` 실행 시 `use_build_context_synchronously` info 1건 발생하는데 이는 기존 코드의 경고이다 (에러 아님).
- Linux 데스크톱 빌드는 macOS 로컬 우선 타겟이 아니며, 필요 시 Linux 빌드 환경에서 `libgtk-3-dev`, `cmake`, `ninja-build`, `clang`, `pkg-config` 패키지를 준비한다.
- 랭킹 서버(PHP)는 선택사항이며, 앱은 서버 없이도 정상 동작한다.

### QA 산출물 관리
- QA 스크린샷, 시각 검증 이미지, 임시 캡처 파일을 레포 루트(`/Users/cheng80/Desktop/jewelmatch`)에 생성하지 않는다.
- `*_qa.png`, `*_screenshot.png`, `*_preview.png` 같은 검증용 이미지는 `tmp/qa/` 또는 `tmp/imagegen/` 아래에만 저장한다.
- 브라우저/Playwright/스크립트 캡처 경로를 지정할 때는 반드시 `tmp/qa/<작업명>.png`처럼 하위 임시 디렉터리를 명시한다.
- 이미 레포 루트에 생성된 QA 이미지를 발견하면 새 산출물을 만들기 전에 `tmp/qa/`로 옮기거나 삭제한다.
