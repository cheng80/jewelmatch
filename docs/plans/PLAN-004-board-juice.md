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
- 규칙, 점수식, 상태 머신 타이밍(`removeDelay` 등) 변경
- 콜아웃 문구 번역, 새 에셋, 새 dependency
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

### Step 3 확인과 튜닝
- [ ] 실제 화면에서 눈으로 확인(파티클 크기, 밝기, 수명, 콜아웃 위치)
- [ ] 모바일 웹 실기기 FPS 패널(`?fps=1`)로 전후 비교
- [ ] 02_UI_UX SCREEN-003에 연출 설명 추가

## 5. 예상 변경 범위
- 파일/모듈: `lib/game/components/board_juice_layer.dart`(신규), `match_board_renderer.dart`, `match_board_gem_overlay_renderer.dart`, `match_game_hud*.dart`, `match_board_{models,update,resolution,input,logic}.dart`, `match_board_game{,_vfx}.dart`, `particle_burst.dart`(삭제)
- DB/API 영향: 없음
- UI 영향: 보드와 HUD 연출만
- 배포/마이그레이션 영향: 없음

## 6. 검증 계획
- [x] Unit test: `test/board_juice_test.dart`(착지 스쿼시, 수렴과 탄생 팝, 무효 범프)
- [x] `flutter test --no-pub` 135 passed, `flutter analyze --no-pub` No issues
- [x] `flutter build web --release --no-pub` 통과(4칸 아틀라스 확장 전 리비전)
- [ ] UI 수동 검증: 미실행. 자동화 브라우저 창이 가려져 프레임이 초당 1회로 묶여 스크린샷 실패

## 7. 위험 / 미해결 사항
- 파티클과 텍스트가 화면에 어떻게 보이는지 아직 아무도 보지 않았다. 수치는 전부 1차 추정값.
- `BlendMode.plus`는 밝은 배경에서 하얗게 포화된다. 현재 보드는 어두워서 문제없을 것으로 예상.
- 점수 롤업은 굴러가는 동안 약 0.045초마다 `TextPainter`를 다시 만든다. 실기기에서 부담되면 간격을 늘린다.

## 8. 완료 조건
- [x] 계획한 구현 완료
- [ ] 필요한 테스트/검증 완료
- [ ] 기준 문서 변경사항 반영
- [x] PROJECT_STATUS 갱신
- [x] 다음 작업자가 필요하면 HANDOFF 갱신
- [ ] 장기적으로 남길 중요한 결정은 ADR로 분리(현재 해당 없음)
