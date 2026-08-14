# One Store와 Apps in Toss 등록 자료

기준일: 2026-08-14
앱: `Stone Match`

이 문서는 One Store와 Apps in Toss 등록에 필요한 메타데이터, 이미지, 출시 절차를 정리한다. Google Play와 App Store용 문구는 [`store_metadata_play_appstore_2026.md`](store_metadata_play_appstore_2026.md)를, 빌드 채널 상태는 [`store_channel_branching.md`](store_channel_branching.md)를 따른다.

## One Store

### 등록 메타데이터 초안

| 항목 | 입력값 또는 준비 상태 |
|---|---|
| 상품 제목 | `Stone Match`, 최대 50자 |
| 한줄설명 | `보석을 맞추고 콤보를 이어가는 캐주얼 매치-3 퍼즐`, 최대 100자 |
| 상품설명 | Play Store 설명을 기준으로 작성, 최대 1,300자 |
| 기본 언어 | 한국어, 해외 판매 시 영어를 기본 언어로 설정 |
| 검색 키워드 | `매치3`, `퍼즐`, `보석`, `스톤매치`, `캐주얼게임`, `타임어택` 등 1~10개 |
| 권한 설명 | 최종 Android Manifest의 요청 권한과 사용 목적을 모두 작성 |
| 판매자 정보 | 판매자명, 공식 이메일, 전화번호, 웹사이트는 출시 전 확정 |
| 가격 | 무료, 인앱 결제와 유료 아이템은 도입 시 별도 등록 |

### 이미지 자료

| 자료 | 규격 | Stone Match 준비 기준 |
|---|---|---|
| 대표 아이콘 | 512×512, JPG 또는 PNG | 앱 아이콘 원본에서 별도 내보내기 |
| 그래픽 이미지 | 1024×578, JPG 또는 PNG | 가로형 게임 플레이와 `Stone Match` 로고로 새 제작 |
| 스크린샷 | 2~8장, 각 1MB 이하, JPG 또는 PNG, 최대 1300×1300 | 세로 720×1280 또는 가로 1280×720 중 실제 출시 화면 방향으로 통일 |
| 소개 영상 | 선택, MP4 500MB 이하, 15초~10분 | 출시 전 필요 시 제작 |

스크린샷에는 실제 앱 화면을 사용하고, 텍스트가 포함된 이미지라면 언어별로 분리한다.

### 바이너리와 출시

- Android 상품은 APK 또는 AAB를 등록할 수 있다. AAB는 `minSdkVersion` 21 이상이 필요하며, AAB로 전환한 상품은 APK로 되돌릴 수 없다.
- Google Play와 동일한 앱을 같은 패키지명으로 운영하고 업데이트를 지원하려면 개발사가 보유한 동일 서명키를 One Store에 등록해야 한다. Stone Match는 `/Users/cheng80/android_keystore/stonematch_keystore.jks`의 `stonematch_key`를 공통으로 사용할 예정이다. One Store가 생성한 키와 Play의 키를 섞어 쓰지 않는다.
- 신규 AAB 또는 APK은 패키지명, 서명키, versionCode, 악성코드 검사를 통과해야 한다. AAB 등록 뒤에는 One Store가 생성한 범용 APK를 실제 기기에 설치해 확인한다.
- 현재 `onestore` flavor와 Gradle 릴리즈 서명 연결은 구현 전이다. `com.cheng80.stonematch`와 공통 JKS를 적용한 실제 빌드 검증 전에는 업로드하지 않는다.

