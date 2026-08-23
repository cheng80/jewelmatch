# AGENTS.md

Stone Match는 Flutter와 Flame 기반 8×8 매치 3 퍼즐 게임이다.

작업 진입은 [docs/AGENTS.md](docs/AGENTS.md)다. 정본은 docs/ 아래 표준형 문서 팩이다.

## 매 작업 필수 규칙

- 항상 한국어로 간결하게 답하고 결과를 먼저 말한다.
- 작업 전에 [docs/progress/PROJECT_STATUS.md](docs/progress/PROJECT_STATUS.md), [docs/progress/HANDOFF.md](docs/progress/HANDOFF.md), 관련 Spec을 확인한다.
- 현재 코드와 테스트를 사실 기준으로 삼고, 기존 구조를 재사용해 가장 작은 변경으로 처리한다.
- 사용자에게 보이는 문구에는 중간점 문자를 사용하지 않는다.
- 사용자 변경사항과 미추적 파일을 덮어쓰거나 임의로 삭제하지 않는다.
- 임시 산출물은 레포 루트가 아니라 `tmp/` 아래의 작업별 폴더에 둔다.
- 완료 전 변경 범위에 맞는 검증을 실행하고, 실행하지 못한 검증은 통과했다고 말하지 않는다.
- 비밀정보/API 키를 코드나 문서에 기록하지 않는다.
