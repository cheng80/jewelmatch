# PLAN-004 보드 연출 보강

## Metadata
- Plan ID: `PLAN-004`
- Title: 매치 3 원작 수준의 연출, 애니메이션, 파티클 보강
- Status: `IN_PROGRESS`
- Related Requirement: FR-001 ~ FR-003 (보드 플레이 체감)
- Related ADR: 없음
- Owner: KIM TAEK KWON
- Updated: 2026-09-20

## 1. 목표
67a2417에서 모바일 웹 FPS 때문에 매치 파티클을 뺀 뒤 밋밋해진 보드에, 부하를 되돌리지 않는 방식으로 파티클과 물리감을 다시 넣는다.

## 2. 범위
### 포함
- 보석 물리감: 착지 스쿼시, 제거 팝, 특수 보석 탄생 팝과 수렴, 무효 스왑 범프, 선택 맥동, 힌트 끌림, 특수 보석 호흡
- `BoardJuiceLayer`: 충격파 링, 섬광, 파편, 별, 유휴 반짝임, 점수 팝업, 콤보 콜아웃
- 콤보 셰이크, 저시간 보드 테두리 맥동, HUD 점수 롤업과 펀치

### 제외
- 규칙, 점수식, 기존 단계 타이밍(`removeDelay` 등) 변경. 단, 사용자 승인으로 유효 스왑 뒤 `swapSettle` 0.12초만 추가
- 콜아웃 문구 번역, 새 dependency
- 새 에셋은 원칙적으로 제외한다. 단, 승인된 특수효과 레이어 후속(`bomb` E1 및 `hyper`/`supernova` G2 납품 후 E2 통합)의 정지 레이어 에셋은 기존 범위형 효과를 교체하기 위한 예외로 허용한다.
- 프래그먼트 셰이더(모바일 WebView 호환 위험), 히트스톱

## 3. 현재 상태 / 전제
- 기존 구현: `ParticleBurst`는 파티클마다 `Path` 생성 + `MaskFilter.blur`라 비쌌고, 스폰이 빠진 채 warm-up만 남아 있었다. 이번에 삭제.
- 제약사항: PLAN-001 5.3, 5.4. `render()`/`update()`에서 객체 생성 금지, blur/`saveLayer` 금지.
- 조사 결론: CustomPainter는 Flame `render(Canvas)`와 같은 `dart:ui` Canvas라 이득이 없다. 실제 지렛대는 `drawRawAtlas` 일괄 그리기, 아틀라스에 구운 광륜, 가산 합성, typed 버퍼 재사용이다. Flame `ParticleSystemComponent`는 파티클마다 객체와 클로저를 만들어 제외.
- 반드시 유지할 계약: `hasActiveVisualEffects`에 유휴 반짝임을 넣지 않는다(레벨업 판정이 멈춘다).

## 4. 구현 계획
### Step 1 보석 물리감
- [x] `BoardGem.landT/popT/airborne`, `_tickGemJuice`, `_convergeOnSpawns`, 무효 스왑 범프
- [x] 렌더러 변환 통합(스쿼시, 팝, 호흡, 선택, 힌트), 제거 팝 커브, 저시간 맥동

### Step 2 파티클과 텍스트
- [x] `BoardJuiceLayer` 4칸 아틀라스 + 192슬롯, 점수 팝업, 콤보 콜아웃, 콤보 셰이크
- [x] HUD 점수 롤업, 점수/콤보 펀치

### Step 2 보강 트랙 통합 상태
- [x] T1 보드 이벤트, 패턴별 파티클, 특수 발동, 리필 및 시간 보너스 표시
- [x] T2 보석 512×640 아틀라스, baked sheen, 선택 및 스왑 후보 광륜, 무한 모드 5초 자동 힌트
- [x] T3 콤보 및 매치 등급, 저시간 틱의 웹 피치 계층과 HTML Audio 4슬롯 회귀 보강
- [x] T4a HUD 목표, 콤보, 타임바, 버튼, 힌트, 아이템 소모 피드백
- [x] T4b 오버레이, 타이틀, 로딩, 인벤토리, 타임업, 광고 결과 화면 모션과 reduced motion 계약
- [x] T5 특수 burst 및 HUD의 직접 런타임 blur를 baked glow atlas로 교체
- [x] E2 hyper/supernova 범위 효과 레이어 통합과 데스크톱 검증 완료, 실기기 미검증

