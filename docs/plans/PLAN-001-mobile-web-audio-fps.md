# PLAN-001 모바일 웹 오디오/FPS 회귀

## Metadata
- Plan ID: `PLAN-001`
- Title: 모바일 웹/앱인토스 사운드 켠 장시간 측정
- Status: `IN_PROGRESS`
- Related Requirement: `FR-003`, `FR-010`, `SCREEN-003`
- Related ADR: `ADR-004`
- Owner: 다음 세션
- Updated: 2026-08-23

## 1. 목표
사운드를 켠 실기기에서 화면 복귀, 다시 하기, 배너 유무, 특수효과 유무를 같은 조건으로 재측정하고 누적 카운터를 남긴다.

## 2. 범위
### 포함
- 타임 결과창 이탈→복귀→다시 하기에서 BGM/SFX
- 무한 모드 배너 표시/미표시 30초 이상 A/B
- 특수효과 표시/미표시 A/B
- `window.stoneMatchSfx.getState()` plays/drops/errors/unlocks 보존
- FPS 패널 AVG/LOW/GAP

### 제외
- 효과음을 꺼서 성능 문제를 해결하는 것
- 렌더러를 CanvasKit/Wasm으로 교체하는 것
- 특수효과 품질 저하 (차이가 확인된 뒤에만)

## 3. 현재 상태 / 전제
- 기존 구현: HTML Audio 4슬롯, unlock은 첫 제스처와 visibility 복귀 후 첫 제스처, 웹 같은 BGM은 소스 재설정 play
- 제약사항: 짧은 수동 확인은 통과. 장시간 카운터 없음
- 반드시 유지할 계약: ADR-004. 강제 전면 광고 없음. ranking.php를 웹 빌드에 넣지 않음

## 4. 구현 계획
### Step 1
- [x] HTML Audio 4슬롯, 경로 수정, unlock 1회화, 웹 BGM replay

### Step 2
- [x] 짧은 수동 확인에서 복귀 후 SFX와 다시 하기 BGM 복구

### Step 3
- [ ] 동일 기기·빌드·모드에서 30초 이상 측정, 카운터 보존 (TASK-001)

### Step 4
- [ ] 배너 유무 A/B (TASK-001)

### Step 5
- [ ] 특수효과 유무 A/B (TASK-001)

### Step 6
- [ ] 결과로 Spec/Status/Handoff 갱신. 장기 결정이면 ADR-004 보완

## 5. 예상 변경 범위
- 파일/모듈: 측정만이면 코드 변경 없음. 회귀가 재현되면 `lib/resources/sound_manager*.dart`, `web/stone_match_sfx.js`, HUD/배너
- DB/API 영향: 없음
- UI 영향: FPS 패널, 무한 모드 배너 안전 영역
- 배포/마이그레이션 영향: 웹/앱인토스 테스트 빌드 재배포 가능

## 6. 검증 계획
- [ ] Unit test: 코드 고치면 `sound_manager_test.dart`, `fps_window_stats_test.dart`
- [ ] Integration/API test: 해당 없음
- [ ] UI/E2E 또는 수동 검증: 실기기 30초 이상, 배너/특수효과 한 변수씩
- [ ] 관련 Acceptance Criteria 확인: FR-003, FR-010

## 7. 위험 / 미해결 사항
- GC를 모든 드롭의 원인으로 단정하지 말 것. 오디오/GPU 동시 정지 이력이 있다
- HTTP 200만 보고 mp3가 정상이라고 보지 말 것
- 측정 조건을 섞으면 A/B가 무효
- ISSUE-007(2026-09-24): Android Chrome 153에서 같은 탭에 게임 문서를 다시 불러오면 멀티스레드 skwasm이 메모리 오류로 멈춘다. `b71ba31`과 `223303e`에서 모두 재현(같은 탭 연속 실행 첫 1~2회 안). 새 Chrome 첫 로드는 13회 모두 정상. 격리 헤더를 빼 단일 스레드로 돌리면 재로드 4회 모두 정상이지만 20초 평균 FPS가 89.2에서 44.7~45.6, p95가 11.2ms에서 33.6ms로 나빠진다. 도구: `tmp/local-verify/s12_ab.js`, `s13_fps.js`(로컬 서버, `adb reverse`, COI 유무)
- ISSUE-007 해소(2026-09-24): Flutter 3.44.8에서 3.47.5로 올린 뒤 같은 조건(격리 헤더, profile wasm, `s12_ab.js`)으로 같은 탭 연속 6회 모두 멈춤 없음. `s13_fps.js` 20초 평균 86.8fps, p95 11.3ms, 50ms 초과 프레임 0.

## 8. 완료 조건
- [ ] 동일 조건 AVG/LOW/GAP과 SFX 카운터가 기록된다
- [ ] 배너와 특수효과를 한 변수씩 비교한다
- [ ] PROJECT_STATUS / HANDOFF 갱신
- [ ] 코드 변경이 있으면 관련 테스트와 ADR

---

# Flutter Flame 모바일 웹 최적화 인계

원문 제목 키: 이 팩 PLAN-001의 성능 인계 절 (이 파일에 흡수됨)

# Flutter Flame 모바일 웹 성능 및 오디오 최적화 핸드오프

**작성일:** 2026-08-15

**최종 갱신일:** 2026-08-16

**기준 프로젝트:** Stone Match

**적용 대상:** Flutter Web, Flame 게임, iOS Safari, WKWebView 기반 미니앱

이 문서는 Stone Match에서 진행한 모바일 웹 성능 측정과 최적화 결과를 다른 Flutter Flame 게임에 재사용하기 위한 핸드오프다. 성공한 변경뿐 아니라 효과가 없었던 비교, 잘못된 진단 경로, 모바일 오디오 장애까지 함께 기록한다.

## 1. 결론 요약

이번 조사에서 확인된 핵심은 다음과 같다.

