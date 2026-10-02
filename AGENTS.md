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

## 자동화 테스트 요청

- 사용자가 "자동화 테스트 돌려줘"라고 하면 관련 스킬을 읽고 실행, 결과 확인, 발견한 문제 수정을 진행한다. 실행 방법은 `tools/PLAY_BOT.md`다.
- 에고를 지정했으면 ego-browser 스킬(`/Users/cheng80/.agents/skills/ego-browser/SKILL.md`)과 `npm run play:bot:ego`를 사용한다. 기존 TaskSpace는 같은 ID로 재개하며 사용자 제어 중단을 우회하지 않는다.
- 먼저 `npm run test:play-bot`와 변경 관련 테스트를 실행한다. 플레이 대상은 해당 작업에서 정한 URL을 사용한다. 대상이 정해지지 않은 일반 회귀 검증은 로컬/QA부터 진행하며 운영 GA4 전송은 명시적 운영 수집 확인 요청에 사용한다.
- 운영 플레이 봇은 화면 인식과 실제 포인터로 검증한다. `qaPerf=1`은 QA 환경으로 분류되므로 운영 GA4 수집 확인에 사용하지 않는다. 교환 시도만으로 성공을 보고하지 않고 보드 변화, 양수 종료 점수와 필요한 수집 결과를 확인한다.

## 운영 관리자 검증

- 운영 PocketBase 검증에는 `pocketbase/.local/remote-admin.env`(Git 제외0600)의 검증 전용 계정만 사용한다. 기존 소유자 관리자 암호 재설정과 소유자 계정 로그인 테스트를 하지 않는다. 등록용 `.env.pocketbase`로 fallback하지 않는다. 실행/백업/폐기 규칙은 `tools/pocketbase/VERIFICATION_ADMIN.md`다.
