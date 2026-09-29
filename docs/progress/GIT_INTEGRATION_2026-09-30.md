# 2026-09-30 Git 통합 검토

## 게시 범위

사용자가 기존 게임 변경의 커밋, 푸시와 main 통합을 승인했다. 이전 인계의 커밋 금지는 이 승인 이전 이력이다. PocketBase 전환, 영속 이벤트 큐와 서버 집계, NAS Sentry 오류 수집, 선택 동의 GA4 및 관련 테스트와 문서를 게시한다. 기존 웹 오디오 무음 unlock 수정과 서식 변경도 보존한다.

## 검증

- Flutter 전체 테스트 622개 통과.
- PocketBase 0.39.7 로컬 통합 24개, importer 15개 통과.
- 웹 오디오 Node 테스트 3개 통과.
- backend define 42개, package scripts 11개, GA4 define/deploy/repo 검사, Sentry 빌드 도구 13그룹 통과.
- flutter analyze 통과. 임시 산출물 tmp/**를 분석에서 제외하고 기존 리뷰 서비스의 중괄호 경고 2건을 수정했다.
- release Wasm 및 JS fallback 웹 빌드 통과. 출력은 tmp/git-publish-20260930/web이며 이번 작업은 운영 재배포를 수행하지 않는다.
- 비밀 패턴 및 로컬 관리자 자격정보/DSN과 게시 파일의 값 대조 결과 일치 없음. .env와 운영 config는 Git 제외 유지.
- 게임 저장소에 GitHub Actions workflow와 main 보호 규칙이 없어 로컬 검증을 병합 근거로 사용한다.

## 기존 원격 브랜치 판정

codex/docs-agent-artifact-cleanup의 b0b8a2e는 main보다 116커밋 뒤처진 8월 9일 문서 변경이다. 고유 커밋은 1개다.

- .omo 제외 해제는 현재 .gitignore에 이미 반영돼 있다.
- START_HERE.md는 후속 9d21af0에서 폐기됐다. 다시 복원하지 않는다.
- docs/planning의 아이템/보상/진행 체크리스트는 표준 문서 팩으로 이관됐다. 현재 제품 계약, PLAN-003 및 코드/테스트가 정본이다.
- 구버전 스프라이트 경로, NAS PHP 랭킹과 당시 완료 상태는 현재 구현과 맞지 않는다. 과거 체크리스트의 미검증 사항을 현재 검증 결과로 사용하지 않는다.

자동 병합이나 cherry-pick은 오래된 문서를 복원하거나 현재 규칙을 후퇴시킬 수 있어 적용하지 않는다. 현행 문서에 추가할 독립 구현은 없다. 원격 브랜치는 이력 확인용으로 보존한다. 병합한 것처럼 처리하는 ours merge나 브랜치 삭제를 수행하지 않는다.

## 남은 범위

PLAN-010 계정 연결, PLAN-011 Step3 보고서와 native/intoss, 실기기/장시간 성능, 운영 cron 예약 시각 검증은 이번 Git 통합으로 완료되지 않는다. 대시보드는 독립 저장소의 ac6dac0 main에 이미 게시돼 있어 추가 변경하지 않는다.