1. PC Chrome과 로컬 서버가 정상이어도 iOS WKWebView 병목은 재현되지 않을 수 있다. 최종 판단은 반드시 같은 iPhone, 같은 호스트 앱, 같은 게임 모드에서 한다.
2. 평균 FPS만으로는 순간 정지를 찾을 수 없다. 30초 평균, 짧은 구간 최저, 최대 프레임 공백을 함께 기록해야 한다.
3. Wasm과 CanvasKit 렌더러 차이는 이번 사례에서 주요 원인이 아니었다.
4. 전체 화면 배경 애니메이션, `saveLayer`, 매 프레임 객체 생성은 모바일 WebView에서 먼저 제거할 가치가 컸다.
5. 남은 순간 정지는 JavaScriptCore GC와 겹치는 구간이 있었지만, 오디오, GPU, `mediaremoted` 정지가 함께 발생해 GC만의 문제로 단정할 수 없었다.
6. 효과음은 게임 성능 측정에서 제외하면 안 된다. 사용자 터치 없이 실행된 자동 테스트는 무음 대조군일 뿐 실제 플레이 성능값이 아니다.
7. 모바일 효과음 장애는 플레이어 증가, 잘못된 Flutter 자산 URL, 모든 터치에서 반복한 오디오 잠금 해제가 연속으로 겹친 문제였다.
8. 화면 이탈 후 같은 BGM이 돌아오지 않는 경우 `resume`만 반복하지 말고, 웹에서만 오디오 소스를 다시 설정해 재생해야 한다.

## 2. 최초 증상과 재현 환경

### 증상

- Apps in Toss iOS WebView에서 일반 스크롤 메뉴도 심하게 끊겼다.
- 게임 중 평균 FPS가 40대까지 내려가고 순간적으로 5에서 10 FPS가 관찰됐다.
- 특별한 연출 없이 플레이하는 중에도 일시 정지가 발생해 GC가 의심됐다.
- PC Chrome과 일반 로컬 서버에서는 같은 병목이 재현되지 않았다.
- 모바일 웹에서는 BGM은 계속 나오지만 동시 효과음 이후 SFX만 멈추거나 일부가 누락됐다.
- 타임 아웃 결과창에서 화면을 이탈했다 복귀한 뒤 `다시 하기`를 누르면 SFX는 나오지만 BGM이 복구되지 않았다.

### 실기기 기준 환경

- 기기: iPhone 14 Pro Max
- iOS: 26.6
- Apps in Toss 호스트: Toss 5.272.0
- 게임: Flutter Web Wasm release
- 모드: Simple 무한 모드
- 광고: 테스트 배너 표시

버전은 재현 당시의 기록이다. 다른 앱에서는 반드시 기기, OS, 호스트 앱 버전을 새로 기록한다.

## 3. 측정 도구와 지표

### 3.1 앱 내부 FPS 패널

Stone Match는 `lib/app.dart`에서 다음 값을 표시한다.

- `FPS`: 약 0.5초 샘플의 현재 FPS
- `ms`: 최근 Flutter `FrameTiming`의 평균 총 프레임 시간
- `30s AVG`: 최근 30초의 가중 평균 FPS
- `LOW`: 최근 30초 안에서 가장 낮은 약 0.5초 구간 FPS
- `GAP`: 최근 30초의 가장 긴 프레임 간격

패널은 다음 조건에서 표시한다.

- 앱 설정의 FPS 표시 옵션
- URL 쿼리 `fps=1` 또는 `qaPerf=1`
- 빌드 정의 `QA_PERF_AUTORUN=true`

모바일에서는 하단 광고가 패널을 가릴 수 있으므로 게임 프레임 안에서는 하단에서 112 논리 픽셀 위에 배치했다. 넓은 화면에서 패널을 게임 프레임 밖에 둘 수 있으면 하단 12 픽셀 위치를 사용한다.

주의할 점:

- 패널 자체도 `Ticker`, `FrameTiming`, 주기적 `setState` 비용이 있다. 상시 운영 지표가 아니라 필요할 때 켜는 진단 기능으로 둔다.
- 화면 캡처 한 장은 순간값만 보여준다. 30초 누적값과 시스템 추적을 함께 사용한다.
- `LOW`는 단일 최악 프레임 FPS가 아니라 짧은 구간 최저값이다. 단일 정지는 `GAP`으로 본다.

### 3.2 자동 플레이

성능 전용 빌드는 다음 방식을 사용했다.

- `QA_PERF_AUTORUN=true`
- Simple 모드로 직접 진입
- 기존 힌트 이동을 700ms마다 실제 게임 입력 경로로 실행
- `QA_PERF_LABEL`로 화면에 실험 이름 표시

자동 플레이는 같은 입력을 반복하는 A/B 비교에 유용하지만 다음 한계가 있다.

- iOS 오디오 자동재생 정책은 우회하지 못한다.
- 측정 전에 사용자가 화면을 한 번 터치해 BGM과 SFX를 실제로 해제해야 한다.
- 수동 플레이의 빠른 연속 입력과 모든 특수 보석 조합을 완전히 재현하지 못한다.

### 3.3 iPhone 시스템 추적

Apps in Toss WebView가 Safari Web Inspector에 노출되지 않을 때는 `xctrace`의 `Animation Hitches`를 사용했다.

```bash
mkdir -p tmp/qa/intoss_fps

xcrun xctrace record \
  --template 'Animation Hitches' \
  --device '<iPhone UDID>' \
  --all-processes \
  --time-limit 30s \
  --output tmp/qa/intoss_fps/<고유한_이름>.trace
```

관찰 대상:

- 게임을 실행하는 `WebContent`
- `WebKit.GPU`
- `mediaremoted`
- 호스트 앱 프로세스
- JavaScriptCore의 allocation, marking, sweep 표본

기존 `.trace` 경로는 재사용하지 않는다. 서로 다른 길이의 trace는 단순 횟수가 아니라 시간당 정지율도 비교한다.

### 3.4 Safari 원격 Web Inspector

- 일반 iPhone Safari 페이지는 Mac Safari의 앱 및 기기 검사에서 콘솔과 DOM에 접근할 수 있었다.
- Apps in Toss 내부 WKWebView는 호스트가 `isInspectable`을 허용하지 않으면 표시되지 않는다.
- 따라서 일반 Safari 검사 성공을 Apps in Toss 검사 가능으로 해석하면 안 된다.

