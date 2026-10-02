import { PNG } from 'pngjs';

// Result titles appear before the panel and its 800ms score count-up finishes.
export class FinalScoreTracker {
  update(score, now) {
    this.startedAt ??= now;
    if (!Number.isFinite(score)) return null;
    if (score !== this.last) { this.last = score; this.changedAt = now; }
    return now - this.startedAt >= 3000 && now - this.changedAt >= 1000 ? score : null;
  }
}

// PhoneFrame (390x750) and MatchBoardGameLayout's current timed-mode layout.
export function geometry(width, height) {
  const scale = Math.min(width / 390, height / 750);
  const hud = 390 * .2;
  const top = 10 + hud * (.54 + 1.06 + .04 + .77 + .18 + .44 + .24);
  const ref = Math.min(390 * .976, 750 - top - (hud * 1.68 + 8) - 12);
  const tile = ref / (8 + .025 * 9);
  return { x: (width - 390 * scale) / 2 + (390 - tile * 8) / 2 * scale,
    y: (height - 750 * scale) / 2 + (top + tile * .025) * scale, tile: tile * scale };
}

function hue(r, g, b) {
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  if (max < 65 || d / max < .38) return null;
  const h = ((max === r ? (g - b) / d : max === g ? (b - r) / d + 2 : (r - g) / d + 4) * 60 + 360) % 360;
  if (h < 14 || h >= 345) return 0; // red
  if (h < 43) return 1; // orange
  if (h < 73) return 2; // yellow
  if (h < 165) return 3; // green
  if (h < 255) return 4; // blue
  return 5; // purple
}

export function readBoard(buffer, g) {
  const image = PNG.sync.read(buffer);
  const cells = [], confidence = [];
  for (let row = 0; row < 8; row++) {
    cells[row] = [];
    for (let col = 0; col < 8; col++) {
      const counts = Array(6).fill(0);
      // Inner gem region excludes grid lines, shadows and neighbouring tiles.
      for (let dy = .20; dy < .80; dy += .035) for (let dx = .20; dx < .80; dx += .035) {
        const x = Math.round(g.x + (col + dx) * g.tile), y = Math.round(g.y + (row + dy) * g.tile);
        if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
        const i = (y * image.width + x) * 4;
        const color = hue(image.data[i], image.data[i + 1], image.data[i + 2]);
        if (color !== null) counts[color]++;
      }
      const total = counts.reduce((a, b) => a + b, 0), peak = Math.max(...counts);
      cells[row][col] = total >= 12 && peak / total >= .58 ? counts.indexOf(peak) : null;
      confidence.push(total ? peak / total : 0);
    }
  }
  return { cells, signature: cells.flat().join(','), known: cells.flat().filter(c => c !== null).length,
    confidence: Math.min(...confidence) };
}

export function findMove(cells) {
  const matchAt = (r, c) => {
    const color = cells[r][c];
    if (color === null) return false;
    for (const [dr, dc] of [[1, 0], [0, 1]]) {
      let n = 1;
      for (const sign of [-1, 1]) {
        for (let k = 1; k < 8; k++) {
          const rr = r + dr * k * sign, cc = c + dc * k * sign;
          if (rr < 0 || rr >= 8 || cc < 0 || cc >= 8 || cells[rr][cc] !== color) break;
          n++;
        }
      }
      if (n >= 3) return true;
    }
    return false;
  };
  for (let r = 0; r < 8; r++) for (let c = 0; c < 8; c++) {
    for (const [dr, dc] of [[0, 1], [1, 0]]) {
      const rr = r + dr, cc = c + dc;
      if (rr >= 8 || cc >= 8 || cells[r][c] === null || cells[rr][cc] === null || cells[r][c] === cells[rr][cc]) continue;
      [cells[r][c], cells[rr][cc]] = [cells[rr][cc], cells[r][c]];
      const valid = matchAt(r, c) || matchAt(rr, cc);
      [cells[r][c], cells[rr][cc]] = [cells[rr][cc], cells[r][c]];
      if (valid) return { a: { row: r, col: c }, b: { row: rr, col: cc } };
    }
  }
  return null;
}
