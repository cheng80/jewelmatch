# 스토어 채널 분기 가이드

Stone Match는 하나의 프로젝트 루트에서 App Store, Google Play, One Store, Apps in Toss를 빌드한다. 채널별로 프로젝트를 복제하지 않는다.

## 현재 적용 범위

Flutter 코드는 `STORE_CHANNEL` Dart define으로 출시 채널을 선택한다. 선택하지 않으면 기존 Android 배포 흐름과 같은 `play`를 사용한다.

| 값 | 대상 |
|---|---|
| `appstore` | Apple App Store |
| `play` | Google Play |
| `onestore` | One Store |
| `intoss` | Apps in Toss HTML5 |

잘못된 값은 앱 시작 시 실패한다. 채널 선택 확인은 다음 명령으로 한다.

```bash
flutter test test/app_config_test.dart --dart-define=STORE_CHANNEL=play
```

## 현재 빌드 명령

아래 명령은 Flutter 코드의 채널값을 선택한다. Android product flavor와 iOS 별도 bundle ID는 구현 전이다. Apps in Toss는 콘솔 `appName`과 운영 광고 그룹을 확정하기 전까지 테스트 산출물로만 사용한다.

```bash
# Google Play
flutter build appbundle --release --dart-define=STORE_CHANNEL=play

# One Store
flutter build apk --release --dart-define=STORE_CHANNEL=onestore

# Apple App Store
flutter build ipa --release --dart-define=STORE_CHANNEL=appstore

# Apps in Toss 공식 테스트 광고 Web 빌드와 .ait 패키징
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
```

## 채널별 구현 상태

| 항목 | 현재 | 다음 작업 |
|---|---|---|
| 공통 Flutter 채널값 | 적용됨 | 운영 빌드별 값 검증 |
| Google Play | `com.cheng80.stonematch`, `stonematch_key` 사용 예정 | `play` product flavor와 실제 서명 연결 |
| One Store | Google Play와 같은 `com.cheng80.stonematch`, `stonematch_key` 사용 | `onestore` flavor와 One Store 키 등록 |
| App Store | 기존 `com.cheng80.stonematch` 사용 | Apple ID와 Xcode build configuration 연결 |
| Apps in Toss | SDK 3.x 설정, 광고 브리지, 테스트 Web과 `.ait` 빌드 적용 | 콘솔 `appName`, 운영 광고 그룹, QR 실기기 검증 |

## 구현 순서

1. 설정 화면과 인앱 리뷰를 채널별로 분기한다.
2. Android `play`, `onestore` product flavor와 iOS 설정을 추가한다.
3. Apps in Toss 콘솔 값을 확정하고 QR 테스트를 한다.
4. Apps in Toss 리더보드를 연결한다.

## 출시 전 결정할 값

- App Store Connect Apple ID
- Apps in Toss 콘솔 `appName`, 리더보드 구성, 광고 단위

식별자, 서명키, 콘솔 토큰은 소스에 저장하지 않는다.

Android 공통 JKS 경로는 `/Users/cheng80/android_keystore/stonematch_keystore.jks`이고 별칭은 `stonematch_key`다. 비밀번호는 문서에 기록하지 않는다.

One Store와 Apps in Toss의 등록 자료는 [`store_metadata_onestore_intoss_2026.md`](store_metadata_onestore_intoss_2026.md)를 따른다.
