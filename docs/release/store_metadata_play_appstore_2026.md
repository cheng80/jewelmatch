# Stone Match 스토어 등록 메타데이터 초안

기준일: 2026-06-16  
앱: `Stone Match` (`com.cheng80.stonematch`)

스토어 콘솔에 바로 붙여 넣기 전, 실제 개인정보처리방침 URL·지원 URL·랭킹 서버 운영 여부를 확정해야 한다.

## 공통 입력값

| 항목 | 값 |
|------|----|
| 앱 이름 | `Stone Match` |
| Android package | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| 카테고리 후보 | Games / Puzzle / Casual |
| 현재 버전 | `1.0.0+1` |
| 개인정보처리방침 URL | 출시 전 확정 |
| 지원 URL | 출시 전 확정 |
| 마케팅 URL | 선택 |

## Google Play 초안

### ko-KR

- App name: `Stone Match`
- Short description: `보석을 맞추고 콤보를 이어가는 캐주얼 매치-3 퍼즐`

Full description:

```text
Stone Match는 8×8 보드에서 같은 보석을 맞추고 콤보를 이어가는 캐주얼 매치-3 퍼즐 게임입니다.

[주요 기능]
- 제한 없이 즐기는 무한 모드
- 목표 점수를 채워 올라가는 레벨 모드
- 시간을 벌며 기록에 도전하는 타임 모드
- 4개 이상 매치로 만드는 특수 보석
- 사운드, 언어, 화면 켜짐 설정
- 타임 어택 랭킹 지원

[개인정보 및 데이터]
- 게임 설정과 기록은 기기에 저장됩니다.
- 랭킹 기능을 사용할 경우 플레이어 이름과 점수가 랭킹 서버로 전송될 수 있습니다.
- 자세한 내용은 개인정보처리방침을 확인해 주세요.
```

### en-US

- App name: `Stone Match`
- Short description: `A casual match-3 puzzle game with stones, combos, and timed play.`

Full description:

```text
Stone Match is a casual match-3 puzzle game played on an 8x8 board.

[Key Features]
- Endless mode for relaxed play
- Level mode with score targets
- Timed mode where matches earn extra time
- Special stones created by bigger matches
- Sound, language, and keep-awake settings
- Time attack ranking support

[Privacy and Data]
- Game settings and local records are stored on your device.
- If ranking is enabled, player name and score may be sent to the ranking server.
- Please review the privacy policy for details.
```

## App Store 초안

### App Information

| 항목 | 값 |
|------|----|
| Name | `Stone Match` |
| Subtitle KO | `보석 매칭 퍼즐` |
| Subtitle EN | `Casual Stone Match-3` |
| Primary Category | Games |
| Secondary Category | Puzzle 또는 Casual |

### Promotional Text

- KO: `무한, 레벨, 타임 모드로 즐기는 캐주얼 보석 매칭 퍼즐.`
- EN: `Play endless, level, and timed match-3 modes in Stone Match.`

### Description KO

```text
Stone Match는 같은 보석을 맞추고 콤보를 이어가는 캐주얼 매치-3 퍼즐 게임입니다.

주요 기능
- 여유롭게 즐기는 무한 모드
- 목표 점수에 도전하는 레벨 모드
- 시간을 벌며 기록을 노리는 타임 모드
- 큰 매치로 생성되는 특수 보석
- 사운드, 언어, 화면 켜짐 설정
- 타임 어택 랭킹 지원

개인정보 및 데이터
- 설정과 로컬 기록은 기기에 저장됩니다.
- 랭킹 기능 사용 시 플레이어 이름과 점수가 서버로 전송될 수 있습니다.
```

### Description EN

```text
Stone Match is a casual match-3 puzzle game where you swap stones, clear matches, and chain combos.

Key features
- Endless mode for relaxed play
- Level mode with score targets
- Timed mode where matches earn extra time
- Special stones from bigger matches
- Sound, language, and keep-awake settings
- Time attack ranking support

Privacy and data
- Settings and local records are stored on your device.
- If ranking is enabled, player name and score may be sent to the ranking server.
```

### Keywords

- KO: `매치3,퍼즐,보석,스톤매치,캐주얼게임,타임어택`
- EN: `match3,puzzle,stones,casual,timed,combo`

## 그래픽 체크

Google Play 공식 문서는 app icon 512×512 PNG, feature graphic 1024×500, 스크린샷 최소 2장을 요구한다. Apple은 디바이스 타입별 1~10장의 `.jpeg`, `.jpg`, `.png` 스크린샷을 요구한다.

Stone Match는 iOS 설정상 iPhone+iPad 지원(`TARGETED_DEVICE_FAMILY = "1,2"`)이므로 iPhone과 iPad 스크린샷을 모두 준비한다.

| 플랫폼 | 권장 준비 |
|--------|-----------|
| Google Play | phone 1080×1920 세로 4~5장, feature graphic 1024×500 |
| App Store iPhone | 6.9" 세로 1320×2868 또는 허용 대체 해상도 |
| App Store iPad | 13" 세로 2064×2752 또는 허용 대체 해상도 |

## 공식 참고

- Google Play preview assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