## 4. 측정 결과

| 비교 | 결과 | 판단 |
| --- | --- | --- |
| PC 로컬 자동 플레이 약 42초 | 평균 약 60 FPS, p95 약 17.3ms, long task 0 | PC 결과만으로 실기기 정상 판정 불가 |
| CanvasKit, 자동 30초 | AVG 55.1, LOW 42.0, GAP 139ms | 기준 |
| Wasm, 자동 30초 | AVG 56.7, LOW 43.6, GAP 134ms | 차이가 작아 Wasm 유지 |
| 효과음 반복 프라이밍 수정 전후 | 잠재 정지 286에서 37, `mediaremoted` 113에서 13, WebContent 104에서 14, GPU 60에서 7 | 시간 보정 정지율 약 79에서 82퍼센트 감소 |
| 게임 루프 할당 축소, 사운드 해제 후 자동 30초 | AVG 55.0, LOW 41.7, GAP 139ms | 평균은 개선됐지만 순간 정지 잔존 |
| 같은 실행의 시스템 추적 | WebContent 정지 22회, 100ms 이상 20회, GPU 20회, `mediaremoted` 29회 | 오디오와 GPU 동시 정지 영향 큼 |
| 수동 플레이 체감 | AVG 약 47, LOW 약 36, 드물게 5 FPS 관찰 | 정식 동일 조건 A/B가 아닌 사용자 관찰값 |
| 2026-09-24 Android NAS `b71ba31`(PLAN-005 1차) | SM-A245N 90Hz, CDP rAF 20초 플레이 평균 89 FPS, p95 11.2ms, Last Hurrah 중 약 88 FPS | 하이퍼 교환, Speed Bonus, Last Hurrah 추가 뒤 단기 회귀 없음. 장시간, 토스 WebView, iPhone은 미측정 |

### GC 해석

Time Profiler에서 다음 표본이 프레임 정지와 겹쳤다.

- `JSC::LocalAllocator::allocateSlowCase`
- JavaScriptCore marking과 sweep
- `JSC::Heap::stopThePeriphery`
- 약 82ms와 123ms의 WebContent 정지 구간

하지만 사운드를 켠 자동 측정의 100ms 이상 WebContent 정지 20회 중 GC 표본이 가까이 확인된 것은 4회였다. 20회 모두 GPU와 `mediaremoted` 정지가 50ms 이내에 함께 발생했다.

따라서 올바른 결론은 다음과 같다.

- 반복 객체 할당과 JSC GC는 일부 순간 정지에 관여했다.
- 모든 드롭의 원인이 GC라고 확정할 수는 없다.
- 오디오를 끈 A/B는 실제 게임 요구사항이 아니므로 검토 대상이 아니라 원인 분리용 대조군으로만 사용한다.

## 5. 적용한 렌더링 최적화

### 5.1 전체 화면 별 배경을 정적으로 변경

기존 배경은 별 그룹의 알파를 계속 변경하며 전체 화면 합성을 반복했다.

변경:

- Flutter `StarryBackground`의 반복 `AnimationController`와 `FadeTransition` 제거
- Flame `SpaceBg`의 시간 업데이트와 그룹별 `saveLayer` 제거
- 배경과 별 그룹을 `ui.Picture`로 캐시
- 정적 `drawPicture`만 실행

Flame 배경은 기존 약 240회 draw 호출을 캐시된 그림 4회로 줄였다. 모바일 WebView에서는 미세한 반짝임보다 전체 화면 지속 합성 제거의 가치가 더 컸다.

다른 게임에 적용할 때:

- 배경이 실제 게임 규칙과 무관하면 먼저 정적으로 비교한다.
- 애니메이션을 유지해야 한다면 전체 화면이 아니라 작은 레이어만 갱신한다.
- `saveLayer`, blur, opacity 애니메이션이 화면 전체에 걸리지 않는지 확인한다.

### 5.2 첫 사용 비용을 로딩 단계로 이동

적용한 방식:

- 타이틀 버튼과 아이콘을 `precacheImage`로 준비
- `MatchBoardGame.loaded`와 `SoundManager.preload()`가 끝날 때까지 게임 입력 차단
- 로딩 중 `GameLoadingOverlay` 표시
- 웹에서 `ParticlePool`과 `SpecialEffectPool`을 `onLoad` 중 warm-up
- `SoundManager.preload()`의 동일 `Future` 재사용
- 웹 앱 셸은 먼저 표시하고, 게임 진입 게이트에서 프리로드 완료를 기다림

목적은 총비용을 없애는 것이 아니라 첫 매치, 첫 파티클, 첫 이미지 디코딩 비용을 플레이 도중이 아닌 로딩 구간에 지불하는 것이다.

주의:

- 사용하지 않는 모든 자산을 무조건 미리 로드하면 초기 진입과 메모리가 악화된다.
- 실제 첫 플레이에서 발생하는 디코딩과 객체 생성만 대상으로 한다.

### 5.3 렌더 단계 임시 할당 감소

적용한 항목:

- 최대 64개 보석마다 생성되던 제거 연출 클로저 제거
- 재사용 가능한 `Vector2` 위치와 크기 객체 사용
- HUD 이미지용 `Paint` 재사용
- 고정 shadow, stroke, gradient `Paint` 재사용
- 레이아웃이 바뀔 때만 gradient shader 생성
- 힌트 수량이 바뀔 때만 `TextPainter` 재생성
- 불필요한 중간 `Rect` 생성을 중심 좌표 계산으로 대체

핵심 원칙:

- `render()`와 `update()` 안에서 `Paint`, `TextPainter`, `Vector2`, 클로저, 리스트, 문자열 키를 만들지 않는다.
- 색상, 크기, 레이아웃이 바뀔 때만 캐시를 갱신한다.
- 재사용 객체는 렌더 직전에 필요한 값만 덮어쓴다.

### 5.4 게임 루프 반복 할당 감소

적용한 항목:

