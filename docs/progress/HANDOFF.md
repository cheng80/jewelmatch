# Handoff

> 다음 작업자가 즉시 시작할 정보만 둔다. 프로젝트 전체 상태는 PROJECT_STATUS.md에 둔다.

Updated: 2026-09-20 21:31 KST

## Current State
최신 추가 변경: 중력을 제거한 매칭 파편의 초기 속도를 1.4배, 수명을 65%로 조정했다. 보석 위 유휴 반짝임 밝기는 2/3, 대각선 광택 스윕 속도는 80%다(한 칸 0.9초, 반복 10초). 최종 튜닝은 main에 반영하며 같은 제품 코드에서 analyze, 전체279tests, Web release build가 모두 통과했다. 개발 서버는 사용자 요청으로 정상 종료했고 8080 포트 리스너가 없음을 확인했다. 추가 실행 중인 구현/검증 프로세스는 없다.

문서 팩은 대체 가능(REPLACEABLE). 정본은 docs/. 이전 문서는 archive/docs/. F1~T6가 통합됐고 독립 리뷰의 입력 3건, 자원 해제와 릴리즈 퇴장 문제 2건을 수정했다. 검증 공백은 표에 남아 있다. 최종 합본 HUD 글자 중복 가설은 PNG 픽셀과 실제 렌더 진단에서 기각됐으며 기존 confetti 겹침으로 확인했다. 실기기 전체 검증은 미완이며 Android 단기 계측 결과는 아래 보고서를 따른다. E2 hyper/supernova 레이어 통합은 main `c3b64dd`에 병합했고 main 분석, 전체 279 tests, Web release build를 통과했다. `fx-g2-sprites` Worktree와 연결된 Orca 터미널 2개는 정리했다. 기존 Claude main 세션은 사용자 정리 요청으로 종료했고, 재인계 예약도 취소 상태다.

## Last Completed
- 마이그레이션 가이드 기준으로 운영 칸을 이 팩에 맞춤
- 기존 주제 본문과 문서 전용 PNG 31장 이관
- 코드와 어긋나던 점수 산식, HUD 랭킹, 시계, 제출 시점을 문서에 반영
- 2026-08-23 대체 가능성 점검 12항을 표준 팩만으로 통과. 이후 정본 경로를 docs/로 옮기고 이전 문서는 archive/docs/로 둠
- 2026-09-20 F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료. T2가 F1 독립 검수의 입력 회귀 3건을 수정하고 회귀 테스트를 추가했으며 T5가 특수/HUD glow를 baked atlas로 전환
- 과거 합본 검증 `verify_integrated_final.txt`: analyze 0, 262 tests PASS, Web build 0. X2와 bomb 후속 변경으로 HISTORICAL/STALE
- 2026-09-20 다른 계열 교차 리뷰(X2)에서 확정된 결함 6건 수정을 main에 병합: 로딩 오버레이가 1.2초 뒤 멈추던 문제, iOS 15/16 Safari에서 피치 대신 배속만 바뀌던 문제(`webkitPreservesPitch`), 퇴장 고스트 해상도, 광고 결과 배너 위치, 웹 폴백 로그 rate, `CurvedAnimation` 해제
- 2026-09-20 bomb 범위 효과를 16프레임 플립북에서 정지 그림 5장 + 코드 타임라인 + 구운 글로우 밑깔기로 교체(`bomb_layers.png` 1280×256, `bomb_layer_timeline.dart`). 정점 지름 약 3.1칸, 수명 0.52초 그대로, bomb 텍스처 6.00MiB → 1.25MiB. 병합 직전 검증: analyze 0, 274 tests PASS, Web build 0
- G2 hyper/supernova 정지 레이어 PNG 납품과 정량 게이트 PASS를 확인했다. 제품 통합과 실제 Flutter 렌더 검증, main 병합과 병합 후 데스크톱 검증을 완료했다. 실기기 검증은 별도다.

