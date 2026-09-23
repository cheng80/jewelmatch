# UI / UX Spec

> 화면, 사용자 흐름, 상태와 인터랙션의 Source of Truth다. 톤은 DESIGN.md, 동작 규칙은 이 문서와 FR ID로 연결한다.

작성 기준일: 2026-08-23, 계약 정합 수정 2026-08-23
근거: 현재 코드. DESIGN.md는 톤, 동작은 이 문서와 FR ID

## 1. 전체 User Flow

    Entry (TitleView)
      ├─ 무한 → GameView(simple)
      ├─ 레벨 → PlayerNameDialog → GameView(progression)
      ├─ 타임 → PlayerNameDialog → GameView(timed)
      ├─ 랭킹 → RankingListPopup
      ├─ 튜토리얼 → HowToPlay dialog
      └─ 설정 → SettingView

    GameView
      ├─ Loading overlay (최소 350ms)
      ├─ Intro 낙하 (입력 차단)
      ├─ Play HUD
      ├─ Pause / HowToPlay / Ranking / Stats
      ├─ NoMoves → 셔플 또는 새 보드
      ├─ LevelCelebration → LevelUp → StageInventory(옵션) → 다음 레벨
      └─ TimeUp → 광고 이어가기(레벨) / 재시도 / 나가기

## 2. 화면 목록

| ID | 화면 | 목적 | 관련 요구사항 |
|---|---|---|---|
| SCREEN-001 | 타이틀 | 모드 선택, 랭킹, 튜토리얼, 설정 | FR-003, FR-004, FR-005, FR-012 |
| SCREEN-002 | 플레이어 이름 | 레벨/타임 랭킹용 이름 | FR-009 |
| SCREEN-003 | 게임 보드 | 플레이와 HUD | FR-001 ~ FR-008 |
| SCREEN-004 | 로딩 | 첫 프레임 버벅임 가림 | FR-003 |
| SCREEN-005 | 일시정지 | 계속/재시도/나가기 | FR-009 |
| SCREEN-006 | 이동 없음 | 셔플/새 보드 | FR-001 |
| SCREEN-007 | 레벨 축하 | 클리어 연출 | FR-004 |
| SCREEN-008 | 레벨업 결과 | 보상, 인벤토리, 다음 레벨 | FR-004, FR-007, FR-008 |
| SCREEN-009 | 스테이지 인벤토리 | 다음 판 로드아웃, 광고 보충 | FR-007, FR-010 |
| SCREEN-010 | 타임업/실패 | 결과, 랭킹, 이어가기 | FR-004, FR-005, FR-009, FR-010 |
| SCREEN-011 | 통계 | 한 판 수치 | FR-001 |
| SCREEN-012 | 플레이 방법 | 규칙 설명 | FR-012 |
| SCREEN-013 | 인게임 랭킹 | 보드 위 목록 | FR-009 |
| SCREEN-014 | 설정 | 오디오, 언어, FPS, 평점 | FR-011 |
| SCREEN-015 | 타이틀 랭킹 팝업 | 타임/레벨 목록 | FR-009 |
| SCREEN-016 | 기록 | 누적 랭크, 배지, 개인 기록 | PLAN-005 R1 |

## 3. 화면 명세

### SCREEN-001 타이틀

- 목적: 첫 진입과 모드 선택
- 진입 조건: 앱 시작 또는 게임 나가기
- 관련 요구사항: FR-003, FR-004, FR-005, FR-011, FR-012
- 주요 컴포넌트: 로고, 무한/레벨/타임/랭킹 원형 버튼, 설정/튜토리얼 아이콘, 하단 버전. 타임 버튼 바로 아래에 "오늘의 보드 M월 D일"(KST, BR-053)
- 주요 액션: 무한은 바로 게임, 레벨/타임은 이름 대화상자, 랭킹 팝업, 설정 push
- 이동 대상: SCREEN-002, SCREEN-003, SCREEN-014, SCREEN-015, SCREEN-012

### 상태
- Loading: 타이틀 에셋 precache 전 GameLoadingOverlay
- Empty: 없음
- Success: 버튼 활성
- Error: 없음
- Disabled: 없음

### Validation / Feedback
- 버튼 탭 시 버튼 SFX
- 웹이 아니면 2초 뒤 인앱 리뷰 조건 확인

### SCREEN-002 플레이어 이름

- 목적: 랭킹 표시명 확보
- 진입 조건: 레벨/타임 시작
- 관련 요구사항: FR-009
- 주요 컴포넌트: 입력 필드, 취소, 시작
- 주요 액션: 저장 후 게임 진입, 취소 시 타이틀 유지
- 이동 대상: SCREEN-003

### 상태
- Empty: hint GUEST
- Success: 이름 저장
- Disabled: 없음

