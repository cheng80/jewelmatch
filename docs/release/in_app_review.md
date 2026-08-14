# 인앱 리뷰 정책과 구현

Stone Match는 `in_app_review` 패키지를 사용한다. 채널별 정책은 [`store_channel_branching.md`](store_channel_branching.md)를 따른다.

## 현재 구현

| 항목 | 파일 |
|------|------|
| 리뷰 서비스 | `lib/services/in_app_review_service.dart` |
| App Store ID 설정 | `lib/app_config.dart`의 `AppConfig.appStoreId` |
| 첫 실행일 저장 | `main.dart`에서 `saveFirstLaunchDateIfNeeded()` |
| 타이틀 자동 요청 | `TitleView` 진입 시 3일 경과 조건 |
| 첫 클리어 후 요청 | `maybeRequestReviewAfterFirstClear()` |
| 설정의 평점 남기기 | `RateAppTile` → `openStoreListing()` |

현재는 웹에서만 평점 섹션을 숨긴다. `appStoreId`가 비어 있으면 스토어 페이지 이동은 실행되지 않는다.

## 채널별 목표 정책

| 채널 | 자동 리뷰 요청 | 평점 메뉴 |
|---|---|---|
| App Store | 사용 | Apple ID가 있을 때만 표시 |
| Google Play | 사용 | 표시 |
| One Store | 사용하지 않음 | 숨김 |
| Apps in Toss | 사용하지 않음 | 숨김 |

이 정책은 채널별 기능 플래그 구현 후 적용된다. 구현 전에는 현재 동작을 기준으로 실기기 테스트한다.

## 원칙

- `requestReview()`는 버튼에 직접 연결하지 않는다. 플랫폼 quota가 있어 사용자가 눌러도 팝업이 안 뜰 수 있다.
- 버튼/설정 메뉴는 `openStoreListing()`로 스토어 페이지를 연다.
- iOS/macOS의 스토어 페이지 이동에는 App Store Connect Apple ID가 필요하다.

## 출시 전 체크

- [ ] App Store 채널의 Apple ID 입력
- [ ] 첫 클리어 후 요청이 게임 흐름을 방해하지 않는지 확인
- [ ] 3일 경과 자동 요청 조건이 과도하지 않은지 확인
- [ ] App Store와 Google Play의 평점 동작을 각각 실기기에서 확인
- [ ] One Store와 Apps in Toss에서 평점 메뉴와 자동 요청이 보이지 않는지 확인

## 테스트 메모

- iOS TestFlight에서는 시스템 리뷰 요청이 표시되지 않을 수 있다. Apple 문서는 TestFlight 배포 앱에서 request review 동작이 없다고 안내한다.
- Android는 Play Store가 설치된 환경과 테스트 트랙 등록 상태가 필요하다.

## 공식 참고

- Apple RequestReviewAction: https://developer.apple.com/documentation/storekit/requestreviewaction
- Android Play In-App Review: https://developer.android.com/guide/playcore/in-app-review
