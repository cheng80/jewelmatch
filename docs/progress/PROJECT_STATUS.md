# Project Status

> 프로젝트 전체의 NOW. 다음 작업자 인계 문장은 HANDOFF.md에 둔다. 구현 상태와 검증 상태를 섞지 않는다.

Updated: 2026-09-20 21:31 KST

## Current Phase
Phase 3 — Stabilization (Phase 4 출시 값은 대기)
이관 단계: 대체 가능(REPLACEABLE). 2026-08-23 표준 팩만으로 대체 가능성 점검 12항 통과. 정본은 docs/. 이전 문서는 archive/docs/. 릴리즈 준비와 분리.

## Active Plan
- `PLAN-001` 모바일 웹 오디오/FPS 회귀 — IN_PROGRESS
- `PLAN-004` 보드 연출 보강 — IN_PROGRESS (F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료, T6 및 독립 리뷰 수정 완료, 합본 HUD 잔상 가설은 픽셀 진단으로 기각, 기존 confetti 겹침)

## Current Tasks
- [x] TASK-001a HTML Audio 4슬롯/경로/unlock/웹 BGM replay
- [x] TASK-001b 짧은 수동 확인 (복귀 SFX, 다시 하기 BGM)
- [ ] TASK-001c 실기기 30초 이상 카운터 보존 — IN_PROGRESS
- [ ] TASK-001d 무한 모드 배너 표시/미표시 A/B
- [ ] TASK-001e 특수효과 표시/미표시 A/B
- [ ] TASK-001f 결과로 Status/Handoff 갱신
- [x] TASK-004a PLAN-004 Step 1, 2 구현 (보석 물리감, BoardJuiceLayer, HUD 롤업)
- [x] TASK-004b 화면/오버레이 연출, 보석 피드백, 사운드 계층 및 blur 제거 통합, UI_UX 반영
- [x] TASK-004c T6 레벨 클리어 시각 연출, reduced motion 즉시 완료 및 독립 리뷰 수정
- [x] TASK-004d 합본 HUD 잔상 가설 진단: 추가 glyph 없음, 기존 confetti 겹침, 제품 수정 없음
- [x] TASK-004e 다른 계열 교차 리뷰(X2) 결함 6건 수정과 main 병합
- [x] TASK-004f bomb 범위 효과를 정지 그림 + 코드 타임라인 + 구운 글로우로 교체, main 병합
- [x] TASK-004g hyper, supernova 레이어 전환 구현과 데스크톱 검증 완료 (main `c3b64dd` 병합 및 작업 Worktree/Orca 세션 정리 완료)
- [x] TASK-004h 기본 매칭 파편/콤보 별빛의 중력과 위쪽 편향 제거, 방사형 감속/소멸로 조정. 후속 확산1.4배, 수명65%, 유휴 반짝임2/3, 광택 스윕80%/반복10초 (main 반영)
- [ ] TASK-004d 모바일 실기기 FPS 전후 비교, 장시간 WebView와 실제 광고 SDK 확인
- [x] TASK-MIG-001 F1~T6 합본 analyze / test / web build 과거 통과 기록 보존. E2 데스크톱 검증은 완료, 실기기 스모크는 미실행

## Completed
- Phase 1 Foundation, Phase 2 Core Features
- 문서 계약을 코드 기준으로 맞춤
- Standard 구조: ROADMAP / PLAN / STATUS
- 기존 주제 본문·문서 자산 Detailed Migration

## Blocked / Known Issues
- PLAN-002: 토스 사용자 식별과 서버 저장 정책 없음
- TASK-004: Apple ID, 개인정보 URL, INTOSS 운영 광고 그룹은 제품 외부 결정
- ISSUE-001: 모바일 웹 오디오 끊김 이력, 장시간 카운터 없음 → PLAN-001
- ISSUE-002: 앱인토스 iPhone FPS 급락, GC 단정 금지 → PLAN-001
- ISSUE-003: refill 3회 세션 로컬 → PLAN-002
- ISSUE-004: RunInventory 비영속 → PLAN-003 (2차 범위로는 허용)
- ISSUE-005: 빈 App Store ID

## Implementation Status
- 주요 기능: 3모드 매치-3, 특수 보석 탭 발동, 레벨 런 인벤토리 2차, 선택형 광고, 랭킹, 다국어. F1, T1, T2, T3, T4a, T4b, T5 연출 통합 상태. hyper/supernova 레이어 후속 E2는 main `c3b64dd`에 반영했고 병합 후 데스크톱 검증을 통과했다. 버전 1.0.0+1
- Release Readiness: 스토어 문서 초안과 채널 define은 있음. 운영 광고 그룹, Apple ID, URL, flavor 미입력. 장시간 모바일 웹 회귀 미완

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2 회귀 테스트가 안착/제거 중 드래그, 범프 잔류, geometry stale bump 3건과 pointer flow를 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1/T1/T2/T3/T4a/T4b/T5 근거. T4b ego 문자 중복은 headless에서 재현되지 않아 원인 미확정 |
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

## Next
1. Claude 인계 예약은 사용자 요청으로 취소했다. Codex가 현재 main에서 Android 첫 멈춤 재현 결과를 이어 관리한다. 개발 서버는 중지 상태다
2. 실기기 FPS, 가독성, 오디오와 광고 흐름 확인. iOS 15/16에서 연쇄와 저시간 틱의 피치 상승을 청취
3. 모바일 실기기 `?fps=1` 전후 비교, 장시간 WebView 오디오/FPS와 실제 광고 SDK 확인
4. PLAN-001 장시간 측정은 원문부터 INCOMPLETE. 별도 승인 작업이지 이관 공백 메우기가 아님
5. STALE AIT를 현재 리비전으로 볼지는 별도 Task. 이관 완료 조건이 아님
6. 출시 값이 오면 TASK-004. 식별 정책이 오면 PLAN-002를 READY

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
