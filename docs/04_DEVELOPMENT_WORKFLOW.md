# Development Workflow

> 개발 규칙과 문서 운영 방식을 한 문서로 관리한다.
> 이 폴더의 명세 / 로드맵 / 계획 / 현황 / 인수인계만 기준으로 읽는다.

작성 기준일: 2026-08-23

## 1. 기본 원칙

- 기존 Architecture와 코드 패턴을 우선한다.
- 요구하지 않은 기능, dependency, 대규모 refactoring을 임의로 추가하지 않는다.
- Secret/API Key를 코드나 문서에 기록하지 않는다.
- 명세와 코드가 충돌하면 조용히 한쪽을 선택하지 않는다.
- 현재 코드와 테스트를 오래된 체크리스트보다 우선한다.
- 사용자 문구에 중간점 문자를 쓰지 않는다.
- 임시 산출물은 tmp/<작업명>/ 아래. 레포 루트에 두지 않는다.
- 실행하지 못한 검증을 통과했다고 말하지 않는다.

## 2. 기획 → 개발 준비

1. Product Spec에서 Goals, Non-Goals, User Flow와 FR/BR을 정의한다.
2. UI/UX에서 화면과 상태를 정의한다.
3. Tech Spec에서 Architecture/Data/API를 정의한다.
4. Roadmap에 Phase/Milestone만 둔다.
5. 모순과 누락을 점검한 후 개발을 시작한다.

제품/화면/기술 계약은 이 폴더의 Spec과 ADR이 정본이다. 코드와 충돌하면 코드를 사실로 적고 Spec을 고친다.

## 3. 작업 시작

    AGENTS → PROJECT_STATUS → HANDOFF → 활성 PLAN(있으면) → 관련 Spec → 코드

- 현재 Task의 범위와 완료 조건은 PROJECT_STATUS에서 확인한다.
- 관련 기존 구현과 테스트를 먼저 확인한다.
- 랭킹 초기화는 승인, 백업, dry-run, 예상 건수, 사후 조회 순. 배포는 사용자가 요청한 깨끗한 main에서만. 제출 ZIP은 손으로 수정하지 않는다.

## 4. 구현 중

- 범위 밖 문제는 Task에 몰래 포함하지 않고 Status의 Blocked/Known Issue로 남긴다.
- 제품 요구 변경 → Product Spec 및 필요 시 UI/UX 갱신.
- 구조/Data/API 변경 → Tech Spec 갱신.
- 중요한 기술 결정 → 필요할 때 ADR 작성.
- 버그는 공통 경로에서 한 번만 고친다. 가능하면 최소 회귀 테스트를 먼저 남긴다.
- 주석은 코드만으로 이유가 안 보일 때만 한글.
- Flame HUD를 Flutter 위젯으로 매 프레임 다시 만들지 않는다.

## 5. 작업 완료 조건

    Implement → Test → Acceptance Criteria → Task DONE → Status → Handoff

- [ ] 요구 범위 구현
- [ ] Acceptance Criteria 확인
- [ ] 필요한 테스트/수동 검증 실행
- [ ] 기준 문서와 코드 일치
- [ ] Task/Project Status 최신화
- [ ] 인수인계 최신화
- [ ] 활성 PLAN이 있으면 상태 갱신

문서만 변경: 링크, 형식, diff.
코드 변경: 관련 flutter test, 필요 시 flutter analyze, 관련 플랫폼 빌드.
랭킹 PHP 변경: 게임 ZIP을 다시 만들지 않고 NAS 업로드 여부를 보고에 명시.

검증 명령: flutter test, 필요 시 flutter analyze, 관련 플랫폼 빌드. 웹은 --base-href를 배포 경로와 같게.

## 6. Task 상태

    TODO / IN_PROGRESS / BLOCKED / REVIEW / DONE

DONE은 구현뿐 아니라 필요한 검증과 문서 갱신까지 끝난 상태다.
현재 Task 목록은 PROJECT_STATUS.md에만 둔다.

## 7. 문서 변경 규칙

- 진행률은 Spec에 쓰지 않는다.
- 제품/기술 명세에는 현재 Task 상태를 쓰지 않는다.
- 인수인계는 장기 기록 저장소가 아니라 다음 작업자가 이어받기 위한 최신 상태다.
- 새 문서는 독립 정본 또는 별도 변경 이력이 필요한 경우에만 만든다.
- 이 폴더 밖의 문서 트리를 가리키거나 그 문서를 이 폴더의 기준으로 쓰지 않는다.

## 8. Roadmap → Plan → Task

1. Roadmap에는 큰 Phase/Milestone만 둔다.
2. 여러 파일/레이어 변경, API 변경, 큰 리팩터링, 복잡한 기능은 구현 전에 `plans/PLAN-xxx.md`를 작성한다.
3. Plan은 목표/범위/구현 순서/영향/검증을 정의한다. 진행률을 Plan에 쌓지 않는다.
4. 실행 가능한 작은 항목은 PROJECT_STATUS.md의 Current Tasks로 관리한다.
5. 단순 수정은 Plan을 만들지 않는다.
6. 장기적으로 남길 중요한 기술 결정은 ADR로 분리한다.
7. 완료된 Plan은 삭제하지 않고 Status를 DONE으로 바꾼다.

복잡도 판단:

    Requirement → Roadmap → 작업 선정 → Simple이면 Task, Complex이면 PLAN 후 Task 분해 → Implementation → Test → Status → Handoff


## 신규 작성 / 기존 문서 이관
- 신규 작성: Spec → Plan → Implementation → Progress → Handoff. 완료는 새 문서 팩만으로 작업 가능한지다.
- 기존 이관: MIGRATION_GUIDE.md를 따른다. 완료는 대체 가능(REPLACEABLE)이다. 실패하면 기존 docs 디렉터리를 삭제하지 않는다.
- 줄 수는 완전성 근거가 아니다.

## 문서-코드 충돌
충돌을 발견하면 문서를 코드에 맞추기 전에 의도를 확인한다. 확정 불가면 DOC-CODE-MISMATCH / NEEDS-DECISION.

## 상세정보 보존
테스트, 빌드, 배포, Git, 완료 기준, 운영 절차의 세부 수준을 유지한다. 명령과 체크리스트는 이 파일 하단에 흡수되어 있다.

## 9. Git / 배포 경계

- 커밋, push, PR, merge는 사용자가 명시할 때만.
- 커밋 메시지와 PR은 한국어. 형식: 분류: 변경 내용
- 배포 요청 시 깨끗한 main에서 실행. NAS는 tools/deploy_match_web.sh
- 공모전 ZIP은 전용 스킬로 만들고 손으로 수정하지 않는다.
- main, NAS, 제출 ZIP 상태를 구분해 보고한다.

## 10. 검증 최소 세트

보드/특수/아이템: test/match_board_logic_test.dart, special_gem_combo_test.dart, item_effect_test.dart, stage_reward_test.dart, item_inventory_test.dart
랭킹/광고/채널: ranking_service_test.dart, ad_reward_policy_test.dart, app_config_test.dart
오디오/성능: sound_manager_test.dart, fps_window_stats_test.dart
전체: flutter test, 필요 시 flutter analyze

---

# 에이전트 작업 기준

원문 제목 키: `agent_work_rules.md` (이 파일에 흡수됨)

# 에이전트 작업 기준

이 문서는 `AGENTS.md`에서 분리한 Stone Match 전용 상세 기준이다. 모든 항목을 매번 실행하는 것이 아니라 현재 작업에 해당하는 절만 적용한다. 명령과 절차는 아래에 연결된 주제별 문서를 단일 기준으로 삼는다.

## 1. 사실 기준과 문서 동기화

- 현재 코드와 테스트를 오래된 세션, 계획, 체크리스트보다 우선한다.
- 실행 규칙의 단일 기준은 `AGENTS.md`, 이 문서, 주제별 문서와 저장소 스크립트다. 선택형 스킬이나 특정 에이전트 도구에만 존재하는 규칙을 두지 않는다.
- 현재 환경에 없는 도구나 스킬 이름을 작업 절차에 고정하지 않는다. 선택형 도우미가 없어도 문서에 적힌 스크립트와 검증 절차로 같은 결과를 낼 수 있어야 한다.
- 구현 상태가 바뀌면 `planning/stone_match_execution_checklist.md`와 관련 설계 문서를 함께 갱신한다.
- 체크리스트는 코드, 테스트, 빌드, 보존된 QA 자료로 확인된 항목만 완료 처리한다.
- 일시적인 커밋 해시, 랭킹 건수, 백업 파일명, Worktree 경로는 정책 문서에 고정하지 않는다.
- 결과를 바꿀 수 있는 선택지가 둘 이상이면 추측으로 구현하지 말고 사용자에게 확인한다. 단순하고 되돌릴 수 있는 선택은 기존 패턴을 따른다.

## 2. 제품명과 사용자 문구

