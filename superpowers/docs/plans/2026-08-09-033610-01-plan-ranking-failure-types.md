# 랭킹 실패 유형 구분

**Goal:** Stone Match 랭킹의 404, 조회 실패, 저장 실패, 연결 실패를 구분하고 서버 저장 실패나 동시 등록에도 기존 랭킹 데이터를 보존한다.
**Why planning is required:** Flutter 클라이언트와 PHP 서버의 공개 응답 계약 및 파일 기반 랭킹 데이터 쓰기 경계가 함께 바뀐다.
**Acceptance:** 실패 유형별 응답과 번역 문구가 구분되고, 실제 빈 랭킹은 빈 상태로 유지되며, 랭킹 장애가 게임 진행·재시작·나가기를 막지 않는다. 서버는 기존 데이터 파일을 직접 덮어쓰기 전에 완전한 임시 파일을 만들고 모드별 잠금 안에서 `load → 판정 → save`를 수행한다. 운영 배포와 운영 데이터 변경은 하지 않는다.

### Outcome 1: 타입 있는 클라이언트 실패 계약
- Work: `lib/services/ranking_service.dart`가 기존 `http` 패키지의 `Client`를 사용해 정상 결과와 `notFound`, `loadFailed`, `saveFailed`, `unavailable`을 구분한다. `fetchTop1`, `fetchList`, `submit`의 공개 결과 형식을 일관되게 바꾼다.
- Verify: `flutter test test/ranking_service_test.dart`

### Outcome 2: 빈 랭킹과 장애 UI 구분
- Work: `lib/widgets/ranking_list_popup.dart`, `lib/vm/ranking_notifier.dart`, `lib/views/overlays/time_up_overlay.dart`와 5개 번역 파일에서 목록 조회와 제출 실패 유형별 문구를 표시한다. 닫기·재시작·나가기 흐름은 변경하지 않는다.
- Verify: `flutter test test/ranking_service_test.dart && flutter analyze`

### Outcome 3: 원자적 서버 저장과 모드별 제출 잠금
- Work: `matchranking/ranking.php`가 파일 없음만 빈 목록으로 처리하고 읽기·잠금·JSON 파싱 실패는 `ranking_load_failed`, 저장 실패는 `ranking_save_failed`로 HTTP 500 응답한다. 같은 디렉터리의 임시 파일을 완전히 쓴 뒤 `rename`하고, `time`과 `level`별 잠금 파일로 제출의 읽기·판정·저장을 보호한다.
- Risks/open questions: 로컬 PHP 실행기가 없어 문법 검사와 동시성 실행 검증은 수행할 수 없다. 정적 diff 검토만 하고 배포하지 않는다.
- Verify: `git diff --check && git diff -- matchranking/ranking.php`

### Outcome 4: 최종 회귀 검증과 독립 커밋
- Work: 집중 테스트, 정적 분석, 전체 테스트와 최종 diff를 확인하고 관련 변경만 한국어 커밋 하나로 기록한다.
- Risks/open questions: Flutter SDK는 프로젝트 문서 기준 `3.44.0`이지만 현재 PATH는 `3.44.8`이다. 이 차이를 결과에 명시한다.
- Verify: `flutter analyze && flutter test && git diff --check && git status --short --branch`
