# 랭킹 제출 재시도 배포

**Goal:** 랭킹 서버의 일시 장애로 기록 저장에 실패한 사용자가 종료 화면에서 같은 기록을 다시 제출할 수 있게 하고 NAS Web에 배포한다.
**Why planning is required:** GitHub 병합과 운영 NAS 정적 파일 교체가 포함된다.
**Acceptance:** 관련 테스트와 Web 빌드가 통과한 변경만 한국어 PR로 병합한다. 배포 직전 대상 `main`과 공개 주소 상태를 확인하고, 배포 후 공개 파일 해시와 HTTP 상태를 검증한다. 중단 시 기존 원격 `main`을 다시 빌드해 같은 배포 스크립트로 복구할 수 있어야 한다.

### Outcome 1: 검증된 변경을 main에 통합
- Work: `codex/ranking-submit-retry`의 랭킹 실패 상태, 종료 화면 재시도 버튼, 번역과 회귀 테스트만 커밋한다. 기존 로컬 `main`의 미게시 커밋을 먼저 fast-forward push한 뒤 PR을 생성하고 squash merge한다.
- Risks/open questions: 인증 실패, 원격 `main` 선행, 충돌, 테스트 실패 또는 병합 불가 상태에서는 중단한다.
- Verify: `flutter test && flutter analyze`

### Outcome 2: 병합된 main을 NAS Web에 배포
- Work: 깨끗하고 원격과 동기화된 `main`에서 `tools/deploy_match_web.sh`를 실행한다. 배포 토큰은 출력하지 않고 환경 설정 존재 여부만 확인한다.
- Risks/open questions: 배포 스크립트는 기존 `/match`를 교체하므로 업로드 실패 시 배포 직전 `origin/main`을 다시 빌드해 재배포한다.
- Verify: 공개 URL HTTP 상태, COOP/COEP와 Wasm MIME 헤더, 주요 정적 파일의 로컬·원격 SHA-256 일치, `match.zip` 제거 상태를 확인한다.