- 외부 표시명은 `Stone Match` 또는 제출물 표기인 `STONE MATCH`를 사용한다. 이전 이름은 남아 있는 디렉터리, 패키지 등 내부 식별자를 설명할 때만 사용한다.
- 사용자에게 보이는 문구에는 중간점 문자를 사용하지 않는다. 구분은 쉼표, 괄호, 줄바꿈을 사용한다.
- 랭킹 문구에 의미 없는 `#`나 `!`를 붙이지 않는다. 영문 표기는 `Rank 26 (Level 1)`처럼 쓴다.
- 자연스럽지 않은 광고 문구, 억지 영문 슬로건, 구현 상태를 드러내는 임시 표현을 사용자 화면에 넣지 않는다.

## 3. 랭킹 계약과 서버 경계

- 진행 랭킹은 현재 진입 레벨이 아니라 완료한 레벨 수다. 레벨 4 진입 상태는 3을 제출하고, 완료 레벨이 없는 레벨 1 상태는 0이며 제출하지 않는다.
- 유효한 진행 기록은 TimeUp 진입 또는 일시정지 나가기에서 제출한다. 일시정지 나가기는 제출 완료를 기다린다. TimeUp 나가기는 진입 시 보낸 제출을 기다리지 않는다. 클라이언트 계약은 `tools/ranking_client_contract.md`를 본다.
- 랭킹 서버 장애가 게임 진행이나 타이틀 복귀를 막아서는 안 된다.
- 2026-09-23부터 게임 내 랭킹 저장소는 Supabase다(ADR-009, PLAN-006). 스키마 변경은 `supabase/migrations/`에 새 마이그레이션으로 추가하고 원격 적용 뒤 보안 권고(advisors)를 확인한다. 적용한 마이그레이션 파일은 고치지 않는다.
- Supabase secret/service_role 키는 클라이언트, 저장소, 문서, 로그에 두지 않는다. 공개용 키와 URL은 `config/supabase.json`(Git 제외)에만 둔다.
- `matchranking/ranking.php`는 폐기 예정이며 Flutter 웹 빌드와 공모전 ZIP에 포함되지 않는다. 폐기 결정 전까지 NAS와 저장소에 남긴다.
- 운영 랭킹에 유효한 시험 기록을 넣거나 데이터를 초기화하지 않는다. 원격 스모크 기록은 확인 직후 SQL로 지우고 건수를 기록한다. 초기화는 사용자 승인 뒤 백업, dry-run, 예상 건수 고정, 사후 조회 순서로 수행한다(TECH_SPEC API-004).
- 게임 흐름은 `architecture/game_flow.md`, 초기화와 복원은 `tools/ranking_server.md`를 따른다.

## 4. Git, NAS 배포, 제출 ZIP

- 기능 수정은 격리 Worktree에서 검증하고, `main`은 병합, 배포, 정리에 사용한다.
- 배포 요청을 받으면 커밋과 푸시, main 병합, Worktree 정리를 마친 깨끗한 main에서 실행한다.
- NAS 배포는 `tools/deploy_match_web.sh`를 사용한다. 상세 실행과 사후 검증은 `tools/web_build.md`를 따른다.
- 공모전 ZIP은 `build-stone-match-submission` 스킬로 만든다. 생성된 ZIP을 손으로 수정하지 않는다.
- 클라이언트 코드, 정적 자산, 실행 안내가 바뀌면 NAS와 제출 ZIP 상태를 각각 확인한다. PHP만 바뀐 경우 게임 ZIP을 다시 만들지 않는다.
- main, NAS, 제출 ZIP의 상태를 구분해 보고한다. 갱신된 ZIP은 예전에 풀어 둔 폴더가 아니라 새로 압축 해제한 내용으로 검증한다.
- 웹 UI 변경은 넓은 브라우저 화면과 좁은 화면에서 비율과 잘림을 확인한다.

## 5. 공모전 문서

- 게임기획안은 완성작 소개서나 단순 역기획서가 아니라 실제 제작 전에 쓰는 게임 기획서로 작성한다.
- 제품 요구, 게임 규칙, UX, 밸런스, 상태와 데이터, 기술 구조, 장애 처리, 검증 조건을 담되 문서 제목이나 본문에서 PRD와 TRD 통합본이라고 과시하지 않는다.
- 심사 기준을 본문에서 직접 설명하거나 심사위원을 설득하는 형식으로 쓰지 않는다. 공모전 분량과 원본 양식은 지킨다.
- 한글 DOCX는 설치된 `Malgun Gothic`을 사용한다. 미설치 `페이퍼로지`가 글자 실행 구간이나 문단 기본 서식에 남지 않게 하고, 원본에서 의도한 부분만 굵게 유지한다.
- DOCX 수정 뒤 최종 PDF의 모든 페이지를 렌더링해 불필요한 굵기, 페이지 밀림, 정렬, 링크, 서명을 확인한다. 다른 프로젝트 문서는 검증 없이 기준본으로 사용하지 않는다.
- 최종 문서와 빌드는 `/Users/cheng80/Desktop/2026미니게임메이커스챌린지/STONE_MATCH_제출서류 검토/`에 둔다.

## 6. 임시 산출물

- 문서 생성 원고와 일회성 스크립트는 `tmp/stone_submission/`, 문서와 PDF 시각 검증 자료는 `tmp/qa/stone_submission/` 아래에 둔다.
- 브라우저 캡처와 일반 QA 자료는 `tmp/qa/<작업명>/`, 이미지 생성 중간 결과는 `tmp/imagegen/<작업명>/` 아래에 둔다.
- 레포 루트에는 임시파일이나 제출물을 두지 않는다. 최종 제출 폴더에는 최종 산출물만 두고, 시스템 임시 폴더를 사용했다면 완료 전에 잔여 파일을 확인한다.

## 7. 로컬 검증 환경

- Flutter와 Dart는 현재 셸의 `PATH`에서 찾고, 검증 전 `command -v flutter`와 `command -v dart`로 실행 경로를 확인한다.
- Android SDK는 `/Users/cheng80/Library/Android/sdk`에 있다.
- 기본 실행, 분석, 테스트, 빌드 명령은 프로젝트 `README.md`를 따른다.
- 문서만 바꾼 경우 링크, 형식, diff 검증으로 충분하다. 코드나 빌드 동작을 바꾼 경우 관련 테스트, `flutter analyze`, 필요한 플랫폼 빌드를 실행한다.

## 8. 코드 수정 원칙

- 사용자가 특정 파일이나 블록만 Git과 비교하거나 복원하라고 하면 지정 범위만 확인하고 변경한다. 주변의 최신 작업은 함께 되돌리지 않는다.
- 버그 수정은 가능하면 문제를 재현하는 가장 작은 회귀 테스트를 먼저 남기고, 공통 호출 경로에서 원인을 한 번만 고친다.
- 주석은 역할이나 이유가 코드만으로 분명하지 않을 때만 한글로 작성한다. 동작을 그대로 반복하는 주석과 그림 문자는 넣지 않는다.
- Riverpod은 기존 수동 `Notifier`와 `Provider` 패턴을 유지하며 `riverpod_annotation`이나 `build_runner` 코드 생성을 새로 도입하지 않는다.
- Flame과 Flutter는 같은 프레임 예산을 공유한다. 게임 위에서 매 프레임 Flutter 위젯을 다시 만들거나 전체 화면 블러와 그라데이션을 계속 다시 그리지 않는다. 실시간 HUD는 기존 Flame 구성요소를 우선하고, Flutter 오버레이는 갱신 범위와 다시 그리기 범위를 분리한다.


---

# 테스트·빌드·배포 명령

원문 제목 키: 이 팩 Workflow의 테스트·빌드·배포 명령 절 (이 파일에 흡수됨)

# Stone Match 테스트, 빌드, 배포 명령

모든 명령은 Stone Match 저장소 루트에서 실행한다. 로컬 확인, NAS 배포, Apps in Toss 배포는 서로 다른 산출물을 사용한다.

## 1. 최초 준비

```bash
command -v flutter
command -v dart
command -v node
node --version

flutter pub get
npm install
```

- Apps in Toss SDK는 Node.js 24 이상을 권장한다.
- `flutter`, `dart`는 현재 셸의 `PATH`에 있는 실행 파일을 사용한다.
- `node_modules/`, `build/`, `*.ait`, `.env`, `.env.intoss`는 Git에 커밋하지 않는다.

## 2. 주요 테스트

### 코드 변경 후 기본 검증

```bash
flutter analyze
flutter test
```

현재 전체 테스트 수는 변경될 수 있으므로 명령의 종료 코드와 마지막 `All tests passed`를 기준으로 판단한다.

### 특정 영역만 빠르게 확인

```bash
# 광고 정책, 광고 서비스, 채널 설정
npm run test:ads

# FPS 통계, 웹 오디오, QA 자동 효과 경로
flutter test \
  test/fps_window_stats_test.dart \
  test/sound_manager_test.dart \
  test/match_board_game_qa_special_effect_test.dart

# 게임 규칙
flutter test test/match_board_logic_test.dart
```

특정 테스트 통과는 전체 회귀 테스트를 대신하지 않는다. 최종 병합 전에는 `flutter test` 전체를 실행한다.

## 3. 로컬 실행

### 일반 개발 실행

