# ADR-004 — 웹 SFX는 HTML Audio 고정 4슬롯

- Status: Accepted
- Date: 2026-08-15

## Context
모바일 웹/앱인토스에서 효과음이 겹친 뒤 멈추거나, 화면 복귀 후 안 나왔다. flame_audio AudioPool 이름과 실제 플레이어 수/Web Audio 경로가 달랐다. 잘못된 mp3 URL이 SPA fallback으로 HTML을 200 반환했다.

## Decision
웹 SFX는 Web Audio를 우회하고 HTML Audio 4슬롯을 재사용한다. unlock은 첫 제스처와 visibility 복귀 후 첫 제스처만. 웹에서 같은 BGM 재요청은 resume이 아니라 소스 재설정 play. BGM과 SFX 경로를 분리한다.

## Alternatives Considered
- 대안 A: flame_audio Web Audio 유지, 풀 크기만 증가
- 대안 B: 효과음을 꺼서 FPS/정지 회피

## Reason
실기기에서 드롭/에러 원인이 슬롯 포화, 잘못된 URL, 반복 unlock, 웹 resume 실패로 갈라졌다. 효과음 제거는 제품 요구가 아니다.

## Consequences
- 장점: iOS 컨텍스트 정지 경로를 피하고 진단 카운터를 남긴다
- 단점/비용: 동시 SFX 4개 상한. 네이티브와 경로가 갈린다
- 후속 영향: 장시간 카운터와 배너 A/B는 TASK-001. 에셋 경로는 build/web 실제 트리와 Content-Type 확인

## Related
- FR-003, FR-010
- TASK-001
- git: 2026-08-15 웹 효과음 우회/경로/unlock, 2026-08-16 BGM 재시작, 2026-08-23 복귀 복구
