# Jewel Match 스토어 등록 메타데이터 (Google Play / Apple App Store)

최종 업데이트: 2026-04-04  
앱: `Jewel Match` / `쥬얼 매치` (`com.cheng80.jewelmatch`)

이 문서는 **Google Play / Apple 공식 문서** 기준으로 정리한 등록용 메타데이터입니다.  
목표는 아래 2가지입니다.

1. 심사 시 필요한 **필수 입력 항목** 누락 방지
2. 콘솔에 바로 붙여 넣을 수 있는 **제출 초안(ko-KR / en-US)** 제공

---

## 1) 공식 문서 기준 필수 항목

## A. Google Play (Play Console)

### 1) 메인 스토어 리스팅 필수
- `App name` (최대 30자)
- `Short description` (최대 80자)
- `Full description` (최대 4000자)
- `App icon` (필수, `512 x 512`, 32-bit PNG, 최대 1024KB)
- `Feature graphic` (필수, `1024 x 500`, JPG 또는 24-bit PNG)
- `Screenshots` (게시를 위해 최소 2장, device type별 최대 8장)
- `Contact email` (필수)

### 2) App content/정책 제출 필수
- `Data safety form` (공개/테스트 트랙 앱 필수)
- `Privacy policy URL` (Data safety 제출 및 노출 연계)
- `Ads declaration` (Contains ads 여부)
- `Target audience and content`
- `Content rating`
- `App access` (로그인 없음, 전체 기능 공개)

---

## B. Apple App Store (App Store Connect)

### 1) App Information / Platform Version 필수
- `Name` (2~30자)
- `Age Rating` (필수)
- `Primary Category` (필수)
- `Privacy Policy URL` (iOS/macOS 앱 필수)
- `Screenshots` (필수, 디바이스 타입별 1~10장)
- `Description` (필수, 최대 4000자)
- `Keywords` (필수, 최대 100 bytes)
- `Support URL` (필수)
- `Copyright` (필수)

### 2) App Review Information 필수
- `Contact name`
- `Contact email`
- `Contact phone`

---

## 2) Jewel Match 공통 입력값

- 앱 이름: `쥬얼 매치` (영문: `Jewel Match`)
- Android package: `com.cheng80.jewelmatch`
- iOS bundle id: `com.cheng80.jewelmatch`
- 카테고리: `Games` > `Puzzle` (또는 `Casual`)
- 지원 이메일: `cheng80@gmail.com`
- 개인정보처리방침 URL: `https://cheng80.myqnapcloud.com/web/jewelmatch/privacy.html` (출시 전 설정)
- 앱 버전(현재): `1.0.0+1`

---

## 3) Google Play 제출용 입력안 (ko-KR / en-US)

## A. Product details

### ko-KR
- App name: `쥬얼 매치`
- Short description (<=80):  
  `같은 보석을 맞춰 없애는 캐주얼 매치 퍼즐 게임`
- Full description (<=4000):

```text
쥬얼 매치(Jewel Match)는 보석을 맞춰 없애며 점수를 올리는 캐주얼 퍼즐 게임입니다.

[핵심 기능]
- 직관적인 매치 플레이
- BGM·효과음, 볼륨·음소거 설정
- 화면 꺼짐 방지 옵션
- 다국어 지원 (ko, en, ja, zh-CN, zh-TW)

[데이터]
- 설정(볼륨, 음소거 등)과 로컬 진행 데이터는 기기에만 저장됩니다.
- 로그인 없이 모든 기능을 이용할 수 있습니다.

[권한]
- 인터넷: 사용하지 않음 (오프라인 플레이 가능)
```

### en-US
- App name: `Jewel Match`
- Short description (<=80):  
  `Match gems and clear the board in this casual puzzle game.`
- Full description (<=4000):

```text
Jewel Match is a casual puzzle game where you match gems and clear the board.

[Key Features]
- Intuitive match gameplay
- BGM and sound effects, volume and mute settings
- Keep screen on option
- Multi-language (ko, en, ja, zh-CN, zh-TW)

[Data]
- Settings (volume, mute, etc.) and local progress are stored only on device.
- No login required; all features available offline.

[Permissions]
- Internet: Not used (play offline)
```

---

## B. Graphics checklist (Play)

### Play 필수/권장 이미지 규격 (픽셀)

| 항목 | 필수 여부 | 규격 |
|---|---|---|
| App icon | 필수 | `512 x 512` PNG (32-bit, alpha), 최대 1024KB |
| Feature graphic | 필수 | `1024 x 500` JPG 또는 24-bit PNG |
| Phone screenshots | 필수 | 최소 2장, 최대 8장/기기타입 |

