# AGENTS.md

## Cursor Cloud specific instructions

### Overview
Jewel Match는 Flutter + Flame 기반 8×8 매치-3 퍼즐 게임이다. 기본 명령어는 `README.md` 참조.

### Flutter SDK
- Flutter SDK `3.38.x` (Dart `^3.10.8`)가 필요하다. `/opt/flutter/bin`이 `PATH`에 포함되어야 한다.
- `~/.bashrc`에 `export PATH="/opt/flutter/bin:$PATH"`가 설정되어 있다.

### 주요 명령어
| 작업 | 명령어 |
|------|--------|
| 의존성 설치 | `flutter pub get` |
| 정적 분석 | `flutter analyze` |
| 테스트 | `flutter test` |
| 웹 빌드 | `flutter build web --release` |
| 웹 개발 서버 | `flutter run -d chrome` 또는 빌드 후 `python3 -m http.server 8080 --directory build/web` |

### 주의사항
- Android SDK는 설치되어 있지 않다. 웹(`chrome`)과 Linux 데스크톱(`linux`) 타겟만 사용 가능.
- `pubspec.lock`이 커밋되어 있지 않으므로 `flutter pub get` 실행 시 의존성이 새로 resolve된다.
- `flutter analyze` 실행 시 `use_build_context_synchronously` info 1건 발생하는데 이는 기존 코드의 경고이다 (에러 아님).
- Linux 데스크톱 빌드에는 `libgtk-3-dev`, `cmake`, `ninja-build`, `clang`, `pkg-config` 패키지가 필요하다.
- 랭킹 서버(PHP)는 선택사항이며, 앱은 서버 없이도 정상 동작한다.