### Step 3 확인과 튜닝
- [x] 데스크톱 실제 화면과 픽셀 렌더 확인(파티클 크기, 밝기, 수명, 콜아웃 위치). 합본 HUD 잔상은 별도 확인 중
- [ ] 모바일 웹 실기기 FPS 패널(`?fps=1`)로 전후 비교
- [x] 02_UI_UX SCREEN-003과 화면 전환 및 접근성 연출 설명 추가
- [x] T6 순차 시각 연출 및 reduced motion 즉시 완료
- [x] 통합 독립 리뷰와 확인된 P2 수정 완료

## 5. 예상 변경 범위
- 파일/모듈: `lib/game/components/board_juice_layer.dart`(신규), `match_board_renderer.dart`, `match_board_gem_overlay_renderer.dart`, `match_game_hud*.dart`, `match_board_{models,update,resolution,input,logic}.dart`, `match_board_game{,_vfx}.dart`, `particle_burst.dart`(삭제)
- DB/API 영향: 없음
- UI 영향: 보드, HUD, 타이틀 및 오버레이 전환, 레벨 클리어 시각 연출
- 배포/마이그레이션 영향: 없음

## 6. 검증 계획
- [x] Unit test: `test/board_juice_test.dart`(착지 스쿼시, 수렴과 탄생 팝, 무효 범프)
- [x] F1, T1, T2, T3, T4a, T4b, T5, T6 전용 및 회귀 테스트
- [x] 통합 검증 기록: `analyze exit=0`, 전체 `262 tests` PASS, Web build exit=0 (`reports/verify_integrated_final.txt`, 2026-09-20 15:53 KST). HISTORICAL이며 X2와 bomb 후속 변경으로 STALE
- [x] bomb E1 해당 리비전 검증 기록: analyze 0, `274 tests` PASS, Web build 0. HISTORICAL이며 E2 후속 통합 전 결과
- [x] `flutter build web --release --no-pub` 통과(4칸 아틀라스 확장 전 리비전)
- [x] 데스크톱 ego/headless 화면 검증 및 픽셀/위젯 검증. T4b ego 문자 중복은 headless에서 재현되지 않아 원인 미확정
- [ ] 모바일 실기기 UI와 FPS 전후 비교
- [ ] 실제 광고 SDK 및 모바일 WebView 장시간 검증

## 7. 위험 / 미해결 사항
- 자동화 브라우저와 픽셀 회귀에서 파티클, 텍스트, HUD 및 화면 전환을 확인했다. 자동화 캡처 rAF는 실기기 성능 근거가 아니다.
- `BlendMode.plus`는 밝은 배경에서 하얗게 포화된다. 현재 보드는 어두워서 문제없을 것으로 예상.
- T2의 균등 보석 batch는 일반 프레임 draw 1회이지만 착지 squash fallback이 여러 행에 흩어지면 draw call이 9회를 넘을 수 있다. T5의 번개 glow는 blur 대신 선분별 stamp로 transient draw call이 늘어나는 절충이 있다.
- T4b ego 캡처의 일부 타임업 문자 중복은 headless에서 재현되지 않았고 원인을 확정하지 않았다.
- T6 일반 축하는 3000ms 뒤 완료하며 reduced motion은 첫 post-frame에 즉시 완료한다. 점수와 보상은 변경하지 않는다.

## 8. 완료 조건
- [x] 계획한 구현 완료
- [ ] 필요한 테스트/검증 완료: 모바일 실기기 FPS 미완, 합본 HUD 잔상 가설은 픽셀 진단으로 기각, 기존 confetti 겹침
- [x] 기준 문서 변경사항 반영
- [x] PROJECT_STATUS 갱신
- [x] 다음 작업자가 필요하면 HANDOFF 갱신
- [ ] 장기적으로 남길 중요한 결정은 ADR로 분리(현재 해당 없음)


## 9. Codex 인수 F1 (2026-09-20)

