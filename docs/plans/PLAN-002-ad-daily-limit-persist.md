# PLAN-002 광고 일일 제한 서버 영속

## Metadata
- Plan ID: `PLAN-002`
- Title: refill 3회를 세션 메모리에서 채널 사용자+서버 날짜로 이동
- Status: `DONE` (PocketBase 운영 적용과 권한/동시성 검증 완료. 앱인토스 실제 광고 SDK 확인은 채널 검증 과제로 별도 유지)
- Related Requirement: `FR-010`, `BR-103`
- Related ADR: `ADR-003`
- Owner:
- Updated: 2026-08-23

2026-09-29 갱신: 사용자 식별은 PocketBase 설치 익명 인증(ADR-010), 서버 날짜는 KST, 설정은 `sm_config`의 `ads.daily_refill_limit`이다. 트랜잭션 안에서 횟수를 검사/기록한다. 실제 0.39.7 통합 테스트의 날짜 경계와 동시24요청3지급, 운영 API 지급 및 서비스 재시작/동일계정 유지 검증으로 완료했다. 관련 클라이언트 단위 테스트는 ad_reward_policy_test.dart, 서버는 test/pocketbase/integration_test.py다. 토스 원본 사용자키/광고ID는 이벤트에 보내지 않는다. 저장소 삭제/재설치는 새 익명 사용자다.

## 1. 목표
아이템 보충 광고 3회 제한이 앱 재시작과 날짜 경계에서 유지된다. 측정 이벤트에 광고 식별자가 없다.

## 2. 범위
### 포함
- 식별/저장 정책 확정
- `AdRewardPolicy` 영속 교체
- ad_* 이벤트 연결 지점

### 제외
- 강제 전면 광고
- 코인/IAP
- 토스 사용자 ID를 클라이언트 로그에 넣는 것

## 3. 현재 상태 / 전제
- 기존 구현: `AdRewardPolicy`가 세션 메모리로 일 3회와 이어가기 1회를 센다
- 현재 계약: 토스 식별자에 의존하지 않고 PocketBase 익명 사용자와 서버 날짜로 처리한다
- 반드시 유지할 계약: rewarded 완료에서만 지급. placement 3개만. BR-101~103

## 4. 구현 계획
### Step 1
- [x] 채널 사용자 식별과 서버 날짜 기준 확정

### Step 2
- [x] 정책 객체가 로컬 세션이 아니라 영속 저장을 읽게 한다

### Step 3
- [x] 테스트와 Tech Spec 갱신

## 5. 예상 변경 범위
- 파일/모듈: `lib/ads/ad_reward_policy.dart`, 가능하면 서버 API
- DB/API 영향: TECH_SPEC API-006의 PocketBase 상태/지급 API
- UI 영향: 보충 버튼 잔여 횟수
- 배포/마이그레이션: PLAN-013에서 운영 적용

## 6. 검증 계획
- [x] Unit: 날짜 경계, 재시작, rewarded 아닌 결과 미지급
- [x] 이벤트 payload에 광고 ID/토스 ID 없음
- [x] 관련 Acceptance Criteria

## 7. 위험 / 미해결 사항
- 익명 설치 식별자를 재설치/저장소 삭제로 바꿀 수 있어 부정 사용 완전 방지를 보장하지 않는다
- 로컬 날짜와 서버 날짜 불일치

## 8. 완료 조건
- [x] 재시작과 날짜 경계에서 3회가 유지된다
- [x] PROJECT_STATUS 갱신
- [x] 장기 저장 계약이 바뀌면 ADR