```bash
flutter run -d chrome
```

Flutter 디버그 실행은 기능 확인용이다. FPS 비교 수치로 사용하지 않는다.

### Supabase 연결 실행

`config/supabase.example.json`을 `config/supabase.json`으로 복사하고 프로젝트 URL과 공개용 키를 넣는다. 이 파일은 Git에서 제외된다.

```bash
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

파일 없이 실행하면 랭킹은 연결 불가로 표시되고, 보충 광고는 세션 로컬 제한만 쓰며, 이벤트는 보내지 않는다. `npm run dev:ads`는 파일이 있으면 자동으로 넣는다.

### 브라우저 모의 광고

```bash
npm run dev:ads
```

`STORE_CHANNEL=intoss`, `INTOSS_AD_MODE=mock`으로 실행한다. 보상 흐름과 배너 레이아웃을 Chrome에서 확인할 때 사용하며 실제 토스 광고 요청은 하지 않는다.

### 일반 릴리즈 Web을 정적 서버로 확인

```bash
flutter build web \
  --release \
  --base-href "/" \
  --wasm \
  --no-web-resources-cdn \
  --no-source-maps
dart run tools/patch_flutter_web_deprecations.dart
python3 -m http.server 8080 --directory build/web
```

브라우저에서 `http://localhost:8080/`에 접속한다. 이 서버는 기능 스모크 테스트용이며 NAS의 COOP/COEP 헤더 환경과 같지 않으므로 최종 FPS 판정에는 사용하지 않는다. 종료는 실행한 터미널에서 `Ctrl+C`다.

## 4. 일반 Web과 NAS 배포

### `/match/`용 Web 빌드만 생성

```bash
flutter build web \
  --release \
  --base-href "/match/" \
  --wasm \
  --no-web-resources-cdn \
  --dart-define-from-file=config/supabase.json
dart run tools/patch_flutter_web_deprecations.dart
```

결과는 `build/web/`에 생성된다. `/match/` 빌드를 루트(`/`)에 배포하거나 그 반대로 배포하지 않는다.
`tools/deploy_match_web.sh`는 `config/supabase.json`이 있으면 같은 옵션을 자동으로 넣고, 없으면 Supabase 기능이 꺼진 빌드라고 로그를 남긴다.

### NAS 자동 배포

배포 전 깨끗한 `main`과 원격 동기화를 확인한다.

```bash
git status --short --branch
git fetch origin
git rev-list --left-right --count main...origin/main
```

마지막 명령의 카운트가 `0 0`이어야 한다. 최초 한 번은 로컬 환경 파일을 준비한다.

```bash
cp .env.example .env
```

`.env`에서 다음 값만 실제 값으로 바꾼다.

```dotenv
MATCH_DEPLOY_URL=<NAS 배포 URL>
MATCH_DEPLOY_TOKEN=<NAS 배포 토큰>
```

배포 명령:

```bash
tools/deploy_match_web.sh --help
tools/deploy_match_web.sh
```

스크립트가 기존 `build/web`, `match/`, `match.zip`을 정리하고 새 빌드, Wasm 헤더, ZIP 생성, NAS 업로드까지 수행한다. 배포 후 다음을 확인한다.

```bash
curl -I https://cheng80.myqnapcloud.com/match/
```

브라우저에서는 첫 로드, 새로고침 라우팅, 사운드, 랭킹을 확인하고 콘솔에서 `window.crossOriginIsolated === true`인지 확인한다.

## 5. Apps in Toss 테스트 빌드와 배포

### API 키 저장

API 키는 `.env`, 명령 기록, 문서에 넣지 않는다. AIT CLI의 토큰 프로필에 한 번 등록한다.

```bash
npx ait token add
```

여러 워크스페이스를 구분해야 할 때만 별칭을 사용한다.

```bash
npx ait token add dev
```

삭제는 `npx ait token remove` 또는 `npx ait token remove dev`를 사용한다.

### 공식 테스트 광고 `.ait` 생성

```bash
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
ls -lh ./*.ait
shasum -a 256 ./*.ait
```

이 명령은 다음 작업을 순서대로 수행한다.

1. 루트 base href의 Wasm Flutter Web 릴리즈 빌드
2. `STORE_CHANNEL=intoss`, `INTOSS_AD_MODE=test` 적용
3. Apps in Toss 광고 브리지 주입
4. `.ait` 패키징

### AIT 테스트 배포와 딥링크 출력

기본 토큰 프로필을 사용하는 경우:

```bash
npx ait deploy \
  --location ./<appName>.ait \
  --scheme-only \
  --memo "실기기 테스트"
```

별칭 프로필을 사용하는 경우 `--profile dev`를 추가한다. 이 명령은 원격 테스트 배포를 새로 생성하므로 명시적으로 배포할 때만 실행한다. 출력된 `intoss-private://...` 링크는 테스트용이며 API 키는 포함하지 않는다.

### 연결된 iPhone에서 열기

```bash
xcrun devicectl list devices

xcrun devicectl device process launch \
  --device "<기기 이름 또는 UDID>" \
  --terminate-existing \
  --payload-url '<intoss-private 링크>' \
  com.vivarepublica.cash
```

딥링크에는 `&`가 들어가므로 반드시 작은따옴표로 감싼다. 토스 앱이 설치되어 있고 Mac에서 해당 iPhone을 신뢰한 상태여야 한다.

## 6. Apps in Toss 운영 광고 빌드

운영 광고 그룹 ID는 Git에서 제외된 `.env.intoss`에만 둔다. API 키는 계속 AIT CLI 토큰 프로필을 사용한다.

```dotenv
INTOSS_APP_NAME=<콘솔_appName>
INTOSS_REWARDED_AD_GROUP_ID=<보상형 광고 그룹 ID>
INTOSS_BANNER_AD_GROUP_ID=<배너 광고 그룹 ID>
```

```bash
set -a
source .env.intoss
set +a
npm run build:intoss
```

운영 빌드는 광고 그룹 ID가 모두 없으면 실패한다. `.ait` 생성 후 업로드는 테스트 빌드와 같은 `npx ait deploy` 명령을 사용하지만, 실제 출시와 검토 요청은 Apps in Toss 콘솔에서 별도로 진행한다.

## 7. iPhone FPS와 GC 재측정

먼저 새 AIT 테스트 배포를 iPhone에서 열고 같은 모드, 같은 조건으로 플레이한다. 화면의 FPS 패널은 `AVG`, `LOW`, `GAP`을 기록한다.

`QA_PERF_AUTORUN`도 iOS 웹 자동재생 정책을 우회하지 않는다. 자동 플레이 측정 전에 게임 화면을 한 번 탭해 BGM과 SFX를 해제하고, 소리가 실제로 재생되는지 확인한다. 터치 없이 측정한 결과는 무음 대조군으로만 사용한다.

Mac에서 30초 시스템 추적을 함께 수집할 때:

```bash
mkdir -p tmp/qa/intoss_fps

xcrun xctrace record \
  --template 'Animation Hitches' \
  --device '<iPhone UDID>' \
  --all-processes \
  --time-limit 30s \
  --output tmp/qa/intoss_fps/<고유한_이름>.trace
```

- 기존 `.trace` 경로를 재사용하지 않는다.
- 측정 중에는 한 변수만 바꾼다.
- Apps in Toss WebView는 Web Inspector가 열리지 않을 수 있으므로 `WebContent`, `WebKit.GPU`, `mediaremoted`, Toss 프로세스의 잠재 정지를 비교한다.
- 측정 순서와 이전 결과는 **`../performance/flutter_flame_mobile_web_optimization_handoff.md`**에 이어서 기록한다.

## 8. 완료 판정과 기록

| 작업 | 최소 완료 조건 |
| --- | --- |
| 코드 수정 | 관련 테스트, `flutter analyze`, 전체 `flutter test` 통과 |
| 일반 Web 빌드 | Wasm 릴리즈 빌드 성공, `build/web/index.html` 존재 |
| NAS 배포 | 업로드 HTTP 200, 공개 URL 로드, 라우팅·사운드·랭킹 확인 |
| Apps in Toss 빌드 | `.ait` 생성, 파일 크기와 SHA-256 기록 |
| Apps in Toss 배포 | 새 딥링크 발급, 토스 앱 실행, 광고와 게임 흐름 확인 |
| FPS 비교 | 같은 조건 30초, `AVG / LOW / GAP`, 잠재 정지 수 기록 |

배포 기록에는 날짜, Git 커밋, 빌드 모드, 산출물 체크섬, 테스트 결과만 남긴다. API 키, 배포 토큰, 광고 그룹 ID는 남기지 않는다.

## 관련 문서

- **`web_build.md`**: `/match/` Web 빌드와 서버 헤더 상세
- **`../release/release_build.md`**: Android, iOS, Web 릴리즈 빌드
- **`../release/ad_placement_policy.md`**: 광고 위치와 보상 정책
- **`../release/release_checklist.md`**: 출시 전 전체 체크리스트


---

# 릴리즈 빌드

원문 제목 키: 이 팩 Workflow의 릴리즈 빌드 절 (이 파일에 흡수됨)

