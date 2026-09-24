# PLAN-005 Bejeweled Blitz 계승 게임 방향 개편

## Metadata
- Plan ID: `PLAN-005`
- Title: 60초 점수 경쟁 중심 게임 방향 개편(공통 코어, 장기 목표, 경쟁 형식)
- Status: `IN_PROGRESS` (2026-09-24 Step 1a, 1b, 1c, 2 이벤트, 3, 4, 5 구현 완료. 남은 것은 사용자 플레이가 필요한 1d 시간 보상(D7)과 플레이테스트 기록)
- Related Requirement: `FR-001`, `FR-002`, `FR-003`, `FR-004`, `FR-005`, `FR-006`, `FR-009`, `FR-012`
- Related ADR: `ADR-008`(Proposed), `ADR-001`, `ADR-002`, `ADR-006`, `ADR-007`
- Owner:
- Updated: 2026-09-24

기획 본문, 근거, 수치 시작값, 미결정 사항(D1~D10)은 [01_PRODUCT_SPEC.md](../01_PRODUCT_SPEC.md)의 "게임 방향 기획" 절이 정본이다. 이 PLAN은 구현 순서와 변경 범위만 다룬다.

## 1. 목표
두 타이머 모드가 공유하는 60초 판에 실력 표현 장치를 넣고, 재화 없이 오래 할 이유(누적 랭크, 배지, 기록)를 만든 뒤, 타임 모드를 실력 경쟁 모드로 키운다. 레벨 모드는 진행과 수익, 무한 모드는 휴식 모드로 역할을 정리한다.

## 2. 범위
### 포함
- Step 1: 공통 60초 코어(하이퍼 큐브 교환 H1~H3, Speed Bonus, Last Hurrah, 시간 보상 T1)
- Step 2: 내부 이벤트 로거와 플레이테스트 기록
- Step 3: 로컬 누적 랭크, 배지, 기록 화면, 무한 모드 연결
- Step 4: 타임 모드 경쟁 형식(일일 동일 보드, 주간 순위). 시작할 때 서버 포함 별도 PLAN으로 분리
- Step 5: 레벨 모드 규칙 변형 스테이지

### 제외
- 사가형 장애물 레벨, 생명, 대기 시간, 모드별 횟수 제한, 기간제 부스트
- 특수 보석 매치 발동(M1). 탭 발동 유지
- 특수 보석끼리의 교환 조합(Bejeweled Stars식). `match_board_special_combos.dart`의 bomb+bomb, bomb+star, star+star 코드는 계속 연결하지 않는다
- Blazing Speed. FPS 측정 전 보류
- 코인과 인앱 결제 구현. PLAN-003, PLAN-002 이후 별도 PLAN
- 외부 분석 SDK. 기존 "GA/Firebase 전환 기준"을 따른다

## 3. 현재 상태 / 전제
- 기존 구현(2026-09-23 코드 확인):
  - 스왑 조합 차단: `lib/game/match_board_input.dart`의 `_triggerSpecialSwapImpl`이 항상 `false`를 돌려준다. `_trySwapImpl`이 일반 스왑 전에 이 함수를 먼저 부른다. 하이퍼 교환은 이 한 곳에서 연결할 수 있다.
  - 탭 발동: 같은 파일의 칸 선택 처리에서 특수 보석 칸을 누르면 즉시 `triggerSpecialCell`을 호출한다. H1을 넣으려면 하이퍼 칸에서 시작한 드래그나 두 번째 칸 선택을 교환으로, 단순 탭을 발동으로 구분해야 한다.
  - 연쇄 큐: `lib/game/match_board_specials.dart`는 효과 범위의 `hyper`를 연쇄 큐에서 뺀다(`includeHyper` 조건). `hyper` 발동은 `triggerColor`를 받는 경로가 이미 있다.
  - 힌트와 NoMoves: `lib/game/match_board_logic.dart`의 `getAllValidMoves`와 `hasAnyValidMove`. `lib/game/match_board_resolution.dart`가 이동이 없으면 `onNoMoves`를 부른다.
  - 시간 보상: `match_board_resolution.dart`의 제거 처리. 상수는 `lib/game/match_board_game_mode_rules.dart`(60초, 상한 90초, 배율 0.6, 기본 1, 콤보당 1).
  - TimeUp: `lib/game/match_board_game_timing.dart`의 `_triggerTimeUpImpl`이 `timeUp`을 켜고 `TimeUp` 오버레이를 연다. 랭킹 제출은 `lib/views/overlays/time_up_overlay.dart`(진입 시)와 `pause_menu_overlay.dart`(나가기 대기)에서 `lib/vm/ranking_notifier.dart`를 거친다.
  - 레벨 시작 특수 보석: `lib/game/jewel_rank_progression.dart`의 `JewelProgressionBonus.kindsForNextLevel`.
  - 한 판 통계: `lib/game/match_board_models.dart`의 `MatchBoardGameStats`. 색별 제거 통계는 없다.
  - 분석: GA4, Firebase Analytics, 내부 이벤트 로거 모두 없다.
