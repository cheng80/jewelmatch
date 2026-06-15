# 인앱 리뷰 정책과 구현

Stone Match는 `in_app_review` 패키지를 사용한다.

## 현재 구현

| 항목 | 파일 |
|------|------|
| 리뷰 서비스 | `lib/services/in_app_review_service.dart` |
| App Store ID 설정 | `lib/app_config.dart`의 `AppConfig.appStoreId` |
| 첫 실행일 저장 | `main.dart`에서 `saveFirstLaunchDateIfNeeded()` |
| 타이틀 자동 요청 | `TitleView` 진입 시 3일 경과 조건 |
| 첫 클리어 후 요청 | `maybeRequestReviewAfterFirstClear()` |
| 설정의 평점 남기기 | `RateAppTile` → `openStoreListing()` |

웹에서는 인앱 리뷰가 미지원이라 설정 화면에서 평점 섹션을 숨긴다.

## 원칙

- `requestReview()`는 버튼에 직접 연결하지 않는다. 플랫폼 quota가 있어 사용자가 눌러도 팝업이 안 뜰 수 있다.
- 버튼/설정 메뉴는 `openStoreListing()`로 스토어 페이지를 연다.
- iOS/macOS는 App Store Connect의 Apple ID를 `AppConfig.appStoreId`에 넣어야 한다.

## 출시 전 체크

- [ ] `AppConfig.appStoreId` 입력
- [ ] 첫 클리어 후 요청이 게임 흐름을 방해하지 않는지 확인
- [ ] 3일 경과 자동 요청 조건이 과도하지 않은지 확인
- [ ] 설정의 평점 남기기 버튼이 iOS/Android 실기기에서 스토어로 이동하는지 확인

## 테스트 메모

- iOS TestFlight에서는 시스템 리뷰 요청이 표시되지 않을 수 있다. Apple 문서는 TestFlight 배포 앱에서 request review 동작이 없다고 안내한다.
- Android는 Play Store가 설치된 환경과 테스트 트랙 등록 상태가 필요하다.

## 공식 참고

- Apple RequestReviewAction: https://developer.apple.com/documentation/storekit/requestreviewaction
- Android Play In-App Review: https://developer.android.com/guide/playcore/in-app-review
