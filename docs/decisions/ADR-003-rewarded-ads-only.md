# ADR-003 — 선택형 보상 광고와 무한 모드 배너만

- Status: Accepted
- Date: 2026-08-14

## Context
Apps in Toss, Play, One Store, App Store를 한 정책으로 가야 한다. 강제 전면은 스토어/토스 가이드와 플레이 방해 위험이 있다.

## Decision
placement는 continueStage, refillItem, infiniteBanner 세 개만. 보상은 rewarded 완료에서만. 정책/횟수/복원은 게임 코드, SDK는 AdService. 일일 3회는 현재 세션 로컬.

## Alternatives Considered
- 대안 A: 스테이지 시작/종료 전면 광고
- 대안 B: 채널마다 다른 위치

## Reason
아이템 루프를 먼저 검증하고 광고를 붙이려는 수익화 순서와 같다. 토스 게임 가이드의 일시 화면 광고 금지를 공통 규칙으로 올린다.

## Consequences
- 장점: 채널 SDK를 바꿔도 위치가 안 흔들린다
- 단점/비용: 세션 로컬 제한은 재시작에 풀림. TASK-002
- 후속 영향: 운영 광고 그룹은 dart-define. 비밀은 소스에 안 넣음

## 개정 2026-09-24 — 채널별 광고 제공자와 진행 순서

사용자 결정으로 채널별 광고 제공자를 정한다. 광고 위치 3개와 보상 규칙은 그대로다.

| 채널 | 광고 | 상태 |
|---|---|---|
| 웹(NAS) | 없음. 테스트 전용 배포라 광고를 넣지 않는다 | 적용됨. 기본 빌드(`INTOSS_AD_MODE=disabled`)에서 배너, 이어하기 광고, 보충 광고가 모두 숨겨진다(2026-09-24 로컬 웹 확인) |
| 앱인토스 | 토스 광고 SDK(`IntossAdService`, `web/intoss_ads.js`) | 코드 있음. 테스트 광고 QR 실기기 확인과 운영 광고 그룹 ID(TASK-004) 남음 |
| Play, App Store | Google AdMob(`google_mobile_ads`) 예정. Unity Ads는 필요할 때 미디에이션으로 추가 검토 | 미착수. 계획된 구조 작업을 먼저 끝낸 뒤 붙인다 |

- AdMob은 Android와 iOS 전용이다. `AdMobAdService`를 `AdService` 구현으로 추가하고 `STORE_CHANNEL=play|appstore`에서만 고른다. 웹 빌드에는 들어가지 않게 조건부 import로 분리한다.
- 하루 보충 제한은 채널과 관계없이 Supabase 서버 기준(BR-103)을 재사용한다.
- AdMob 도입 때 함께 할 일: 플랫폼별 앱 ID, Google UMP 동의, iOS ATT, 개인정보처리방침 초안의 광고 SDK 수집 항목.

## Related
- FR-010
- BR-100 ~ BR-103
- TASK-002
- git: 2026-08-14 광고 정책, 2026-08-15 앱인토스 광고
