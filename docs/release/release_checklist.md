# 스토어 출시 체크리스트

Stone Match 출시 전 확인 목록이다.

## 앱 기본값

| 항목 | 값 |
|------|----|
| App name | `Stone Match` |
| Android applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| Category 후보 | Games / Puzzle / Casual |
| 현재 버전 | `1.0.0+1` |

## 공통

- [ ] `pubspec.yaml` 버전과 빌드 번호 증가
- [ ] `flutter analyze` 통과
- [ ] `flutter test` 통과
- [ ] 릴리즈 빌드 생성
- [ ] 앱 아이콘과 스플래시가 Stone Match 이름/비주얼과 일치
- [ ] 개인정보처리방침 URL 확정
- [ ] 지원 URL 또는 연락처 확정
- [ ] 랭킹 서버를 공개 기능으로 쓸 경우 데이터 저장·삭제 정책 정리

## Android / Google Play

- [ ] Google Play Console 앱 생성
- [ ] `com.cheng80.stonematch` applicationId 확인
- [ ] 릴리즈 keystore 생성과 보관
- [ ] `android/key.properties`와 release signing 설정
- [ ] AAB 빌드: `flutter build appbundle --release`
- [ ] 앱 콘텐츠: Data safety, Ads, Target audience, Content rating, App access 작성
- [ ] 스토어 등록정보: 이름, 짧은 설명, 전체 설명, 아이콘, feature graphic, 스크린샷
- [ ] 내부 테스트 트랙 업로드와 설치 테스트

## iOS / App Store

- [ ] Apple Developer Program 준비
- [ ] App Store Connect 앱 생성
- [ ] Bundle ID `com.cheng80.stonematch` 확인
- [ ] `AppConfig.appStoreId` 입력
- [ ] Signing Team / Provisioning Profile 확인
- [ ] IPA 빌드: `flutter build ipa --release`
- [ ] TestFlight 업로드와 실기기 테스트
- [ ] iPhone+iPad 스크린샷 준비 (`TARGETED_DEVICE_FAMILY = "1,2"`)
- [ ] 앱 정보: 카테고리, 나이 등급, 개인정보처리방침, 지원 URL, 심사 연락처 입력

## Web / NAS

- [ ] 실제 배포 경로와 `--base-href` 일치
- [ ] `tools/deploy_match_web.sh` 환경 변수 확인
- [ ] `matchranking/` 서버 파일과 `ranking_data.json` 권한 확인
- [ ] 배포 후 첫 로드, 라우팅, 사운드 unlock, 랭킹 API 스모크 테스트

상세 빌드는 [`release_build.md`](release_build.md), 스토어 문구는 [`store_metadata_play_appstore_2026.md`](store_metadata_play_appstore_2026.md)를 따른다.
