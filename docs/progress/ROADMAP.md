# Roadmap

> 프로젝트의 큰 Phase/Milestone만 기록한다. 상세 구현 계획은 `../plans/PLAN-xxx.md`로 분리한다. 현재 Task는 `PROJECT_STATUS.md`에서 관리한다.

작성 기준일: 2026-08-23
갱신: 2026-09-23 (Phase 5 게임 방향 개편 추가, 기존 Economy는 Phase 6으로 이동)

## Phase 1 — Foundation
- [x] Flutter+Flame 8×8 코어, 타이틀/게임/설정, 심플+타임, 웹 빌드

## Phase 2 — Core Features
- [x] 특수 보석 탭 발동, 진행 모드, 힌트 제한, 아이템 1~2차, 랭킹, 오버레이 흐름

## Phase 3 — Stabilization
- [ ] 웹/앱인토스에서 사운드를 켠 장시간 플레이 회귀
- [ ] 광고 배너 유무와 특수효과 유무를 한 변수씩 비교
- [x] HTML Audio 4슬롯, 복귀 후 BGM/SFX 단기 수정

## Phase 4 — Release
- [x] 스토어 문서 초안, 채널 define, 광고 정책, 앱인토스 테스트 빌드
- [ ] 운영 광고 그룹, Apple ID, 개인정보/지원 URL, flavor/서명
- [ ] 광고 일일 제한 서버 영속 (Supabase 코드 구현, 원격 적용 대기. PLAN-006)
- [ ] Supabase 기반 구축: 랭킹 이전, 원격 설정, 이벤트 로그 (ADR-009, PLAN-006)

## Phase 5 — Gameplay Direction (제안: ADR-008 Proposed, PLAN-005 DRAFT)
- [ ] 방향 승인과 미결정 사항 D1~D10 결정
- [ ] 두 타이머 모드 공통 60초 코어: 하이퍼 큐브 교환, Speed Bonus, Last Hurrah, 시간 보상 조정
- [ ] 내부 이벤트 로거와 플레이테스트 기록
- [ ] 재화 없는 장기 목표: 누적 랭크, 배지, 기록 화면
- [ ] 타임 모드 경쟁 형식(일일 동일 보드, 주간 순위), 레벨 모드 규칙 변형 스테이지

## Phase 6 — Economy
- [ ] 영속 인벤토리
- [ ] 내부 이벤트 로깅 (2026-09-23 Supabase로 기본 이벤트 구현. 원격 적용 대기. PLAN-006)
- [ ] 코인 경제(코인 1종, 랭킹 모드와 분리), 인앱 결제 (지표 후)
