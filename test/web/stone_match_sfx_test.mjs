import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../../web/stone_match_sfx.js', import.meta.url), 'utf8');
function harness() {
  const audios = [];
  const plays = [];
  const events = {};
  class Audio {
    constructor() { this.src = ''; this.currentTime = 0; this.paused = true; audios.push(this); }
    // iOS처럼 volume 쓰기가 무시되는 조건을 재현한다.
    get volume() { return 1; }
    set volume(_) {}
    addEventListener() {}
    load() {}
    pause() { this.paused = true; }
    play() {
      this.paused = false;
      plays.push(this.src);
      return new Promise((resolve) => { this.resolvePlay = resolve; });
    }
  }
  const document = { baseURI: 'https://example.test/', hidden: false,
    addEventListener: (name, fn) => { events[name] = fn; } };
  const window = {};
  vm.runInNewContext(source, { Audio, HTMLMediaElement: Audio, document, window, URL,
    setTimeout: () => 1, clearTimeout() {} });
  return { api: window.stoneMatchSfx, audios, plays, document, events };
}
function assertSilent(url) {
  assert.ok(url.startsWith('data:audio/wav;base64,'), `unlock played ${url}`);
  const wav = Buffer.from(url.split(',')[1], 'base64');
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.readUInt16LE(34), 8);
  assert.equal(wav.readUInt32LE(40), wav.length - 44);
  assert.ok(wav.subarray(44).length > 0);
  assert.ok(wav.subarray(44).every((sample) => sample === 128));
}

test('첫 입력의 unlock 4회는 볼륨 제어 없이도 무음이고 반복 입력은 재생하지 않는다', () => {
  const h = harness();
  h.api.initialize('sfx/Collect.mp3');
  h.api.unlock();
  assert.equal(h.plays.length, 4);
  h.plays.forEach(assertSilent);
  h.api.unlock();
  assert.equal(h.plays.length, 4);
});

test('화면 복귀 시 이전 효과음을 재생하지 않는다', () => {
  const h = harness();
  h.api.initialize('sfx/Collect.mp3');
  h.api.unlock();
  h.api.play('sfx/BtnSnd.mp3', 1, 250, 1);
  h.document.hidden = true;
  h.events.visibilitychange();
  h.document.hidden = false;
  h.api.unlock();
  h.plays.slice(-4).forEach(assertSilent);
  assert.equal(h.api.getState().unlocks, 2);
});

test('unlock 완료가 늦어도 직후 버튼 효과음 한 번을 끊지 않는다', async () => {
  const h = harness();
  h.api.initialize('sfx/Collect.mp3');
  h.api.unlock();
  const completeUnlock = h.audios[0].resolvePlay;
  h.api.play('sfx/BtnSnd.mp3', 1, 250, 1);
  completeUnlock();
  await Promise.resolve();
  assert.equal(h.audios[0].paused, false);
  assert.equal(h.api.getState().plays, 1);
  assert.equal(h.api.getState().active, 1);
  assert.equal(h.plays.filter((url) => url.endsWith('/BtnSnd.mp3')).length, 1);
});
