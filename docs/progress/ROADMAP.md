# Roadmap

> 프로젝트의 큰 Phase/Milestone만 기록한다. 상세 구현 계획은 `../plans/PLAN-xxx.md`로 분리한다. 현재 Task는 `PROJECT_STATUS.md`에서 관리한다.

작성 기준일: 2026-08-23
갱신: 2026-09-24 08:10 KST (PLAN-008 실험 스위치 반영, 앱인토스와 광고는 구조 개편 뒤)

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
- [ ] Play, App Store 광고: Google AdMob(ADR-003 개정). 계획된 구조 작업(PLAN-006 배포, PLAN-005 코어) 뒤 진행. 웹(NAS)은 테스트 전용이라 광고 없음
- [x] 광고 일일 제한 서버 영속 (Supabase 원격 적용, NAS 배포. PLAN-006)
- [ ] Supabase 기반 구축: 랭킹 이전, 원격 설정, 이벤트 로그 (원격 적용과 NAS 배포 완료. 앱인토스 QR 확인은 구조 개편 뒤. ADR-009, PLAN-006)

## Phase 5 — Gameplay Direction (ADR-008 Accepted, PLAN-005 IN_PROGRESS)
- [ ] 방향 승인과 미결정 사항 D1~D10 결정 (D1~D6 승인, D8, D9 권장안 결정, D10 해당 없음, D7은 플레이테스트 뒤)
- [ ] 두 타이머 모드 공통 60초 코어: 하이퍼 큐브 교환, Speed Bonus, Last Hurrah 완료. 시간 보상 T1, Time 보석, Multiplier 보석은 스위치로 구현(PLAN-008), 채택은 D7 플레이테스트 뒤
- [ ] 내부 이벤트 로거와 플레이테스트 기록
- [x] 재화 없는 장기 목표: 누적 랭크, 배지, 기록 화면
- [x] 타임 모드 경쟁 형식(일일 동일 보드, 주간 순위, PLAN-007), 레벨 모드 도전 스테이지(BR-043)

## Phase 6 — Economy
- [ ] 영속 인벤토리
- [ ] 내부 이벤트 로깅 (Supabase 기본 이벤트 7종 원격 적재 확인. 배포 대기. PLAN-006)
- [ ] 코인 경제(코인 1종, 랭킹 모드와 분리), 인앱 결제 (지표 후)

## 관측과 사용자 식별 보강 (2026-09-29)

한 단계 검증과 결과 보고 후 다음 단계로 진행한다. 여러 SDK와 가입 개편을 한 번에 적용하지 않는다.

- [ ] [PLAN-009](../plans/PLAN-009-telemetry-foundation.md): 기존 통계의 이벤트 식별, 판/시간 기준, 요약(Step 1~3 완료), 전송 신뢰성(Step 4 대기)
- [ ] [PLAN-010](../plans/PLAN-010-player-identity.md): 공통 사용자 식별 계약, 최소 프로필, 채널별 계정 연결과 기록 복구
- [ ] [PLAN-011](../plans/PLAN-011-ga4-behavior-analytics.md): GA4 매핑, 채널별 검증, 보고서
- [ ] [PLAN-012](../plans/PLAN-012-crash-observability.md): 충돌/오류와 직전 행동, 심볼과 성능 검증

PLAN-009의 이벤트/판 기준과 PLAN-010 식별 계약이 외부 연동의 선행 조건이다. PLAN-010의 모든 채널 로그인 구현은 GA4/오류 연동의 필수 선행 조건이 아니다. 세부 구현과 병렬 소유권은 각 PLAN에 둔다.