### Play 스크린샷 권장 해상도

- 세로 기본: `1080 x 1920` (9:16)
- 가로 선택: `1920 x 1080` (16:9)

권장 스크린샷 구성: 타이틀 화면 → 게임 플레이 → 클리어 화면 → 설정 화면

---

## C. App content / Data safety 입력 가이드

- Data collected: `No` (설정·베스트 스코어는 기기 로컬 저장, 서버 전송 없음)
- Data shared: `No`
- Privacy policy URL: `https://cheng80.myqnapcloud.com/web/jewelmatch/privacy.html`
- Ads: `No` (광고 없음)
- App access: `All functionality is available without special access` (로그인 불필요)
- Target audience and content: 퍼즐 게임 기준 연령 설정
- Content rating: 설문 기반 생성

---

## 4) Apple App Store 제출용 입력안 (ko / en)

## A. App Information

- Name: `쥬얼 매치` (<=30)
- Subtitle (ko): `보석 매칭 퍼즐` (<=30)
- Subtitle (en): `Gem Matching Puzzle` (<=30)
- Primary Category: `Games` > `Puzzle`
- Age Rating: 퍼즐 게임 기준 설문 응답
- Privacy Policy URL: `https://cheng80.myqnapcloud.com/web/jewelmatch/privacy.html`

---

## B. Version metadata

### Promotional Text (선택, <=170)
- ko: `같은 보석을 모아 화려한 콤보를 날려보세요.`
- en: `Match gems and chain combos in a relaxing puzzle.`

### Description (필수, <=4000)

ko:
```text
쥬얼 매치는 보석을 맞춰 없애며 즐기는 캐주얼 퍼즐 게임입니다.

주요 기능
- 보석 매칭 플레이
- BGM·효과음, 볼륨·음소거, 화면 꺼짐 방지
- 다국어 (ko, en, ja, zh-CN, zh-TW)

데이터
- 설정과 로컬 진행 데이터는 기기에만 저장됩니다. 로그인 없이 이용 가능합니다.
```

en:
```text
Jewel Match is a casual puzzle game about matching gems and clearing the board.

Key features
- Gem-matching gameplay
- BGM, sound effects, volume, mute, keep screen on
- Multi-language (ko, en, ja, zh-CN, zh-TW)

Data
- Settings and local progress stored on device only. No login required.
```

### Keywords (필수, <=100 bytes)
- ko 예시: `퍼즐,보석,매치,캐주얼,게임,쥬얼,클래식`
- en 예시: `puzzle,gem,match,casual,game,jewel,classic`

### Support URL (필수)
- `https://cheng80.myqnapcloud.com/web/jewelmatch/privacy.html`

### Copyright
- `2026 KIM TAEK KWON`

---

## C. Screenshot checklist (Apple)

### Apple 스크린샷 필수 규칙

- 포맷: `.jpeg`, `.jpg`, `.png`
- 수량: 디바이스 타입별 `1~10장`
- iPhone용 최소 1장 이상 필수
- iPad 지원 시 iPad용 최소 1장 이상 필수

### Apple 권장 해상도

| 기기군 | 권장 해상도(세로) |
|---|---|
| iPhone (6.9") | `1320 x 2868` |
| iPad (13") | `2064 x 2752` |

권장 스크린샷 흐름: 타이틀 → 게임 플레이 → 클리어 → 설정

---

## 5) 제출 전 최종 체크리스트

- [ ] 앱명/패키지명/Bundle ID 확인 (`Jewel Match` / `쥬얼 매치`, `com.cheng80.jewelmatch`)
- [ ] 개인정보처리방침 URL 운영 확인
- [ ] Play/App Store locale별 텍스트 최종 교정
- [ ] 최신 UI 기준 스크린샷 교체
- [ ] Play Data safety: 로컬 저장만 사용 확인
- [ ] Apple Support URL 연락 정보 충족 여부 점검
- [ ] App Review 연락처/전화번호 최종 입력

---

## 6) 공식 문서 출처

## Google Play
- Create and set up your app  
  https://support.google.com/googleplay/android-developer/answer/9859152
- Add preview assets  
  https://support.google.com/googleplay/android-developer/answer/9866151
- Data safety section  
  https://support.google.com/googleplay/android-developer/answer/10787469

## Apple App Store Connect
- App information  
  https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Screenshot specifications  
  https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
