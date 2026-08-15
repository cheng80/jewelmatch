# Stone Match 테스트, 빌드, 배포 명령

모든 명령은 Stone Match 저장소 루트에서 실행한다. 로컬 확인, NAS 배포, Apps in Toss 배포는 서로 다른 산출물을 사용한다.

## 1. 최초 준비

```bash
command -v flutter
command -v dart
command -v node
node --version

flutter pub get
npm install
```

- Apps in Toss SDK는 Node.js 24 이상을 권장한다.
- `flutter`, `dart`는 현재 셸의 `PATH`에 있는 실행 파일을 사용한다.
- `node_modules/`, `build/`, `*.ait`, `.env`, `.env.intoss`는 Git에 커밋하지 않는다.

## 2. 주요 테스트

### 코드 변경 후 기본 검증

```bash
flutter analyze
flutter test
```

현재 전체 테스트 수는 변경될 수 있으므로 명령의 종료 코드와 마지막 `All tests passed`를 기준으로 판단한다.

### 특정 영역만 빠르게 확인

```bash
# 광고 정책, 광고 서비스, 채널 설정
npm run test:ads

# FPS 통계, 웹 오디오, QA 자동 효과 경로
flutter test \
  test/fps_window_stats_test.dart \
  test/sound_manager_test.dart \
  test/match_board_game_qa_special_effect_test.dart

# 게임 규칙
flutter test test/match_board_logic_test.dart
```

특정 테스트 통과는 전체 회귀 테스트를 대신하지 않는다. 최종 병합 전에는 `flutter test` 전체를 실행한다.

## 3. 로컬 실행

### 일반 개발 실행

```bash
flutter run -d chrome
```

Flutter 디버그 실행은 기능 확인용이다. FPS 비교 수치로 사용하지 않는다.

### 브라우저 모의 광고

```bash
npm run dev:ads
```

`STORE_CHANNEL=intoss`, `INTOSS_AD_MODE=mock`으로 실행한다. 보상 흐름과 배너 레이아웃을 Chrome에서 확인할 때 사용하며 실제 토스 광고 요청은 하지 않는다.

### 일반 릴리즈 Web을 정적 서버로 확인

```bash
flutter build web \
  --release \
  --base-href "/" \
  --wasm \
  --no-web-resources-cdn \
  --no-source-maps
dart run tools/patch_flutter_web_deprecations.dart
python3 -m http.server 8080 --directory build/web
```

브라우저에서 `http://localhost:8080/`에 접속한다. 이 서버는 기능 스모크 테스트용이며 NAS의 COOP/COEP 헤더 환경과 같지 않으므로 최종 FPS 판정에는 사용하지 않는다. 종료는 실행한 터미널에서 `Ctrl+C`다.

## 4. 일반 Web과 NAS 배포

### `/match/`용 Web 빌드만 생성

```bash
flutter build web \
  --release \
  --base-href "/match/" \
  --wasm \
  --no-web-resources-cdn
dart run tools/patch_flutter_web_deprecations.dart
```

결과는 `build/web/`에 생성된다. `/match/` 빌드를 루트(`/`)에 배포하거나 그 반대로 배포하지 않는다.

### NAS 자동 배포

배포 전 깨끗한 `main`과 원격 동기화를 확인한다.

```bash
git status --short --branch
git fetch origin
git rev-list --left-right --count main...origin/main
```

마지막 명령의 카운트가 `0 0`이어야 한다. 최초 한 번은 로컬 환경 파일을 준비한다.

```bash
cp .env.example .env
```

`.env`에서 다음 값만 실제 값으로 바꾼다.

```dotenv
MATCH_DEPLOY_URL=<NAS 배포 URL>
MATCH_DEPLOY_TOKEN=<NAS 배포 토큰>
```

배포 명령:

```bash
tools/deploy_match_web.sh --help
tools/deploy_match_web.sh
```

스크립트가 기존 `build/web`, `match/`, `match.zip`을 정리하고 새 빌드, Wasm 헤더, ZIP 생성, NAS 업로드까지 수행한다. 배포 후 다음을 확인한다.

```bash
curl -I https://cheng80.myqnapcloud.com/match/
```

브라우저에서는 첫 로드, 새로고침 라우팅, 사운드, 랭킹을 확인하고 콘솔에서 `window.crossOriginIsolated === true`인지 확인한다.

## 5. Apps in Toss 테스트 빌드와 배포

### API 키 저장

API 키는 `.env`, 명령 기록, 문서에 넣지 않는다. AIT CLI의 토큰 프로필에 한 번 등록한다.

```bash
npx ait token add
```

여러 워크스페이스를 구분해야 할 때만 별칭을 사용한다.

```bash
npx ait token add dev
```

삭제는 `npx ait token remove` 또는 `npx ait token remove dev`를 사용한다.

### 공식 테스트 광고 `.ait` 생성

```bash
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
ls -lh ./*.ait
shasum -a 256 ./*.ait
```

이 명령은 다음 작업을 순서대로 수행한다.