- 빈 특수효과 이벤트는 새 리스트 대신 `const <SpecialEffectEvent>[]` 반환
- 카메라 흔들림은 매 프레임 새 `Vector2`를 반환하지 않고 `updateInto()`로 기존 객체 갱신
- 보드 셀의 `row:col` 문자열 키를 보드 생성 시 한 번 캐시
- 제거 예정 셀 조회는 캐시된 키를 사용

모든 리스트를 풀링할 필요는 없다. 프로파일에서 상시 호출되는 작은 할당부터 제거하는 것이 안전하다.

### 5.5 근거가 없어 제외한 항목

- `ParticlePool`은 의심 시점의 제거 콜백에서 실제 객체를 만들지 않아 추가 최적화 대상에서 제외했다.
- CanvasKit과 Wasm 차이가 작아 렌더러 교체를 해결책으로 사용하지 않았다.
- 효과음을 끄는 것은 제품 요구사항에 맞지 않아 최종 해결책에서 제외했다.
- 특수효과 품질 저하는 표시 유무 A/B에서 차이가 확인될 때만 검토한다.

## 6. 모바일 웹 효과음 장애와 최종 대응

### 6.1 증상

- BGM은 계속 재생됐다.
- 여러 효과음이 겹친 뒤 일부 SFX가 누락되거나 완전히 멈췄다.
- 가끔 복구됐지만 페이지를 나갔다 다시 들어와야 하는 경우도 있었다.
- 데스크톱에서는 재현이 어려웠다.

### 6.2 원인 1: 웹 플레이어와 AudioContext 증가

`flame_audio`가 사용하는 `audioplayers_web` 경로에서 동시 SFX 재생 시 플레이어와 Web Audio 컨텍스트가 늘어날 수 있었다. `AudioPool`의 `maxPlayers`를 영구 상한으로 오해하면 안 된다. 포화 시 새 플레이어가 만들어지는 구현인지 사용 중인 패키지 버전의 실제 코드를 확인해야 한다.

최종 정책:

- BGM은 기존 Flame 오디오 경로 유지
- 웹 SFX는 `web/stone_match_sfx.js`의 HTML 오디오 요소 4개만 공유
- 4개가 모두 사용 중이면 새 플레이어를 만들지 않고 초과 SFX를 드롭
- `stoneMatchSfx.getState()`로 재생, 드롭, 오류, unlock, 활성 슬롯 확인

고정 슬롯은 자원 폭증을 막지만 5개 이상 완전 동시 재생은 누락될 수 있다. 게임 사운드 설계에 맞춰 4를 시작값으로 두고 실제 드롭 수치가 있을 때만 늘린다.

### 6.3 원인 2: Flutter 웹 자산 URL 오류

첫 HTML Audio 배포에서는 다음 주소를 사용했다.

```text
assets/sfx/Collect.mp3
```

실제 빌드 파일은 다음 위치였다.

```text
assets/assets/audio/sfx/Collect.mp3
```

SPA fallback 때문에 잘못된 MP3 URL도 HTTP 200으로 `index.html`을 반환했다. 그 결과 iPhone에서 다음 상태가 확인됐다.

```json
{"plays":36,"drops":0,"errors":173,"lastError":"The operation is not supported."}
```

HTTP 200만 확인하면 안 된다. 반드시 `Content-Type`, 크기, 체크섬을 확인한다.

```bash
find build/web/assets -type f | rg 'Collect|BtnSnd'
curl -fsSI 'https://example.com/game/assets/assets/audio/sfx/Collect.mp3'
```

정상 예:

```text
content-type: audio/mpeg
```

### 6.4 원인 3: 모든 터치에서 unlock 반복

앱 루트 `Listener.onPointerDown`은 모든 터치에서 `unlockForWeb()`을 호출했다. 함수가 이미 해제됐는지 확인하지 않아 네 개 HTML Audio 요소의 무음 `play`, `pause`가 실제 효과음과 계속 경쟁했다.

경로 수정 후 실제 측정값:

```json
{"plays":17,"drops":0,"errors":5,"lastError":"The operation was aborted."}
```

드롭은 0이므로 슬롯 포화가 아니라 반복 unlock에 의한 중단이었다.

최종 구조:

```dart
static void unlockForWeb() {
  if (!kIsWeb) return;
  _webSfxPool?.unlock();
  if (_webUnlocked) return;
  _webUnlocked = true;
  // 대기 중인 BGM 처리
}
```

`unlockForWeb()`는 매 포인터 입력에서 호출되지만, JavaScript 풀은 `needsUnlock`이 `true`일 때만 실제 플레이어를 해제한다. `document.visibilitychange`에서 화면이 숨겨지면 진행 중인 SFX 슬롯을 정리하고 `needsUnlock = true`로 바꾼다. 따라서 화면 복귀 후 첫 입력에서만 다시 해제하고, 평상시에는 반복 프라이밍하지 않는다.

최종 모바일 수동 확인에서는 화면 복귀 후 효과음이 정상적으로 재생됐다. 다만 사용자가 페이지를 닫아 최종 콘솔 누적 카운터는 보존하지 못했으므로 장시간 회귀 테스트는 남아 있다.

### 6.5 원인 4: 화면 복귀 후 같은 BGM의 `resume` 실패

재현 경로는 다음과 같았다.

1. 타임 모드가 종료되어 결과창이 표시된다.
2. 화면을 이탈했다 복귀하면 BGM이 멈춘다.
3. `다시 하기`로 같은 메인 BGM을 요청하면 SFX는 정상이지만 BGM은 나오지 않는다.
4. `나가기`로 메인 화면에 돌아가면 메뉴 BGM은 정상적으로 재생된다.

게임 진행 중 화면 이탈은 복귀 후 일시정지 창의 `계속하기`가 `resumeBgm()`을 명시적으로 호출하므로 정상이었다. 반면 타임 아웃 상태는 일시정지 창을 추가하지 않고, `다시 하기`가 같은 경로의 `playBgm()`을 호출했다.

첫 수정은 같은 곡이면 `resume()`를 호출하도록 바꾸었지만 모바일 웹에서는 복구되지 않았다. 메뉴로 나가면 BGM이 복구된 것은 `Main_BGM`에서 `Menu_BGM`으로 곡이 바뀌면서 `FlameAudio.bgm.play()`가 플레이어를 `release`, `setSource`, `resume`하기 때문이었다.

