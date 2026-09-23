# Stone Match — Project Team Docs

표준형(Standard) 구성이다. 이 폴더만으로 명세와 진행 상태를 읽는다.
코드와 테스트가 사실이다. 이 폴더 밖의 문서 트리를 기준으로 쓰지 않는다.
기존 주제 문서의 본문은 요약이 아니라 해당 표준 파일 하단에 그대로 흡수했다. Product/UI/Tech/Workflow/PLAN-001만으로 대체 열람한다.

작성 기준일: 2026-08-23

이 팩은 기존 문서 이관 경로다. 신규 작성과 섞지 않는다. 이관 절차는 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)다.
현재 이관 단계: 대체 가능(REPLACEABLE). 정본은 이 docs/ 팩이다. 이전 주제 문서는 archive/docs/에 있다. 이는 현재 릴리즈 준비가 모두 PASS라는 뜻이 아니다.

문서는 요약본이 아니다. 규칙, 예외, 수치, 명령, 체크리스트는 실제 작업에 쓸 수 있는 수준으로 둔다.

## 문서 구조

    .
    ├── AGENTS.md
    ├── README.md
    ├── 01_PRODUCT_SPEC.md
    ├── 02_UI_UX.md
    ├── 03_TECH_SPEC.md
    ├── 04_DEVELOPMENT_WORKFLOW.md
    ├── MIGRATION_GUIDE.md
    ├── plans/
    │   ├── PLAN_TEMPLATE.md
    │   ├── PLAN-001-mobile-web-audio-fps.md
    │   ├── PLAN-002-ad-daily-limit-persist.md
    │   ├── PLAN-003-persistent-inventory.md
    │   ├── PLAN-004-board-juice.md
    │   ├── PLAN-005-blitz-modernized-direction.md
    │   └── PLAN-006-supabase-backend.md
    ├── progress/
    │   ├── ROADMAP.md
    │   ├── PROJECT_STATUS.md
    │   └── HANDOFF.md
    ├── release/
    │   └── PRIVACY_POLICY_DRAFT.md
    └── decisions/
        ├── ADR_TEMPLATE.md
        └── ADR-xxx.md

## 정본

| 질문 | 기준 문서 |
|---|---|
| 무엇을 왜 만드는가? | [01_PRODUCT_SPEC.md](01_PRODUCT_SPEC.md) |
| 화면과 사용자 흐름은? | [02_UI_UX.md](02_UI_UX.md) |
| 어떤 구조/데이터/API로 만드는가? | [03_TECH_SPEC.md](03_TECH_SPEC.md) |
| 어떻게 작업하고 검증하는가? | [04_DEVELOPMENT_WORKFLOW.md](04_DEVELOPMENT_WORKFLOW.md) |
| 프로젝트가 어떤 큰 단계로 진행되는가? | [progress/ROADMAP.md](progress/ROADMAP.md) |
| 이번 기능/복합 작업을 어떻게 구현하는가? | [plans/](plans/) |
| 지금 어디까지 왔고 현재 Task는 무엇인가? | [progress/PROJECT_STATUS.md](progress/PROJECT_STATUS.md) |
| 다음 작업자가 무엇을 이어받는가? | [progress/HANDOFF.md](progress/HANDOFF.md) |
| 왜 중요한 기술 결정을 했는가? | [decisions/](decisions/) |
| 개인정보처리방침과 스토어 데이터 표기는? | [release/PRIVACY_POLICY_DRAFT.md](release/PRIVACY_POLICY_DRAFT.md) (법률 검토 전 초안) |
| 기존 문서를 어떻게 이관하는가? | [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) |

## Roadmap → Plan → Task
- Roadmap: Phase/Milestone만
- Plan: 복잡한 작업의 구현 전략. 모든 Task에 강제하지 않는다
- Task: Plan을 나눈 실행 단위. 이 구성에서는 PROJECT_STATUS 안에서 관리한다

