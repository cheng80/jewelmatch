import { chromium } from 'playwright-core';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { geometry, readBoard, findMove, FinalScoreTracker } from './play_bot_vision.mjs';
export { geometry, readBoard, findMove } from './play_bot_vision.mjs';

async function enableAccessibility(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.dispatchEvent('click');
}

async function clickButton(page, name) {
  const labels = { '설정': /^(설정|Settings)$/, '뒤로': /^(뒤로|Back)$/, '타임': /^(타임|Time)$/,
    '시작': /^(시작|Start)$/, '다시하기': /^(다시하기|Retry|Play Again|Restart)$/ };
  const button = page.getByRole('button', { name: labels[name] || name, exact: true });
  for (let i = 0; i < 120; i++) {
    await enableAccessibility(page);
    if (await button.isVisible()) break;
    await page.waitForTimeout(250);
  }
  // Flutter's transparent semantics root may intercept Playwright hit testing.
  // Menu actions use their accessible click handlers; board moves use real pointers.
  await button.dispatchEvent('click');
}

async function main() {
  const args = process.argv.slice(2);
  const value = (key, fallback) => { const index = args.indexOf(key); return index < 0 ? fallback : args[index + 1]; };
  if (args.includes('--help')) {
    console.log('node tools/play_bot.mjs --url <game-root> [--rounds 1|2] [--moves 8] [--qa] [--analytics] [--headed] [--executable <browser>] [--cdp <endpoint>] [--out <directory>]');
    return;
  }
  const target = new URL(value('--url', 'http://127.0.0.1:8765/'));
  const qa = args.includes('--qa'), analytics = args.includes('--analytics');
  const rounds = Number(value('--rounds', '1'));
  const moveLimit = Number(value('--moves', '8'));
  if (![1, 2].includes(rounds)) throw new Error('--rounds must be 1 or 2');
  if (!Number.isInteger(moveLimit) || moveLimit < 1 || moveLimit > 20) throw new Error('--moves must be 1..20');
  if (qa && analytics) throw new Error('QA traffic cannot verify production GA4. Run --analytics without --qa.');
  if (!qa && [...target.searchParams.keys()].some(key => /^qa/i.test(key))) throw new Error('Production mode rejects QA query parameters.');
  if (target.hash) throw new Error('Use the game root URL without a hash route.');
  const out = path.resolve(value('--out', 'tmp/play-bot/latest'));
  await mkdir(out, { recursive: true });
  const executablePath = value('--executable', undefined), cdp = value('--cdp', undefined);
  const browser = cdp ? await chromium.connectOverCDP(cdp) : await chromium.launch({ headless: !args.includes('--headed'), ...(executablePath ? { executablePath } : {}) });
  // A new context isolates preferences and credentials from the user's profile.
  const context = await browser.newContext({ viewport: { width: 430, height: 900 }, deviceScaleFactor: 1, locale: 'ko-KR', timezoneId: 'Asia/Seoul' });
  const page = await context.newPage();
  const report = { url: target.origin + target.pathname, mode: qa ? 'qa' : 'production', analytics,
    startedAt: new Date().toISOString(), rounds: [], ga4: [], errors: [] };
  page.on('pageerror', error => report.errors.push(error.message));
  // Store only measurement ID, event names, environment and HTTP status; no client IDs or URLs.
  const collect = request => {
    const url = new URL(request.url());
    if (!/(^|\.)google-analytics\.com$/.test(url.hostname) || !url.pathname.endsWith('/collect')) return null;
    const common = url.searchParams;
    const lines = (request.postData() || '').split('\n');
    return lines.map(line => {
      const data = new URLSearchParams(line);
      return { measurementId: common.get('tid'), event: data.get('en') || common.get('en'),
        environment: data.get('ep.telemetry_env') || common.get('ep.telemetry_env') };
    });
  };
  page.on('response', response => {
    const events = collect(response.request());
    if (events) report.ga4.push(...events.map(event => ({ ...event, status: response.status() })));
  });
  page.on('requestfailed', request => {
    const events = collect(request);
    if (events) report.ga4.push(...events.map(event => ({ ...event, failure: request.failure()?.errorText })));
  });
  const pause = ms => page.waitForTimeout(ms);
  try {
    if (qa) target.searchParams.set('qaPerf', '1');
    await page.goto(target.href);
    await clickButton(page, '설정');
    await enableAccessibility(page);
    const consent = page.getByRole('switch', { name: /사용 통계 보내기|Send usage|Analytics|usage statistics/i });
    await consent.waitFor({ state: 'visible' });
    if (analytics && await consent.getAttribute('aria-checked') !== 'true') await consent.dispatchEvent('click');
    if (!analytics && await consent.getAttribute('aria-checked') === 'true') await consent.dispatchEvent('click');
    for (let i = 0; i < 40; i++) {
      if ((await consent.getAttribute('aria-checked') === 'true') === analytics) break;
      await pause(100);
    }
    report.consent = await consent.getAttribute('aria-checked');
    if (analytics && report.consent !== 'true') throw new Error('Analytics consent did not become enabled');
    await clickButton(page, '뒤로');
    // New session after explicit consent so session_start also uses the chosen setting.
    if (analytics) { await page.reload(); await enableAccessibility(page); }
    await clickButton(page, '타임');
    await clickButton(page, '시작');
    for (let round = 1; round <= rounds; round++) {
      const result = { round, attempts: 0, verifiedMoves: 0, score: null };
      report.rounds.push(result);
      const deadline = Date.now() + 150000;
      const finalScore = new FinalScoreTracker();
      let lastFailed = '', failures = 0;
      while (Date.now() < deadline) {
        await enableAccessibility(page);
        const text = await page.locator('flt-semantics').allTextContents();
        const ending = text.find(t => /시간 종료!|Time.?s? Up!/i.test(t));
        if (ending) {
          const match = ending.match(/(?:게임 점수 결과|Game Score Result|Final Score|Score Result|Game Score|Score)\s*([\d,]+)/i);
          // TimeUp first animates its title before exposing the result panel.
          const settled = finalScore.update(match ? Number(match[1].replaceAll(',', '')) : null, Date.now());
          if (settled === null) { await pause(250); continue; }
          result.score = settled;
          await page.screenshot({ path: path.join(out, `round-${round}-end.png`) });
          break;
        }
        if (result.verifiedMoves >= moveLimit) { await pause(250); continue; }
        const viewport = page.viewportSize(), g = geometry(viewport.width, viewport.height);
        let move, before, beforeScore;
        if (qa) {
          const state = await page.evaluate(() => window.__jewelMatchGetState?.());
          if (!state?.isPlaying || state.introFillInProgress || state.boardState !== 'idle') { await pause(250); continue; }
          move = await page.evaluate(() => window.__jewelMatchGetHintMove?.());
          before = state.boardSignature;
          beforeScore = state.score;
        } else {
          const first = readBoard(await page.screenshot(), g);
          await pause(220);
          const second = readBoard(await page.screenshot(), g);
          if (first.known < 56 || first.signature !== second.signature) { await pause(200); continue; }
          before = second.signature;
          move = findMove(second.cells);
          if (before === lastFailed && failures >= 3) throw new Error('Same board rejected 3 pointer moves; refusing to report playback success');
        }
        if (!move) { await pause(300); continue; }
        const point = cell => ({ x: g.x + (cell.col + .5) * g.tile, y: g.y + (cell.row + .5) * g.tile });
        const a = point(move.a), b = point(move.b);
        result.attempts++;
        await page.mouse.move(a.x, a.y);
        await page.mouse.down();
        await page.mouse.move(b.x, b.y, { steps: 12 });
        await page.mouse.up();
        await pause(800);
        let changed = false;
        for (let check = 0; check < 8; check++) {
          if (qa) {
            const after = await page.evaluate(() => window.__jewelMatchGetState?.());
            if (after?.boardState === 'idle') { changed = after.score > beforeScore && after.boardSignature !== before; break; }
          } else {
            const after = readBoard(await page.screenshot(), g);
            await pause(180);
            const stable = readBoard(await page.screenshot(), g);
            if (after.known >= 56 && stable.signature === after.signature) { changed = after.signature !== before; break; }
          }
          await pause(250);
        }
        if (changed) { result.verifiedMoves++; failures = 0; lastFailed = ''; }
        else { failures = lastFailed === before ? failures + 1 : 1; lastFailed = before; }
        if (result.verifiedMoves === 1) await page.screenshot({ path: path.join(out, `round-${round}-playing.png`) });
      }
      if (result.score === null) throw new Error('Timed round did not reach a readable result before the deadline');
      if (!result.verifiedMoves || result.score <= 0) throw new Error('No verified match or positive final score');
      console.log(`판 ${round}: 유효 교환 ${result.verifiedMoves}회, 최종 점수 ${result.score}`);
      if (round < rounds) await clickButton(page, '다시하기');
    }
    await pause(3000);
    if (analytics) {
      const received = report.ga4.filter(e => e.status >= 200 && e.status < 300);
      // Internal round_start/end are mapped to GA4 level_start/end. session_start
      // is generated by Google, not explicitly sent as a collect event by the app.
      const required = ['page_view', 'level_start', 'level_end'];
      if (required.some(event => !received.some(e => e.event === event))) throw new Error('GA4 collect did not acknowledge every required event');
      if (received.some(e => e.measurementId !== 'G-1D8SDVLZQX')) throw new Error('Unexpected GA4 measurement ID');
    }
    report.success = true;
  } catch (error) {
    report.success = false;
    report.failure = error.message;
    await writeFile(path.join(out, 'failure-ui.txt'), await page.locator('body').ariaSnapshot()).catch(() => {});
    await page.screenshot({ path: path.join(out, 'failure.png') }).catch(() => {});
    process.exitCode = 1;
    console.error(error.message);
  } finally {
    report.finishedAt = new Date().toISOString();
    await writeFile(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
    console.log(`검증 보고서: ${path.join(out, 'report.json')}`);
    await context.close();
    if (!cdp) await browser.close();
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await main();
}