최종 수정은 다른 스토어 채널에 영향을 주지 않도록 웹으로 한정했다.

```dart
if (_currentBgm == path) {
  if (kIsWeb) {
    await playBgmIfUnmuted(); // 소스를 다시 설정해 play
  } else {
    resumeBgm(onlyIfCurrent: path);
  }
  return;
}
```

NAS 일반 웹 빌드를 사용한 모바일 수동 검증에서 결과창 복귀 직후에는 BGM이 멈춘 상태를 유지했고, `다시 하기`로 새 라운드에 진입하면 BGM과 SFX가 모두 정상적으로 재생되는 것을 확인했다.

### 6.6 다른 게임에 이식할 때의 기준

1. 기존 SFX 플레이어가 실제로 고정 상한인지 패키지 코드를 확인한다.
2. BGM과 SFX 재생 경로를 분리한다.
3. SFX는 고정 슬롯으로 시작한다.
4. 오디오 해제는 최초 사용자 제스처와 화면 복귀 후 첫 제스처에서만 실행한다.
5. 자산 URL이 실제 `build/web` 구조와 일치하는지 확인한다.
6. 서버가 잘못된 오디오 URL을 HTML로 대체하지 않는지 확인한다.
7. 재생 오류를 삼키지 말고 최소 진단 카운터를 노출한다.
8. 실제 모바일에서 BGM과 SFX를 켠 상태로 연속 플레이한다.
9. 일시정지, 결과창, 광고 등 서로 다른 상태에서 화면 이탈과 복귀를 각각 검증한다.

## 7. 재사용 가능한 테스트 순서

### 단계 1: 기준 고정

다음을 표에 기록한다.

- Git 기준점
- 기기와 OS
- 브라우저 또는 호스트 앱 버전
- Flutter 빌드 모드와 렌더러
- 게임 모드
- 광고 표시 상태
- BGM과 SFX 상태
- 측정 시간

### 단계 2: PC는 기능 기준선으로만 사용

- release web으로 자동 플레이가 작동하는지 확인한다.
- 좌표와 QA 입력 경로를 검증한다.
- PC에서 정상이라고 모바일 병목이 없다고 결론 내리지 않는다.

### 단계 3: 실기기 기준값 측정

- 같은 모드에서 30초 이상 측정
- `AVG`, `LOW`, `GAP` 기록
- BGM과 SFX가 실제로 들리는지 확인
- `Animation Hitches` trace 동시 수집

### 단계 4: 한 번에 한 변수만 변경

권장 순서:

1. 전체 화면 지속 애니메이션 제거
2. 효과음 반복 프라이밍 제거
3. 렌더 단계 임시 할당 제거
4. 게임 루프 상시 할당 제거
5. 광고 배너 표시와 미표시 비교
6. 특수효과 표시와 미표시 비교

### 단계 5: 결과를 인과관계와 상관관계로 분리

- 한 변경 뒤 FPS와 정지율이 함께 개선되면 원인 후보가 강해진다.
- GC 표본이 근처에 있다는 이유만으로 GC를 단일 원인으로 확정하지 않는다.
- 오디오, GPU, WebContent 정지가 동시에 발생하면 다음 A/B로 분리한다.
- 실제 제품에서 끌 수 없는 기능은 최종 해결책이 아니라 진단용 대조군으로만 사용한다.

## 8. 주요 명령어

### 기본 검증

```bash
flutter analyze
flutter test
```

### Wasm release web

```bash
flutter build web \
  --release \
  --base-href "/" \
  --wasm \
  --no-web-resources-cdn
```

하위 경로 배포는 실제 경로로 `--base-href`를 바꾼다. 루트 빌드와 하위 경로 빌드를 섞지 않는다.

### 원격 파일 검증

```bash
curl -fsSI 'https://example.com/game/'
curl -fsSI 'https://example.com/game/main.dart.wasm'
curl -fsSI 'https://example.com/game/assets/assets/audio/sfx/Collect.mp3'

shasum -a 256 build/web/main.dart.wasm
curl -fsS 'https://example.com/game/main.dart.wasm' | shasum -a 256
```

Wasm 환경에서는 다음 헤더도 확인한다.

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Content-Type: application/wasm`

### iPhone Safari 실행

```bash
xcrun devicectl list devices

xcrun devicectl device process launch \
  --device '<device id>' \
  --terminate-existing \
  --payload-url 'https://example.com/game?qaPerf=1' \
  com.apple.mobilesafari