공식 기준: [판매정보](https://onestore-dev.gitbook.io/dev/docs/apps/android/app-info), [바이너리](https://onestore-dev.gitbook.io/dev/docs/apps/android/binary), [앱 서명](https://onestore-dev.gitbook.io/dev/docs/apps/android/app-signing), [AAB FAQ](https://onestore-dev.gitbook.io/dev/help/faq/apps/one-store-android-app-bundle)

## Apps in Toss

### 콘솔 등록 메타데이터 초안

| 항목 | 입력값 또는 준비 상태 |
|---|---|
| 한국어 앱 이름 | `스톤매치`, 콘솔에서 수정 가능 |
| 영어 앱 이름 | `Stone Match`, 최대 15자 |
| appName | `stonematch`, 등록 뒤 수정과 삭제 불가 |
| 앱 유형 | 게임 |
| 부제 | `보석을 맞추고 콤보를 이어가는 퍼즐` |
| 상세 설명 | `8×8 보드에서 같은 보석을 3개 이상 맞춰 제거하는 매치-3 퍼즐입니다. 무한, 레벨, 타임 모드에서 특수 보석과 콤보를 활용해 기록에 도전합니다.` |
| 고객센터 | 이메일, 연락처 또는 채팅 상담 주소를 출시 전 확정 |
| 카테고리 | `퍼즐` |
| 웹보드 게임 | 선택하지 않음 |
| 검색 키워드 | `매치, 퍼즐, 보석, 스톤, 캐주얼, 게임, 타임, 콤보, 랭킹, 레벨` |
| 리더보드 | 한국어 `점`, 영어 `points`, `높은 점수부터` |

### 이미지 자료

| 자료 | 규격 | Stone Match 준비 기준 |
|---|---|---|
| 앱 로고 | 600×600, 배경색이 있는 PNG, 투명 배경 불가 | [`assets/intoss/app_logo_600.png`](assets/intoss/app_logo_600.png) |
| 다크모드 앱 로고 | 600×600, 배경색이 있는 PNG, 투명 배경 불가 | [`assets/intoss/app_logo_dark_600.png`](assets/intoss/app_logo_dark_600.png) |
| 썸네일 | 1932×828, PNG | [`assets/intoss/thumbnail_1932x828.png`](assets/intoss/thumbnail_1932x828.png) |
| 세로 스크린샷 | 636×1048 PNG 최소 3장 | [`01 타이틀`](assets/intoss/screenshot_portrait_01_title_636x1048.png), [`02 게임 플레이`](assets/intoss/screenshot_portrait_02_gameplay_636x1048.png), [`03 레벨 진행`](assets/intoss/screenshot_portrait_03_progression_636x1048.png) |

스크린샷은 선택 항목이지만, 검색 결과와 미니앱 미리보기에 쓰이며 제출한 앱부터 홈 노출에 반영된다. 로고와 썸네일에는 토스 제공 리소스를 사용하지 않는다.

Stone Match는 세로형 게임이므로 세로 스크린샷 3장만 등록하고 가로형 스크린샷은 등록하지 않는다.

이미지들은 `STORE_CHANNEL=intoss`, 광고 비활성화 상태의 실제 Web 빌드를 브라우저에서 실행해 캡처했다. 썸네일은 실제 가로 게임 화면 위에 게임 로고만 배치했으며 테스트 광고나 디버그 표시를 포함하지 않는다.

콘솔 리더보드는 앱인토스 게임센터 SDK에 점수를 제출해야 실제 데이터가 쌓인다. 현재 자체 랭킹과 별개이므로 출시 전에 타임 모드 종료 점수를 `submitGameCenterLeaderBoardScore`로 연결할지 확정한다.

### 게임 등급분류 증빙

- Google Play, App Store, One Store 등에서 동일 게임을 이미 출시했다면 해당 스토어 페이지 URL과 게임물관리위원회 자체등급분류 정보를 입력한다.
- One Store와 Apps in Toss 버전의 원본 플레이 화면을 각각 2장씩 준비한다. 편집한 홍보 이미지가 아니라 실제 게임 화면을 사용한다.
- 별도 심의를 받았다면 게임물 등급분류증명서를 PDF로 제출한다.

### 출시 절차

1. 콘솔에서 앱 이름, appName, 앱 유형을 등록한다. 수익화나 토스 로그인을 쓸 계획이면 사업자 인증과 대표관리자 상태를 먼저 확인한다.
2. `STORE_CHANNEL=intoss`로 root base href Web 빌드를 만든다.
3. `apps-in-toss.config.ts`와 Web Framework 설정을 추가한 뒤 `.ait`를 만든다. 압축 해제 기준 100MB 이하여야 한다.
4. 콘솔에 `.ait`를 업로드하고 QR 코드로 토스 앱에서 테스트한다. 검토 요청 전 최소 한 번의 QR 테스트가 필요하다.
5. 앱정보 검토와 출시 검토를 각각 요청한다. 앱정보 검토는 영업일 기준 1~2일, 번들 출시 검토는 최대 3영업일이 걸릴 수 있다.
6. 승인 후 콘솔에서 출시한다. 새 버전도 업로드, 검토, 승인, 출시 과정을 다시 거친다.

공식 기준: [콘솔에서 앱 등록하기](https://developers-apps-in-toss.toss.im/prepare/console-workspace.html), [토스앱 테스트하기](https://developers-apps-in-toss.toss.im/development/test/toss.html), [미니앱 출시](https://developers-apps-in-toss.toss.im/development/deploy.html), [게임 출시 체크리스트](https://developers-apps-in-toss.toss.im/checklist/app-game.html)
