import assert from 'node:assert/strict';
import test from 'node:test';
import { PNG } from 'pngjs';
import { geometry, readBoard, findMove } from './play_bot.mjs';
import { FinalScoreTracker } from './play_bot_vision.mjs';

test('final score excludes title-only and animated intermediate values', () => {
  const tracker = new FinalScoreTracker();
  assert.equal(tracker.update(null, 0), null);
  assert.equal(tracker.update(1524, 1000), null);
  assert.equal(tracker.update(2132, 1500), null);
  assert.equal(tracker.update(4100, 2100), null);
  assert.equal(tracker.update(4100, 3000), null);
  assert.equal(tracker.update(4100, 3100), 4100);
});

test('findMove finds a valid adjacent exchange without modifying the board', () => {
  const cells = Array.from({ length: 8 }, (_, r) => Array.from({ length: 8 }, (_, c) => (r * 2 + c) % 6));
  cells[0][0] = 4; cells[0][1] = 4; cells[0][2] = 3; cells[1][2] = 4;
  const before = JSON.stringify(cells), move = findMove(cells);
  assert.ok(move);
  assert.equal(Math.abs(move.a.row - move.b.row) + Math.abs(move.a.col - move.b.col), 1);
  assert.equal(JSON.stringify(cells), before);
  const { a, b } = move;
  [cells[a.row][a.col], cells[b.row][b.col]] = [cells[b.row][b.col], cells[a.row][a.col]];
  const hasMatch = cell => {
    const color = cells[cell.row][cell.col];
    for (const [dr, dc] of [[1, 0], [0, 1]]) {
      for (let start = -2; start <= 0; start++) {
        if ([0, 1, 2].every(k => cells[cell.row + dr * (start + k)]?.[cell.col + dc * (start + k)] === color)) return true;
      }
    }
    return false;
  };
  assert.ok(hasMatch(a) || hasMatch(b));
});

test('unknown tiles cannot be used as matches or swap targets', () => {
  const cells = Array.from({ length: 8 }, () => Array(8).fill(null));
  assert.equal(findMove(cells), null);
});

test('screenshot recognition handles six gem colours and both phone-frame scales', () => {
  for (const [width, height] of [[430, 900], [960, 750]]) {
    const png = new PNG({ width, height }), g = geometry(width, height);
    const colors = [[210, 20, 30], [190, 85, 15], [230, 190, 30], [65, 150, 20], [30, 130, 220], [150, 35, 195]];
    const expected = [];
    for (let r = 0; r < 8; r++) {
      expected[r] = [];
      for (let c = 0; c < 8; c++) {
        const color = (r * 2 + c) % 6;
        expected[r][c] = color;
        for (let y = Math.ceil(g.y + r * g.tile); y < g.y + (r + 1) * g.tile; y++) {
          for (let x = Math.ceil(g.x + c * g.tile); x < g.x + (c + 1) * g.tile; x++) {
            const i = (y * width + x) * 4;
            png.data.set([...colors[color], 255], i);
          }
        }
      }
    }
    const actual = readBoard(PNG.sync.write(png), g);
    assert.equal(actual.known, 64);
    assert.deepEqual(actual.cells, expected);
  }
});