- 제약사항: 미출시라 외부 지표가 없다. 모바일 웹 FPS 검증(PLAN-001)이 미완이다. 토스 사용자 식별 정책이 없다(PLAN-002).
- 반드시 유지할 계약: BR-001, BR-002, BR-100~BR-103, ADR-003 광고 위치 3개, ADR-004(Web Audio로 되돌리지 않음), Riverpod codegen 금지, 실시간 HUD는 Flame 구성요소 우선, 사용자 문구 중간점 금지, ranking.php는 웹 빌드와 제출 ZIP에 넣지 않음.

## 4. 구현 계획
### Step 0 — 결정 게이트
- [x] D1 ADR-008 승인(2026-09-24, Accepted). ROADMAP Phase 5 진행 중
- [x] D2 H1, H2, H3 모두 채택, 탭 발동 색은 가장 많은 색. D3 H2 반환 없음, 점수와 시간 상한. D4 탭 유지. ADR-001 개정 절
- [x] D5 Speed Bonus는 타임 모드만, BR-011과 별도 가산, 콤보 배수 미적용
- [x] D6 Last Hurrah는 타임 모드만, 끝난 뒤 제출. 레벨 모드는 해당 없음. ADR-007 개정 절
- [x] Step 4 전: D8(앱인토스 공식 리더보드 대상) — 권장안으로 레벨 완료 수 유지(2026-09-24). D10(기존 타임 기록 처리)은 Supabase 랭킹에 실사용 기록이 없어 해당 없음(2026-09-24)
- [x] Step 5 전: D9 — 권장안으로 이동 제한 미혼합, 4의 배수 레벨 도전 스테이지(2026-09-24)

### Step 1 — 공통 60초 코어
#### 1a. 하이퍼 큐브 교환(H1~H3)
구현(2026-09-24, `f343fad`): H1, H2(연쇄 포함 10000점, +3초 상한), H3, 탭 색(가장 많은 색, 동률 작은 번호), 힌트 우선순위와 NoMoves, `hyper_swap` 이벤트, 게임 방법 문구 5개 언어. 하이퍼 탭은 HUD `onTapUp`에서 확정해 드래그와 구분한다. 테스트 추가, 전체 337건 통과. 실기기 터치와 H2 FPS는 통합 뒤 확인.