```

### 효과음 상태 확인

일반 Safari 원격 Web Inspector 콘솔:

```js
JSON.stringify(window.stoneMatchSfx?.getState?.())
```

정상 판단:

- `plays`가 입력에 따라 증가한다.
- `errors`가 증가하지 않는다.
- `unlocks`는 첫 터치와 화면 복귀 후 첫 터치에서만 1씩 증가한다.
- `drops`는 일반 플레이에서 0에 가깝다.
- `active`는 재생 종료 후 0으로 돌아온다.

## 9. 반복하지 말아야 할 접근

- PC에서 병목이 재현되지 않는다는 이유로 최적화를 종료하지 않는다.
- debug Chrome FPS를 release 실기기 수치와 비교하지 않는다.
- 스크린샷 한 장의 순간 FPS만으로 개선 여부를 판단하지 않는다.
- 사용자 터치가 없는 무음 자동 테스트를 실제 게임 성능으로 기록하지 않는다.
- 효과음을 꺼서 제품 성능 문제를 해결했다고 판단하지 않는다.
- HTTP 200만 보고 오디오 자산이 정상이라고 판단하지 않는다.
- `AudioPool` 이름만 보고 플레이어 수가 고정된다고 가정하지 않는다.
- 모든 렌더 객체를 무차별적으로 풀링하지 않는다. 실제 상시 할당 경로만 수정한다.
- GC와 가까운 정지를 모두 GC 원인으로 분류하지 않는다.
- 기존 trace 파일을 덮어쓰지 않는다.

## 10. 다음 앱 적용 체크리스트

### 계측

- [ ] FPS 패널을 설정에서 켜고 끌 수 있다.
- [ ] 현재 FPS, 30초 AVG, LOW, GAP을 구분해 표시한다.
- [ ] 광고와 주요 UI를 가리지 않는다.
- [ ] 동일 입력을 반복하는 QA 자동 플레이 경로가 있다.
- [ ] 자동 플레이 전에 실제 사용자 터치로 오디오를 해제한다.

### 렌더링

- [ ] 전체 화면 opacity, blur, `saveLayer` 반복 여부를 확인했다.
- [ ] 정적 배경과 장식은 picture 또는 raster cache를 사용한다.
- [ ] `render()`와 `update()` 안의 `Paint`, `TextPainter`, 리스트, 클로저, `Vector2` 생성을 확인했다.
- [ ] 레이아웃 변경 때만 shader와 텍스트 캐시를 갱신한다.
- [ ] 첫 사용 이미지, 파티클, 효과 풀을 필요한 범위에서 warm-up한다.

### 오디오

- [ ] BGM과 SFX 경로를 분리했다.
- [ ] SFX 플레이어 수가 실제로 고정돼 있다.
- [ ] 최초 포인터 입력과 화면 복귀 후 첫 입력에서만 실제 unlock한다.
- [ ] 동시 재생 포화 정책이 있다.
- [ ] 실제 오디오 URL과 `Content-Type`을 확인했다.
- [ ] plays, drops, errors, unlocks, active 상태를 확인할 수 있다.
- [ ] 결과창에서 화면 이탈 후 다시 하기 시 BGM과 SFX가 복구된다.
- [ ] BGM과 SFX를 켠 모바일 장시간 플레이를 수행했다.

### 실기기

- [ ] 같은 기기, 같은 호스트, 같은 모드에서 30초 이상 비교했다.
- [ ] 한 테스트에서 한 변수만 바꿨다.
- [ ] FPS 패널과 시스템 trace를 함께 기록했다.
- [ ] 광고 배너 표시와 미표시를 분리 측정했다.
- [ ] 특수효과 표시와 미표시를 분리 측정했다.

## 11. Stone Match 참고 파일

| 파일 | 역할 |
| --- | --- |
| `lib/app.dart` | FPS 패널, 30초 통계, 웹 첫 포인터 처리 |
| `lib/views/game_view.dart` | QA 자동 플레이, 게임 로딩 게이트 |
| `lib/widgets/starry_background.dart` | Flutter 정적 별 배경 |
| `lib/game/components/space_bg.dart` | Flame 정적 배경 picture 캐시 |
| `lib/game/components/match_board_gem_overlay_renderer.dart` | 보석 렌더 임시 할당 축소 |
| `lib/game/components/match_game_hud.dart` | HUD Paint, shader, 텍스트 캐시 |
| `lib/game/match_board_camera_shake.dart` | `Vector2` 재사용 |
| `lib/game/match_board_logic.dart` | 빈 이벤트 상수 리스트, 셀 키 캐시 |
| `lib/resources/sound_manager.dart` | BGM, SFX 분기와 필요 시 1회 unlock |
| `lib/resources/sound_manager_web_sfx.dart` | 웹 SFX 고정 풀 연결 |
| `lib/resources/web_sfx_bridge_web.dart` | Dart와 JavaScript 오디오 브리지 |
| `web/stone_match_sfx.js` | HTML Audio 4슬롯과 진단 카운터 |
| `test/fps_window_stats_test.dart` | FPS 누적 통계 테스트 |
| `test/sound_manager_test.dart` | 웹 오디오 정책 회귀 테스트 |
| 이 팩 Workflow의 테스트·빌드·배포 명령 절 | 로컬, NAS, AIT 빌드와 배포 명령 |

## 12. 남은 검증

- 최종 HTML Audio 4슬롯 수정본의 장시간 모바일 플레이 누적 카운터 확인
- 같은 빌드에서 Apps in Toss 하단 배너 표시와 미표시 A/B
- 특수효과 표시와 미표시 A/B
- 위 비교에서 차이가 있을 때만 HUD의 남은 프레임별 도형과 색상 생성 계측
- 웹 화면 꺼짐 방지는 브라우저와 호스트 정책에 따라 무시될 수 있으므로 별도 실기기 검증

현재 상태는 짧은 모바일 수동 플레이에서 화면 복귀 후 SFX 누락과 `다시 하기` BGM 미복구가 해소된 것으로 확인됐지만, 장시간 회귀 테스트까지 완료된 상태는 아니다.


---

# FPS 드롭 계측 계획

원문 제목 키: `fps_drop_simulation_plan.md` (이 파일에 흡수됨)

# FPS Drop Simulation Plan

목표: 무한 모드(`mode=simple`)에서 실제 플레이에 가까운 자동 입력을 넣고, 평균 FPS가 아니라 프레임 드롭이 발생하는 구간을 포착한다.

## 배경

이전 짧은 자동 플레이 결과는 평균적으로 안정적이었다.

- URL: `http://localhost:53965/game?mode=simple`
- 입력: 약 42초 동안 인접 셀 클릭 124회
- RAF 기준 평균 FPS: 약 60.0
- p95 frame time: 약 17.3ms
- long task: 0

하지만 이 결과는 “평균 상태”만 보여준다. 다음 세션에서는 프레임이 떨어지는 순간을 잡아야 하므로, 프레임 샘플을 이벤트 단위로 기록해야 한다.

## 모바일 웹 초기 진입 대응

모바일 웹에서는 PC 웹보다 첫 화면 진입과 첫 매치 이펙트에서 체감 지연이 크게 보일 수 있다. 현재 대응은 초기 작업을 실제 플레이 입력 전에 끝내는 방식이다.