## In Progress
- Plan: `PLAN-004` 보드 연출 보강. F1, T1, T2, T3, T4a, T4b, T5, T6 구현과 통합 완료. 2026-09-20 통합 브랜치를 커밋해 main에 fast-forward 병합했다(로컬). push 여부는 `git status`로 확인한다
- Task: 실기기 검증. 합본 HUD 진단은 glyph 중복 근거 없음으로 마감했다.
- Task: E2는 main 병합 및 작업 세션 정리 완료. Claude 재인계는 취소됐으며 Codex가 현재 main에서 계속한다.
- 주의: T2의 균등 gem atlas 제출은 batch지만 여러 행의 착지 squash는 `drawImageRect` fallback으로 draw call이 9회를 넘을 수 있다. T5 special glow는 약 4.5MiB 공유 이미지이며 T4a HUD interactions와 painters 구조를 유지한다
- 주의: T4b 타임업은 reduced motion에서도 결과를 즉시 읽히게 하되 1900ms 제출과 버튼 활성 시점을 유지한다. ego 캡처 문자 중복은 headless에서 재현되지 않아 원인 미확정
- 주의: Android Chrome 단기 FPS 계측만 수행했다. 장시간 WebView, iPhone, 실제 광고 SDK, 실제 기기 오디오 청취는 미검증이다
- E2 검증: 전체279tests와 Web build exit0, 최종 analyze exit0. 독립 관련78회귀와 별도픽셀4회귀 PASS. 고정pivot, tier, 풀 재사용, 종료, bomb 초기픽셀 및 supernova 외곽번개 보존 확인.
- Plan: `PLAN-001`
- Task: TASK-001c 실기기 30초 이상 카운터 보존

## Next Task
1. Claude 재인계는 사용자 요청으로 취소했다. 현재 main과 Android 검증 보고서를 기준으로 이어간다. 완료된 E2를 재적용하거나 정리된 Worktree를 재생성하지 않는다.
2. 실기기 FPS, 가독성, 오디오와 광고 흐름 확인. iOS 15/16 기기에서 연쇄와 저시간 틱의 피치가 실제로 오르는지 듣는다
3. `?fps=1`로 모바일 실기기 FPS 전후 비교와 장시간 WebView 확인
4. PLAN-001 실기기 장시간 측정 (원문부터 INCOMPLETE. 별도 승인 작업)
5. 이전 문서는 archive/docs/에 있음. 삭제 여부는 별도 결정
6. STALE AIT 재검증과 PLAN-001 실측은 이관 밖 별도 작업

## Blocked
- PLAN-002, TASK-004: 외부 값/정책

## Known Issues
- ISSUE-001, ISSUE-002: 모바일 웹 오디오/FPS. PLAN-001
- ISSUE-003: 광고 3회 세션 로컬
- ISSUE-004: 인벤토리 비영속 (2차 허용)
- ISSUE-005: 빈 App Store ID

## Changed Contracts
- PLAN-004: `ParticleBurst`/`ParticlePool` 삭제, `BoardJuiceLayer`로 대체. `hasActiveVisualEffects`는 유휴 반짝임을 포함하지 않음. HUD 점수는 롤업 표시값이고 저장/랭킹은 `board.score` 그대로. F1~T6 통합과 T2 입력 회귀 및 독립 리뷰 P2 수정 완료
- PLAN-004 시각 계약: gem atlas 512×640, 64px 셀, baked sheen, squash fallback, special glow 약 4.5MiB 공유 이미지, T4a HUD 구조 유지
- PLAN-004 화면 계약: T4b 공통 카드/exit/reduced motion, TimeUp 1900ms 제출 및 입력 시점, 레벨 축하 일반 3000ms, reduced motion 즉시 완료
- BR-040: 레벨 1~5는 level*7500, 6부터 37500+(level-5)*5000. ADR-006
- BR-092: HUD 랭킹/top1은 타임 전용
- BR-073: 시계는 인트로, 즉시형 확인, 프리즘 색 선택 중 정지
- BR-093: Pause 나가기는 제출 await, TimeUp 나가기는 기다리지 않음. ADR-007
- BR-072: 하이퍼 큐브는 일반 보석만