## AI가 읽는 순서

기획: README → PRODUCT_SPEC → UI_UX → TECH_SPEC → DEVELOPMENT_WORKFLOW → ROADMAP

개발: AGENTS → PROJECT_STATUS → HANDOFF → 활성 PLAN → 관련 명세 → 코드

작업 종료: 검증 → PLAN/Task 상태 → PROJECT_STATUS → HANDOFF → ADR(필요 시)

이관: MIGRATION_GUIDE를 먼저 읽고, 기존 문서를 요약본으로 바꾸지 않는다.

## 기존 주제 문서 흡수 위치

요약이 아니라 본문을 표준 파일 하단에 붙였다.

| 기존 주제 | 이 팩에서 읽는 파일 |
|---|---|
| architecture/game_flow, special_gems, progression_score | 01_PRODUCT_SPEC.md |
| planning 아이템/보상/광고/하단패널/아이콘 프롬프트, 스토어 메타 | 01_PRODUCT_SPEC.md |
| DESIGN, 보석 디자인 검토, 설정/리뷰/튜토리얼 | 02_UI_UX.md |
| architecture/code-flow, 랭킹, 채널, 웹오디오, gradle, web build, SFX 프롬프트 | 03_TECH_SPEC.md |
| agent_work_rules, 테스트/배포 명령, 릴리즈, iOS 프로필, 실행 체크리스트 | 04_DEVELOPMENT_WORKFLOW.md |
| performance 인계와 FPS 계측 계획 | plans/PLAN-001-mobile-web-audio-fps.md |

문서 전용 PNG는 `assets/` 아래 이 팩 안에 있다. 앱 런타임 `assets/images` 스프라이트는 복사하지 않았다.

## 이미지 폴더

표준 팩 안에 둔다. 다른 문서 트리를 가리키지 않는다.

    assets/
    ├── design/new_gem_concepts/   # 보석 콘셉트 PNG 12
    ├── reference_images/         # UI 참고 스크린샷 13
    └── release/intoss/           # Apps in Toss 로고·스크린샷 6

## 이관 기준

요약 이전이 아니다. 기존 주제 문서의 표, 명령, 체크리스트, 산식, 프롬프트, 화면 규칙을 표준 파일 하단에 본문 그대로 붙였다. 걷어낸 것은 다른 파일을 가리키던 상대 링크뿐이고, 그 내용은 이미 같은 팩 안에 있다.

`docs/README.md`의 문서 맵은 파일 목록이라 이 팩의 흡수 위치 표로 대체한다. 맵에 있던 용도 문장은 아래와 같다.

