# 랭킹 관리자 초기화

**Goal:** 인증된 관리자만 타임 또는 레벨 랭킹 한 종류를 미리 확인한 뒤 안전하게 초기화할 수 있게 한다.
**Why planning is required:** 운영 랭킹 데이터를 삭제하는 공개 API 변경이므로 인증 실패, 오조작, 동시 저장, 복구 가능성을 명시해야 한다.
**Acceptance:** `POST action=reset`만 허용하고 `time` 또는 `level` 한 모드만 처리한다. 토큰은 `/share/Web/.match_deploy.env`의 `MATCH_DEPLOY_TOKEN`과 `X-Ranking-Admin-Token` 헤더로만 비교하되 이 관리자 헤더를 CORS 허용 목록에는 추가하지 않는다. 토큰 설정이 없으면 reset만 503, 인증 실패는 401이다. 인증된 dry-run은 현재 건수만 반환하고 데이터를 바꾸지 않는다. 실제 초기화는 해당 모드 JSON을 사전에 NAS에서 백업하고 dry-run 건수를 필수 정수 `expectedCount`로 보낸 뒤 정확한 확인 문자열로만 실행한다. 모드 잠금 안에서 다시 읽은 건수가 다르면 409 `ranking_count_changed`, 로드 실패면 500으로 중단하며, 일치할 때만 빈 배열을 원자 저장한다. 실행 후 목록 0건과 다른 모드 무변경을 확인하고, 문제가 있으면 백업 JSON을 수동 복원한다. 토큰 값은 저장소, URL, body, 로그, 검증 출력에 남기지 않는다. 이 작업에서는 NAS 배포나 운영 데이터 초기화를 실행하지 않는다.

### Outcome 1: 관리자 전용 단일 모드 초기화
- Work: `matchranking/ranking.php`에 `reset` action을 추가한다. POST, 명시적 모드, 서버 직접 호출용 헤더 토큰, dry-run, 필수 정수 `expectedCount`, 정확한 확인 문자열, 기존 모드별 배타 잠금, 잠금 후 건수 재검증, 로드 실패 중단, `saveData(mode, [])`를 적용한다. CORS는 기존 `Content-Type`만 허용하고 기존 `list`, `top1`, `submit` 동작은 유지한다.
- Risks/open questions: 로컬에 PHP 실행 파일이 없어 lint와 실행 검증은 할 수 없다. 서버 적용 후 무인증 401, dry-run 건수, 실제 초기화와 다른 모드 무변경을 별도로 확인해야 한다.
- Verify: `rg -n "case 'reset'|X-Ranking-Admin-Token|hash_equals|dryRun|expectedCount|ranking_count_changed|RESET time|RESET level|saveData\(\$mode, \[\]\)" matchranking/ranking.php && git diff --check`

### Outcome 2: 백업과 복원 가능한 운영 절차
- Work: 운영 문서 한 곳에 JSON 사전 백업, 인증된 dry-run, 단일 모드 실제 초기화, 사후 건수 확인, 수동 복원, 토큰 미출력 주의를 기록한다.
- Risks/open questions: 백업과 복원은 NAS 파일 시스템에서 수동 수행하며 API 복원 기능은 만들지 않는다.
- Verify: `rg -n "백업|dry-run|RESET time|RESET level|복원|X-Ranking-Admin-Token" docs/tools/ranking_server.md`

### Outcome 3: 회귀와 보안 경계 검증
- Work: JSON 번역 파싱, Flutter 정적 분석과 테스트, PHP diff의 토큰 query/body 미지원 및 전체 초기화 부재를 검토한다. PHP 실행 불가 사실을 결과에 남긴다.
- Verify: `python3 -m json.tool assets/translations/en.json >/dev/null && flutter analyze && flutter test && git diff --check`
