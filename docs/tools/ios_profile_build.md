# iOS 프로필 빌드 및 실기기 설치

Stone Match를 iPhone/iPad 실기기에서 성능 점검할 때 쓰는 프로필 모드 절차다.

## 사전 준비

- macOS + Xcode
- iPhone 또는 iPad 실기기
- Apple Developer 계정과 서명 설정
- `ios/Runner.xcworkspace`에서 Team, Bundle Identifier 확인

현재 Bundle ID는 `com.cheng80.stonematch`다.

## 기기 확인

```bash
flutter devices
```

## 프로필 빌드

```bash
flutter build ios --profile -d <DEVICE_ID>
```

빌드 결과:

```text
build/ios/iphoneos/Runner.app
```

## 실기기 실행

권장:

```bash
flutter run --profile -d <DEVICE_ID>
```

Xcode 실행:

1. `ios/Runner.xcworkspace` 열기
2. 대상 기기 선택
3. Run 실행

빌드된 앱만 설치:

```bash
xcrun devicectl device install app --device <DEVICE_ID> build/ios/iphoneos/Runner.app
```

## 모드 구분

| 모드 | 용도 |
|------|------|
| `--debug` | 개발, 핫 리로드 |
| `--profile` | 실기기 성능 측정 |
| `--release` | 스토어 배포 |

릴리즈 IPA 생성은 [`../release/release_build.md`](../release/release_build.md)를 따른다.