- [x] 입력: 하이퍼 칸의 단순 탭은 발동, 하이퍼에서 인접 칸으로의 드래그나 두 칸 선택은 교환으로 분기. 기존 F1 입력 회귀 테스트(`t2_f1_input_regression_test`, `t2_pointer_flow_test`) 유지
- [x] `_triggerSpecialSwapImpl`에 하이퍼 경로만 연결. H1은 일반 보석 색 제거, 특수 보석 대상은 그 특수 보석 발동과 그 색 제거. non-hyper 조합은 계속 `false`
- [x] H2 하이퍼끼리 교환: 판 전체 제거, D3에 따른 점수와 시간 상한
- [x] H3: 효과 범위에 든 `hyper`를 원인 특수 보석 색으로 큐에 넣는다
- [x] 하이퍼 탭 색 선택 기준(D2, 시작안: 가장 많은 색)
- [x] 힌트와 NoMoves: 하이퍼 교환을 유효 이동으로 볼지, 힌트 후보로 보여 줄지 D2와 함께 결정하고 반영
- [x] 아이템 `hyperCube`(BR-072)와 효과 표시가 겹치지 않는지 확인
- [x] 테스트: `special_gem_combo_test`의 "스왑해도 발동하지 않음" 기대를 하이퍼에 한해 바꾸고 non-hyper 조합 비활성은 유지. `match_board_logic_test`에 H1, H2, H3, 색 선택, NoMoves 케이스 추가
- [x] 문서: FR-002, BR-020~BR-022, FR-006, 특수 보석 룰 5, 7, 8, 11절, 게임 방법 오버레이 문구(5개 언어, FR-012), ADR-001

#### 1b. Speed Bonus
구현(2026-09-24, `936dfee`): `lib/game/speed_bonus.dart` 순수 로직(창 3.5초, 3번째 이어진 스왑부터 +200, 최대 +1000), `MatchBoardLogic.trySwap`에서 가산, `SpeedBonusBadge` Flame HUD(보드 오른쪽 아래, reduced motion은 팝 없음), 효과음 없음, `speed_bonus_peak` 이벤트. 테스트 11건. 실기기 플레이테스트와 FPS는 통합 뒤 확인.

- [x] 규칙 모델: 유저 스왑 기준 빠른 매치 카운트, 간격 창, 단계(+200~+1000), 초기화 조건. 순수 로직으로 분리해 단위 테스트
- [x] 점수 결합(D5 시작안: BR-011 결과와 별도 가산, 콤보 배수 미적용)
- [x] HUD: Flame 구성요소로 단계 표시. 기존 HUD 롤업, 시간 보너스 표시와 겹치지 않게 배치
- [x] 효과음: 기존 콤보 피치 규칙과 충돌 여부 확인
- [x] 문서: FR-005(적용 모드에 따라 FR-004), 새 BR, 02_UI_UX HUD 절

#### 1c. Last Hurrah
구현(2026-09-24, `a2d78d2`): `lib/game/last_hurrah.dart`, Flame 표시, 판 종료 확정 `_finalizeRound()`, `last_hurrah` 이벤트, QA 필드 `lastHurrahActive`. 6초 상한, reduced motion과 백그라운드 즉시 계산, 레벨 모드 비적용. 2026-09-24 권장안으로 마무리 규칙 확정(Product Spec 6-4): 새 특수 보석 생성 금지, Multiplier 배율 동결, 자연 연쇄 20단계 상한, 콤보 배수 기본 꺼짐(`last_hurrah_combo_multiplier`로 비교).

- [x] TimeUp 흐름에 마무리 단계 추가: 입력 잠금, 남은 특수 보석을 위쪽 행부터 왼쪽에서 오른쪽 순서로 발동, `hyper`는 무작위 남은 색, 연쇄 완료 후 점수 확정
- [x] 시간 보상 없음. 콤보 배수는 권장안으로 기본 꺼짐, 스위치로 플레이테스트 비교
- [x] 연출 길이 상한, reduced motion은 즉시 계산
- [x] 랭킹 제출을 마무리 완료 후로 이동. 일시정지 나가기 대기 규칙(BR-093)과 TimeUp 나가기 비대기 규칙 재정의
- [x] 테스트: `time_up_overlay_test`, 흐름 테스트에 마무리 단계, 제출 시점, reduced motion 케이스
- [x] 문서: ADR-007, BR-093, FR-005, 02_UI_UX TimeUp 절

