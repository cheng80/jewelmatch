# PLAN-003 영속 인벤토리

## Metadata
- Plan ID: `PLAN-003`
- Title: PlayerInventory 로컬 영속과 타이틀 진입
- Status: `DRAFT`
- Related Requirement: `FR-007`, `SCREEN-001`, `SCREEN-009`
- Related ADR:
- Owner:
- Updated: 2026-08-23

## 1. 목표
앱 재시작 후 아이템 수량과 장착 슬롯이 유지된다. 타이틀에서 인벤토리에 들어갈 수 있다.

## 2. 범위
### 포함
- `PlayerInventory`와 StorageKeys
- 장착 해제, 타이틀 진입
- 저장/로드 테스트

### 제외
- 코인 마켓, IAP
- 광고 보충 서버 영속 (PLAN-002)

## 3. 현재 상태 / 전제
- 기존 구현: `RunInventory`는 세션만. 2차 범위로는 허용
- 제약사항: 실패/재시작 시 사용분 롤백 여부를 구현 전에 고정해야 한다
- 반드시 유지할 계약: 중복 장착 불가, 수량 0 사용 불가, 진행 모드 HUD만 로드아웃, BR-070~073

## 4. 구현 계획
### Step 1
- [ ] 저장 모델과 키, 마이그레이션 여부

### Step 2
- [ ] 타이틀/결과 인벤토리 진입과 해제

### Step 3
- [ ] 테스트와 Product/UI Spec 갱신

## 5. 예상 변경 범위
- 파일/모듈: `lib/game/item_inventory.dart`, `StorageKeys`, `TitleView`, `StageInventoryOverlay`
- DB/API 영향: 로컬만
- UI 영향: SCREEN-001에 인벤토리 버튼
- 배포/마이그레이션 영향: 기존 세션 데이터와 충돌 없음. 신규 키

## 6. 검증 계획
- [ ] 저장/로드, 중복 장착 방지, 수량 0 장착 방지
- [ ] 앱 재시작 후 유지
- [ ] 모바일 폭에서 슬롯/뱃지 겹침 없음

## 7. 위험 / 미해결 사항
- 사용 즉시 차감 vs 클리어 시 확정
- 타이틀에서 장착 변경과 진행 중 런 스냅샷 불일치

## 8. 완료 조건
- [ ] 재시작 후 수량/슬롯 유지
- [ ] PROJECT_STATUS / Spec 갱신