1. 루트 base href의 Wasm Flutter Web 릴리즈 빌드
2. `STORE_CHANNEL=intoss`, `INTOSS_AD_MODE=test` 적용
3. Apps in Toss 광고 브리지 주입
4. `.ait` 패키징

### AIT 테스트 배포와 딥링크 출력

기본 토큰 프로필을 사용하는 경우:

```bash
npx ait deploy \
  --location ./<appName>.ait \
  --scheme-only \
  --memo "실기기 테스트"
```

별칭 프로필을 사용하는 경우 `--profile dev`를 추가한다. 이 명령은 원격 테스트 배포를 새로 생성하므로 명시적으로 배포할 때만 실행한다. 출력된 `intoss-private://...` 링크는 테스트용이며 API 키는 포함하지 않는다.

### 연결된 iPhone에서 열기

```bash
xcrun devicectl list devices

xcrun devicectl device process launch \
  --device "<기기 이름 또는 UDID>" \
  --terminate-existing \
  --payload-url '<intoss-private 링크>' \
  com.vivarepublica.cash
```

딥링크에는 `&`가 들어가므로 반드시 작은따옴표로 감싼다. 토스 앱이 설치되어 있고 Mac에서 해당 iPhone을 신뢰한 상태여야 한다.

## 6. Apps in Toss 운영 광고 빌드

운영 광고 그룹 ID는 Git에서 제외된 `.env.intoss`에만 둔다. API 키는 계속 AIT CLI 토큰 프로필을 사용한다.

```dotenv
INTOSS_APP_NAME=<콘솔_appName>
INTOSS_REWARDED_AD_GROUP_ID=<보상형 광고 그룹 ID>
INTOSS_BANNER_AD_GROUP_ID=<배너 광고 그룹 ID>
```

```bash
set -a
source .env.intoss
set +a
npm run build:intoss
```

운영 빌드는 광고 그룹 ID가 모두 없으면 실패한다. `.ait` 생성 후 업로드는 테스트 빌드와 같은 `npx ait deploy` 명령을 사용하지만, 실제 출시와 검토 요청은 Apps in Toss 콘솔에서 별도로 진행한다.

## 7. iPhone FPS와 GC 재측정

먼저 새 AIT 테스트 배포를 iPhone에서 열고 같은 모드, 같은 조건으로 플레이한다. 화면의 FPS 패널은 `AVG`, `LOW`, `GAP`을 기록한다.

`QA_PERF_AUTORUN`도 iOS 웹 자동재생 정책을 우회하지 않는다. 자동 플레이 측정 전에 게임 화면을 한 번 탭해 BGM과 SFX를 해제하고, 소리가 실제로 재생되는지 확인한다. 터치 없이 측정한 결과는 무음 대조군으로만 사용한다.

Mac에서 30초 시스템 추적을 함께 수집할 때:

```bash
mkdir -p tmp/qa/intoss_fps

xcrun xctrace record \
  --template 'Animation Hitches' \
  --device '<iPhone UDID>' \
  --all-processes \
  --time-limit 30s \
  --output tmp/qa/intoss_fps/<고유한_이름>.trace
```

- 기존 `.trace` 경로를 재사용하지 않는다.
- 측정 중에는 한 변수만 바꾼다.
- Apps in Toss WebView는 Web Inspector가 열리지 않을 수 있으므로 `WebContent`, `WebKit.GPU`, `mediaremoted`, Toss 프로세스의 잠재 정지를 비교한다.
- 측정 순서와 이전 결과는 [`../performance/flutter_flame_mobile_web_optimization_handoff.md`](../performance/flutter_flame_mobile_web_optimization_handoff.md)에 이어서 기록한다.

## 8. 완료 판정과 기록

| 작업 | 최소 완료 조건 |
| --- | --- |
| 코드 수정 | 관련 테스트, `flutter analyze`, 전체 `flutter test` 통과 |
| 일반 Web 빌드 | Wasm 릴리즈 빌드 성공, `build/web/index.html` 존재 |
| NAS 배포 | 업로드 HTTP 200, 공개 URL 로드, 라우팅·사운드·랭킹 확인 |
| Apps in Toss 빌드 | `.ait` 생성, 파일 크기와 SHA-256 기록 |
| Apps in Toss 배포 | 새 딥링크 발급, 토스 앱 실행, 광고와 게임 흐름 확인 |
| FPS 비교 | 같은 조건 30초, `AVG / LOW / GAP`, 잠재 정지 수 기록 |

배포 기록에는 날짜, Git 커밋, 빌드 모드, 산출물 체크섬, 테스트 결과만 남긴다. API 키, 배포 토큰, 광고 그룹 ID는 남기지 않는다.

## 관련 문서

- [`web_build.md`](web_build.md): `/match/` Web 빌드와 서버 헤더 상세
- [`../release/release_build.md`](../release/release_build.md): Android, iOS, Web 릴리즈 빌드
- [`../release/ad_placement_policy.md`](../release/ad_placement_policy.md): 광고 위치와 보상 정책
- [`../release/release_checklist.md`](../release/release_checklist.md): 출시 전 전체 체크리스트