| 용도 | 이 팩에서 읽는 곳 |
|---|---|
| 에이전트 작업 시 제품 문구, 랭킹, 배포, 제출물 기준 | 04_DEVELOPMENT_WORKFLOW.md 하단 에이전트 작업 기준 |
| 진행·배포 체크리스트 | 04_DEVELOPMENT_WORKFLOW.md 하단 실행·배포 체크리스트 |
| 앱 초기화, 화면, Flame 계층, 주요 파일 역할 | 03_TECH_SPEC.md 하단 코드 흐름 분석 |
| 매치-3 규칙, 모드, 오버레이 흐름 | 01_PRODUCT_SPEC.md 하단 게임 플로우 |
| 특수 보석 생성, 탭 발동, 연쇄, 하이퍼 처리 규칙 | 01_PRODUCT_SPEC.md 하단 특수 보석 룰 |
| 진행 모드 레벨별 목표 점수 산식 | 01_PRODUCT_SPEC.md 하단 진행 모드 목표 점수 |
| 아이템 슬롯, 인벤토리, 보상형 광고, 선택형 코인/인앱 플랜 | 01_PRODUCT_SPEC.md 하단 아이템 플랜 |
| 레벨 클리어 후 스테이지 아이템 보상 지급 규칙 | 01_PRODUCT_SPEC.md 하단 스테이지 보상 체계 |
| 아이템 슬롯·인벤토리 단계별 구현 체크리스트 | 04_DEVELOPMENT_WORKFLOW.md 하단 아이템 구현 체크리스트 |
| 무한 모드 하단 패널과 QA 노출 정책 | 01_PRODUCT_SPEC.md 하단 무한 모드 하단 패널 |
| 주요 테스트, 로컬 실행, Web/NAS/Apps in Toss 빌드와 배포 명령 | 04_DEVELOPMENT_WORKFLOW.md 하단 테스트·빌드·배포 명령 |
| Web 릴리즈 빌드, /match/ base-href, 배포 절차 | 03_TECH_SPEC.md 하단 Web 빌드 |
| 랭킹 데이터 백업, 초기화, 복원 절차 | 03_TECH_SPEC.md 하단 랭킹 서버 운영 |
| 클라이언트 제출값, 제출 시점, HUD 타임 전용 계약 | 03_TECH_SPEC.md 하단 랭킹 클라이언트 계약 |
| Android Gradle/Kotlin DSL 설정 | 03_TECH_SPEC.md 하단 Android Gradle 설정 |
| iOS 프로필 빌드와 실기기 설치 | 04_DEVELOPMENT_WORKFLOW.md 하단 iOS 프로필 빌드 |
| 설정 화면 구조와 타이틀 하단 버전 표시 정책 | 02_UI_UX.md 하단 설정 화면과 버전 표시 |
| SFX·BGM 생성 프롬프트와 코드 매핑 | 03_TECH_SPEC.md 하단 SFX·BGM 프롬프트 |
| Flutter Web + Flame 오디오 정책과 회귀 대응 | 03_TECH_SPEC.md 하단 웹 오디오 정책 |
| Supertonic TTS 임시 SFX 생성 방법 | 03_TECH_SPEC.md 하단 Supertonic TTS SFX |
| 온보딩 튜토리얼 도입 후보와 제약 | 02_UI_UX.md 하단 온보딩 튜토리얼 후보 |
| Google Play / App Store / Web 출시 체크리스트 | 04_DEVELOPMENT_WORKFLOW.md 하단 릴리즈 체크리스트 |
| Android AAB/APK, iOS IPA, Web 릴리즈 빌드 | 04_DEVELOPMENT_WORKFLOW.md 하단 릴리즈 빌드 |
| 광고 위치, 보상, 미디에이션 공통 정책 | 01_PRODUCT_SPEC.md 하단 광고 노출과 보상 정책 |
| 스토어 채널 분기와 빌드 상태 | 03_TECH_SPEC.md 하단 스토어 채널 분기 |
| Play/App Store 등록 메타데이터 초안 | 01_PRODUCT_SPEC.md 하단 스토어 메타 Play/App Store |
| One Store/Apps in Toss 등록 메타데이터와 출시 자료 | 01_PRODUCT_SPEC.md 하단 스토어 메타 One Store/Apps in Toss |
| 마켓 스크린샷 문구 KO/EN | 01_PRODUCT_SPEC.md 하단 스크린샷 카피 |
| 인앱 리뷰 정책과 현재 구현 | 02_UI_UX.md 하단 인앱 리뷰 |
| 제품 UI 톤과 디자인 원칙 | 02_UI_UX.md 하단 디자인 원칙 |
| 새 보석 시각 방향 검토 | 02_UI_UX.md 하단 새 보석 디자인 검토 |
| FPS 드롭 계측 계획 | plans/PLAN-001 하단 FPS 드롭 계측 계획 |
| Flutter Flame 모바일 웹 성능과 오디오 최적화 인계 | plans/PLAN-001 하단 성능 인계 |

참고 이미지 폴더는 `assets/design/new_gem_concepts/`, `assets/reference_images/`다. 옛 맵의 `screenshots/` 폴더는 원본에도 없다.