### Validation / Feedback
- 빈 값은 기본 GUEST로 처리하는 현재 입력 UX를 유지한다
- 키보드가 팝업을 가리지 않게 inset을 반영한다

### SCREEN-003 게임 보드 / HUD

- 목적: 보드 조작과 상태 표시
- 진입 조건: /game?mode=
- 관련 요구사항: FR-001 ~ FR-008
- 주요 컴포넌트:
  - 상단 원형 버튼: 일시정지, 힌트, (타임만) 랭킹, 튜토리얼
  - 점수, 베스트, 콤보, 타임바 또는 무제한 표시, 레벨/목표
  - 하단: 레벨 모드 4칸 로드아웃. 타임은 없음. 무한은 빌드 정책에 따름
  - 무한 릴리즈: 하단 96px 배너 안전 영역
- 주요 액션: 스왑, 특수 보석 탭, 아이템 탭, 힌트, 일시정지
- 하이퍼 입력(2026-09-24): 하이퍼 칸은 누를 때가 아니라 뗄 때 발동한다. 하이퍼에서 시작한 드래그, 또는 일반 보석 선택 뒤 인접 하이퍼 선택은 교환(H1, H2)이다
- 도전 스테이지 목표 줄(레벨 모드 4의 배수 레벨, BR-043): 점수 아래 "목표 N" 자리에 색 목표는 보석 아이콘과 `진행/목표`, 특수 목표는 `특수 발동 진행/목표`, 보석 목표는 `보석 진행/목표`를 그린다. 달성하면 글자가 초록색(0xFF7CFFB2)이 된다. 기존 80% 맥동과 달성 강조를 진행도 비율로 재사용한다. 진입 때 아이템 안내 배너로 "도전 스테이지"를 2.4초 보인다
- Speed Bonus 표시(타임 모드): 보드 오른쪽 아래 `SPEED +N`을 1.1초 보여 주고 0.12초 팝한다. reduced motion이면 팝 없이 표시만. 효과음 없음
- 이동 대상: SCREEN-005 ~ SCREEN-013

### 상태
- Loading: SCREEN-004
- Intro: 투명 IntroBlock, 입력 차단, 시계 정지
- Playing: 입력 가능
- itemTargeting: 대상 칸 선택, 일반 스왑 차단. 일반 칸 선택 중 시간은 흐름
- prismColorPick: 프리즘 색 고르는 동안 시계 정지. 색 확정 뒤 보석 지정은 itemTargeting
- itemConfirm: 즉시형 아이템 사용 확인(셔플/타임슬립/힌트+). 확인 중 시계 정지
- Overlay: 해당 오버레이가 입력을 가져감
- Disabled: 힌트 0, 수량 0 아이템, 잠긴 슬롯, 모드 부적합 아이템

### Validation / Feedback
- 무효 스왑: 복귀 모션 + Fail SFX
- 아이템 사용 실패: 짧은 피드백 배너, 수량 유지
- 힌트 0: 추가 피드백 없이 무시
- 저시간: TimeTic SFX
- 매칭 제거 파편과 콤보 별빛은 중심에서 사방으로 퍼지며 감속하고 작아져 사라진다. 중력이나 위쪽 발사 편향을 적용하지 않아 도중에 아래로 처지지 않는다. 후속 튜닝으로 확산 속도는 1.4배, 파편/별/링/섬광의 수명은 이전의 65%로 줄였다. 보석 위 유휴 반짝임 밝기는 이전의 2/3이며 대각선 광택 스윕(light sweep/sheen sweep)은 이전의 80% 속도로 흐르고 같은 보석에서 10초마다 반복한다.
- 보석 피드백: 선택 보석과 인접 스왑 후보, 무효 드래그 대상에 광륜을 표시한다. 보석 착지 스쿼시, 특수 보석의 짧은 수축, 유휴 광택은 보드 입력과 점수 규칙을 바꾸지 않는다.
- 무한 모드 자동 힌트: 5초 유휴 뒤 기존 힌트 한 쌍을 표시하며 수량을 줄이지 않는다. 타임 모드와 레벨 모드에는 자동 힌트를 표시하지 않는다.
- 특수 보석과 HUD glow: 특수 발동의 번개, 별, 폭발, 하이퍼 광륜과 목표, 콤보, 타임바, 아이템 광륜은 기존 색, 위치, 히트 영역을 유지한다. 적용 완료된 bomb과 HUD glow는 baked glow로 표시하고, 특수 연출은 사라진 뒤 잔상을 남기지 않는다.
- E2 hyper/supernova는 정지 레이어 5장과 코드 타임라인으로 전환했다. hyper는 청록/보라 전기와 룬, supernova는 금색 별/충격파를 쓰며 고정 중심에서 성장하고 소멸한다. 실제 Flutter 픽셀과 데스크톱 보드 캡처는 확인했으며 실기기 성능은 미검증이다.