- Claude 작업 중단 상태를 보존하고 기반 튜닝을 수행했다. 커밋은 아직 하지 않았다.
- 유효 스왑만 swapSettle 0.12초 뒤 기존 판정으로 넘어간다. 제거/낙하/리필 간격, 점수식, 프리즘 및 특수 탭 직접 발동은 그대로다. 안착 중 중복 입력은 거절한다.
- 무효 스왑은 보석별 0.18초 sin 범프로 처리하며 기존 입력 잠금 0.04초는 늘리지 않는다. 새 유효 스왑은 잔여 범프를 취소한다.
- 제거 시작 섬광을 아틀라스로 한 번 방출하고 셀 사각형 플래시를 없앴다.
- 기본 파편 6→10, 중간 8→12, 강한 단계 10→14. 전체 192슬롯과 버스트 예산 150 유지.
- 섬광 0.2→0.12초, 크기 1.35→0.75타일. 링 0.4→0.32초, 크기 1.7→1.25타일, 아틀라스 링 띠 폭 축소.
- 콤보 2~3은 0.6초, 상위는 0.8초이며 보드 위쪽 가장자리로 이동. 점수 팝업은 0.65초, 연쇄별 사다리 배치와 상단 콜아웃 영역 회피.
- 유휴 반짝임 간격 0.22~0.32초, 크기 0.60~0.80타일. 진행 완료 대기에는 포함하지 않는다.
- 아틀라스는 onMount에서 재생성, onRemove에서 해제. 활성 슬롯만 압축하며 길이별 typed-data 뷰를 미리 캐시한다.
- 최초 검증: analyze 및 전체 136 tests, web release build 성공. 이후 재마운트와 busy 판정 회귀 테스트 추가, 최종 재검증 결과는 F1_report.md 및 통합 인계 참조.
- ego-browser 프레임에서 파편, 반짝임과 사각형 제거를 확인했다. rAF 31/s 캡처 환경이므로 실기기 성능 통과 근거로 삼지 않는다.

## 10. F1~T6 통합 인수 (2026-09-20 15:53 KST)

- 통합 WT에 F1~T6가 적용됐고 독립 리뷰 및 두 P2 수정이 완료됐다. 합본 HUD 잔상은 별도 확인 중이다.
- T2가 F1 독립 검수의 세 회귀를 수정했다. 안착 또는 제거 중 드래그를 거절하고, 무효 범프를 드래그 시작 및 geometry 변경에서 취소하며, 새 유효 스왑에서 잔여 복귀를 취소한다.
- T2의 gem atlas는 512×640, 64px 셀이다. 정상 보석 제출은 batch draw를 사용하고 비균등 squash는 `drawImageRect` 예외 경로를 사용하므로 프레임별 draw call 상한 9를 계약으로 두지 않는다. T5 special glow는 약 4.5MiB 공유 이미지이며 T4a HUD interactions와 painters 구조를 유지한다.
- T4b는 타임업의 1900ms 제출 및 입력 시점, reduced motion의 즉시 표시를 함께 검증했다. 레벨 축하는 일반 3000ms, reduced motion 즉시 완료이며 시각 연출만 구동한다.
- 최신 합본 근거였던 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_integrated_final.txt`는 `analyze 0`, `262 tests PASS`, Web build 0의 HISTORICAL 기록이다. 2026-09-20 16:24 KST 다른 세션에서 같은 작업트리를 재검증했고(`verify_claude_recheck.txt`, 같은 결과) 그 뒤 main에 병합했다. X2와 bomb 후속 변경으로 현재 기준에서는 STALE이다.
- bomb E1 후속 리비전은 analyze 0, `274 tests PASS`, Web build 0을 남겼다. 이 결과도 해당 리비전의 HISTORICAL 기록이며 hyper/supernova E2 통합 검증을 포함하지 않는다.
- Codex가 `fx-g2-sprites`를 재인수해 E2 구현과 실제 Flutter 렌더/전체279tests/analyze/Web build 검증을 완료했다. main `c3b64dd`에 병합했으며 실기기 미검증 상태다. 상세는 11절이다.

- 합본 HUD 최종 진단(16:08 KST): 무손실 PNG의 추가 밝은 glyph 픽셀 0, 변한 픽셀은 confetti 색 합성으로 설명됐다. pause 150프레임 동안 game render/update 증가 0. 제품 소스 변경 없이 가설 기각. 근거: `_fx_orchestration/reports/T6_integrated_visual_fix.md`.

## 11. E2 hyper/supernova 레이어 전환 (2026-09-20 19:30 KST)
- 기존 Orca G2 납품을 검수하고 동일 WT/구현 세션을 재사용했다. 각 효과는 1280×256, 256px 정수 셀 5칸, pivot128로 렌더한다. 효과별 캐시/실패 폴백과 공용 typed renderer를 사용하고 코드 타임라인으로 성장/회전/소멸한다.
- bomb 곡선/배율과 세 효과 수명(.52/.60/.72초), 점수/보상/영향셀, supernova 십자 번개를 유지했다. 숨김 슬롯의 scale0으로 뒤 레이어가 사라지는 CPU Skia 문제를 실제픽셀로 재현하여 alpha0+가역변환으로 수정했다.
- 전체279tests/Web release exit0. 초기 analyze의 테스트스타일 및 리뷰tmp 경고를 정리하고 최종 analyze exit0. 독립78관련회귀/4픽셀회귀 PASS, 데스크톱 보드캡처 확인. 보고서 `_fx_orchestration/reports/E2_review.md` 및 E2 검증 로그 참조.
- 2026-09-20 19:54 KST: main `c3b64dd` 병합 후 analyze 0, 전체 279 tests PASS, Web release build 0을 재확인했다(`reports/verify_main_after_E2_merge.txt`). main과 feature의 tree 동일 및 clean 확인 후 `fx-g2-sprites` Worktree와 Orca 터미널 2개를 정리했다. 검증 자료는 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/backups_pre_cleanup/fx-g2-sprites-20260920-e2`에 보존했다. 실기기 FPS/오디오/광고 미검증, 21:20 기존 Claude main 인계 예약은 유지한다.

