# Tab Order 게임 플로우

## 1. 게임 규칙 요약

- 숫자 모드
  - `1`부터 `50`까지 순서대로 누른다.
- 알파벳 모드
  - `A`부터 `Z`까지 순서대로 누른다.
- 화면에는 항상 `5×5` 그리드가 표시된다.
- 처음에는 1차 테이블만 보인다.
  - 숫자 모드: `1~25`
  - 알파벳 모드: `A~Y`
- 정답 큐브를 누르면 그 칸이 사라지고, 2차 테이블이 남아 있으면 같은 칸에 새 큐브가 채워진다.
  - 숫자 모드: `26~50`
  - 알파벳 모드: `Z`
- 오답 큐브를 누르면 흔들림만 발생하고 진행은 유지된다.
- 5초 동안 정답을 누르지 못하면 현재 정답 큐브가 깜박인다.
- 마지막 값까지 맞추면 클리어 화면이 뜬다.

## 2. 큐브 배치 방식

### 2-1. 초기 배치

```text
_prepareGrid()
├─ currentNumber = 1
├─ 타이머 / 힌트 초기화
├─ shuffledFirst = shuffle(1차 테이블)
├─ shuffledSecond = shuffle(2차 테이블)
└─ _createGrid()
   └─ 25칸에 shuffledFirst를 순서대로 배치
```

즉 처음 화면의 25칸은 모두 1차 테이블 값이다.

### 2-2. 정답 처리 후 교체

```text
정답 큐브 탭
├─ 큐브 회전 + 페이드아웃
└─ onComplete
   ├─ 2차 테이블이 남아 있으면
   │  └─ 같은 gridIndex 칸에 새 CubeButton 생성
   └─ 없으면
      └─ 빈 칸 유지
```

중요한 점:

- 2차 테이블도 셔플된다.
- 새 큐브는 "같은 칸"에 채워진다.
- 사용자가 눌러야 하는 목표값은 항상 순서대로 증가한다.

## 3. 전체 흐름도

```mermaid
flowchart TD
    A([앱 시작]) --> B[TitleView]

    B -->|숫자 모드| C[GoRouter -> /game?mode=0]
    B -->|알파벳 모드| D[GoRouter -> /game?mode=1]
    B -->|설정| S[SettingView]
    S -->|뒤로가기| B

    C --> GV[GameView]
    D --> GV

    GV --> LOAD[OneToFiftyGame.onLoad]
    LOAD --> PREP[라벨 초기화 + Grid 준비]
    PREP --> CD[Countdown overlay]

    CD --> CD3["3 / TimeTic"]
    CD3 --> CD2["2 / TimeTic"]
    CD2 --> CD1["1 / TimeTic"]
    CD1 --> CDS["Start / Start"]
    CDS --> SG[startGame]

    SG --> PLAY{isPlaying}
    PLAY --> UPD[update(dt)<br/>시간 갱신 / 힌트 타이머]
    UPD --> WAIT[탭 대기]
    UPD -->|5초 경과| HINT[정답 큐브 깜박임]
    HINT --> WAIT

    WAIT --> TAP[CubeButton 탭]
    TAP --> CHECK{정답 여부}

    CHECK -->|정답| CORRECT[Collect / animateCorrect]
    CHECK -->|오답| WRONG[Fail / animateWrong]
    WRONG --> PLAY

    CORRECT --> LAST{마지막 값인가}

    LAST -->|아니오| NEXT[currentNumber 증가<br/>HUD 힌트 갱신]
    NEXT --> FILL{2차 테이블 남음?}
    FILL -->|예| REPLACE[같은 칸에 새 큐브 생성<br/>animateFadeIn]
    FILL -->|아니오| EMPTY[빈 칸 유지]
    REPLACE --> PLAY
    EMPTY --> PLAY

    LAST -->|예| CLEAR["베스트 기록 저장<br/>Clear overlay"]
    CLEAR --> RETRY[다시하기]
    CLEAR --> EXIT1[나가기]
    RETRY --> PREP
    EXIT1 --> B

    PLAY -.->|Pause 버튼| PAUSE[PauseMenu overlay]
    PAUSE --> CONT[계속하기]
    PAUSE --> EXIT2[나가기]
    CONT --> PLAY
    EXIT2 --> B
```

## 4. 단계별 설명

### 4-1. 타이틀

- 사용자는 숫자 모드 또는 알파벳 모드를 선택한다.
- 선택 시 효과음이 재생되고 `/game?mode=...`로 이동한다.

### 4-2. 게임 준비

- `OneToFiftyGame.onLoad()`가 실행된다.
- `SpaceBg`, `GameHud`, `GridBg`, `CubeButton x 25`가 준비된다.
- `Countdown` 오버레이가 켜진다.

### 4-3. 카운트다운

- `3 -> 2 -> 1 -> Start` 순서로 표시된다.
- `Start`가 끝나면 `startGame()`이 호출된다.
- 이때부터만 `isPlaying = true`가 되어 탭 판정이 시작된다.

### 4-4. 플레이 중

- 매 프레임 시간과 힌트 타이머가 갱신된다.
- HUD에는 현재 시간과 다음 목표값이 표시된다.
- 5초 동안 정답을 못 찾으면 해당 큐브가 깜박인다.

### 4-5. 정답 탭

- `Collect` 효과음 재생
- 현재 큐브 회전 후 제거
- `currentNumber` 증가
- HUD 힌트 갱신
- 2차 테이블이 남아 있으면 같은 칸에 새 큐브 생성

### 4-6. 오답 탭

- `Fail` 효과음 재생
- 큐브 흔들림 애니메이션
- 진행 상태 변화 없음

### 4-7. 일시정지

- pause 버튼을 누르면 `PauseMenu` 오버레이가 뜬다.
- `계속하기`
  - 엔진 재개
  - BGM 재개
  - 게임 계속
- `나가기`
  - 타이틀 화면으로 복귀

### 4-8. 클리어

- 마지막 값을 누르면 `Clear` 오버레이가 뜬다.
- 결과 시간과 베스트 기록을 표시한다.
- `다시하기`
  - 그리드를 새로 준비하고 카운트다운부터 다시 시작
- `나가기`
  - 타이틀 화면으로 복귀

## 5. 효과음 매핑

| 상황 | 효과음 |
|------|--------|
| 타이틀/메뉴 버튼 | `BtnSnd.mp3` |
| 카운트다운 3,2,1 | `TimeTic.mp3` |
| Start | `Start.mp3` |
| 정답 | `Collect.mp3` |
| 오답 | `Fail.mp3` |
| 클리어 | `Clear.mp3` |

## 6. 구현상 핵심 포인트

- 게임은 `5×5` 고정 그리드다.
- 큐브 위치는 `gridIndex`로 관리된다.
- 화면 크기가 바뀌어도 `gridIndex`를 기준으로 같은 칸에 재배치된다.
- `backdrop / viewport / world` 레이어가 분리되어 있다.
- safe area는 게임 요소 배치 기준으로만 쓰고, 배경과 딤은 전체 화면을 쓴다.