HUD 버튼 배치: 일시정지 → 힌트 → (랭킹은 타임만) → 튜토리얼. 베스트 점수는 힌트/랭킹 오른쪽에 둔다. 레벨 모드에는 HUD 랭킹 버튼과 1위 왕관이 없다.

### SCREEN-004 로딩

- 목적: GameWidget 마운트와 프리로드를 가린다
- 진입 조건: GameView 진입
- 관련 요구사항: FR-003
- 주요 액션: 없음. 최소 350ms 후 보드

### SCREEN-005 일시정지

- 목적: 플레이 중단
- 관련 요구사항: FR-009
- 주요 액션: 계속, 재시도, 나가기, 설정, 통계
- 나가기: 타임/레벨이면 랭킹 제출을 기다린 뒤 타이틀. 제출 중 중복 탭 방지
- 설정: SettingView push. 통계: SCREEN-011

### 상태
- Success: 메뉴
- Disabled: 랭킹 제출 중 나가기 재진입 차단

### SCREEN-006 이동 없음

- 목적: 막힌 보드 해소
- 관련 요구사항: FR-001
- 주요 액션: 셔플, 새 보드, 통계
- 시간은 일시정지된다

### SCREEN-007 / SCREEN-008 레벨 축하와 결과

- 목적: 클리어 연출 후 보상 확인
- 관련 요구사항: FR-004, FR-007, FR-008
- SCREEN-007: 짧은 축하 후 SCREEN-008
- SCREEN-008: 이전/다음 레벨 배지, 보상 칩, 인벤토리 버튼, 다음 레벨
- 인벤토리는 결과 안에 펼치지 않고 별도 창으로 연다

### SCREEN-009 스테이지 인벤토리

- 목적: 다음 스테이지 로드아웃과 아이템 보충
- 관련 요구사항: FR-007, FR-010
- 주요 컴포넌트: 해금 배너, 4슬롯, 8종 그리드, 수량 뱃지, 광고 보충 버튼, 닫기
- 주요 액션: 빈 슬롯 선택 후 아이템 장착, 수량 0이면 광고 보충
- 2차에서 해제 전용 조작은 없다. 다른 아이템으로 교체한다
- 잠긴 슬롯은 자물쇠, 탭 무시
- 하단 닫기만 사용. 상단 X 없음

### 상태
- Empty: 빈칸 슬롯
- Disabled: 수량 0, 중복 장착, 잠금, 광고 미준비
- Loading: 광고 로딩/재생 문구
- Error: 보상 미지급 메시지

문구 주의: 사용자에게 "임시"라는 말을 쓰지 않는다. 코드 키 temporaryInventoryTitle이 있어도 번역 문구는 제품 톤을 따른다.

### SCREEN-010 타임업 / 실패

- 목적: 결과와 다음 행동
- 관련 요구사항: FR-004, FR-005, FR-009, FR-010
- 주요 액션: 재시도, 나가기, 랭킹 재제출, 레벨 실패 시 광고 보고 이어가기
- 이어가기는 실패 결과 화면에서만. 오버레이 위에 광고를 바로 띄우지 않는다
- 타임 모드는 TimeUp 전에 Last Hurrah가 있다. 보드 아래 가운데에 LAST HURRAH를 표시하고(Flame HUD, 0.16초 팝, reduced motion은 팝 없음, 표시 중에는 SPEED 배지를 숨김) 남은 특수 보석이 차례로 터진다. 최대 6초. 결과 패널과 제출의 1900ms는 TimeUp 진입부터 센다

### 상태
- Loading: 랭킹 제출 중
- Success: 순위 메시지
- Error: notFound / loadFailed / saveFailed / unavailable / intoss 실패. 재시도 아이콘
- Disabled: 광고 미준비, 이미 이어가기 사용

### SCREEN-011 통계

- 목적: 유효 스왑, 매치 그룹, 제거 수, 특수 생성/발동
- 진입: 결과/노무브의 통계 버튼

### SCREEN-012 플레이 방법

- 목적: 기본 규칙과 특수 보석 카드
- 진입: 타이틀 아이콘 또는 HUD 튜토리얼
- 닫으면 이전 화면

### SCREEN-013 인게임 랭킹

- 목적: 타임 모드 보드 위 목록
- 진입: 타임 HUD 왕관만. 레벨/무한 HUD에는 없음
- HUD 왕관은 타임 top1 이름/점수 요약, 탭 시 목록. 1위는 이번 주 기준이라 이름 앞에 "이번 주"(번역 키 `hudWeeklyTop`)를 붙인다. 랭킹 팝업 타임 탭은 "이번 주 타임"이고 목록 위에 매주 월요일 0시(한국 시간) 초기화 안내를 보인다(BR-095)
- 장애 시 게임은 유지하고 오류 문구만 표시