## Important Decisions
- ADR-001 특수 보석 탭 발동
- ADR-002 진행 랭킹 = 완료 레벨 수
- ADR-003 선택형 광고만
- ADR-004 웹 HTML Audio 4슬롯
- ADR-005 STORE_CHANNEL define
- ADR-006 목표 점수 완화
- ADR-007 제출 시점과 HUD 범위

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2의 3개 회귀 테스트와 pointer flow 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T1~T5의 ego/headless, 위젯, 픽셀 근거. T4b ego 문자 중복은 headless 재현 없음, 원인 미확정 |
| PLAN-004 mobile device UI / FPS | PARTIAL | RECHECKED | 2026-09-20 21:20 KST | `99622e9` | INCOMPLETE | Android Chrome35초 rAF 평균63.94FPS, p95 33.57ms, GAP55.94ms. 첫 멈춤 원인 미확정, iPhone/광고A/B/장시간 미완. `tmp/android-fps-20260920/RESULT.md` |
| T6 level celebration | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | 일반 3000ms / reduced motion 즉시, 점수/시간/보상 불변 테스트와 합본 화면 확인 |
| Independent review fixes | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1 입력 3건, 게임 이탈 자원 해제와 release snapshot P2 수정 및 재검증. 합본 HUD 추가 진단은 기존 confetti 겹침으로 마감 |
| NAS Web smoke | PASS | RECHECKED | 2026-09-20 21:20 KST | 제품 main `99622e9` | CURRENT | `tmp/nas-deploy-20260920/`: Wasm 배포 HTTP200, index/bootstrap/wasm/MP3 원격 해시 일치, deep route200, 격리 헤더, 두 모드 랭킹 조회 통과. Android 게임 로드 확인 |
| Apps in Toss 재배포 | PASS | HISTORICAL | 2026-08-15 | d777cf0 | STALE | git 문서: 일반 AIT 재배포. 이후 오디오 수정. 현재 리비전 미재검증 |
| Web 장시간 오디오/FPS | INCOMPLETE | HISTORICAL | 2026-08-23 이전 | PLAN-001 / ADR-004 원문 | UNKNOWN | 짧은 수동 확인만 통과. 장시간 카운터 없음. 원문부터 미완 |
| Android/iOS store device | NOT_RUN | NONE | UNKNOWN | UNKNOWN | UNKNOWN | 출시 체크리스트 미완 |
| Release build F1-T6 revision | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | integrated_final Web build exit=0. 이후 X2와 bomb 후속 변경, 모바일/스토어 실기기 스모크는 별도 미실행 |
| E2 hyper/supernova layer integration | PASS | HISTORICAL | 2026-09-20 19:54 KST | main `c3b64dd` (후속 문서 갱신만 추가) | STALE | `verify_main_after_E2_merge.txt`: main 병합 후 analyze exit=0, 전체 279 tests PASS, Web release build exit=0. 병합 전 독립 78회귀+픽셀4회귀와 실제 보드 캡처도 확인. 실기기 미검증 |
| 매칭 파편 방사형 소멸 | PASS | HISTORICAL | 2026-09-20 20:24 KST | main `9137895` + 미커밋 파편 수정 | STALE | `tmp/match-radial-fx/analyze.log`: analyze exit0, `test.log`: 전체 279 tests PASS. 웹 릴리즈 재빌드와 새 브라우저 캡처는 미실행 |
| 매칭 속도/반짝임/광택 스윕 튜닝 | PASS | RECHECKED | 2026-09-20 21:06 KST | 이 문서를 포함한 main 튜닝 커밋과 동일 제품 코드 | CURRENT | `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_main_tuning_before_commit.txt`: analyze exit0, 전체279tests PASS, Web release build exit0. 앞선 debug hot reload와 화면 유지 확인. 실기기 미검증 |

## Files to Read First
1. progress/PROJECT_STATUS.md
2. 이 파일
3. plans/PLAN-004-board-juice.md
4. plans/PLAN-001-mobile-web-audio-fps.md
5. decisions/ADR-004-web-html-audio-sfx.md
6. 01_PRODUCT_SPEC.md 의 FR-003, FR-010

## Resume Commands
이 팩만 보고 실행한다. 비밀은 넣지 않는다.

    flutter test
    flutter analyze

웹 측정이 필요하면 PLAN-001의 웹 빌드 절과 FPS 패널(`?fps=1` 또는 `?qaPerf=1`)을 쓴다.

## Open Questions
- STALE 배포 증거를 현재 리비전에서 재검증할지는 이관 밖 결정
- 21:20 KST Claude 재인계 예약은 사용자 요청으로 PAUSED 처리했다. 인계 프롬프트 전송 없음.
- PLAN-002 식별 저장 정책

