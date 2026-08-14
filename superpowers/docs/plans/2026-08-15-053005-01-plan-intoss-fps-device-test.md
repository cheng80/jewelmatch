# 앱인토스 FPS 실기기 테스트 배포

**Goal:** Wasm 성능 개선 테스트 빌드를 앱인토스에 업로드하고 연결된 iPhone에서 실행한다.
**Why planning is required:** 외부 테스트 배포 상태를 새로 만드는 작업이다.
**Acceptance:** 기존 배포는 유지하고, `stonematch.ait` 1건만 테스트 배포한다. 새 deploymentId가 발급되고 기존 ID와 다름을 확인한 뒤 `CHENG_iPhone`의 토스 앱에서 새 딥링크를 연다. FPS 패널은 직전 30초 평균·최저 FPS와 최대 프레임 공백을 유지해 단일 캡처에도 이전 급락이 남아야 한다. 토큰, 워크스페이스 또는 앱 이름이 예상과 다르면 배포 전에 중단한다. 반복 비용이 큰 실기기 테스트는 아래 기록과 체크리스트를 갱신해 같은 비교를 되풀이하지 않는다.

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

### Outcome 4: 남은 GC 할당 축소와 재측정 준비
- Work: 매 프레임 64개 보석에 생성되던 제거 효과 콜백을 없애고, HUD의 고정 `Paint`·그라데이션·힌트 수량 텍스트를 레이아웃 변경 때만 만든다. 게임 규칙과 화면 구성은 바꾸지 않는다. 현재 `ParticlePool`은 실제 제거 콜백에서 생성하지 않으므로 최적화 대상에서 제외한다.
- Verify: `flutter analyze`, 전체 `flutter test`, Wasm Web 빌드. 화면이 같은지는 다음 실기기 A/B에서 확인한다.

## 완료한 조사와 결과

| 항목 | 결과 | 다시 할 필요 |
| --- | --- | --- |
| PC·일반 로컬 서버 재현 | 병목 재현 안 됨. Apps in Toss iOS WebView에서만 평균 40 FPS대와 순간 5~10 FPS가 관찰됨 | 없음 |
| FPS 계측 | 설정 토글과 이동 가능한 패널에 현재 FPS, 30초 평균, 0.5초 구간 최저, 최대 프레임 공백 표시 | 없음 |
| 정적 배경 | `StarryBackground` 애니메이션과 `SpaceBg`의 반복 합성을 제거하고 정적 그림 캐시 적용 | 없음 |
| Web Inspector | Toss iOS 호스트의 `WKWebView.isInspectable`이 꺼진 상태라 연결 불가 | 호스트 정책 변경 때만 |
| CanvasKit / Wasm | 동일 자동 플레이 30초 기준 CanvasKit AVG 55.1, LOW 42.0, GAP 139ms / Wasm AVG 56.7, LOW 43.6, GAP 134ms. 유의미한 차이 없음 | 없음, Wasm 유지 |
| 웹 효과음 프라이밍 | 모든 포인터 입력마다 12개 SFX 풀을 재생·정지하던 반복 프라이밍 발견. 최초 1회로 제한 | 없음 |
| 효과음 수정 전후 | 수정 전 46.6초 / 수정 후 30초에서 잠재 정지 286→37, mediaremoted 113→13, WebContent 104→14, WebKit.GPU 60→7, Toss 2→0. 시간 보정 정지율 약 79~82% 감소 | 없음 |
| 남은 GC 의심 | Time Profiler에서 WebContent의 `JSC::LocalAllocator::allocateSlowCase`, marking, sweep와 82~123ms 정지 구간이 겹침. 일부 잔여 급락은 JSC 할당·GC와 연관됨 | 아래 항목으로 분리 측정 |
| 지속 할당 축소 | 보석마다 생성하던 렌더 콜백 최대 64개/프레임 제거. HUD 이미지 `Paint`, 고정 그라데이션, 힌트 수량 `TextPainter` 재사용. 실제로 생성되지 않는 `ParticlePool`은 제외 | 실기기 효과 측정 필요 |

## 다음 실기기 테스트 체크리스트

한 번에 한 변수만 바꾸고 각 테스트는 같은 모드·약 30초 플레이로 비교한다. 결과는 이 표 아래에 수치와 함께 추가한다.

- [ ] 이번 프레임별 객체 할당 축소판에서 FPS `AVG / LOW / GAP`과 WebContent 잠재 정지 횟수·100ms 이상 횟수 측정
- [ ] 같은 빌드에서 효과음 켬 / 효과음 끔 비교
- [ ] 같은 빌드에서 하단 배너 표시 / 미표시 비교
- [ ] 특수 효과 표시 / 미표시 비교 후 차이가 있을 때만 해당 효과의 추가 풀링 검토
- [ ] 위 세 비교로 차이가 없으면 HUD의 프레임별 도형·색상 생성량을 다음 후보로 계측
- [ ] 테스트마다 기기, iOS·토스 버전, 모드, 측정 시간, FPS 수치, 잠재 정지 수를 기록

## 다음 기록 양식

| 날짜 | 빌드/변수 | 모드·시간 | AVG | LOW | GAP | WebContent 정지 | 100ms 이상 | 결론 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 2026-08-15 | 효과음 반복 프라이밍 수정 후 | 수동 플레이 30초 | - | - | - | 14 | 7 | 오디오 계열 정지는 크게 감소했지만 JSC GC 구간은 남음 |