### SCREEN-015 타이틀 랭킹 팝업

- 목적: 타임/레벨 상위 30
- 진입: 타이틀 랭킹 버튼. 두 모드 목록 모두 여기서 본다

### SCREEN-016 기록

- 목적: 판을 거듭하는 장기 목표(누적 랭크, 배지)와 개인 기록을 보여 준다(Product Spec 6-6)
- 진입: 타이틀 설정 버튼 옆 왕관 아이콘, 라우트 `/records`
- 내용: 랭크와 진행 막대, 다음 랭크까지 남은 점수, 누적 점수, 모드별 최고, 최고 한 수, 최장 연쇄, 누적 제거, 특수 보석 누적, 배지 10종과 등급을 한 화면 스크롤로 보인다
- 알림: 랭크 상승이나 배지 획득이 있으면 TimeUp에는 성공 배너 최대 2줄, LevelUp에는 1줄, 일시정지 나가기에는 900ms 토스트 1줄을 보인다. 흐름은 막지 않는다

### SCREEN-014 설정

- 목적: 화면 켜짐, FPS, BGM/SFX, 평점, 언어
- 볼륨 슬라이더는 드래그 중 미리보기, 놓을 때 저장
- 웹에서 평점 타일 숨김
- FPS 기본 꺼짐. 좁은 화면은 하단 광고 위 우측, 넓은 화면은 프레임 바깥 하단. 웹 QA는 ?fps=1 또는 ?qaPerf=1

## 4. 공통 UX 규칙

- Loading 표시 원칙: 타이틀 에셋과 게임 마운트는 전면 로딩. 랭킹/광고는 해당 컨트롤만 로딩 상태로 둔다
- Error 표시 원칙: 랭킹/광고 실패는 문구와 재시도. 보드 진행을 막지 않는다
- Empty State 원칙: 랭킹 없음, 보상 없음, 빈 슬롯은 짧은 안내 문구
- 확인이 필요한 파괴적 액션: 즉시형 아이템 사용 확인, 일시정지 나가기(랭킹 제출 대기). TimeUp 나가기는 제출 완료를 기다리지 않는다
- 접근성/반응형: PhoneFrame 390×750 FittedBox. GameView는 Flame 자체 스케일. 터치 영역은 원형 HUD 버튼. 다국어 5종. 중간점 문자 금지
- 시각 계층: 보석이 가장 밝고, UI 크롬은 흑요석/황동. 보석 프레임은 팝업에만. DESIGN.md
- 광고: 인트로, 로딩, 튜토리얼, 클리어 연출, 팝업, 보드 조작 중에는 표시하지 않는다
- 모션: 라우트 FadeTransition. 웹 카메라 흔들림 큐는 끈다

### 화면과 오버레이 모션 (T4b, 2026-09-20)