# 릴리즈 빌드 가이드

Stone Match 스토어 업로드용 빌드 절차다.

채널 선택값과 채널별 구현 상태는 **`store_channel_branching.md`**를 기준으로 한다. 이 문서의 현재 Android와 iOS 식별자는 공통값이며, 아직 스토어별 식별자로 분리되지 않았다.

## 현재 앱 식별자

| 항목 | 값 |
|------|----|
| 앱 이름 | `Stone Match` |
| Dart package | `stonematch` |
| Android applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| 현재 버전 | `1.0.0+1` |

## 채널 선택

빌드에는 반드시 출시 대상에 맞는 `STORE_CHANNEL` Dart define을 넣는다.

| 채널 | 값 |
|---|---|
| Google Play | `play` |
| One Store | `onestore` |
| App Store | `appstore` |
| Apps in Toss | `intoss` |

현재 define은 Flutter 코드의 채널값만 선택한다. Android product flavor, iOS 별도 bundle ID, Apps in Toss `.ait` 패키징을 추가하기 전에는 One Store와 Apps in Toss 산출물을 업로드하지 않는다.

## 공통 준비

`pubspec.yaml`의 버전을 먼저 올린다.

```yaml
version: 1.0.1+2
```

빌드 시 오버라이드도 가능하다.

```bash
flutter build appbundle --release --build-name 1.0.1 --build-number 2 \
  --dart-define=STORE_CHANNEL=play
flutter build ipa --release --build-name 1.0.1 --build-number 2 \
  --dart-define=STORE_CHANNEL=appstore
```

## 스플래시 로고

웹과 네이티브 스플래시는 `flutter_native_splash` 설정을 통해 생성한다. 앱 내부 타이틀 로고와 별도로, 스플래시 전용 자산은 다음 파일을 사용한다.

```text
assets/images/ui/stone_match_splash_logo.png
```

이 자산은 원본 타이틀 로고를 그대로 꽉 채우지 않고, 모바일 화면에서 좌우 여백이 남도록 투명 패딩과 가로 중심 보정을 포함한다. `pubspec.yaml`의 `flutter_native_splash.image`와 `android_12.image`는 이 스플래시 전용 자산을 가리켜야 한다.

스플래시 자산을 바꾼 뒤에는 생성 리소스를 함께 갱신한다.

```bash
dart run flutter_native_splash:create
```

갱신 대상:

- `web/splash/img/*`
- `android/app/src/main/res/drawable*/splash.png`
- `android/app/src/main/res/drawable*/android12splash.png`
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/*`

모바일 웹 QA는 Flutter 부트스트랩을 차단한 상태에서 순수 스플래시 화면을 캡처해, 로고가 가로 중앙에 있고 화면 폭을 과도하게 채우지 않는지 확인한다.

## Android

Google Play 업로드용은 AAB를 쓴다.

```bash
flutter build appbundle --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=play
```

출력:

```text
build/app/outputs/bundle/release/app-release.aab
```

직접 배포나 설치 테스트용 APK:

```bash
flutter build apk --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=play
```

출력:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Google Play와 One Store는 같은 Android 앱으로 운영하기로 했다. 공통 앱 서명키로 사용할 값은 아래와 같다.

| 항목 | 값 |
|---|---|
| JKS 경로 | `/Users/cheng80/android_keystore/stonematch_keystore.jks` |
| 키 별칭 | `stonematch_key` |
| applicationId | `com.cheng80.stonematch` |

`android/key.properties`에는 위 JKS 경로와 별칭, 비밀번호를 설정한다. JKS와 비밀번호는 Git에 올리지 않고 별도 백업한다. 현재 `android/app/build.gradle.kts`의 릴리즈 서명 연결은 구현 전이므로, 연결과 실제 서명 빌드 검증 전에는 업로드하지 않는다.

One Store는 `onestore` 채널값을 쓰되, Google Play와 같은 `applicationId`와 JKS를 사용한다. 두 스토어 버전은 같은 기기에 동시에 설치할 수 없다. `onestore` flavor 구현과 실제 서명 빌드 검증 전에는 Google Play 빌드 명령을 재사용해 One Store에 업로드하지 않는다.

## iOS

App Store Connect 업로드용 IPA:

```bash
flutter build ipa --release --build-name <버전> --build-number <빌드번호> \
  --dart-define=STORE_CHANNEL=appstore
```

출력:

```text
build/ios/ipa/Runner.ipa
```

업로드:

1. Transporter 앱 설치
2. Apple Developer 계정 로그인
3. `Runner.ipa` 업로드
4. App Store Connect에서 처리 완료 후 TestFlight 또는 심사 제출

## Web / NAS

Web 배포는 **`../tools/web_build.md`**를 따른다. NAS 업로드 자동화는 `tools/deploy_match_web.sh`를 사용한다.

## Apps in Toss Web

Apps in Toss는 NAS 배포와 별도다. Node.js 24 이상 환경에서 공식 테스트 광고 ID를 포함한 Web과 `.ait`를 한 번에 만든다.

```bash
npm install
INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test
```

이 명령은 Flutter Web 빌드 뒤 앱인토스 광고와 레벨 리더보드 브리지를 `build/web`에만 주입하므로 NAS용 일반 Web 빌드에는 토스 SDK가 포함되지 않는다. 운영 빌드는 `INTOSS_AD_MODE=production`과 콘솔의 보상형, 배너 광고 그룹 ID를 사용해 별도로 만든다.

## 출시 전 필수 검증

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=STORE_CHANNEL=play
```

Android/iOS 릴리즈 빌드는 각 SDK와 서명 설정이 준비된 환경에서 별도 검증한다.


---

# 릴리즈 체크리스트

원문 제목 키: 이 팩 Workflow의 릴리즈 체크리스트 절 (이 파일에 흡수됨)

# 스토어 출시 체크리스트

Stone Match 출시 전 확인 목록이다.

채널 선택값과 구현 상태는 **`store_channel_branching.md`**를 기준으로 한다.

## 앱 기본값

| 항목 | 값 |
|------|----|
| App name | `Stone Match` |
| Google Play applicationId | `com.cheng80.stonematch` |
| One Store applicationId | `com.cheng80.stonematch` |
| iOS bundle id | `com.cheng80.stonematch` |
| Apps in Toss appName | 콘솔 등록 후 확정 |
| Category 후보 | Games / Puzzle / Casual |
| 현재 버전 | `1.0.0+1` |

## 공통

- [ ] `pubspec.yaml` 버전과 빌드 번호 증가
- [ ] `flutter analyze` 통과
- [ ] `flutter test` 통과
- [ ] 릴리즈 빌드 생성
- [ ] 출시 채널에 맞는 `STORE_CHANNEL` define 사용
- [ ] 앱 아이콘과 스플래시가 Stone Match 이름/비주얼과 일치
- [ ] 개인정보처리방침 URL 확정
- [ ] 지원 URL 또는 연락처 확정
- [ ] 랭킹 서버를 공개 기능으로 쓸 경우 데이터 저장·삭제 정책 정리

## Android / Google Play

- [ ] Google Play Console 앱 생성
- [ ] `com.cheng80.stonematch` applicationId 확인
- [ ] 공통 JKS `/Users/cheng80/android_keystore/stonematch_keystore.jks`, 별칭 `stonematch_key` 생성과 별도 백업
- [ ] `android/key.properties`와 release signing 설정
- [ ] AAB 빌드: `flutter build appbundle --release --dart-define=STORE_CHANNEL=play`
- [ ] 앱 콘텐츠: Data safety, Ads, Target audience, Content rating, App access 작성
- [ ] 스토어 등록정보: 이름, 짧은 설명, 전체 설명, 아이콘, feature graphic, 스크린샷
- [ ] 내부 테스트 트랙 업로드와 설치 테스트

## Android / One Store

- [ ] Google Play와 같은 `com.cheng80.stonematch` applicationId 사용, 동시 설치는 지원하지 않음
- [ ] 공통 JKS `/Users/cheng80/android_keystore/stonematch_keystore.jks`, 별칭 `stonematch_key`로 첫 서명 빌드 검증
- [ ] 개발사 보유 JKS를 One Store에 등록
- [ ] `onestore` product flavor 구현과 APK 또는 AAB 빌드 검증
- [ ] 빌드: `flutter build apk --release --flavor onestore --dart-define=STORE_CHANNEL=onestore`
- [ ] 상품 제목, 한줄설명, 상품설명, 권한 설명, 검색 키워드, 판매자 정보 입력
- [ ] 대표 아이콘 512×512, 그래픽 이미지 1024×578, 스크린샷 2~8장 준비
- [ ] AAB를 선택했다면 minSdk 21 이상 및 One Store 범용 APK 설치 테스트
- [ ] One Store 콘솔 등록과 실기기 설치 테스트

## iOS / App Store

- [ ] Apple Developer Program 준비
- [ ] App Store Connect 앱 생성
- [ ] Bundle ID `com.cheng80.stonematch` 확인
- [ ] `AppConfig.appStoreId` 입력
- [ ] Signing Team / Provisioning Profile 확인
- [ ] IPA 빌드: `flutter build ipa --release --dart-define=STORE_CHANNEL=appstore`
- [ ] TestFlight 업로드와 실기기 테스트
- [ ] iPhone+iPad 스크린샷 준비 (`TARGETED_DEVICE_FAMILY = "1,2"`)
- [ ] 앱 정보: 카테고리, 나이 등급, 개인정보처리방침, 지원 URL, 심사 연락처 입력

## Web / NAS

- [ ] 실제 배포 경로와 `--base-href` 일치
- [ ] `tools/deploy_match_web.sh` 환경 변수 확인
- [ ] `matchranking/` 서버 파일과 `ranking_data.json` 권한 확인
- [ ] 배포 후 첫 로드, 라우팅, 사운드 unlock, 랭킹 API 스모크 테스트

## Apps in Toss

- [ ] Apps in Toss 콘솔 워크스페이스와 게임 앱 등록
- [ ] 콘솔 `appName` 확정, 빌드 환경 변수 `INTOSS_APP_NAME`에 반영
- [ ] 앱 로고 600×600, 투명 배경 없는 PNG와 썸네일 1932×828 PNG 준비
- [ ] 세로 스크린샷 3장 또는 가로 스크린샷 1장 이상 준비
- [ ] 고객센터 정보, 게임 카테고리, 검색 키워드, 상세 설명 입력
- [ ] 동일 게임의 오픈마켓 등급분류 정보 또는 게임물 등급분류증명서 준비
- [ ] 리더보드 사용 시 점수 단위와 정렬 기준 확정
- [x] SDK 3.x 설정과 테스트 광고 Web, `.ait` 로컬 패키징 검증
- [x] 앱인토스 공식 리더보드에는 레벨 모드 기록만 제출하고 게임 내 안내 노출
- [ ] 콘솔 appName으로 테스트 빌드: `INTOSS_APP_NAME=<콘솔_appName> npm run build:intoss:test`
- [ ] `.ait` 패키징, 압축 해제 기준 100MB 이하 확인, 콘솔 QR 실기기 테스트
- [ ] 검토 요청 전 QR 테스트를 최소 1회 완료
- [ ] 광고 적용 시 **`ad_placement_policy.md`**의 위치, 사전 로드, 사운드 정지와 보상 지급 조건 확인
- [ ] 리더보드 적용 시 콘솔 설정과 게임 내 동작 확인

상세 빌드는 **`release_build.md`**, 채널 분기는 **`store_channel_branching.md`**, 광고 정책은 **`ad_placement_policy.md`**, One Store와 Apps in Toss 등록 자료는 **`store_metadata_onestore_intoss_2026.md`**, Play와 App Store 문구는 **`store_metadata_play_appstore_2026.md`**를 따른다.


---

# iOS 프로필 빌드

원문 제목 키: 이 팩 Workflow의 iOS 프로필 빌드 절 (이 파일에 흡수됨)

# iOS 프로필 빌드 및 실기기 설치

Stone Match를 iPhone/iPad 실기기에서 성능 점검할 때 쓰는 프로필 모드 절차다.

## 사전 준비

- macOS + Xcode
- iPhone 또는 iPad 실기기
- Apple Developer 계정과 서명 설정
- `ios/Runner.xcworkspace`에서 Team, Bundle Identifier 확인

현재 Bundle ID는 `com.cheng80.stonematch`다.

## 기기 확인

```bash
flutter devices
```

## 프로필 빌드

```bash
flutter build ios --profile -d <DEVICE_ID>
```

빌드 결과:

```text
build/ios/iphoneos/Runner.app
```

## 실기기 실행

권장:

```bash
flutter run --profile -d <DEVICE_ID>
```

Xcode 실행:

1. `ios/Runner.xcworkspace` 열기
2. 대상 기기 선택
3. Run 실행

빌드된 앱만 설치:

```bash
xcrun devicectl device install app --device <DEVICE_ID> build/ios/iphoneos/Runner.app
```

## 모드 구분

| 모드 | 용도 |
|------|------|
| `--debug` | 개발, 핫 리로드 |
| `--profile` | 실기기 성능 측정 |
| `--release` | 스토어 배포 |

릴리즈 IPA 생성은 **`../release/release_build.md`**를 따른다.


---

# 실행·배포 체크리스트

원문 제목 키: `stone_match_execution_checklist.md` (이 파일에 흡수됨)

# Stone Match — 실행·배포 체크리스트

> 현재 구현과 테스트를 기준으로 쓴다. **끝낸 항목은 `[x]`**, 진행 중·보류는 `[ ]`로 갱신한다.

## 제품·플레이

- [x] 8×8 매치-3 코어 (`MatchBoardLogic` / `MatchBoardRenderer`)
- [x] 심플 모드 / 타임 모드 (`JewelGameMode`, 쿼리 `mode=simple|timed`)
- [x] 일시정지·NoMoves·TimeUp 오버레이 흐름 (이 팩의 게임 플로우 절 기준)
- [x] 타임 모드: 매치 보상 초·저시간 `TimeTic`·타임 오버 `TimeUp` SFX
- [x] 무효 스왑 `Fail` SFX
- [x] 매치 이벤트 SFX: `ComboHit`·`BigMatch`·`SpecialGem` — 우선순위 기반 단일 재생
- [x] 매치 파티클: `ParticleBurst` — 3매치(기본) / 4+·콤보·특수(화려) 3단계
- [x] 스프라이트시트 사전 로드 + `FadeTransition` 전환 → 장면 전환 버벅임 제거
- [x] 웹 오디오 기준점 확정: SFX는 Web Audio를 우회하고 HTML 오디오 고정 4슬롯을 재사용하여 iOS 컨텍스트 정지 경로 제거
- [x] 보드 크롬/슬롯 배경 `ui.Picture` 캐싱 (`MatchBoardRenderer`)
- [x] 보드 클리핑 최소화: 낙하/리필/인트로 구간에서만 `clipRRect`
- [x] HUD `TextPainter`/`Paint` 재사용 캐싱 (`MatchGameHud`)
- [x] 설정에서 켜고 끄는 FPS 계측 패널 추가 (`FrameTiming`, 웹 QA 쿼리 지원)
- [x] 하이퍼 보석 `ColorFilter.matrix` 제거 → 전용 스프라이트 프레임 사용
- [x] 특수 보석 렌더: `bomb`/`star`/`hyper`/`supernova`는 `Special_Action_Arcane.png`, legacy `row`/`col`은 `Special_Arcane.png`
- [x] 튜토리얼 스프라이트 프리뷰를 원본 픽셀 기준 프레임 크롭으로 통일 (`SpriteSheetFrame`)
- [x] 파티클 퍼짐 반경·입자 수·수명·글로우 강도 축소로 GPU 부담 완화
- [x] MVVM 리팩터링: `flutter_riverpod` 도입, `SettingsNotifier`·`RankingNotifier`, 오버레이 파일 분리, 공통 위젯 추출
- [x] Riverpod 구독 범위 최적화: `select`로 필요한 필드만 구독 (`SettingView` / `PauseMenuOverlay` / `TimeUpOverlay`)
- [x] 볼륨 슬라이더 draft/commit 분리로 드래그 중 `shared_preferences`/설정 연속 쓰기 제거
- [x] `StarryBackground` GlobalKey 싱글톤 — App 레벨 1개만 배치, 전환 시 재생성 비용 0
- [x] 모든 라우트 `FadeTransition` + `endOfFrame` 대기 패턴 적용 (타이틀·게임·설정)
- [x] `GameView` 비율 프레임: `kIsWeb` 대신 화면 비율 기반 → 태블릿에서도 비율 유지
- [x] `PackageInfo` 캐싱 (`FutureBuilder` 제거)
- [x] HUD 콤보 스트립 라벨/숫자 세로 간격 미세조정 마무리
- [ ] (선택) 밸런스·난이도 튜닝 기록을 이 팩 Product Spec의 게임 플로우 절 또는 별도 GDD에 반영

## 오디오·에셋

- [x] `AssetPaths` + `SoundManager.preload` 정합 (경로 깨지면 앱 기동 실패)
- [x] BGM: 메뉴·메인 경로·포맷(wav/mp3)과 실제 파일 일치 확인
- [x] 보석 스프라이트 시트 교체: `Jewel_Arcane.png` (`128×128` 프레임 기준)
- [x] 특수 보석 시트: `Special_Arcane.png`(legacy row/col) + `Special_Action_Arcane.png`(bomb/star/hyper/supernova) 적용
- [x] 이 팩 Tech Spec의 SFX·BGM 프롬프트 절 — AISFX / Soundverse 프롬프트 정리
- [ ] 교체한 `TimeUp` 등 SFX가 의도한 톤인지 인게임에서 최종 청취

## 플랫폼·설정

- [x] 설정: 볼륨·음소거·화면 켜짐·언어
- [x] 웹: `kIsWeb`일 때 설정의「평점 남기기」비표시, 타이틀 자동 리뷰 요청 생략
- [x] Apps in Toss SDK 3.x 광고 브리지, 보상형 이어하기·아이템 보충, 무한 모드 하단 배너와 모의 테스트 환경
- [x] Apps in Toss 공식 리더보드는 레벨 모드 기록만 제출하고, 게임 내 타임·레벨 랭킹은 기존 서버로 유지
- [ ] 광고 일일 제한 서버 영속화와 측정 이벤트 분석 제공자 연결
- [ ] iOS `AppConfig.appStoreId` 등 스토어 연동 값 출시 전 입력 (App Store Connect 등에서 설정)

## 반응형 프레임·레이아웃

- [x] `PhoneFrameScaffold` + `PhoneFrame` 도입 — 고정 논리 해상도 `390×750` + `FittedBox`
- [x] `TitleView`·`SettingView`에 `PhoneFrameScaffold` 적용 → 비율·폰트·간격 유지
- [x] `GameView`는 Flame 자체 `LayoutBuilder` 스케일링 — `FittedBox` 미적용
- [x] `StarryBackground` GlobalKey 싱글톤 — `App` 레벨 1개만 (Scaffold 바깥·모든 뷰 공유)
- [ ] 웹 브라우저 리사이즈·키보드·분할 화면에서 비율 유지 최종 확인

## Web 빌드·배포

- [x] 이 팩 Tech Spec의 Web 빌드 절 — `--base-href`와 배포 폴더 관계 문서화
- [ ] 실제 서버 경로(예: `/match/`)에 맞춰 **빌드 시 `--base-href`를 동일하게** 맞출 것
- [ ] 배포 후 정적 파일·라우팅·첫 로드·사운드(unlock) 스모크 테스트

## 릴리즈·스토어 문서

- [x] 이 팩 Workflow의 릴리즈 빌드 절 — Android/iOS/Web 릴리즈 빌드 절차
- [x] 이 팩 Workflow의 릴리즈 체크리스트 절 — Play/App Store/Web 출시 체크리스트
- [x] 이 팩 Product Spec의 스토어 메타 Play/App Store 절 — 스토어 등록 문구 초안
- [x] 이 팩 Product Spec의 스토어 메타 One Store/Apps in Toss 절 — One Store/Apps in Toss 등록 자료
- [x] 이 팩 Product Spec의 광고 정책 절 — 광고 위치와 보상 정책
- [x] 이 팩 Product Spec의 스크린샷 카피 절 — 스크린샷 카피 초안
- [x] 이 팩 UI Spec의 인앱 리뷰 절 — 인앱 리뷰 정책과 현재 구현
- [x] 이 팩 Tech Spec의 스토어 채널 분기 절 — 스토어 채널 분기와 현재 빌드 상태
- [x] 이 팩 Tech Spec의 Android Gradle 절 — Android Gradle/Kotlin DSL 설정 메모
- [x] 이 팩 Workflow의 iOS 프로필 빌드 절 — iOS 프로필 빌드 절차
- [x] 이 팩 UI Spec의 설정/버전 표시 절 — 설정 화면/타이틀 하단 버전 표시 문서
- [x] 이 팩 UI Spec의 온보딩 튜토리얼 절 — 온보딩 튜토리얼 도입 후보 문서
- [ ] 출시 전 개인정보처리방침 URL·지원 URL·App Store ID 확정

## 문서·코드 동기화

- [x] `README.md` — 디렉터리·라우팅·문서 링크
- [x] 우주 배경 성능 최적화 리팩터 → 이 팩 Tech Spec의 코드 흐름 분석 §11 갱신
- [x] `PhoneFrameScaffold` 도입·파티클·SFX → 이 팩 Tech Spec의 코드 흐름 분석 §9·§10 갱신
- [x] 렌더링 최적화와 에셋 구조 변경 사항을 이 팩 Tech Spec의 코드 흐름 분석 절에 반영
- [x] 최근 Riverpod 최적화/로딩 오버레이/오디오 정책 변경 사항을 관련 문서에 반영

## 테스트·품질

- [x] `flutter test` 기본 위젯/게임 스모크
- [ ] 필요 시 통합 테스트·골든·웹 E2E 범위 확장

## 후속 최적화 점검

- [x] 게임 루프 상시 빈 특수효과 리스트와 카메라 흔들림 `Vector2`, 제거 연출 문자열 키 반복 생성 제거
- [ ] Apps in Toss iPhone GC와 프레임 급락 후속 테스트를 이 팩 PLAN-001의 성능 인계 절의 체크리스트에 따라 수행하고 결과 기록
- [ ] 전체 화면 기준 `ConsumerWidget` / `setState` 범위를 다시 점검해 불필요한 rebuild 구간 추가 축소
- [ ] Flutter DevTools 기준으로 초기 진입·게임 플레이 중 rebuild hotspot / frame drop 구간 계측
- [ ] 계측 결과를 바탕으로 HUD / 오버레이 / 타이틀뷰의 추가 분리 또는 provider 세분화 여부 판단


---

# 아이템 구현 체크리스트

원문 제목 키: `item_slot_market_implementation_checklist.md` (이 파일에 흡수됨)

# 아이템 슬롯·인벤토리 구현 체크리스트

이 문서는 **`item_slot_market_plan.md`**의 실행용 체크리스트다. 기획 원칙은 플랜 문서를 기준으로 하고, 스테이지 보상 지급 규칙은 **`stage_reward_system.md`**를 기준으로 한다. 실제 작업은 이 문서의 단계별 체크박스를 갱신한다.

## 사용 방식

- 완료한 항목은 `[x]`로 바꾼다.
- 기능 단위 PR/커밋은 이 문서의 단계 번호를 기준으로 묶는다.
- 단계가 바뀌면 `flutter analyze`, 관련 `flutter test`, 웹 화면 QA 결과를 남긴다.
- 임시 QA 스크린샷은 레포 루트가 아니라 `tmp/qa/` 아래에 저장한다.

## 0차: 힌트 제한과 모드별 지급

### 목표

- 무한 모드는 연습모드로 유지하고 힌트 수량 제한을 두지 않는다.
- 타임 모드는 새 플레이마다 힌트 3개를 지급한다.
- 레벨 모드는 최초 2개 지급, 다음 스테이지 진입마다 1개 추가, 미사용분 누적.

### 구현

- [x] `MatchBoardGame`에 모드별 힌트 초기값을 추가한다.
- [x] 무한 모드는 `hintBadgeCount == null`로 처리해 뱃지를 그리지 않는다.
- [x] 타임 모드는 초기 힌트 3개를 갖는다.
- [x] 레벨 모드는 초기 힌트 2개를 갖는다.
- [x] 레벨업 후 다음 스테이지 진입 시 힌트 1개를 추가한다.
- [x] 제한 모드에서 힌트가 0개면 별도 피드백 없이 힌트를 제공하지 않는다.
- [x] 제한 모드에서 힌트가 성공적으로 표시된 경우에만 잔량을 1 감소시킨다.
- [x] 힌트 아이콘 우측 하단에 숫자 뱃지를 그린다.
- [x] 뱃지 위치를 최종 기준으로 좌 5px, 위 5px 조정한다.

### 테스트·QA

- [x] 무한 모드에서 뱃지가 보이지 않는다.
- [x] 타임 모드에서 시작 뱃지가 `3`으로 보인다.
- [x] 레벨 모드에서 시작 뱃지가 `2`로 보인다.
- [x] 타임 모드에서 힌트 3회 사용 후 뱃지가 `0`이 된다.
- [x] 뱃지 `0`에서 추가 클릭 시 새 힌트/피드백이 없다.
- [x] 레벨 모드에서 레벨업 후 미사용분에 1개가 누적된다.
- [x] `test/widget_test.dart`에 모드별 힌트 제한 테스트를 추가한다.
- [x] `flutter analyze --no-pub` 통과.
- [x] `flutter test --no-pub` 통과.
- [x] `flutter build web --release --no-pub` 통과.
- [x] Chrome QA 스크린샷 저장: `tmp/qa/hint_badge_shifted_*.png`.

## 1차: 아이템 효용성 테스트 HUD

### 목표

- 정식 경제/인벤토리 없이 8개 아이템을 하단 두 줄 슬롯에 노출한다.
- 모든 아이템은 테스트용으로 바로 사용 가능하게 한다.
- 대상 칸 선택 중에는 일반 스왑 입력을 막는다. 일반 칸 선택 중 시간은 흐르고, 즉시형 확인과 프리즘 색 선택 중에는 멈춘다.

### 모델·상태

- [x] `ItemKind` enum을 추가한다.
- [ ] 8개 아이템 메타데이터를 한 곳에 둔다.
- [ ] 아이템 이름, 아이콘, 대상 선택 필요 여부, 모드 제한을 데이터로 분리한다.
- [x] 1차에서는 아이템 수량/인벤토리/영속 저장을 만들지 않는다.
- [x] `itemTargeting` 상태를 게임 또는 보드 입력 계층에 추가한다.
- [x] 대상 선택 중 일반 스왑 입력을 막는다.
- [x] 대상 선택 취소 경로를 제공한다.
- [x] 대상 선택 완료/취소/실패 후 일반 입력 흐름으로 복귀한다.

### UI

- [x] 하단에 8개 테스트 슬롯 영역을 만든다.
- [x] 1줄: 룬 망치, 고대 폭탄, 토르 망치, 하이퍼 큐브.
- [x] 2줄: 프리즘 변환, 운명의 셔플, 타임 슬립, 힌트+.
- [x] 슬롯은 보드 하단 공간을 침범하지 않게 반응형 배치한다.
- [x] 비활성 아이템은 눌러도 보드 상태가 변하지 않게 한다.
- [x] 타임 슬립은 시간 없는 모드에서 비활성 처리한다.
- [x] 힌트+는 무한 모드에서 비활성 처리한다.
- [x] 2차 런 인벤토리 전환 후 무한/타임 모드의 하단 8개 테스트 슬롯을 제거한다.
- [x] 진행 모드에서만 `StageLoadout` 4칸 HUD 슬롯을 표시한다.

### 보드 효과

- [x] 룬 망치: 선택 셀 1개 제거.
- [x] 고대 폭탄: 선택 셀 중심 3×3 제거.
- [x] 토르 망치: 선택 셀 기준 `GemKind.star`와 같은 십자 제거.
- [x] 하이퍼 큐브: 선택한 일반 보석 색상과 같은 일반 보석 전체 제거.
- [x] 하이퍼 큐브가 특수 보석을 선택하면 사용 실패한다. 색상만 참조하지 않는다.
- [x] 프리즘 변환: 선택 보석 색 변경 UI와 변경 후 매치 체크를 구현한다.
- [x] 운명의 셔플: 특수 보석 위치를 보존하고 일반 보석만 섞는다.
- [x] 운명의 셔플 후 최소 1개 유효 이동을 보장한다.
- [x] 타임 슬립: `hasTimedClock`이 true인 모드에서만 시간을 추가한다.
- [x] 힌트+: 제한 모드 힌트 잔량을 소모하지 않고 즉시 힌트를 표시한다.

### 테스트·QA

- [ ] 각 아이템 효과 단위 테스트를 추가한다.
- [x] 가장자리/모서리에서 룬 망치, 고대 폭탄, 토르 망치 범위가 안전하게 잘린다.
- [x] 하이퍼 큐브가 일반 보석 선택 시 같은 색 전체 제거를 수행한다.
- [x] 하이퍼 큐브가 특수 보석 선택 시 사용되지 않는다.
- [x] 운명의 셔플 후 특수 보석 좌표가 유지된다.
- [x] 일반 칸 대상 선택 중 타임바 시간이 계속 줄어든다. 즉시형 확인과 프리즘 색 선택 중에는 멈춘다.
- [x] 대상 선택 중 일반 스왑이 발생하지 않는다.
- [x] 힌트+ 사용 시 기존 힌트 잔량은 변하지 않고 힌트가 즉시 표시된다.
- [x] 웹 모바일 크기에서 무한/타임 모드는 하단 아이템 슬롯이 보이지 않는다.
- [x] 웹 모바일 크기에서 진행 모드는 4칸 로드아웃 슬롯이 보인다.

## 2차: 스테이지 종료 보상과 런 인벤토리

### 목표

- 스테이지 종료 시 `MatchBoardGameStats` 기반으로 아이템을 지급한다.
- 지급 아이템은 현재 런/앱 실행 세션 동안만 유지한다.
- 레벨클리어 창에서만 다음 스테이지 loadout을 변경한다.
- 실제 슬롯 제한과 이후 스테이지 loadout 적용을 검증한다.

### 모델

- [x] `RunInventory` 모델을 추가한다.
- [x] `StageLoadout` 모델을 추가한다.
- [x] 아이템 보유 수량은 `Map<ItemKind, int>` 또는 동등한 구조로 관리한다.
- [x] 한 스테이지에서 사용할 loadout은 시작 시 스냅샷으로 고정한다.
- [x] 레벨클리어 창에서 편집 중인 다음 스테이지 loadout을 별도 상태로 둔다.
- [x] 2차에서는 앱 재시작 후 보유 수량 유지가 필요 없다.
- [x] 슬롯 최대 4개, 초기 2개 오픈 정책을 적용한다.
- [x] 3번 슬롯은 6스테이지 클리어 시 해금한다.
- [x] 4번 슬롯은 12스테이지 클리어와 최근 3스테이지 보상 수량 합계 중 2 이상인 판이 1회 이상일 때 해금한다.
- [x] 슬롯 해금 시 새 슬롯은 빈칸으로 열고, 아이템 자동 장착은 하지 않는다.

### 인벤토리 장착 UI

- [x] 레벨클리어 창 안에 인벤토리 버튼을 두고, 버튼을 눌렀을 때 별도 `StageInventory` 창을 연다.
- [x] 결과창 안에 인벤토리 내용을 직접 펼치지 않는다.
- [x] `StageInventory` 창은 나중에 다른 진입점에서도 호출 가능한 독립 오버레이로 둔다.
- [x] 레벨클리어 창과 인벤토리 창의 바깥 팝업은 `assets/images/ui/obsidian_panel_frame.png` 나인패치를 사용한다.
- [x] 안쪽 인벤토리는 일반 Flutter 슬롯/패널로 그리고, 나인패치 프레임을 중첩하지 않는다.
- [x] 유저에게 보여 주는 화면 문구에는 `임시`라는 용어를 쓰지 않는다.
- [x] 2차 인벤토리 호출은 레벨클리어 창에서만 가능하다.
- [x] 인벤토리 항목 탭으로 다음 스테이지 오픈 슬롯을 설정한다.
- [x] 잠긴 슬롯은 자물쇠로 표시하고 탭해도 변경되지 않는다.
- [x] 해금된 빈 슬롯은 `빈칸`으로 표시하고, 장착은 유저가 직접 선택한다.
- [x] 해금 이벤트 발생 시 인벤토리 창을 자동으로 열고 해금 배너와 슬롯 강조 애니메이션을 보여 준다.
- [x] 상단 X 없이 하단 `닫기` 버튼으로 인벤토리 창을 닫는다.
- [x] 게임 중 인벤토리 장착 변경은 2차에서 구현하지 않는다.

### 보상 판정

- [x] `MatchBoardGameStats`, `board.score`, `targetScore`, `board.maxCombo`를 입력으로 받는 보상 판정기를 만든다.
- [x] 조건별 보상 테이블을 코드 상수 또는 데이터 클래스로 분리한다.
- [x] 스테이지 종료 결과에서 보상 판정은 1회만 실행한다.
- [x] 같은 결과 화면에서 중복 지급되지 않게 플래그를 둔다.
- [x] 2차에서는 클리어 시에만 지급한다.
- [x] 점수 단독 티어가 아니라 목표 대비 점수와 콤보/특수 보석/제거/효율 통계를 결합해 보상을 지급한다.
- [x] 보상 기준을 플레이 테스트 기준보다 어렵게 조정해 한 판에서 과도한 아이템이 나오지 않게 한다.
- [x] 아이템별 레어도 표를 `stage_reward_system.md`에 정리한다.
- [x] 복합 보상 기준 미달 시 토르 망치 1개를 최소 보상으로 지급한다.
- [x] 한 스테이지 무료 보상 개수 제한을 두지 않는다.
- [x] 여러 조건 충족 시 조건별 보상을 모두 지급하고, 같은 아이템은 수량을 합산한다.

### 결과 화면·다음 스테이지

- [x] 클리어/결과 화면에 지급 아이템 목록을 표시한다.
- [x] 인벤토리는 결과 화면에 바로 펼치지 않고, 인벤토리 버튼으로 진입한다.
- [x] 다음 스테이지부터 앱 실행 세션 동안 `RunInventory`의 남은 수량을 사용할 수 있다.
- [x] 아이템 사용 시 보유 수량이 1 감소한다.
- [x] 수량 0개 아이템은 슬롯에 있어도 사용할 수 없다.
- [x] 무한/타임 모드 HUD에서는 런 인벤토리 슬롯을 표시하지 않는다.
- [x] 실패/재시작/NoMoves에서 보상 지급 타이밍이 중복되지 않는다.

### 테스트·QA

- [x] 보상 조건별 단위 테스트를 추가한다.
- [x] 보상 개수 제한이 없고 같은 아이템 수량이 합산되는 테스트를 추가한다.
- [x] 중복 지급 방지 테스트를 추가한다.
- [x] 인벤토리 수량 차감 테스트를 추가한다.
- [x] 슬롯 3/4 해금과 해금 슬롯 빈칸 유지 테스트를 추가한다.
- [x] 앱 재시작 없이 이후 스테이지에서 보상 아이템 사용 가능.
- [x] 앱 재시작 후 2차 런 인벤토리는 유지되지 않아도 된다.
- [x] `flutter analyze --no-pub` 통과.
- [x] `flutter test --no-pub test/stage_reward_test.dart test/item_inventory_test.dart test/widget_test.dart` 통과.
- [x] `flutter build web --release --no-pub` 통과.
- [x] Chrome QA 스크린샷 저장: `tmp/qa/phase2_stage_inventory_slot3_unlock_empty_slot.png`.
- [x] Chrome QA 스크린샷 저장: `tmp/qa/item_slots_simple_mobile.png`, `tmp/qa/item_slots_timed_mobile.png`, `tmp/qa/item_slots_progression_mobile.png`.

## 3차: 인벤토리 UI와 영속 데이터

### 목표

- 아이템은 스테이지 데이터가 아니라 플레이어 개인 데이터로 저장한다.
- 모든 아이템을 인벤토리 화면에 표시하고 수량 뱃지를 보여준다.
- 빈 슬롯 선택, 장착, 해제를 구현한다.

### 저장 모델

- [ ] `PlayerInventory` 모델을 추가한다.
- [ ] 보유 수량, 장착 슬롯, 슬롯 해금 상태를 저장한다.
- [ ] `GameSettings` 또는 별도 저장소에 로컬 영속화한다.
- [ ] 기존 설정 저장 키와 충돌하지 않는 `StorageKeys`를 추가한다.
- [ ] 저장 데이터 버전 또는 마이그레이션 여지를 둔다.
- [ ] 스테이지 시작 시 `StageLoadout` 스냅샷을 만든다.
- [ ] 스테이지 중 사용은 개인 인벤토리에서 즉시 차감한다.
- [ ] 실패/재시작/앱 종료 시 차감 롤백 여부를 정책대로 고정한다.

### 인벤토리 화면

- [ ] 타이틀 화면에 `인벤토리` 진입 버튼을 추가한다.
- [ ] 스테이지 시작 전 준비 화면 또는 진입 흐름을 만든다.
- [ ] 상단에 현재 오픈 슬롯과 장착 아이템을 표시한다.
- [ ] 중앙에 모든 아이템 목록을 표시한다.
- [ ] 소지 수량 0개 아이템도 목록에 표시한다.
- [ ] 각 아이템 타일에 수량 뱃지를 표시한다.
- [ ] 열린 빈 슬롯 선택 후 아이템 탭으로 장착한다.
- [ ] 장착된 슬롯 탭으로 해제한다.
- [ ] 중복 장착 불가 상태를 표시한다.
- [ ] 수량 0개 아이템은 장착 불가로 표시한다.
- [ ] 잠긴 슬롯에는 해금 조건을 표시한다.

### 테스트·QA

- [ ] 저장/로드 단위 테스트를 추가한다.
- [ ] 장착/해제 단위 테스트를 추가한다.
- [ ] 중복 장착 방지 테스트를 추가한다.
- [ ] 수량 0개 장착 방지 테스트를 추가한다.
- [ ] 앱 재시작 후 보유량과 장착 슬롯이 유지된다.
- [ ] 모바일 폭에서 인벤토리 타일/뱃지/슬롯이 겹치지 않는다.

## 3.5차: 웹 테스트 이벤트 로깅

### 목표

- GA/Firebase 도입 전에 내부 이벤트 이름과 파라미터를 고정한다.
- 웹 QA에서 콘솔 또는 localStorage/sessionStorage로 이벤트를 확인한다.

### 구현

- [ ] `AnalyticsService` 인터페이스를 추가한다.
- [ ] no-op 구현을 기본값으로 둔다.
- [ ] 웹 테스트용 구현은 콘솔과 localStorage/sessionStorage에 기록한다.
- [ ] 세션 단위 임시 `sessionId`를 만든다.
- [ ] QA용 최근 이벤트 로그 패널을 선택적으로 추가한다.
- [ ] 이벤트 payload에 개인 식별 정보를 넣지 않는다.

### 필수 이벤트

- [ ] `stage_start`
- [ ] `stage_clear`
- [ ] `stage_fail`
- [ ] `item_earned`
- [ ] `item_equipped`
- [ ] `item_unequipped`
- [ ] `item_used`
- [ ] `item_target_cancel`
- [ ] `continue_clicked`
- [ ] `ad_continue_clicked_mock`
- [ ] `ad_item_refill_clicked_mock`

### 테스트·QA

- [ ] 이벤트 이름 상수 테스트를 추가한다.
- [ ] 아이템 사용/취소 이벤트가 1회만 기록된다.
- [ ] 스테이지 종료 이벤트에 점수, 모드, 레벨, 통계가 포함된다.
- [ ] localStorage/sessionStorage 이벤트 로그를 웹 QA에서 확인한다.
- [ ] 개인정보성 값이 이벤트에 포함되지 않는다.

## 4차: 보상형 광고 mock

### 목표

- 실제 광고 SDK 전에 mock 서비스로 흐름을 고정한다.
- 광고로 이어하기와 아이템 보충을 검증한다.
- 광고 위치와 보상 정책은 **`../release/ad_placement_policy.md`**를 따른다.

### 구현

- [ ] `AdRewardService` 인터페이스를 추가한다.
- [ ] mock 광고 구현을 만든다.
- [ ] 실패 화면에 광고 이어하기 진입을 추가한다.
- [ ] 광고 이어하기는 진행 모드의 실패한 스테이지에서만 노출하고, 시도당 1회로 제한한다.
- [ ] 광고 이어하기 후 동일 스테이지를 재개한다.
- [ ] 아이템 부족 시 광고 보충 버튼을 제공한다.
- [ ] 광고 보충은 해당 아이템 1개만 지급한다.
- [ ] 아이템 보충은 하루 전체 3회 제한 모델을 추가한다.
- [ ] 광고 재시작 후 스테이지 종료 보상이 중복 지급되지 않게 한다.

### 테스트·QA

- [ ] mock 광고 성공/실패 테스트를 추가한다.
- [ ] 광고 이어하기 후 시간/보드/점수 복구 범위를 확인한다.
- [ ] 광고 아이템 보충 후 수량이 1 증가한다.
- [ ] 일일 제한 초과 시 버튼 상태가 바뀐다.
- [ ] 광고 mock 클릭 이벤트가 기록된다.

## 5차: 코인 경제 후보

### 목표

- 코인은 선택 기능이다. 지표 없이 강제 도입하지 않는다.
- 도입 시 보상 감각과 가벼운 구매 재화로만 사용한다.

### 구현

- [ ] `EconomyService` 또는 코인 저장 모델을 추가한다.
- [ ] 스테이지 클리어 기본 코인 보상을 계산한다.
- [ ] 목표 초과/최대 콤보 보너스를 계산한다.
- [ ] 실패 시 기본 코인은 지급하지 않는다.
- [ ] 코인 보상 내역을 결과 화면에 표시한다.
- [ ] 아이템 구매 가격 테이블을 데이터로 분리한다.
- [ ] 슬롯 3/4 해금 비용을 데이터로 분리한다.
- [ ] 코인 부족 상태는 실패 유도 압박이 아니라 구매 불가 상태로 표현한다.

### 테스트·QA

- [ ] 코인 보상 계산 단위 테스트를 추가한다.
- [ ] 아이템 구매 차감 테스트를 추가한다.
- [ ] 코인 부족 구매 불가 테스트를 추가한다.
- [ ] 결과 화면 보상 내역이 실제 저장 코인과 일치한다.

## 6차: 인앱 결제 후보

### 목표

- 인앱 결제는 지표 확인 후 선택적으로 붙인다.
- 게임 로직과 결제 SDK를 직접 결합하지 않는다.

### 도입 전 조건

- [ ] D1/D7 리텐션이 의미 있게 유지된다.
- [ ] 실패 후 광고 이어하기 사용률이 높다.
- [ ] 아이템 부족 시 광고 보충 사용률이 높다.
- [ ] 광고 이후 이탈률이 낮다.
- [ ] 특정 아이템 반복 수요가 확인된다.
- [ ] 개인정보 처리 고지와 스토어 정책 문구가 준비됐다.

### 구현 후보

- [ ] `PurchaseService` 인터페이스를 추가한다.
- [ ] 상품 ID와 상품 타입을 데이터로 분리한다.
- [ ] 광고 제거 상품 후보를 추가한다.
- [ ] 스타터 팩 후보를 추가한다.
- [ ] 아이템 번들 후보를 추가한다.
- [ ] 코인 경제를 도입한 경우에만 코인 팩 후보를 추가한다.
- [ ] 결제 복원 흐름을 추가한다.
- [ ] 결제 실패/취소 상태를 UI에 반영한다.

### 테스트·QA

- [ ] mock purchase 성공/실패/취소 테스트를 추가한다.
- [ ] 구매 복원 테스트를 추가한다.
- [ ] 실제 스토어 sandbox 테스트는 별도 릴리즈 체크리스트와 연결한다.

## 공통 완료 기준

- [ ] 변경 파일에 대해 `dart format`을 실행한다.
- [ ] `flutter analyze` 또는 `flutter analyze --no-pub`가 통과한다.
- [ ] 관련 `flutter test`가 통과한다.
- [ ] 게임 화면 변경은 웹 또는 실제 기기에서 수동 QA한다.
- [ ] QA 스크린샷은 `tmp/qa/` 아래에 저장한다.
- [ ] 문서와 실제 구현이 어긋나면 이 문서와 플랜 문서를 같이 갱신한다.
