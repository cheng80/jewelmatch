// Invoke through run_play_bot_ego.mjs; Ego's embedded runtime has cwd=/.
const fs = await import('node:fs/promises');
const path = await import('node:path');
const { pathToFileURL } = await import('node:url');
const config = globalThis.STONE_BOT_CONFIG;
if (!config?.root) throw new Error('Use node tools/run_play_bot_ego.mjs');
const { geometry, readBoard, findMove, FinalScoreTracker } = await import(pathToFileURL(path.join(config.root, 'tools/play_bot_vision.mjs')).href);
const task = await taskSpace(config.space || 'Stone Match 플레이 봇');
const page = task.page('p1');
const out = config.out;
await fs.mkdir(out, { recursive: true });
console.log({ spaceId: task.spaceId, page: page.label });
const report = { browser: 'ego lite', input: 'CDP mouse events', startedAt: new Date().toISOString(), attempts: 0, verifiedMoves: 0, score: null };
const target = new URL(config.url);
if (target.hash || [...target.searchParams.keys()].some(key => /^qa/i.test(key))) throw new Error('운영 플레이는 QA query/hash 없이 실행하세요.');
const observe = async () => {
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(el => ({
    role: el.getAttribute('role'), name: el.getAttribute('aria-label') || el.textContent || '', checked: el.getAttribute('aria-checked'),
  })));
};
const menu = async name => {
  for (let i = 0; i < 100; i++) {
    const nodes = await observe();
    if (nodes.some(n => n.role === 'button' && n.name.trim() === name)) {
      await page.evaluate(name => {
        const button = [...document.querySelectorAll('flt-semantics[role="button"]')]
          .find(el => (el.getAttribute('aria-label') || el.textContent || '').trim() === name);
        button.click();
      }, name);
      return;
    }
    await page.waitForTimeout(200);
  }
  throw new Error(`버튼을 찾지 못했습니다: ${name}`);
};
const screenshot = async name => {
  const filename = path.join(out, name);
  await page.screenshot({ path: filename, scale: 'css' });
  return fs.readFile(filename);
};
try {
  await page.goto(target.href);
  await observe();
  console.log(await page.snapshot());
  await menu('설정');
  let consent;
  for (let i = 0; i < 40; i++) {
    consent = (await observe()).find(n => n.role === 'switch' && /사용 통계 보내기/.test(n.name));
    if (consent) break;
    await page.waitForTimeout(100);
  }
  report.analyticsConsent = consent?.checked === 'true';
  // Shared Ego preferences stay at the user's selected setting.
  await menu('뒤로');
  await menu('타임');
  const deadline = Date.now() + 150000;
  const finalScore = new FinalScoreTracker();
  let failures = 0;
  let automaticResumes = 0;
  while (Date.now() < deadline) {
    if (task.ownership !== 'agent') throw new Error('사용자 제어로 전환되어 플레이를 중단합니다.');
    const nodes = await observe();
    if (nodes.some(n => n.role === 'button' && n.name.trim() === '계속하기')) {
      if (++automaticResumes > 3) throw new Error('에고 게임이 반복해서 일시정지됩니다. 창 상태를 확인하세요.');
      await menu('계속하기');
      await page.waitForTimeout(250);
      continue;
    }
    if (nodes.some(n => n.role === 'button' && n.name.trim() === '시작')) await menu('시작');
    const ending = nodes.find(n => /시간 종료!.*게임 점수 결과/s.test(n.name));
    const match = ending?.name.match(/게임 점수 결과\s*([\d,]+)/);
    if (nodes.some(n => /시간 종료!/.test(n.name))) {
      const settled = finalScore.update(match ? Number(match[1].replaceAll(',', '')) : null, Date.now());
      if (settled !== null) { report.score = settled; break; }
      await page.waitForTimeout(250);
      continue;
    }
    if (report.verifiedMoves >= 8 || nodes.some(n => /시간 종료!/.test(n.name))) { await page.waitForTimeout(250); continue; }
    const viewport = await page.evaluate(() => ({ width: innerWidth, height: innerHeight }));
    const g = geometry(viewport.width, viewport.height);
    const before = readBoard(await screenshot('current.png'), g);
    await page.waitForTimeout(220);
    const stable = readBoard(await screenshot('current.png'), g);
    if (stable.known < 56 || stable.signature !== before.signature) { await page.waitForTimeout(200); continue; }
    const move = findMove(stable.cells);
    if (!move) { await page.waitForTimeout(200); continue; }
    const point = cell => ({ x: g.x + (cell.col + .5) * g.tile, y: g.y + (cell.row + .5) * g.tile });
    const a = point(move.a), b = point(move.b);
    report.attempts++;
    // Ego's native mouse wrapper changed window focus and paused this game.
    // CDP injects trusted pointer input into this page using CSS coordinates;
    // it still follows Flutter/Flame's normal input and match resolution path.
    await page.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved', x: a.x, y: a.y });
    await page.cdp('Input.dispatchMouseEvent', { type: 'mousePressed', x: a.x, y: a.y, button: 'left', buttons: 1, clickCount: 1 });
    for (let step = 1; step <= 12; step++) {
      await page.cdp('Input.dispatchMouseEvent', { type: 'mouseMoved',
        x: a.x + (b.x - a.x) * step / 12, y: a.y + (b.y - a.y) * step / 12, button: 'left', buttons: 1 });
    }
    await page.cdp('Input.dispatchMouseEvent', { type: 'mouseReleased', x: b.x, y: b.y, button: 'left', buttons: 0, clickCount: 1 });
    await page.waitForTimeout(800);
    let changed = false;
    for (let check = 0; check < 8; check++) {
      const after = readBoard(await screenshot('current.png'), g);
      await page.waitForTimeout(180);
      const settled = readBoard(await screenshot('current.png'), g);
      if (after.known >= 56 && settled.signature === after.signature) { changed = after.signature !== before.signature; break; }
      await page.waitForTimeout(250);
    }
    if (changed) {
      report.verifiedMoves++;
      failures = 0;
      console.log(`에고 유효 교환 ${report.verifiedMoves}/8`);
      if (report.verifiedMoves === 1) await screenshot('playing.png');
    } else if (++failures >= 3) throw new Error('에고 포인터 교환 3회 실패. 성공으로 처리하지 않습니다.');
  }
  if (!report.verifiedMoves || !(report.score > 0)) throw new Error('유효 교환과 양수 종료 점수를 확인하지 못했습니다.');
  await screenshot('end.png');
  console.log(await page.snapshot());
  report.success = true;
  report.finishedAt = new Date().toISOString();
  await fs.writeFile(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  console.log(report);
  await task.finish({ keep: [] });
} catch (error) {
  report.success = false;
  report.failure = error.message;
  report.finishedAt = new Date().toISOString();
  await fs.writeFile(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  console.error(report);
  // Ego's user-control stop is never retried or bypassed. Resume this space only
  // after the user returns control; do not create a replacement task space.
  throw error;
}