- 공통 카드: `LuminaOverlayCard` 내부의 `OverlayEnterTransition`으로 240ms 스케일(0.9 → 1)과 페이드. 스크림은 정적으로 유지하며 움직이는 카드만 `RepaintBoundary`로 격리한다.
- 일시정지, 이동 없음, 통계, 인게임 랭킹, 튜토리얼, 인벤토리 닫기: `runOverlayExit(context, action)`이 카드 한 장을 캡처해 160ms 축소와 페이드로 없앤다. `action`은 즉시 실행하며 잔상은 입력과 접근성 트리에서 제외한다. 같은 프레임의 연속 닫기는 한 번만 실행한다. 콜백 실패 시 즉시 재시도할 수 있고 화면이 남아 있으면 다음 프레임에 다시 닫을 수 있다. 캡처를 지원하지 않는 렌더러에서는 효과만 생략하고 동작을 실행한다.
- 이름 입력, 타이틀 랭킹, 타이틀 튜토리얼: `showMotionDialog`의 200ms 라우트 애니메이션을 카드에만 적용한다. 카드 자체 등장과 라우트 전환을 중복하지 않는다. 닫힐 때 역전환하며 별도 잔상을 만들지 않는다.
- 타이틀: 로고부터 모드 버튼 4개까지 70ms 간격으로 240ms 등장한다. 버튼을 누르는 동안 0.94배, 손을 떼거나 취소하면 1배로 돌아간다. 실행 콜백은 기존 탭 시점 그대로다.
- 레벨업 보상: 보상 칩을 표시 순서대로 70ms 간격으로 240ms 등장시킨다. 수량과 보상 지급 시점은 바꾸지 않는다.
- 인벤토리: 카드가 높이의 12% 아래에서 올라온다. 새 아이템 장착은 슬롯 420ms 팝과 아이콘 220ms 안착을 사용한다. 기존 720ms 슬롯 해금 연출을 유지하며 잠금이나 수량 규칙은 바꾸지 않는다.
- 타임업: 기존 1900ms 결과 패널과 제출 시점을 유지한다. 점수는 800ms 동안 최종 점수까지 올라가고, 라운드 시작 전 기록보다 좋으면 별과 최고 기록 라벨을 표시한다. 레벨 모드는 도달 레벨을 먼저 비교하고 동점 레벨에서 점수를 비교한다. 실제 저장값과 랭킹 제출값은 표시용 숫자와 분리한다. Pause와 TimeUp 재시작 직전에 비교 기준을 다시 읽는다.
- 광고 보상: 리필 성공은 체크, 실패는 오류 아이콘과 기존 안내 문구로 구분한다. 이어하기 성공 배너는 결과창이 닫혀도 900ms 동안 남고 입력을 막지 않는다. 실패 시에는 결과창 안에서 재시도 안내를 유지한다. 광고 준비, 보상 판정과 횟수 제한은 기존 정책 그대로다.
- 랭킹 로딩: 유한 순차 등장 뒤 정적인 3행 자리표시자를 보여 주고, 응답이 오면 목록이나 기존 오류/빈 상태로 교체한다.
- 첫 로딩: 보석 장식은 1200ms 한 번 재생하고 모래시계와 로딩 문구를 유지한다. blur 반경은 고정한다. 로딩 해제 조건과 최소 350ms는 기존과 같다.
- `MediaQuery.disableAnimations`가 켜지면 카드, 보상, 버튼, 슬롯, 점수와 라우트는 즉시 최종 시각 상태를 표시한다. 타임업 결과도 즉시 읽을 수 있지만 버튼 활성과 제출은 기존 1900ms 시점을 유지해 조기 재시작으로 제출을 건너뛰지 않는다. 대기 중에는 `IgnorePointer`로 포인터와 의미론적 탭 액션을 제외하고 `ExcludeFocus`로 키보드 활성화를 막는다. 레벨 축하는 파티클을 생략하고 첫 post-frame에 즉시 완료한다. 타임업의 1900ms 제출 계약과 구분한다.
- 웹 캡처는 데스크톱 브라우저 결과이며 모바일 실기기 FPS나 실제 광고 SDK 결과를 대신하지 않는다. T4b ego 캡처 일부에서 문자 중복이 보였으나 headless 재현은 없었고 원인은 확정하지 못했다.
- F1 독립 검수에서 발견된 안착 중 게임 스와이프 입력의 무효 드래그 처리, 무효 스와이프 범프 잔류, geometry 변경 뒤 이전 타일 크기 범프 재적용의 3건은 T2에서 수정했고 회귀 테스트로 고정했다.

## 작성 경계

## 상세정보 보존
화면 상태, 인터랙션, 오류/빈 상태, 디자인 원칙과 판단 근거를 유지한다. 참고 이미지와 실제 구현 스크린샷은 섞지 않는다. 이미지 경로는 이 팩의 assets/ 실제 파일을 따른다. 빈 폴더는 만들지 않는다.


화면이 어떻게 보이고 행동하는지를 기록한다. 제품 기능은 Product Spec, 구현 기술은 Tech Spec.

---

# 디자인 원칙

원문 제목 키: `DESIGN.md` (이 파일에 흡수됨)

# Stone Match Design

## Core Direction

Stone Match uses an ancient fantasy temple UI: obsidian stone, aged brass, teal magic, and restrained red danger accents. The jewels are the brightest objects on screen. UI chrome must support the jewels, not compete with them.

## Visual Hierarchy

1. Gameplay jewels: highest saturation and detail.
2. Primary containers and popups: ornate jeweled stone frame.
3. Buttons: simple brass-and-obsidian frame, no gemstones.
4. Circular icon buttons: simple brass ring, no gemstones.
5. Progress and control rails: dark stone track, brass rim, muted teal active state.
6. Background and board slots: darkest, lowest contrast layer.

## Asset Rules

- Use jeweled frames only for popups, modal panels, and major containers.
- Do not use jeweled frames on buttons, sliders, switches, HUD icons, or small repeated controls.
- Button frames must stay simple: brass edge, dark stone center, no text baked into the asset.
- Nine-patch/stretch areas must avoid ornaments, runes, cracks, and highlight seams.
- Generated PNG assets used by the app must be copied into `assets/images/ui/`.

## Controls

- Sliders represent adjustable power or volume. Use a dark stone rail with a brass outline and muted teal/gold active fill.
- Slider thumbs use gold/brass instead of bright candy colors.
- Switches use dark inactive tracks and muted teal active tracks with gold/brass thumbs.
- Time bars use the same rail grammar as sliders, but larger and more legible.
- Critical time may use red/orange fill, but the rail and border stay brass/stone.

## Text