- 타이틀 화면은 버튼/아이콘 이미지 `precacheImage`가 끝나기 전까지 로딩 오버레이를 유지한다.
- 게임 화면은 `MatchBoardGame.loaded`와 `SoundManager.preload()`가 완료될 때까지 로딩 오버레이를 유지한다.
- 로딩 오버레이가 보이는 동안 `AbsorbPointer`로 게임 입력을 막는다.
- 웹에서는 `ParticlePool`, `SpecialEffectPool`을 `onLoad` 중 미리 warm-up 해서 첫 매치 이펙트 생성 비용을 플레이 중이 아니라 로딩 단계에서 부담한다.
- `SoundManager.preload()`는 중복 호출 시 같은 `Future`를 재사용한다.
- 웹 `main()`은 앱 셸 표시를 막지 않도록 사운드/스프라이트 프리로드를 백그라운드로 시작하고, 실제 게임 진입 게이트에서 완료를 기다린다.

QA 기준:

- 모바일 폭 Chrome에서 타이틀 버튼이 준비 전 부분 렌더링되지 않는다.
- 게임 진입 후 첫 매치/수동 VFX 캡처에서 콘솔 overflow/error 플래그가 없어야 한다.
- 관련 캡처는 `tmp/qa/mobile_title_after_loading_gate.png`, `tmp/qa/mobile_game_after_warmup_vfx.png`, `tmp/qa/mobile_game_manual_vfx_after_warmup.png`처럼 `tmp/qa/` 아래에 저장한다.

## 테스트 전 상태 확인

테스트 전에 아래를 먼저 확인한다.

```bash
ps -axo pid,ppid,%cpu,%mem,rss,args | sort -k3 -nr | head -25
vm_stat | sed -n '1,22p'
memory_pressure | tail -20
ps -axo pid,ppid,%cpu,%mem,rss,args | rg "flutter_tools|Google Chrome.*remote-debugging-port|localhost:"
```

기록할 것:

- `syspolicyd`, `trustd`, `WindowServer`, `Finder`, Flutter Chrome renderer의 CPU
- swap in/out 여부
- Flutter 앱 URL과 Chrome remote debugging port
- 테스트가 debug web인지 release web인지

주의: Flutter web debug Chrome은 release보다 무겁다. 실제 성능 판단은 가능하면 release web에서도 별도로 확인한다.

## 실행 대상

무한 모드 URL:

```text
http://localhost:<flutter-port>/game?mode=simple
```

현재 앱 구조 기준 phone frame은 `390x750` 논리 크기다. 보드 좌표는 코드에서 계산한다.

- `PhoneFrame`: `390x750`
- 보드: `8x8`
- 레이아웃 공식: `lib/game/match_board_game_layout.dart`
- 입력 좌표 변환: `lib/game/match_board_geometry.dart`

## 자동 플레이 방식

다음 세션에서는 Playwright 또는 Chrome DevTools Protocol로 브라우저를 열고, 실제 사용자처럼 셀 두 개를 순서대로 클릭한다.

권장 시나리오:

- 90초 이상 실행
- 인접 셀 클릭 반복
- 클릭 간격은 완전 고정하지 말고 40~90ms, 다음 스왑까지 150~300ms 정도로 흔들기
- 유효하지 않은 스왑도 포함한다. 실제 플레이 입력 부하와 동일하게 보기 위해서다.
- 가능하면 “유효 스왑 탐색” 모드도 추가한다. 무작위 클릭만으로는 매치/리필/특수효과 구간이 충분히 발생하지 않을 수 있다.

## 반드시 기록할 지표

RAF 샘플:

- `timestamp`
- `deltaMs`
- `fps = 1000 / deltaMs`
- `dropLevel`
  - `minor`: `deltaMs >= 24ms`
  - `visible`: `deltaMs >= 33ms`
  - `severe`: `deltaMs >= 50ms`

입력 이벤트:

- `moveIndex`
- `clickA timestamp`
- `clickB timestamp`
- 선택한 셀 `(row, col)`
- 클릭 좌표

브라우저 이벤트:

- `PerformanceObserver` long task
- console error/warning
- asset decode/network request가 있으면 URL과 시간

시스템 상태:

- 테스트 시작/종료 시 CPU top
- 드롭 이벤트가 많았던 시점 주변의 CPU top

## 드롭 구간 판정

드롭을 평균 FPS로 판단하지 않는다. 아래 이벤트 목록을 만든다.

```json
{
  "atMs": 12345.6,
  "deltaMs": 48.2,
  "fps": 20.7,
  "nearestMove": 37,
  "phaseGuess": "after-second-click",
  "longTaskNearby": false,
  "notes": "swap/revert or match resolution window"
}
```

`phaseGuess` 후보:

- `route-entry`: 메뉴에서 게임 진입 직후
- `intro-fill`: 첫 보드 낙하/인트로 채움
- `after-first-click`: 첫 셀 선택 직후
- `after-second-click`: 두 번째 셀 클릭 직후
- `swap-revert`: 유효하지 않은 스왑 되돌림 추정
- `match-resolve`: 매치 제거/점수/파티클 추정
- `refill`: 낙하/리필 추정
- `special-vfx`: 특수 보석 발동 추정
- `external-cpu`: 시스템 프로세스 점유와 겹침

## 다음 세션용 Playwright 스크립트 골격

이 스크립트는 그대로 붙여 쓰기 위한 골격이다. 포트는 다음 세션에서 실제 값으로 바꾼다.