#### 1d. 시간 보상 T1
- [ ] Step 2 플레이테스트 결과로 채택 여부(D7) 결정
- [ ] 채택 시 `match_board_resolution.dart` 보상 조건과 상수 변경, BR-050과 특수 보석 룰 10절 갱신

### Step 2 — 내부 이벤트 로거와 플레이테스트
- [x] 로거 어댑터: 2026-09-23 `EventLogger`로 구현하고 Supabase `game_events`에 보낸다(PLAN-006, ADR-009). 게임 코드는 SDK를 직접 부르지 않는다
- [x] 기존 필수 이벤트(아이템 플랜 3.5차)와 Product Spec 8-3 추가 이벤트 연결. 8-3 추가 이벤트와 `daily_key`, `challenge` 파라미터, 아이템과 이어하기 이벤트까지 연결 완료(2026-09-24, Playwright `s14_item_events.js` 7/7). 대응표는 Product Spec 웹 테스트 이벤트 로깅 절
- [ ] 개인 식별 정보 미기록, 임시 sessionId만 사용
- [ ] Product Spec 8-2 플레이테스트 항목을 매 단계 뒤 기록. 결과는 이 PLAN 하단 "플레이테스트 기록"에 남긴다(양식 준비 완료, 기록은 사용자 플레이 필요)

### Step 3 — 기록과 장기 목표(R1)
구현(2026-09-24, `baaff7c`): `lib/services/records/`, 기록 화면 `/records`(SCREEN-016), 결과 화면 알림, `badge_earned`, `rank_up`.
- [x] 로컬 저장 모델과 StorageKeys(`player_records`, 버전 필드). PLAN-003이 아직 없어 StorageHelper(shared_preferences) 기준으로 했다
- [x] 누적 랭크 모델(50단계, 5000 × (n² − 1)). 곡선 확정은 플레이테스트 뒤
- [x] 배지 10종 4등급(Product Spec 6-6 표)
- [x] 기록 화면(타이틀 진입, SCREEN-016)
- [x] 무한 모드 판 점수를 누적 랭크에 반영(일시정지 나가기 시점)
- [x] 테스트: 저장과 로드, 손상값 복구, 배지 판정, 랭크 경계, 기록 화면 넘침

### Step 4 — 타임 모드 경쟁 형식(C1)
구현(2026-09-24, `4435ecb`, 검수 수정 포함): [PLAN-007](PLAN-007-daily-board-weekly-ranking.md).
- [x] 시작 시 서버 변경(기간 구분, 날짜 시드)을 포함한 별도 PLAN 작성(PLAN-007). 시드는 클라이언트가 계산
- [x] 날짜 시드 보드와 리필 순서 재현 테스트(단위 테스트와 두 브라우저 비교)
- [x] 운영 랭킹 초기화: 기록을 지우지 않고 조회 범위만 바꾸므로 해당 없음

### Step 5 — 레벨 모드 규칙 변형(V1)
구현(2026-09-24, `87f50ca`, 검수 수정 포함): `lib/game/stage_challenge.dart`, BR-043.
- [x] D9 결정 후 스테이지 규칙 데이터 구조, 목표 HUD, 색별 제거 통계(이동 카운터는 D9로 제외)
- [x] BR-040, ADR-006과 목표 관계 정리: 4의 배수 레벨만 목표 점수 대신 도전 목표(BR-043), 그 밖의 레벨은 BR-040 그대로

## 5. 예상 변경 범위
- 파일/모듈: `lib/game/match_board_input.dart`, `match_board_specials.dart`, `match_board_resolution.dart`, `match_board_logic.dart`, `match_board_game_timing.dart`, `match_board_game_mode_rules.dart`, `match_board_models.dart`, `lib/game/components/` HUD, `lib/views/overlays/time_up_overlay.dart`, `pause_menu_overlay.dart`, `how_to_play/`, `lib/vm/ranking_notifier.dart`, 번역 파일, 새 기록 및 로거 모듈
- DB/API 영향: Step 1~3 없음(로컬). Step 4에서 랭킹 API 변경
- UI 영향: HUD Speed Bonus 표시, Last Hurrah 연출, 기록 화면, 배지 알림, 게임 방법 안내
- 배포/마이그레이션 영향: 타임 랭킹 점수 규모 변화(D10). 로컬 저장 신규 키