- Gold labels for headings, section titles, dialog titles, selected states, and secondary actions.
- Teal is reserved for functional or magical state only: active rails, focus rings, special-gem arrows, and temporary loading effects.
- Do not use bright teal/mint for large readable text. It competes with the jewels and weakens the ancient-fantasy tone.
- White text should be warm parchment, not pure white, except for short score flashes or gem effects.
- Celebration effects use brass, muted red, and restrained teal. Avoid candy pink, neon cyan, and saturated purple in UI effects.
- Warm white for score and high-priority numeric readouts.
- Red only for danger, critical time, or destructive emphasis.

## Current Application Map

- Title buttons: simple obsidian button frame.
- Popup and modal panels: jeweled obsidian panel frame.
- Popup buttons: simple obsidian button frame.
- HUD icon buttons: circular brass/obsidian frame.
- HUD time bar and app sliders: stone rail with brass/teal hierarchy.


---

# 새 보석 디자인 검토

원문 제목 키: `new_gem_design_review.md` (이 파일에 흡수됨)

# New Gem Design Review

Date: 2026-06-13

## Goal

Replace the current normal gem sprites that are visually close to Bejeweled 3 with an original Stone Match design language.

The current runtime uses:

- Normal gems: `assets/images/sprites/Jewel_Arcane.png`, 7 cells, `896x128`, each cell `128x128`.
- Legacy row/col specials: `assets/images/sprites/Special_Arcane.png`, 2 cells, `256x128`, each cell `128x128`, in current legacy `col`/`row` order.
- Action specials: `assets/images/sprites/Special_Action_Arcane.png`, 4 cells, `512x128`, each cell `128x128`, in `bomb`, `star`, `hyper`, `supernova` order.
- Supernova: standalone 8-point starburst frame in `Special_Action_Arcane.png`; it no longer renders as a normal gem plus `supernova_overlay.png`.
- Runtime render size: about `0.82 * tileSize`, centered in each board tile.

## Generated Concepts

All three concepts are ImageGen exploration sheets, not final runtime sprite sheets.

| Option | File | Direction |
| --- | --- | --- |
| 1 | `assets/design/new_gem_concepts/option-1-candy-lumina-relics.png` | Premium candy relics, strong silhouette variety, ornate specials |
| 2 | `assets/design/new_gem_concepts/option-2-prismatic-toy-stones.png` | Chunky toy-like translucent stones, best small-size readability |
| 3 | `assets/design/new_gem_concepts/option-3-arcane-mineral-charms.png` | Magical carved mineral charms, strongest IP distance |
| 3c | `assets/design/new_gem_concepts/option-3c-arcane-mineral-charms-size-spacing-only.png` | Option 3 direction preserved, with size and spacing normalized |
| 3d specials | `assets/design/new_gem_concepts/option-3d-specials-square-cell-fit.png` | Option 3 special gems revised to fill `128x128` cells without bar-like silhouettes |

| 1 board | `assets/design/new_gem_concepts/option-1-board-scale-preview.png` | Option 1 board-scale preview |
| 2 board | `assets/design/new_gem_concepts/option-2-board-scale-preview.png` | Option 2 board-scale preview |
| 3 board | `assets/design/new_gem_concepts/option-3-board-scale-preview.png` | Option 3 board-scale preview |
| 3b | `assets/design/new_gem_concepts/option-3b-arcane-mineral-charms-size-balanced.png` | Option 3 size-balanced charms |
| 3b board | `assets/design/new_gem_concepts/option-3b-board-scale-preview.png` | Option 3b board-scale preview |
| 3c board | `assets/design/new_gem_concepts/option-3c-board-scale-preview.png` | Option 3c board-scale preview |
| 3d strip | `assets/design/new_gem_concepts/option-3d-specials-384x128-preview.png` | Option 3d specials 384x128 strip |

## Review

### Option 1: Candy Lumina Relics

Best for: a polished Korean casual puzzle identity with premium charm.

Strengths:

- Strongest normal-gem silhouette spread among the readable options.
- Good color separation and strong visual identity.
- Moves away from classic faceted gem language.

Risks:

- Special gems are over-ornate for `128x128` cells.
- Gold frames may become noisy once scaled down in-game.

Verdict: good candidate, but simplify special gems before production.

### Option 2: Prismatic Toy Stones

Best for: immediate mobile readability and broad casual appeal.

Strengths:

- Clearest at small size.
- Simple material language, easy to convert into clean sprite cells.
- Most practical for fast replacement of the normal gem sheet (`Jewel_Arcane.png` in the current runtime).

Risks:

- Some special-gem stripe language still feels close to common match-3 conventions.
- Needs stronger brand specificity so it does not become generic candy-game art.

Verdict: safest production base for normal gems; redesign specials.

### Option 3: Arcane Mineral Charms

Best for: maximum IP distance and a more original fantasy identity.

Strengths:

- Least similar to Bejeweled-style gemstone cuts.
- Carved charm language is distinctive.
- Special gems can become a clear Stone Match signature if simplified.

Risks:

- Rune and crack details may collapse at board scale.
- The overall mood is heavier than the current candy-lumina UI.

Verdict: strongest originality. The original concept direction should be preserved; only size, spacing, and cell fit should be corrected.

### Option 3c: Arcane Mineral Charms, Size/Spacing Pass

Best for: the selected direction for the next sprite-production pass.

Strengths:

- Keeps the original Option 3 carved mineral/rune-stone feel.
- Improves optical size consistency across the normal gems.
- Keeps the rough stone silhouettes and avoids the over-ornate equipment look from the rejected 3b pass.

Risks:

- The horizontal special gem remains wider by design; when composing a special sheet, it should still be centered in a `128x128` cell and reviewed in-game.
- Fine rune grooves may need simplification after actual 128px alpha extraction.

Verdict: current preferred visual target.

### Option 3d Specials: Square Cell Fit

Best for: replacing the vertical, horizontal, and bomb special gems without wasting space inside `128x128` cells.

Strengths:

- Solves the long-bar problem from 3c specials: the outer silhouette fills the square cell, while the inner rune/light channel communicates vertical or horizontal effect.
- Preserves the Option 3 carved mineral charm style.
- The special-sheet preview should keep each special gem readable as its own silhouette.

Risks:

- The internal rune glow may need simplification after alpha extraction so it does not become noisy in-game.

Verdict: use this as the special-gem direction paired with 3c normal gems.

## Recommendation

Proceed with Option 3c as the visual target. Keep the Option 3 concept language intact and enforce only production geometry: consistent size, consistent padding, and clean cell fit.

Production constraints for the next pass:

- Generate each normal gem as an isolated `128x128` transparent-ready cell.
- Keep one bold internal motif per gem, not multiple tiny grooves.
- Preserve the carved mineral charm/rune-stone look from Option 3c.
- Do not add gold hardware, vines, straps, mechanical parts, badges, or framed equipment details.
- Avoid classic faceted diamond/triangle/octal silhouettes where possible.
- Use the 3d special-gem approach: broad square-cell-filling outer silhouettes, with vertical/horizontal behavior shown by the inner rune/light channel instead of by a long bar-shaped gem.
- Use `sprite-gen`-style QA before integration: alpha cleanup, per-cell extraction, normal/special sheet composition, and in-game screenshot review.

## Next Sprite-Gen Plan

The final asset pass should create a new run folder, for example:

```text
assets/generated/sprites/new_gems/
```

Expected deliverables:

- `sprite-request.json`
- isolated transparent gem frames
- composed normal gem sheet candidate, 7 cells, `896x128`
- composed special gem sheet candidate, frame-count per current runtime sheet
- QA contact sheet
- in-game board screenshot comparison


---

# 설정 화면과 버전 표시

원문 제목 키: 이 팩 UI Spec의 설정/버전 표시 절 (이 파일에 흡수됨)

# 설정 화면과 타이틀 하단 버전 표시

Stone Match는 Drawer를 쓰지 않는다. 설정 항목은 `SettingView`에 있고, 앱 버전은 **타이틀 화면 하단**의 `TitleVersionFooter`에 표시된다.

## 현재 구조

| 영역 | 파일 | 내용 |
|------|------|------|
| 설정 화면 | `lib/views/setting_view.dart` | 화면 켜짐, FPS 표시, 사운드, 평점 남기기, 언어 |
| 설정 섹션 | `lib/views/settings/settings_sections.dart` | Riverpod 구독, 볼륨 draft/commit, RateApp |
| 타이틀 하단 버전 표시 | `lib/views/title/title_version_footer.dart` | `Ver <version>+<buildNumber>` |
| 버전 캐싱 | `lib/views/title_view.dart` | `PackageInfo.fromPlatform()` 결과 캐싱 |

## 버전 관리

`pubspec.yaml`의 `version`이 앱 버전과 빌드 번호의 기준이다.

```yaml
version: 1.0.0+1
```

| 구분 | 예 | 쓰임 |
|------|----|------|
| version name | `1.0.0` | 사용자·스토어 노출 |
| build number | `1` | Android `versionCode`, iOS `CFBundleVersion` |

스토어에 같은 version name으로 다시 올리더라도 build number는 이전 업로드보다 커야 한다.

## 설정 화면 변경 규칙

1. 새 설정은 `SettingsNotifier` 또는 명확한 서비스 계층에 상태를 둔다.
2. 저장소 키는 `lib/app_config.dart`의 `StorageKeys`에 추가한다.
3. UI는 `settings_sections.dart`에 섹션 단위로 배치한다.
4. 다국어 문구는 `assets/translations/*.json`에 동시에 추가한다.
5. 웹 미지원 기능은 `kIsWeb` 분기로 숨긴다. 현재 평점 남기기는 웹에서 숨긴다.