## 12. 기본 매칭 파편의 방사형 소멸 (2026-09-20)
- 사용자 피드백: 매칭 파편이 퍼지다가 아래로 쏟아져 물방울이나 풀잎처럼 보인다.
- `onGemsRemoved`의 파편/별과 콤보 별빛에 중력 0을 적용하고, 매칭 파편의 초기 위쪽 편향을 제거한다. 양 축에 같은 감속을 적용해 방출 방향을 유지하며 기존 축소/페이드아웃으로 끝낸다.
- 중력은 고정 크기 typed 버퍼에 슬롯별로 저장하고 방출 때마다 초기화한다. 특수 생성/발동과 리필 입자는 기존 중력을 유지한다. 파티클 개수, 수명, busy 시간, 점수와 게임 판정은 변경하지 않는다.
- 검증: `flutter analyze --no-pub` exit0, 전체 `flutter test --no-pub` 279 tests PASS. 로그 `tmp/match-radial-fx/`. 중력 제거 직후 시점에는 웹 릴리즈 재빌드 및 새 브라우저 캡처가 미실행이었고 main 미커밋 상태였다. 이후 튜닝과 최종 검증은 13절을 따른다.

## 13. 매칭 속도와 보석 광택 튜닝 (2026-09-20 20:58 KST)
- 사용자 요청: 파편이 더 빨리 퍼지고 사라지도록 조정, 반짝임 밝기 2/3, 대각선으로 이동하는 광택 스윕 감속. 사용자가 말한 스켈레톤 효과는 보석의 광택 스윕으로 확인했다.
- 매칭 파편/콤보 별빛 초기 속도1.4배, 링/섬광/파편/콤보 별빛 수명0.65배. 기존 중력0 유지. `_twinkleKind` 알파에2/3를 곱한다.
- 보석 광택의 시간 진행만0.6배로 낮췄다. 한 칸 통과0.72→1.2초, 반복6→10초. 보석별 위상과6프레임 아틀라스는 유지한다.
- analyze exit0, 관련5파일34tests PASS (`tmp/match-radial-tuning/`). 실행 중 debug 서버 hot reload425ms 성공, 현재 게임 화면 유지 확인. 전체279tests는 직전 중력 제거 리비전의 과거 결과다. 이번 변경의 웹 릴리즈 빌드와 실기기 검증은 미실행.
- 사용자 최종 조정(21:01 KST): 광택 스윕 시간 배율을 0.6→0.8로 변경했다. 최종 한 칸 통과 0.9초, 반복 주기 7.5초다.
- 사용자 반복 주기 조정(2026-09-20 21:04 KST): 속도0.8/한 칸0.9초를 유지하고 위상 주기6→8로 변경해 반복을10초로 분리했다. 최종 analyze0/관련34tests PASS, debug hot reload625ms 성공.

- 최종 main 반영 검증(2026-09-20 21:10 KST): 사용자 최종값 속도0.8/반복10초를 포함한 제품 코드에서 analyze exit0, 전체279tests PASS, Web release build exit0. 근거 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_main_tuning_before_commit.txt`. 튜닝 코드와 문서를 main에 함께 반영한다. 개발 서버는 사용자 요청으로 정상 종료했고 8080 리스너가 없음을 확인했다. 실기기 FPS/오디오/광고 검증은 남아 있다.
