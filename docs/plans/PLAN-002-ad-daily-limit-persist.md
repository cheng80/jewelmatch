# PLAN-002 광고 일일 제한 서버 영속

## Metadata
- Plan ID: `PLAN-002`
- Title: refill 3회를 세션 메모리에서 채널 사용자+서버 날짜로 이동
- Status: `DRAFT`
- Related Requirement: `FR-010`, `BR-103`
- Related ADR: `ADR-003`
- Owner:
- Updated: 2026-08-23

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
- 제약사항: 토스 사용자 식별과 서버 저장 정책이 없음. 이 Plan은 그 값이 오기 전에는 IN_PROGRESS로 올리지 않는다
- 반드시 유지할 계약: rewarded 완료에서만 지급. placement 3개만. BR-101~103

## 4. 구현 계획
### Step 1
- [ ] 채널 사용자 식별과 서버 날짜 기준 확정

### Step 2
- [ ] 정책 객체가 로컬 세션이 아니라 영속 저장을 읽게 한다

### Step 3
- [ ] 테스트와 Tech Spec 갱신

## 5. 예상 변경 범위
- 파일/모듈: `lib/ads/ad_reward_policy.dart`, 가능하면 서버 API
- DB/API 영향: 신규. 아직 계약 없음
- UI 영향: 보충 버튼 잔여 횟수
- 배포/마이그레이션 영향: 채널 서버 준비 필요

## 6. 검증 계획
- [ ] Unit: 날짜 경계, 재시작, rewarded 아닌 결과 미지급
- [ ] 이벤트 payload에 광고 ID/토스 ID 없음
- [ ] 관련 Acceptance Criteria

## 7. 위험 / 미해결 사항
- 식별 정책이 없으면 구현하지 않는다
- 로컬 날짜와 서버 날짜 불일치

## 8. 완료 조건
- [ ] 재시작과 날짜 경계에서 3회가 유지된다
- [ ] PROJECT_STATUS 갱신
- [ ] 장기 저장 계약이 바뀌면 ADR