FPS 표시는 설정에서 켜고 끌 수 있으며 기본값은 꺼짐이다. 좁은 화면에서는 하단 광고 영역 위 우측, 넓은 화면에서는 중앙 앱 프레임 바깥 하단에 표시한다. 웹 QA에서는 `?fps=1` 또는 `?qaPerf=1`로 설정과 무관하게 강제 표시할 수 있다.

## 타이틀 하단 버전 표시 변경 시 체크

- `package_info_plus` 의존성 유지
- `TitleView._cachedPackageInfo` 캐싱 유지
- 버전 표기가 레이아웃을 밀지 않는지 타이틀 화면에서 확인
- 스토어 릴리즈 전 `pubspec.yaml` 버전 증가 여부 확인


---

# 인앱 리뷰

원문 제목 키: 이 팩 UI Spec의 인앱 리뷰 절 (이 파일에 흡수됨)

# 인앱 리뷰 정책과 구현

Stone Match는 `in_app_review` 패키지를 사용한다. 채널별 정책은 **`store_channel_branching.md`**를 따른다.

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


---

# 온보딩 튜토리얼 후보

원문 제목 키: 이 팩 UI Spec의 온보딩 튜토리얼 절 (이 파일에 흡수됨)

# 온보딩 튜토리얼 도입 메모

Stone Match에는 현재 `showcaseview` 의존성이 없다. 이 문서는 나중에 단계별 온보딩을 도입할 때의 제약과 적용 후보를 정리한 기술 메모다.

## 도입 후보

| 화면 | 안내 후보 |
|------|-----------|
| 타이틀 | 무한/레벨/타임 모드 차이, 설정, 랭킹 |
| 게임 | 스왑, 특수 보석 생성, 힌트, 일시정지 |
| 설정 | 사운드, 언어, 화면 켜짐, 평점 남기기 |

## 핵심 제약

튜토리얼 단계 중에는 라우트 이동, 다이얼로그, 바텀시트, 오버레이 전환을 섞지 않는 편이 안전하다. Spotlight 대상 위젯은 같은 화면 트리에 안정적으로 존재해야 한다.

Stone Match는 `GameWidget`과 Flame 캔버스가 중심이므로, 캔버스 내부 셀을 직접 `GlobalKey`로 감싸는 방식은 맞지 않는다. 게임 튜토리얼은 Flutter 오버레이 또는 Flame HUD 안내로 별도 설계하는 편이 낫다.

## 구현 원칙

1. Flutter 위젯 대상만 `showcaseview`로 감싼다.
2. Flame 보드 내부 안내는 별도 오버레이 컴포넌트로 구현한다.
3. 튜토리얼 완료 여부는 `shared_preferences` 키로 저장한다.
4. 모든 문구는 `assets/translations/*.json`에 둔다.
5. “다시 보기”는 설정 화면에 배치한다.

## 도입 전 체크리스트

- [ ] `showcaseview` 최신 버전과 Flutter SDK 호환성 확인
- [ ] 튜토리얼 대상이 라우트 전환 없이 같은 화면에 존재하는지 확인
- [ ] 게임 중 튜토리얼이 입력 처리와 충돌하지 않는지 확인
- [ ] 첫 실행 자동 시작 여부와 설정의 다시 보기 UX 결정


---

# UI 참고 이미지

이 팩 경로. 앱 런타임 에셋이 아니다.

- [01_title_screen.png](assets/reference_images/01_title_screen.png)
- [02_pause_popup.png](assets/reference_images/02_pause_popup.png)
- [03_countdown.png](assets/reference_images/03_countdown.png)
- [04_gameplay.png](assets/reference_images/04_gameplay.png)
- [05_button_spacing.png](assets/reference_images/05_button_spacing.png)
- [06_button_color_guide.png](assets/reference_images/06_button_color_guide.png)
- [07_start_text.png](assets/reference_images/07_start_text.png)
- [08_clear_screen.png](assets/reference_images/08_clear_screen.png)
- [09_clear_screen_2.png](assets/reference_images/09_clear_screen_2.png)
- [대표이미지5.png](assets/reference_images/대표이미지5.png)
- [텍스트가이드.png](assets/reference_images/텍스트가이드.png)
- [텍스트가이드1.png](assets/reference_images/텍스트가이드1.png)
- [텍스트가이드3.png](assets/reference_images/텍스트가이드3.png)

### 레벨 클리어 마무리
- 남은 보석 위치를 따라 좌상단에서 우하단으로 빛과 파편이 순차 재생된다. 일반 축하 3000ms 후 기존 결과 흐름으로 이동하고 동작 줄이기에서는 즉시 이동한다. 게임 시간과 점수는 정지 상태를 유지한다.
