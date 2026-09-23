# AGENTS.md

Stone Match는 Flutter와 Flame 기반 8×8 매치 3 퍼즐 게임이다.

이 폴더의 문서를 기준으로 작업한다. 폴더 밖 문서 트리를 읽기 순서에 넣지 않는다.

## 작업 전

1. [progress/PROJECT_STATUS.md](progress/PROJECT_STATUS.md) 확인
2. [progress/HANDOFF.md](progress/HANDOFF.md) 확인
3. [progress/ROADMAP.md](progress/ROADMAP.md)에서 Phase만 확인. 현재 Task는 Status에 있다
4. Active Plan이 있으면 [plans/](plans/)에서 해당 PLAN을 읽는다
5. 관련 Product / UI / Tech Spec 확인
6. 관련 기존 코드와 테스트 확인
7. 이관 중이면 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) 확인. 기존 문서를 요약본으로 바꾸지 않는다.

항상 한국어로 간결하게 답하고 결과를 먼저 말한다.

## 기본 원칙

- 현재 코드와 테스트를 오래된 세션, 계획, 체크리스트보다 우선한다.
- 기존 Architecture와 패턴을 우선하고, 가장 작은 변경으로 처리한다.
- 요구하지 않은 기능, dependency, refactoring을 임의로 추가하지 않는다.
- 명세와 코드가 충돌하면 조용히 한쪽을 고치지 말고 충돌과 정본을 명시한다.
- Secret, API Key, 관리자 토큰, 키스토어 비밀번호를 코드나 문서에 기록하지 않는다.
- 사용자 변경사항과 미추적 파일을 덮어쓰거나 임의로 삭제하지 않는다.
- 사용자에게 보이는 문구에는 중간점 문자를 사용하지 않는다. 구분은 쉼표, 괄호, 줄바꿈을 사용한다.
- 임시 산출물은 레포 루트가 아니라 tmp/ 아래의 작업별 폴더에 둔다.
- 완료 전 변경 범위에 맞는 검증을 실행하고, 실행하지 못한 검증은 통과했다고 말하지 않는다.
- 문서는 요약본이 아니다. 규칙, 예외, 수치, 명령, 체크리스트의 세부 수준을 유지한다.
- 명세와 코드가 충돌하면 문서를 코드에 맞추기 전에 의도를 확인한다. 확정 불가면 DOC-CODE-MISMATCH / NEEDS-DECISION.

## 제품 계약 (자주 깨지는 항목)

- 외부 표시명은 Stone Match 또는 제출물 표기 STONE MATCH다.
- 진행 랭킹은 완료한 레벨 수다. [ADR-002](decisions/ADR-002-ranking-completed-levels.md), BR-001
- TimeUp 진입 또는 일시정지 나가기에서 제출한다. Pause 나가기는 await, TimeUp 나가기는 기다리지 않는다. BR-093, [ADR-007](decisions/ADR-007-ranking-submit-timing.md)
- 랭킹 장애가 플레이/나가기를 막지 않는다. BR-002
- NAS 랭킹 `matchranking/ranking.php`는 2026-09-24 폐기해 저장소에서 제거했다. 새로 만들거나 빌드와 ZIP에 넣지 않는다.
- 게임 내 랭킹, 보충 광고 제한, 이벤트 로그의 저장소는 Supabase다(ADR-009). secret/service_role 키는 어디에도 두지 않고, 공개용 키와 URL은 Git 제외 파일 config/supabase.json으로만 넣는다.
- 운영 랭킹 초기화는 승인, 백업, dry-run, 예상 건수, 사후 조회 순서다.
- Riverpod codegen을 새로 도입하지 않는다.
- 실시간 HUD는 Flame 구성요소를 우선한다.
- 게임 방향 개편(ADR-008, PLAN-005)은 제안 상태다. Accepted와 해당 결정(D1~D10) 전에는 ADR-001 특수 보석 규칙과 ADR-007 제출 시점을 바꾸지 않는다.

## Plan 사용 규칙

- 현재 작업에 활성 PLAN이 있으면 구현 전에 읽는다.
- Roadmap에 상세 구현을 넣지 않는다.
- 복잡한 작업은 구현 전에 PLAN을 만들거나 갱신하고, 단순 작업은 PLAN을 강제하지 않는다.
- 구현 중 계획이 달라지면 PLAN을 현실과 일치하게 갱신한다. 진행률은 PROJECT_STATUS와 HANDOFF에 둔다.
- PLAN의 중요한 장기 기술 결정은 ADR로 분리한다.


## 코드 변경 시 문서 동기화

코드 변경으로 계약이 바뀌면 같은 작업에서 관련 문서를 갱신한다.

    WHAT 변경 → PRODUCT_SPEC
    SCREEN 변경 → UI_UX
    HOW 변경 → TECH_SPEC
    WORKFLOW 변경 → DEVELOPMENT_WORKFLOW
    중요한 WHY 변경 → ADR
    현재 상태 변경 → PROJECT_STATUS
    다음 작업 변경 → TASK / ROADMAP
    인계 정보 변경 → HANDOFF

확정할 수 없으면 DOC-CODE-MISMATCH / NEEDS-DECISION으로 남기고 필요하면 ADR을 만든다.

## 완료 조건

- 구현만 끝났다고 DONE 처리하지 않는다.
- Acceptance Criteria와 필요한 테스트를 확인한다.
- 변경된 계약이 있으면 이 폴더의 기준 문서를 갱신한다.
- Project Status와 Handoff를 최신화한다. 인수인계에는 변경된 계약과 검증 상태를 남긴다.
- 문서만 바꾼 경우 링크, 형식, diff 검증으로 충분하다. 코드 변경은 관련 테스트와 필요 시 analyze/빌드.

## 문서 경계

- WHY / WHAT → [01_PRODUCT_SPEC.md](01_PRODUCT_SPEC.md)
- SCREEN / UX → [02_UI_UX.md](02_UI_UX.md)
- HOW / DATA / API → [03_TECH_SPEC.md](03_TECH_SPEC.md)
- PROCESS → [04_DEVELOPMENT_WORKFLOW.md](04_DEVELOPMENT_WORKFLOW.md)
- PHASE → [progress/ROADMAP.md](progress/ROADMAP.md)
- HOW THIS WORK → [plans/](plans/)
- NOW / TASK → [progress/PROJECT_STATUS.md](progress/PROJECT_STATUS.md)
- CONTINUE FROM HERE → [progress/HANDOFF.md](progress/HANDOFF.md)
- 중요한 기술 결정의 WHY → [decisions/](decisions/)
- 기존 문서 이관 → [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
