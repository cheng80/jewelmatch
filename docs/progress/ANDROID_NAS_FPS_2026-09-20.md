# Android NAS 재접속 FPS 검증 (2026-09-20)

## 대상과 조건
- 제품 리비전 `99622e9`, NAS `/match/` Wasm 릴리즈. main과 원격 푸시 완료. 이후 커밋은 검증 문서만 바꾼다.
- Samsung SM-A245N, Android16, Chrome152.0.7977.82. 1080x2340, 디스플레이90Hz, DPR2.8125.
- 사용자가 첫 이펙트에서 화면 멈춤을 제보했다. 초기 캡처는 AVG66.7/LOW9.7/GAP280ms였지만, 로딩이 섞인30초 창이므로 이펙트 단독 지연으로 해석하지 않는다.
- 첫 재측정은35.1초/유효 입력34회. rAF 평균63.94FPS, p95 33.57ms, 최대55.94ms. 큰 멈춤은 재현되지 않았다.
- 이후 사용자 요청대로 게임 탭96을 완전히 닫고, 목록에서 사라진 것을 확인한 뒤 새 탭97로 다시 열었다. 다른 탭과 브라우저 캐시는 보존했다. 브라우저 앱 전체 종료/캐시 삭제 조건은 아니다.
- scrcpy4.1 미러링/녹화 작동 확인 후, 본 계측 전 종료해 인코딩 부하를 제거했다. ADB 터치1회 후 기존 QA 보드 입력 경로로 매치12회 시도(11회 수락), bomb/hyper/supernova를 각각2회 재생했다. 무한 모드에서 랭킹 제출은 하지 않았다.
- 개발자 도구 CPU 샘플, Network/오류, requestAnimationFrame 및 Long Tasks를 수집했다. CPU 샘플 시작은 새 문서 약0.29초 이후이며 최초 구간 일부는 계측되지 않았다.

## 재접속 결과
| 구간 | 최대 rAF 공백 | 관측 |
|---|---|---|
| 페이지 로딩과 인트로 |190.2ms|메인 문서 긴 작업181ms,151ms,51ms|
| 첫 매치 |22.4ms|큰 멈춤 재현 없음|
| 이후 일반 매치 |최대44.8ms|입력 구간별 약60~86FPS|
| 첫 bomb/hyper/supernova |33.6/44.8/44.8ms|큰 멈춤 재현 없음|
| 반복 bomb/hyper/supernova |55.9/44.8/55.9ms|간헐적 프레임 지연|

전체 약26.8초,1741프레임, 평균65.00FPS, p95 33.56ms. rAF는 실제 화면 표시 프레임과 다른 지표다. 90Hz 디스플레이에서 항상90FPS였다고 판단하지 않는다.

## 원인 근거와 한계
- 긴 작업은 새 문서 시작 후0.56~0.74초(181ms),0.89~1.04초(151ms),1.13~1.18초(51ms)에 발생했다. 첫 매치는3.46초다. 관측한 긴 작업은 첫 매치보다 앞선 로딩 구간이다.
- CPU 샘플과 Network의 단조시각/벽시계 기준을 맞춰 대조했다.181ms 작업에서 Wasm 엔트리의 `instantiate` 및 `_loadWasmEntrypoint`가 약91ms 샘플을 차지했다. 나머지 중 native `(program)` 약76ms는 더 세분할 수 없다.
-151ms 작업에서는 Skwasm 실행, `Intl.Segmenter` 초기화, fetch 호출 등을 관측했다.51ms 작업은 JS 배열을 Wasm 배열로 복사하는 `_1586`과 관련 호출 샘플이 약39ms였다. 따라서 이번 재접속에서 관측한 큰 지연의 근거는 초기화/로딩이며 특정 이펙트 재생으로 지목할 근거는 없다.
- 사용자가 처음 본 멈춤을 사후에 소급 진단할 수는 없다. 이번 결과만으로 같은 원인이었다거나 해결됐다고 단정하지 않는다.
- 네트워크 실패/uncaught exception0, crossOriginIsolated=true. 새 탭에서 오디오 첫 ADB 터치 후 자동재생 거절4건, 이후 plays26/drops0/errors4. 측정 중 추가 오류 없음. 기기 미디어 볼륨0으로 실제 청취 검증은 미실행.
- Chrome 전체 Tracing 내보내기는 완료 응답 지연으로 실패했다. CPU 프로파일과 rAF/Long Tasks/Network 자료는 정상 보존했다. GPU/렌더 워커 내부 원인까지 확정하지 않는다.
- 제품 코드 변경 없이 조사했다. iPhone/토스 광고 A/B, 장시간 검증, 수동 플레이와 미러링 부하의 정량 비교는 남아 있다.

## 근거
- `tmp/nas-deploy-20260920/deploy.log`, `verification.json`: NAS HTTP200, 주요4파일 로컬/원격 SHA256 일치, SPA 경로200, COOP/COEP, 두 모드 랭킹 조회, ZIP PHP/환경파일 제외.
- `tmp/android-fps-20260920/profile.json`:35초 최초 재측정 원시자료.
- `tmp/android-fps-20260920/reopen/frames.json`, `cpu.cpuprofile`, `events.json`, `navigation.json`, `longtask-cpu-correlation.json`, `summary.json`, `final.png`: 완전 탭 종료/재접속 측정.
- `tmp/android-fps-20260920/mirrored.mp4`: 앞선 미러링 확인 영상.

## 작업 상태
- 사용자가21:20 Claude 재인계를 취소했다. 예약 `stone-match-claude`는PAUSED. 기존 Claude를 재개시키는 프롬프트는 보내지 않았다.
- 로컬 개발 서버, 미러링, 자동 입력/프로파일 프로세스 종료. 측정용 ADB9228 포워딩 제거 완료. 휴대폰 게임 탭은 유지한다.
