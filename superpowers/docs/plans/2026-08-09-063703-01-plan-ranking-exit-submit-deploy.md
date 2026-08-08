# 랭킹 종료 저장 수정과 NAS 배포

**Goal:** 유효한 진행 모드 기록과 타임 모드 점수를 수동 종료 또는 제한 시간 종료 시 한 번 저장하고 수정 빌드를 NAS에 배포한다.
**Why planning is required:** 공개 NAS 배포가 외부 서비스 상태를 변경한다.
**Acceptance:** 빈 진행 모드 기록은 제출하지 않고, 레벨 2 이상 도달 기록은 점수가 0이어도 유효하며, 수동 종료는 제출 완료 뒤 타이틀로 이동한다. 관련 테스트와 전체 분석 및 테스트가 통과해야 한다. 기준 리비전은 `1d33611`이며 배포 전 diff와 대상 URL을 확인한다. 배포 후 지정 파일 8개의 로컬 및 원격 SHA-256이 모두 같고 공개 진입점이 200이며 `match.zip`이 404여야 한다. 배포 실패나 해시 불일치 시 중단하고 기준 리비전에서 같은 배포 스크립트를 다시 실행해 복구할 수 있어야 한다.

### Outcome 1: 종료 시 랭킹 기록 보존 ✅
- Work: `rankingScore`가 빈 레벨 1과 이미 한 단계 이상 통과한 기록을 구분하고, 일시 정지 메뉴가 기존 `RankingNotifier`로 제출을 기다린 뒤 이동한다. 중복 클릭은 기존 제출 상태로 차단한다.
- Verify: `flutter test test/widget_test.dart test/pause_menu_overlay_test.dart`

### Outcome 2: 회귀 검증 ✅
- Work: 관련 테스트 이후 전체 정적 분석과 테스트로 기존 종료 및 랭킹 흐름의 회귀를 확인한다.
- Verify: `flutter analyze && flutter test`

### Outcome 3: NAS 배포와 원격 일치 확인 ⬜
- Work: 저장소의 `tools/deploy_match_web.sh`만 사용해 `https://cheng80.myqnapcloud.com/match/`에 배포한다. 비밀값은 출력하지 않는다.
- Risks/open questions: 배포 스크립트는 자동 백업을 만들지 않는다. 문제가 생기면 기준 리비전 `1d33611`에서 재배포한다. 해시 불일치, 공개 진입점 비정상, 업로드 ZIP 잔존 중 하나라도 발생하면 성공으로 보고하지 않는다.
- Verify: `nas-web-build` 스킬의 8개 해시 비교, 공개 진입점 확인, `match.zip` 404 확인