## 6. 검증 계획
- [ ] Unit test: 단계별 규칙 로직(H1~H3, Speed Bonus, Last Hurrah 순서와 점수, 시간 보상, 배지 판정)
- [ ] 회귀: `flutter analyze`, 전체 `flutter test`, 웹 릴리즈 빌드
- [ ] 성능: H2 판 전체 제거와 Last Hurrah 연쇄의 FPS를 PLAN-001 방식으로 전후 비교
- [ ] 수동: Product Spec 8-2 플레이테스트 항목
- [ ] 관련 Acceptance Criteria 갱신 확인

## 7. 위험 / 미해결 사항
- 점수 인플레이션과 랭킹 공정성: H2, Speed Bonus, Last Hurrah가 겹치면 점수 규모가 크게 바뀐다. 상한과 기존 기록 처리가 필요하다
- 모바일 웹 FPS: 연쇄 발동과 판 전체 제거가 PLAN-001의 미해결 문제를 악화시킬 수 있다
- 입력 오작동: 하이퍼 칸에서 탭과 드래그 구분이 모바일 터치에서 헷갈릴 수 있다
- 규칙 복잡도: 탭 발동과 하이퍼 교환이 공존한다. 튜토리얼 보강이 필요하다
- 레벨 목표 밸런스: 공통 코어가 레벨 모드 점수도 올린다(BR-040, ADR-006)
- 지표 부재: 출시 전 판단은 내부 플레이테스트에 기댄다

## 8. 완료 조건
- [ ] 계획한 단계 구현 완료
- [ ] 필요한 테스트/검증 완료
- [ ] 기준 문서 변경사항 반영(Product Spec FR/BR 이관, UI_UX, TECH_SPEC)
- [ ] PROJECT_STATUS 갱신
- [ ] HANDOFF 갱신
- [ ] ADR-008 Accepted, ADR-001과 ADR-007 개정

## 플레이테스트 기록
아직 기록이 없다. 매 단계 뒤 아래 양식을 복사해 한 회차씩 쌓는다. 항목은 Product Spec 게임 방향 기획 8-2절을 따른다. 판단 근거는 테스터 관찰과 로컬 로그이며, 원격 `game_events`를 쓸 때는 그 회차의 익명 사용자만 조회하고 끝나면 지운다.

### 회차 양식

```text
### PT-NN (YYYY-MM-DD, 빌드 커밋, 기기와 브라우저 또는 앱)
- 테스터: 인원, 매치 3 경험(없음, 가끔, 자주). 이름은 적지 않는다
- 진행: 처음 고른 모드, 모드별 판 수, 타임 모드 연속 판 수, 총 시간
- 규칙 이해: 하이퍼 교환과 탭 발동 차이를 설명 없이 알았는가(예, 아니요, 설명 뒤). 헷갈린 장면
- 다시 하기: 타임 모드 결과 뒤 바로 다시 했는가. 그만둔 이유
- 실력 체감: Speed Bonus를 노렸는가, 최고 단계. 점수 차이가 실력에서 나온다고 느꼈는가
- 마무리: Last Hurrah 길이가 지루했는가(짧다, 적당, 길다)
- 시간 보상(D7 판단용): 3개 매치만으로 시간이 늘어나는 것이 너무 쉬웠는가. 60초가 짧거나 길었는가
- 도전 스테이지: 목표를 바로 이해했는가, 클리어 여부와 남은 시간
- 일일 보드와 주간 순위: 같은 보드 반복이 지루했는가, 순위를 확인했는가
- 성능: FPS 평균, p95 프레임 시간, 멈춤 장면(PLAN-001 방식)
- 결정: 이번 회차로 바꿀 수치나 규칙, 보류한 항목
```