```js
const { chromium } = await import("playwright");

const browser = await chromium.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: false,
  args: ["--disable-extensions", "--disable-background-timer-throttling"],
});

const page = await browser.newPage({
  viewport: { width: 390, height: 750 },
  deviceScaleFactor: 1,
});

await page.goto("http://localhost:53965/game?mode=simple", {
  waitUntil: "domcontentloaded",
});
await page.waitForTimeout(3500);

await page.evaluate(() => {
  window.__fpsDeltas = [];
  window.__drops = [];
  window.__longTasks = [];
  window.__marks = [];
  window.__fpsRunning = true;

  let last;
  function loop(ts) {
    if (last !== undefined) {
      const deltaMs = ts - last;
      const sample = { atMs: ts, deltaMs, fps: 1000 / deltaMs };
      window.__fpsDeltas.push(sample);
      if (deltaMs >= 24) window.__drops.push(sample);
    }
    last = ts;
    if (window.__fpsRunning) requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        window.__longTasks.push({
          startTime: e.startTime,
          duration: e.duration,
        });
      }
    }).observe({ entryTypes: ["longtask"] });
  } catch (_) {}
});

function boardMetrics() {
  const w = 390;
  const h = 750;
  const hudScale = Math.min(w, h) * 0.2;
  const topChrome =
    10 +
    hudScale * 0.54 +
    hudScale * 1.38 +
    hudScale * 0.1 +
    hudScale * 0.88 +
    hudScale * 0.22;
  const bottomChrome = hudScale * 0.26 + hudScale * 0.5 + hudScale * 0.18;
  const safeLeft = w * 0.03;
  const safeWidth = w - w * 0.06;
  const ref = Math.min(safeWidth, h - topChrome - bottomChrome - 12);
  const tile = ref / (8 + 0.06 * 9);
  const spacing = tile * 0.06;
  const gridW = 8 * tile + 9 * spacing;
  const bx = safeLeft + (safeWidth - gridW) / 2 + spacing;
  const by = topChrome + spacing;
  return { bx, by, tile };
}

function center(metrics, row, col) {
  return {
    x: metrics.bx + col * metrics.tile + metrics.tile / 2,
    y: metrics.by + row * metrics.tile + metrics.tile / 2,
  };
}

function randomMove() {
  const row = Math.floor(Math.random() * 8);
  const col = Math.floor(Math.random() * 8);
  const dirs = [
    [0, 1],
    [1, 0],
    [0, -1],
    [-1, 0],
  ].filter(([dr, dc]) => row + dr >= 0 && row + dr < 8 && col + dc >= 0 && col + dc < 8);
  const [dr, dc] = dirs[Math.floor(Math.random() * dirs.length)];
  return { a: [row, col], b: [row + dr, col + dc] };
}

const metrics = boardMetrics();
const startedAt = Date.now();
let moveIndex = 0;

while (Date.now() - startedAt < 90000) {
  const move = randomMove();
  const a = center(metrics, move.a[0], move.a[1]);
  const b = center(metrics, move.b[0], move.b[1]);

  await page.evaluate((mark) => window.__marks.push(mark), {
    moveIndex,
    phase: "before-first-click",
    atPerfMs: await page.evaluate(() => performance.now()),
    move,
  });
  await page.mouse.click(a.x, a.y);
  await page.waitForTimeout(40 + Math.floor(Math.random() * 50));

  await page.evaluate((mark) => window.__marks.push(mark), {
    moveIndex,
    phase: "before-second-click",
    atPerfMs: await page.evaluate(() => performance.now()),
    move,
  });
  await page.mouse.click(b.x, b.y);

  moveIndex += 1;
  await page.waitForTimeout(150 + Math.floor(Math.random() * 150));
}

await page.waitForTimeout(1500);

const result = await page.evaluate(() => {
  window.__fpsRunning = false;
  const samples = window.__fpsDeltas;
  const drops = window.__drops;
  const sorted = samples.map((s) => s.deltaMs).sort((a, b) => a - b);
  const percentile = (p) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] || 0;

  function nearestMark(atMs) {
    let best = null;
    for (const mark of window.__marks) {
      const d = Math.abs(mark.atPerfMs - atMs);
      if (!best || d < best.distanceMs) best = { ...mark, distanceMs: d };
    }
    return best;
  }

  return {
    sampleCount: samples.length,
    avgFrameMs: samples.reduce((a, s) => a + s.deltaMs, 0) / Math.max(1, samples.length),
    p50FrameMs: percentile(0.5),
    p90FrameMs: percentile(0.9),
    p95FrameMs: percentile(0.95),
    p99FrameMs: percentile(0.99),
    dropCount24ms: drops.filter((d) => d.deltaMs >= 24).length,
    dropCount33ms: drops.filter((d) => d.deltaMs >= 33).length,
    dropCount50ms: drops.filter((d) => d.deltaMs >= 50).length,
    worstDrops: drops
      .sort((a, b) => b.deltaMs - a.deltaMs)
      .slice(0, 20)
      .map((d) => ({ ...d, nearestMark: nearestMark(d.atMs) })),
    longTasks: window.__longTasks,
  };
});

console.log(JSON.stringify(result, null, 2));
await page.screenshot({ path: "tmp/fps-drop-simulation-final.png" });
await browser.close();
```

## 결과 해석 기준

우선순위:

1. `dropCount50ms > 0`: 눈에 띄는 끊김. `worstDrops`의 `nearestMark`와 long task를 먼저 본다.
2. `dropCount33ms`가 반복 발생: 30fps 체감 구간. 입력 직후인지 리필/특수효과인지 분리한다.
3. `p95FrameMs <= 18ms`이고 `dropCount33ms == 0`: 플레이 중 렌더링은 대체로 안정.
4. 앱 내부 long task가 없는데 시스템 CPU가 높으면 외부 요인으로 분류한다.

## 추가로 잡아야 할 케이스

기본 랜덤 스왑 외에 다음 세션에서 추가할 것:

- 메뉴에서 게임 진입 후 첫 3초 측정
- 첫 보드 인트로 낙하 중 측정
- 무효 스왑 반복만 측정
- 유효 매치가 자주 발생하도록 보드 상태를 읽거나 디버그 훅을 추가한 뒤 측정
- 특수 보석 발동 디버그 훅(`qaVfx=1` 또는 `debugTriggerSpecialEffects`)으로 `row/col/bomb/star/supernova` 각각 측정

## 코드 수정 후보

드롭이 특정 구간으로 좁혀지면 그때만 수정한다.

- 게임 진입 직후: `GameLoadingOverlay`, BGM 전환, SFX pool prime 지연 확인
- 리필/낙하: `match_board_update.dart` 보간/상태 전환 확인
- 특수효과: `special_effect_burst_*`의 draw 호출 수와 blur/maskFilter 확인
- 지속 렌더링: `match_board_renderer.dart`의 `FilterQuality.medium`, color filter, clip 사용 확인
- 외부 CPU: 앱 수정 대신 release web에서 재검증
