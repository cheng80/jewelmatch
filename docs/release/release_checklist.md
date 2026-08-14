# 스토어 출시 체크리스트

Stone Match 출시 전 확인 목록이다.

채널 선택값과 구현 상태는 [`store_channel_branching.md`](store_channel_branching.md)를 기준으로 한다.

## 앱 기본값

| 항목 | 값 |
|------|----|
| App name | `Stone Match` |
| Google Play applicationId | `com.cheng80.stonematch` |
| One Store applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| Apps in Toss appName | 콘솔 등록 후 확정 |
| Category 후보 | Games / Puzzle / Casual |
| 현재 버전 | `1.0.0+1` |

## 공통

- [ ] `pubspec.yaml` 버전과 빌드 번호 증가
- [ ] `flutter analyze` 통과
- [ ] `flutter test` 통과
- [ ] 릴리즈 빌드 생성
- [ ] 출시 채널에 맞는 `STORE_CHANNEL` define 사용
- [ ] 앱 아이콘과 스플래시가 Stone Match 이름/비주얼과 일치
- [ ] 개인정보처리방침 URL 확정
- [ ] 지원 URL 또는 연락처 확정
- [ ] 랭킹 서버를 공개 기능으로 쓸 경우 데이터 저장·삭제 정책 정리

## Android / Google Play

- [ ] Google Play Console 앱 생성
- [ ] `com.cheng80.stonematch` applicationId 확인
- [ ] 공통 JKS `/Users/cheng80/android_keystore/stonematch_keystore.jks`, 별칭 `stonematch_key` 생성과 별도 백업
- [ ] `android/key.properties`와 release signing 설정
- [ ] AAB 빌드: `flutter build appbundle --release --dart-define=STORE_CHANNEL=play`
- [ ] 앱 콘텐츠: Data safety, Ads, Target audience, Content rating, App access 작성
- [ ] 스토어 등록정보: 이름, 짧은 설명, 전체 설명, 아이콘, feature graphic, 스크린샷
- [ ] 내부 테스트 트랙 업로드와 설치 테스트

## Android / One Store

- [ ] Google Play와 같은 `com.cheng80.stonematch` applicationId 사용, 동시 설치는 지원하지 않음
- [ ] 공통 JKS `/Users/cheng80/android_keystore/stonematch_keystore.jks`, 별칭 `stonematch_key`로 첫 서명 빌드 검증
- [ ] 개발사 보유 JKS를 One Store에 등록
- [ ] `onestore` product flavor 구현과 APK 또는 AAB 빌드 검증
- [ ] 빌드: `flutter build apk --release --flavor onestore --dart-define=STORE_CHANNEL=onestore`
- [ ] 상품 제목, 한줄설명, 상품설명, 권한 설명, 검색 키워드, 판매자 정보 입력
- [ ] 대표 아이콘 512×512, 그래픽 이미지 1024×578, 스크린샷 2~8장 준비
- [ ] AAB를 선택했다면 minSdk 21 이상 및 One Store 범용 APK 설치 테스트
- [ ] One Store 콘솔 등록과 실기기 설치 테스트

## iOS / App Store

- [ ] Apple Developer Program 준비
- [ ] App Store Connect 앱 생성
- [ ] Bundle ID `com.cheng80.stonematch` 확인
- [ ] `AppConfig.appStoreId` 입력
- [ ] Signing Team / Provisioning Profile 확인
- [ ] IPA 빌드: `flutter build ipa --release --dart-define=STORE_CHANNEL=appstore`
- [ ] TestFlight 업로드와 실기기 테스트
- [ ] iPhone+iPad 스크린샷 준비 (`TARGETED_DEVICE_FAMILY = "1,2"`)
- [ ] 앱 정보: 카테고리, 나이 등급, 개인정보처리방침, 지원 URL, 심사 연락처 입력

## Web / NAS

- [ ] 실제 배포 경로와 `--base-href` 일치
- [ ] `tools/deploy_match_web.sh` 환경 변수 확인
- [ ] `matchranking/` 서버 파일과 `ranking_data.json` 권한 확인
- [ ] 배포 후 첫 로드, 라우팅, 사운드 unlock, 랭킹 API 스모크 테스트

## Apps in Toss

- [ ] Apps in Toss 콘솔 워크스페이스와 게임 앱 등록
- [ ] 콘솔 `appName` 확정, 빌드 환경 변수 `INTOSS_APP_NAME`에 반영
- [ ] 앱 로고 600×600, 투명 배경 없는 PNG와 썸네일 1932×828 PNG 준비
- [ ] 세로 스크린샷 3장 또는 가로 스크린샷 1장 이상 준비
- [ ] 고객센터 정보, 게임 카테고리, 검색 키워드, 상세 설명 입력
- [ ] 동일 게임의 오픈마켓 등급분류 정보 또는 게임물 등급분류증명서 준비
- [ ] 리더보드 사용 시 점수 단위와 정렬 기준 확정
- [x] SDK 3.x 설정과 테스트 광고 Web, `.ait` 로컬 패키징 검증
- [ ] 콘솔 appName으로 테스트 빌드: `INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test`
- [ ] `.ait` 패키징, 압축 해제 기준 100MB 이하 확인, 콘솔 QR 실기기 테스트
- [ ] 검토 요청 전 QR 테스트를 최소 1회 완료
- [ ] 광고 적용 시 [`ad_placement_policy.md`](ad_placement_policy.md)의 위치, 사전 로드, 사운드 정지와 보상 지급 조건 확인
- [ ] 리더보드 적용 시 콘솔 설정과 게임 내 동작 확인

상세 빌드는 [`release_build.md`](release_build.md), 채널 분기는 [`store_channel_branching.md`](store_channel_branching.md), 광고 정책은 [`ad_placement_policy.md`](ad_placement_policy.md), One Store와 Apps in Toss 등록 자료는 [`store_metadata_onestore_intoss_2026.md`](store_metadata_onestore_intoss_2026.md), Play와 App Store 문구는 [`store_metadata_play_appstore_2026.md`](store_metadata_play_appstore_2026.md)를 따른다.
