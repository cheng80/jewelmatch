# 릴리즈 빌드 가이드

Stone Match 스토어 업로드용 빌드 절차다.

## 현재 앱 식별자

| 항목 | 값 |
|------|----|
| 앱 이름 | `Stone Match` |
| Dart package | `stonematch` |
| Android applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| 현재 버전 | `1.0.0+1` |

## 공통 준비

`pubspec.yaml`의 버전을 먼저 올린다.

```yaml
version: 1.0.1+2
```

빌드 시 오버라이드도 가능하다.

```bash
flutter build appbundle --release --build-name 1.0.1 --build-number 2
flutter build ipa --release --build-name 1.0.1 --build-number 2
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

Play Store 업로드용은 AAB를 쓴다.

```bash
flutter build appbundle --release --build-name <버전> --build-number <빌드번호>
```

출력:

```text
build/app/outputs/bundle/release/app-release.aab
```

직접 배포나 설치 테스트용 APK:

```bash
flutter build apk --release --build-name <버전> --build-number <빌드번호>
```

출력:

```text
build/app/outputs/flutter-apk/app-release.apk
```

릴리즈 서명은 아직 프로젝트 문서에 확정 keystore 값이 없다. Play 업로드 전 `android/key.properties`와 `android/app/build.gradle.kts`의 release signing 설정을 실제 키로 맞춘다.

## iOS

App Store Connect 업로드용 IPA:

```bash
flutter build ipa --release --build-name <버전> --build-number <빌드번호>
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

## Web

Web 배포는 [`../tools/web_build.md`](../tools/web_build.md)를 따른다. NAS 업로드 자동화는 `tools/deploy_match_web.sh`를 사용한다.

## 출시 전 필수 검증

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

Android/iOS 릴리즈 빌드는 각 SDK와 서명 설정이 준비된 환경에서 별도 검증한다.
