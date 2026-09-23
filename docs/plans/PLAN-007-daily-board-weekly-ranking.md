# PLAN-007 타임 모드 일일 동일 보드와 주간 순위

## Metadata
- Plan ID: `PLAN-007`
- Title: 같은 날 같은 보드로 겨루고 타임 순위를 매주 새로 시작한다(PLAN-005 Step 4, C1)
- Status: `DONE` (2026-09-24, 원격 적용과 로컬 웹 실제 백엔드 검증 완료)
- Related Requirement: `FR-005`, `FR-009`, `BR-053`, `BR-095`
- Related ADR: `ADR-008`, `ADR-009`, `ADR-002`
- Owner:
- Updated: 2026-09-24

## 1. 목표
타임 모드의 운 요소를 줄이고 신규 사용자도 순위를 노릴 수 있게 한다. 같은 날에는 누구나 같은 시작 보드와 같은 난수 흐름으로 겨루고, 타임 순위는 KST 월요일 0시에 새로 시작한다.

## 2. 범위
### 포함
- 클라이언트 날짜 시드(`lib/game/daily_seed.dart`), 보드 난수와 힌트, Last Hurrah 난수 분리
- 서버 주간 범위(`ranking_entries.week_start` 생성 열, `get_ranking`, `submit_ranking`)
- 타이틀 "오늘의 보드", 랭킹 팝업 "이번 주 타임"과 초기화 안내, HUD 1위 "이번 주"

### 제외
- 서버 시드 제공(클라이언트가 날짜로 계산한다)
- 기록 삭제형 주간 초기화, 사용자별 최고 기록만 남기기(BR-090 동일 이름 다중 기록 유지)
- 앱인토스 공식 리더보드 변경(D8: 레벨 완료 수 유지)

## 3. 현재 상태 / 전제
- 보드 난수는 `MatchBoardLogic._random` 하나로 시작 보드, 리필, 셔플이 모두 이것을 쓴다.
- Dart `Random(seed)`는 SDK 릴리스마다 수열이 바뀔 수 있어 xorshift32를 직접 구현했다. VM, dart2js, dart2wasm 결과가 같음을 확인했다.
- 반드시 유지할 계약: RPC 시그니처와 반환 형식(이미 배포된 클라이언트 호환), RLS와 권한, 빈도 제한, 이름 규칙, BR-002.

## 4. 구현 계획
### Step 1 — 일일 보드
- [x] KST 날짜 키와 FNV-1a 시드, xorshift32(`DailySeed`, `DailyRandom`)
- [x] 타임 모드 판 시작(첫 보드, 다시 하기)에서만 재시드. NoMoves 새 보드와 셔플은 흐름을 잇고 판 통계를 유지
- [x] 힌트 순서 난수 분리, Last Hurrah 하이퍼 색 난수는 같은 날짜 시드에서 따로 생성
- [x] `round_start`에 `daily_key`
### Step 2 — 주간 순위
- [x] `20260924120000_stone_match_weekly_ranking.sql`: `week_start` 생성 열, 인덱스, time 모드 조회와 순위를 이번 주로 한정, 반환에 `week_start`
- [x] `20260924160000_stone_match_weekly_ranking_plan.sql`: PG17 generic 계획에서도 주간 인덱스를 쓰도록 time과 그 밖의 모드 문장 분리(검수 P2-1)
- [x] 원격 적용(2026-09-24)
### Step 3 — 표시
- [x] 타이틀 타임 버튼 아래 "오늘의 보드 M월 D일", 랭킹 팝업 "이번 주 타임"과 초기화 안내, HUD 1위 "이번 주" 라벨, 다시 하기 때 1위 재조회

## 5. 예상 변경 범위
- 파일/모듈: `lib/game/daily_seed.dart`, `match_board_logic.dart`, `match_board_input.dart`, `match_board_game_flow.dart`, `match_board_game.dart`, `lib/views/title_view.dart`, `lib/widgets/ranking_list_popup.dart`, HUD painter, 번역 5개
- DB/API 영향: API-001, API-003(TECH_SPEC). 시그니처 불변
- UI 영향: SCREEN-001, 랭킹 팝업, 타임 HUD
- 배포/마이그레이션 영향: 기록을 지우지 않아 운영 초기화 절차가 필요 없다. 이전 빌드도 같은 RPC로 이번 주 목록을 받는다

## 6. 검증 계획
- [x] Unit test: `test/daily_seed_test.dart`(KST 경계, 고정값, 같은 날 같은 보드와 점수, 셔플, 다른 날짜, 다시 하기, 무한 모드)
- [x] SQL: PGlite 주간 26/26(재적용 포함 27/27), 기존 회귀 60/60, 강제 generic 계획에서 time 조회가 주간 인덱스로 버퍼 4
- [x] 로컬 웹 + 실제 백엔드(Playwright `tmp/local-verify/s10_plan005b.js`): 두 사용자 같은 시작 보드, 같은 이동 4번 뒤 같은 보드와 점수, 다시 시작해도 같은 보드, 무한 모드 무작위, 지난주 기록 제외 순위, 레벨 전체 기간 유지
- [x] 독립 검수(R3): P1과 P2 수정, P3 반영 또는 명세 기록

## 7. 위험 / 미해결 사항
- 같은 날 무제한 재도전이라 리필 순서를 외울 수 있다. 설계상 허용하고 플레이테스트에서 본다.
- 클라이언트 시계가 틀리면 다른 날 보드를 받는다. 순위의 주는 서버 제출 시각이 정한다.
- 점수는 여전히 클라이언트 값을 믿는다(BR-094). 치트 방지 장치가 아니다.

## 8. 완료 조건
- [x] 계획한 구현 완료
- [x] 필요한 테스트/검증 완료
- [x] 기준 문서 변경사항 반영(Product Spec BR-053, BR-095, TECH_SPEC, UI_UX)
- [x] PROJECT_STATUS 갱신
- [x] HANDOFF 갱신

