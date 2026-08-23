# 릴리즈 빌드 가이드

Stone Match 스토어 업로드용 빌드 절차다.

채널 선택값과 채널별 구현 상태는 [`store_channel_branching.md`](store_channel_branching.md)를 기준으로 한다. 이 문서의 현재 Android와 iOS 식별자는 공통값이며, 아직 스토어별 식별자로 분리되지 않았다.

## 현재 앱 식별자

| 항목 | 값 |
|------|----|
| 앱 이름 | `Stone Match` |
| Dart package | `stonematch` |
| Android applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| 현재 버전 | `1.0.0+1` |

## 채널 선택

빌드에는 반드시 출시 대상에 맞는 `STORE_CHANNEL` Dart define을 넣는다.

| 채널 | 값 |
|---|---|
| Google Play | `play` |
| One Store | `onestore` |
| App Store | `appstore` |
| Apps in Toss | `intoss` |

현재 define은 Flutter 코드의 채널값만 선택한다. Android product flavor, iOS 별도 bundle ID, Apps in Toss `.ait` 패키징을 추가하기 전에는 One Store와 Apps in Toss 산출물을 업로드하지 않는다.

## 공통 준비

`pubspec.yaml`의 버전을 먼저 올린다.

```yaml
version: 1.0.1+2
```

빌드 시 오버라이드도 가능하다.

```bash
flutter build appbundle --release --build-name 1.0.1 --build-number 2 \
  --dart-define=STORE_CHANNEL=play
flutter build ipa --release --build-name 1.0.1 --build-number 2 \
  --dart-define=STORE_CHANNEL=appstore
```

## 스플래시 로고

웹과 네이티브 스플래시는 `flutter_native_splash` 설정을 통해 생성한다. 앱 내부 타이틀 로고와 별도로, 스플래시 전용 자산은 다음 파일을 사용한다.

```text
assets/images/ui/stone_match_splash_logo.png
```

이 자산은 원본 타이틀 로고를 그대로 꽉 채우지 않고, 모바일 화면에서 좌우 여백이 남도록 투명 패딩과 가로 중심 보정을 포함한다. `pubspec.yaml`의 `flutter_native_splash.image`와 `android_12.image`는 이 스플래시 전용 자산을 가리켜야 한다.

스플래시 자산을 바꾼 뒤에는 생성 리소스를 함께 갱신한다.

```bash
dart run flutter_native_splash:create
```

갱신 대상:

- `web/splash/img/*`
- `android/app/src/main/res/drawable*/splash.png`
- `android/app/src/main/res/drawable*/android12splash.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`

모바일 웹 QA는 Flutter 부트스트랩을 차단한 상태에서 순수 스플래시 화면을 캡처해, 로고가 가로 중앙에 있고 화면 폭을 과도하게 채우지 않는지 확인한다.

## Android

Google Play 업로드용은 AAB를 쓴다.

```bash
flutter build appbundle --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=play
```

출력:

```text
build/app/outputs/bundle/release/app-release.aab
```

직접 배포나 설치 테스트용 APK:

```bash
flutter build apk --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=play
```

출력:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Google Play와 One Store는 같은 Android 앱으로 운영하기로 했다. 공통 앱 서명키로 사용할 값은 아래와 같다.

| 항목 | 값 |
|---|---|
| JKS 경로 | `/Users/cheng80/android_keystore/stonematch_keystore.jks` |
| 키 별칭 | `stonematch_key` |
| applicationId | `com.cheng80.stonematch` |

`android/key.properties`에는 위 JKS 경로와 별칭, 비밀번호를 설정한다. JKS와 비밀번호는 Git에 올리지 않고 별도 백업한다. 현재 `android/app/build.gradle.kts`의 릴리즈 서명 연결은 구현 전이므로, 연결과 실제 서명 빌드 검증 전에는 업로드하지 않는다.

One Store는 `onestore` 채널값을 쓰되, Google Play와 같은 `applicationId`와 JKS를 사용한다. 두 스토어 버전은 같은 기기에 동시에 설치할 수 없다. `onestore` flavor 구현과 실제 서명 빌드 검증 전에는 Google Play 빌드 명령을 재사용해 One Store에 업로드하지 않는다.

## iOS

App Store Connect 업로드용 IPA:

```bash
flutter build ipa --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=appstore
```

출력:

```text
build/ios/ipa/Runner.ipa
```

업로드:

1. Transporter 앱 설치
2. Apple Developer 계정 로그인
3. `Runner.ipa` 업로드
4. App Store Connect에서 처리 완료 후 TestFlight 또는 심사 제출

## Web / NAS

Web 배포는 [`../tools/web_build.md`](../tools/web_build.md)를 따른다. NAS 업로드 자동화는 `tools/deploy_match_web.sh`를 사용한다.

## Apps in Toss Web

Apps in Toss는 NAS 배포와 별도다. Node.js 24 이상 환경에서 공식 테스트 광고 ID를 포함한 Web과 `.ait`를 한 번에 만든다.

```bash
npm install
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
```

이 명령은 Flutter Web 빌드 뒤 앱인토스 광고와 레벨 리더보드 브리지를 `build/web`에만 주입하므로 NAS용 일반 Web 빌드에는 토스 SDK가 포함되지 않는다. 운영 빌드는 `INTOSS_AD_MODE=production`과 콘솔의 보상형, 배너 광고 그룹 ID를 사용해 별도로 만든다.

## 출시 전 필수 검증

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=STORE_CHANNEL=play
```

Android/iOS 릴리즈 빌드는 각 SDK와 서명 설정이 준비된 환경에서 별도 검증한다.
