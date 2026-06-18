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