## Constraints / Do Not Change
- BR-001, BR-002
- 특수 보석 탭 발동, 스왑 조합 비활성
- 강제 전면 광고 없음
- ranking.php를 웹 빌드/제출 ZIP에 넣지 않음
- Riverpod codegen 금지
- 사용자 문구 중간점 금지
- ADR-004: Web Audio로 되돌리지 말 것
- STALE/INCOMPLETE를 숨기지 말 것. 이전 문서는 archive/docs/
- 정본 docs/와 archive/docs/를 서로 링크로 묶지 말 것
- 현재 작업 폴더는 `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/jewelmatch`의 main이다. 정리된 `fx-g2-sprites`나 이전 통합 Worktree를 사용하지 말 것
- 삭제 전 자료 148파일의 SHA256을 확인했고 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/backups_pre_cleanup/fx-g2-sprites-20260920-e2`에 보존했다. 보고서와 보드 PNG는 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration`에도 유지한다.
- 제품 main `99622e9`는 origin/main 푸시 및 NAS 배포 완료. Android 짧은 계측만 수행했으며 전체 실기기 검증 완료로 오인하지 말 것

- 합본 HUD 최종 진단(16:08 KST): 무손실 PNG의 추가 밝은 glyph 픽셀 0, 변한 픽셀은 confetti 색 합성으로 설명됐다. pause 150프레임 동안 game render/update 증가 0. 제품 소스 변경 없이 가설 기각. 근거: `_fx_orchestration/reports/T6_integrated_visual_fix.md`.

## 최신 NAS 배포와 Android 계측 (2026-09-20 21:20 KST)
- main `99622e9` 푸시, 로컬 웹 산출물 정리, NAS Wasm 배포 완료. 로컬 개발 서버와 scrcpy 미러링은 종료했다.
- 사용자 첫 이펙트 멈춤 제보를 개발자 도구로 조사 중. 35초/유효 입력34회 측정에서 큰 멈춤은 재현되지 않았으나 90Hz 기기 평균63.94FPS/p95 33.57ms로 성능 검증은 미완. GPU/워커 추적을 포함한 원인 확정이 다음 우선 작업이다.
- 원시자료와 제한은 `tmp/android-fps-20260920/RESULT.md`와 `profile.json`. 초기 화면 GAP280ms와 재측정 GAP55.94ms는 조건이 달라 개선 수치로 비교하지 않는다.

## 재접속 확인과 인계 취소 (2026-09-20 21:26 KST)
- 게임 탭 완전 종료 후 재접속 및 첫 매치/특수효과를 재측정했다. 로딩 최대190.2ms, 첫 매치22.4ms, 첫 bomb/hyper/supernova33.6/44.8/44.8ms. 긴 작업은 첫 매치 이전 Wasm 초기화/초기 렌더 구간에 집중됐다. 최초 사용자 멈춤의 동일 원인 여부는 미확정.
- 상세 근거와 한계: [Android NAS FPS 검증](ANDROID_NAS_FPS_2026-09-20.md). 제품 코드 수정 없음.
- 사용자 요청으로 Claude 인계 예약을 취소(PAUSED)했고 현재 Codex가 계속한다. 기존 Claude에 재개 프롬프트를 보내지 않았다.

## 사용 종료 세션과 브랜치 정리 (2026-09-20 21:31 KST)
- jewelmatch Orca Claude main 세션 `term_15b04b61-db10-4b8c-a439-b4a5739056b8`을 닫았다. 개별 close의 ptyKilled=true, 후속 terminal list의0개, 해당 Claude와 자식 프로세스 부재로 종료를 확인했다. 최초 bulk close의 완료 확인 오류는 개별 종료와 후속 검증으로 해소했다.
- Git/Orca 워크트리는 main1개뿐이며 잔여 작업 워크트리나 prune 대상이 없다. main에 조상으로 포함된 `codex/intoss-level-leaderboard-ui`(643781d) 로컬 브랜치를 `git branch -d`로 삭제했다. 로컬 브랜치는 main만 남는다. 원격 브랜치는 변경하지 않았다.
- main 사용자 변경과 미추적 파일 없음. 원본 에셋/보고서/Android 원시 계측/이전 Worktree 백업 보존. 정리 전 터미널 메타데이터/화면과 브랜치/Worktree 목록은 `_fx_orchestration/backups_pre_cleanup/main-session-20260920/`에 보관했다.
- 기존 Claude 재개 기록을 현재 작업의 인계 대상으로 사용하지 않는다. 취소한 인계 예약은 PAUSED 유지. 현재 Codex 작업과 다른 프로젝트 세션은 유지했다.
