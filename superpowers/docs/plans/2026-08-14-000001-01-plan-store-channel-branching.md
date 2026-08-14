# Stone Match 스토어 채널 분기

**Goal:** 하나의 Stone Match 코드베이스에서 App Store, Google Play, One Store, Apps in Toss를 빌드한다.
**Why planning is required:** 네이티브 앱 식별자, Web 패키징, 사용자 식별과 랭킹 저장소가 채널마다 달라진다.
**Acceptance:** 공통 게임 로직을 복제하지 않고 각 채널 빌드가 올바른 식별자와 기능만 포함하며, Apps in Toss 실기기 테스트와 기존 네이티브 빌드 검증을 통과한다.

### Outcome 1: 단일 코드베이스와 채널 값 확정 (완료)
- Work: `stone_match_intoss` 복제본을 휴지통으로 옮기고, 현재 프로젝트 루트를 유일한 소스로 유지한다. `STORE_CHANNEL` Dart define으로 `appstore`, `play`, `onestore`, `intoss`를 선택한다. define을 생략한 기존 Android 빌드는 `play`를 사용한다. 각 채널의 앱 식별자, 배포 키, 서명 파일은 소스에 저장하지 않는다.
- Risks/open questions: One Store Android `applicationId`, Apps in Toss `appName`, 배포별 서명 키와 스토어 등록 상태는 구현 전에 확정해야 한다.
- Verify: 원본 작업 트리에 복제본 경로나 비밀 파일이 없고 `flutter analyze`가 통과한다.

### Outcome 2: 공통 설정에서 스토어 기능을 분기
- Work: `lib/app_config.dart`에 채널별 기능 플래그를 두고, 설정 화면과 `InAppReviewService`가 그 값만 사용하게 한다. App Store는 Apple ID가 있을 때만 평점 메뉴를 보이고, Google Play는 Android 인앱 리뷰 경로를 사용한다. One Store와 Apps in Toss는 평점 메뉴와 자동 리뷰 요청을 보이지 않는다.
- Risks/open questions: One Store 자체 리뷰 또는 외부 리뷰 페이지를 제공할지 결정하기 전에는 메뉴를 숨긴다.
- Verify: 채널별 define으로 실행한 위젯 테스트가 평점 메뉴의 노출과 비노출을 검증하고 `flutter analyze`가 통과한다.

### Outcome 3: 네이티브 스토어 패키징 분기
- Work: `android/app/build.gradle.kts`에 `play`와 `onestore` product flavor를 추가한다. Google Play와 One Store는 같은 `com.cheng80.stonematch` applicationId와 `/Users/cheng80/android_keystore/stonematch_keystore.jks`의 `stonematch_key`를 사용하며 동시 설치를 지원하지 않는다. iOS는 App Store용 bundle ID와 Apple ID를 Xcode build configuration 또는 빌드 define으로 주입한다. Flutter Dart 패키지명과 게임 표시명은 공통으로 유지한다.
- Risks/open questions: One Store에 공통 개발사 서명키를 등록하고 Gradle 릴리즈 서명 연결을 검증해야 한다. AAB로 전환한 상품은 APK로 되돌릴 수 없다.
- Verify: `flutter build appbundle --flavor play`, One Store용 APK 또는 AAB 빌드, `flutter build ipa --release`를 각각 실행해 최종 식별자를 확인한다.

### Outcome 4: Apps in Toss Web 패키징 추가
- Work: Flutter Web을 루트 base href로 빌드하고 `@apps-in-toss/web-framework`와 `apps-in-toss.config.ts`를 추가한다. 설정의 `webBundleDir`은 `build/web`으로 지정하고, 콘솔에 등록한 `appName`과 일치시킨다. `npx ait build`로 `.ait`를 만들며 네이티브 runner 설정은 바꾸지 않는다.
- Risks/open questions: 콘솔의 확정 appName, 600×600 로고, 1932×828 썸네일, 번들 용량, 랭킹 권한과 테스트 워크스페이스 접근이 필요하다. 게임 등급분류 증빙과 QR 테스트 1회 이상 완료가 출시 검토 전에 필요하다.
- Verify: `flutter build web --release --base-href / --no-web-resources-cdn --no-source-maps`, `npx ait build`, 콘솔 QR 실기기 테스트를 실행한다.

### Outcome 5: Apps in Toss 랭킹 전환
- Work: 현재 `RankingService`의 점수 제출·목록 조회·실패 무시 계약은 유지한다. `intoss`에서만 Apps in Toss 게임 사용자 식별과 공식 리더보드 API를 Dart JS interop으로 연결하고, 수동 닉네임 입력과 PHP 랭킹 제출을 사용하지 않는다. 다른 채널은 기존 PHP 랭킹을 유지한다.
- Risks/open questions: 타임과 진행 랭킹을 각각 만들 수 있는지, 아니면 단일 공식 리더보드에 어떤 점수를 제출할지 콘솔에서 먼저 확정한다. 기존 운영 랭킹 데이터는 사용자 승인 없이 수정하거나 삭제하지 않는다.
- Verify: JS bridge mock 테스트, Apps in Toss QR에서 사용자 식별·점수 제출·순위 표시 테스트, 기존 `flutter test`와 PHP 랭킹 회귀 테스트를 실행한다.

### Outcome 6: 채널별 출시 문서와 운영 점검
- Work: `docs/release/`에 채널별 빌드 명령, 앱 식별자, 리뷰 정책, 광고 위치와 보상 정책, 개인정보 처리, 지원 연락처, 롤백 절차를 갱신한다. Apps in Toss CORS에는 라이브와 QR 테스트 Origin을 모두 등록한다.
- Risks/open questions: 개인정보처리방침, 고객 지원 URL, 게임 등급분류 증빙과 스토어별 수익화 정책은 출시 요청 전에 확정해야 한다.
- Verify: 문서 링크와 명령을 검토하고 각 채널의 사전 출시 체크리스트를 완료한다.
