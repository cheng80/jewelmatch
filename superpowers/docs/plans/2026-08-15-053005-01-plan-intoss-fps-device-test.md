# 앱인토스 FPS 실기기 테스트 배포

**Goal:** Wasm 성능 개선 테스트 빌드를 앱인토스에 업로드하고 연결된 iPhone에서 실행한다.
**Why planning is required:** 외부 테스트 배포 상태를 새로 만드는 작업이다.
**Acceptance:** 기존 배포는 유지하고, `stonematch.ait` 1건만 테스트 배포한다. 새 deploymentId가 발급되고 기존 ID와 다름을 확인한 뒤 `CHENG_iPhone`의 토스 앱에서 새 딥링크를 연다. FPS 패널은 직전 30초 평균·최저 FPS와 최대 프레임 공백을 유지해 단일 캡처에도 이전 급락이 남아야 한다. 토큰, 워크스페이스 또는 앱 이름이 예상과 다르면 배포 전에 중단한다.

### Outcome 1: 배포 대상 고정
- Work: 앱 이름 `stonematch`, 로컬 산출물 `stonematch.ait`, SHA-256 체크섬을 배포 대상으로 사용한다. 운영 광고와 출시 상태는 변경하지 않는다.
- Verify: `shasum -a 256 stonematch.ait`

### Outcome 2: 테스트 배포와 실기기 실행
- Work: AIT CLI로 산출물을 테스트 배포하고 새 deploymentId를 사용해 연결된 `CHENG_iPhone`의 토스 앱을 연다. 실패 시 기존 배포 링크를 복구 경로로 유지한다.
- Risks/open questions: 토스 iOS 앱의 `WKWebView.isInspectable`이 꺼져 있어 Web Inspector 자동 수집은 할 수 없다. 화면의 30초 누적 통계로 확인하며 캡처는 측정 후 한 번만 수행한다.
- Verify: `xcrun devicectl list devices`

### Outcome 3: 자동 재현과 렌더러 비교
- Work: `QA_PERF_AUTORUN` 빌드는 Simple 모드로 바로 진입해 기존 QA 힌트 이동을 700ms마다 실제 게임 입력으로 실행한다. 같은 시나리오를 Wasm과 CanvasKit에서 각각 실행한다.
- Verify: 자동 이동 단위 테스트, `flutter analyze`, 전체 `flutter test`, 각 Web/AIT 빌드, 연결된 iPhone 실행 후 30초 누적 패널 비교.
