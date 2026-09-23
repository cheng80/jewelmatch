/* 이펙트 프롬프트 빌더: 선택값을 장면(횡스크롤, 퍼즐 판, UI) 위에서 재생하는 미리보기 */
(function () {
  'use strict';
  const FX = window.FX;
  const MAXP = 1400;
  const STEP = 1000 / 60;
  const TAU = Math.PI * 2;
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  const K_SPARK = 1, K_SHARD = 2, K_EMBER = 3, K_CONF = 4, K_ORBIT = 5, K_SMOKE = 6;
  const FONT = '"Apple SD Gothic Neo", "Noto Sans KR", system-ui, -apple-system, sans-serif';
  const GEMS = ['#e84a5f', '#f59e3b', '#f5d547', '#4cc86a', '#4a90f0', '#a55ee6'];
  const CH = {
    robe: '#a3263a', robeDark: '#6a1626', trim: '#e6b04a', skin: '#f0bf96', beard: '#ece8e0', staff: '#8a5a32', ink: '#150c18',
    slime: '#5bbf6e', slimeDark: '#2c6b3a', slimeHi: '#c4f5cc', stone: '#3b3950', stoneDark: '#26243a', stoneHi: '#5a5772', moon: '#efe6c8',
    chest: '#9a6430', chestDark: '#5a3818', gold: '#ffd24a',
  };

  function makeRng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) >>> 0; let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function rgb(h) { const n = parseInt(String(h).slice(1, 7), 16) || 0; return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
  function mix(a, b, t) { const A = rgb(a), B = rgb(b); return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join(''); }
  function rgba(h, a) { const c = rgb(h); return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }
  const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const outExpo = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));
  const outCubic = (t) => 1 - Math.pow(1 - t, 3);
  const spring = (t) => (t <= 0 ? 0 : 1 - Math.exp(-6 * t) * Math.cos(10 * t));

  /* 부드러운 스타일: 표시 캔버스에 논리 좌표로 그린다 */
  class SmoothG {
    constructor(ctx) { this.c = ctx; this.cam = { x: 0, y: 0, z: 1 }; this.cache = new Map(); }
    begin(W, H, cw, ch) { this.k = Math.min(cw / W, ch / H); this.ox = (cw - W * this.k) / 2; this.oy = (ch - H * this.k) / 2; this.W = W; this.H = H; this.cx = W / 2; this.cy = H / 2; this.c.imageSmoothingEnabled = true; }
    screen() { this.c.setTransform(this.k, 0, 0, this.k, this.ox, this.oy); }
    world() { const k = this.k, z = this.cam.z; this.c.setTransform(k * z, 0, 0, k * z, this.ox + k * (this.cx + this.cam.x - this.cx * z), this.oy + k * (this.cy + this.cam.y - this.cy * z)); }
    set(a, add) { this.c.globalAlpha = a < 0 ? 0 : a > 1 ? 1 : a; this.c.globalCompositeOperation = add ? 'lighter' : 'source-over'; }
    clear(color) { const c = this.c; c.setTransform(1, 0, 0, 1, 0, 0); this.set(1, false); c.fillStyle = color; c.fillRect(0, 0, c.canvas.width, c.canvas.height); }
    rect(x, y, w, h, color, a, add) { if (a <= 0.003) return; this.set(a, add); this.c.fillStyle = color; this.c.fillRect(x, y, w, h); }
    dot(x, y, s, color, a, add) { this.rect(x - s / 2, y - s / 2, s, s, color, a, add); }
    disk(x, y, r, color, a, add) { if (a <= 0.003 || r <= 0) return; this.set(a, add); const c = this.c; c.fillStyle = color; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
    ellipse(x, y, rx, ry, color, a, add) { if (a <= 0.003 || rx <= 0 || ry <= 0) return; this.set(a, add); const c = this.c; c.fillStyle = color; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill(); }
    ring(x, y, r, w, color, a, add, sy) {
      if (a <= 0.003 || r <= 0) return; this.set(a, add); const c = this.c; c.strokeStyle = color; c.lineWidth = w; c.beginPath();
      if (sy && sy !== 1) c.ellipse(x, y, r, r * sy, 0, 0, TAU); else c.arc(x, y, r, 0, TAU); c.stroke();
    }
    line(x0, y0, x1, y1, w, color, a, add) { if (a <= 0.003) return; this.set(a, add); const c = this.c; c.strokeStyle = color; c.lineWidth = w; c.lineCap = 'round'; c.beginPath(); c.moveTo(x0, y0); c.lineTo(x1, y1); c.stroke(); }
    polyline(p, w, color, a, add) {
      if (a <= 0.003 || p.length < 4) return; this.set(a, add); const c = this.c; c.strokeStyle = color; c.lineWidth = w; c.lineCap = 'round'; c.lineJoin = 'round';
      c.beginPath(); c.moveTo(p[0], p[1]); for (let i = 2; i < p.length; i += 2) c.lineTo(p[i], p[i + 1]); c.stroke();
    }
    poly(p, color, a, add, outline, ow, strokeOnly) {
      if (a <= 0.003) return; this.set(a, add); const c = this.c;
      c.beginPath(); c.moveTo(p[0], p[1]); for (let i = 2; i < p.length; i += 2) c.lineTo(p[i], p[i + 1]); c.closePath();
      if (!strokeOnly) { c.fillStyle = color; c.fill(); }
      if (outline) { c.strokeStyle = outline; c.lineWidth = ow; c.lineJoin = 'round'; c.stroke(); }
    }
    sprite(color) {
      let s = this.cache.get(color);
      if (!s) {
        s = document.createElement('canvas'); s.width = s.height = 64; const g = s.getContext('2d'); const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
        gr.addColorStop(0, rgba(color, 1)); gr.addColorStop(0.35, rgba(color, 0.42)); gr.addColorStop(1, rgba(color, 0));
        g.fillStyle = gr; g.fillRect(0, 0, 64, 64); this.cache.set(color, s);
      }
      return s;
    }
    soft(x, y, r, color, a, add) { if (a <= 0.003 || r <= 0) return; this.set(a, add !== false); this.c.drawImage(this.sprite(color), x - r, y - r, r * 2, r * 2); }
    text(str, x, y, size, color, a, outline) {
      if (!str || a <= 0.01) return; const c = this.c; this.set(a, false);
      c.font = '900 ' + size.toFixed(1) + 'px ' + FONT; c.textAlign = 'center'; c.textBaseline = 'middle';
      if (outline) { c.strokeStyle = outline; c.lineWidth = size * 0.22; c.lineJoin = 'round'; c.strokeText(str, x, y); }
      c.fillStyle = color; c.fillText(str, x, y);
    }
  }

  /* 도트 스타일: 저해상도 버퍼에 정수 사각형만으로 그리고, 중간 밝기는 Bayer 디더 */
  class PixelG {
    constructor(ctx) { this.c = ctx; this.cam = { x: 0, y: 0, z: 1 }; this.pat = new Map(); this.txt = new Map(); this.dither = true; this.useCam = false; this.spans = []; }
    begin(W, H) { this.W = W; this.H = H; this.cx = W / 2; this.cy = H / 2; const c = this.c; c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over'; c.imageSmoothingEnabled = false; }
    screen() { this.useCam = false; }
    world() { this.useCam = true; }
    fx(x) { return this.useCam ? this.cx + (x - this.cx) * this.cam.z + this.cam.x : x; }
    fy(y) { return this.useCam ? this.cy + (y - this.cy) * this.cam.z + this.cam.y : y; }
    X(x) { return Math.round(this.fx(x)); }
    Y(y) { return Math.round(this.fy(y)); }
    S(v) { return this.useCam ? v * this.cam.z : v; }
    level(a) { if (a <= 0.03) return 0; if (!this.dither) return a >= 0.4 ? 16 : 0; return Math.max(0, Math.min(16, Math.round(a * 16))); }
    fill(color, a) {
      const lv = this.level(a); if (lv <= 0) return null; if (lv >= 16) return color;
      const key = color + lv; let p = this.pat.get(key);
      if (!p) {
        const t = document.createElement('canvas'); t.width = t.height = 4; const g = t.getContext('2d'); g.fillStyle = color;
        for (let i = 0; i < 16; i++) if (BAYER[i] < lv) g.fillRect(i & 3, i >> 2, 1, 1);
        p = this.c.createPattern(t, 'repeat'); this.pat.set(key, p);
      }
      return p;
    }
    clear(color) { this.c.globalAlpha = 1; this.c.fillStyle = color; this.c.fillRect(0, 0, this.W, this.H); }
    rect(x, y, w, h, color, a) { const f = this.fill(color, a); if (!f) return; this.c.fillStyle = f; const x0 = this.X(x), y0 = this.Y(y); this.c.fillRect(x0, y0, Math.max(1, this.X(x + w) - x0), Math.max(1, this.Y(y + h) - y0)); }
    dot(x, y, sz, color, a) { const f = this.fill(color, a); if (!f) return; const s = Math.max(1, Math.round(this.S(sz))); this.c.fillStyle = f; this.c.fillRect(this.X(x) - (s >> 1), this.Y(y) - (s >> 1), s, s); }
    disk(x, y, r, color, a) { this.ellipse(x, y, r, r, color, a); }
    ellipse(x, y, rx, ry, color, a) {
      const f = this.fill(color, a); if (!f) return; const R = Math.round(this.S(rx)), RY = Math.max(0, Math.round(this.S(ry))); const X0 = this.X(x), Y0 = this.Y(y);
      this.c.fillStyle = f; if (R <= 0 || RY <= 0) { this.c.fillRect(X0, Y0, Math.max(1, R), 1); return; }
      for (let dy = -RY; dy <= RY; dy++) { const yy = (dy / RY) * R; const hw = Math.floor(Math.sqrt(Math.max(0, R * R - yy * yy + R * 0.8))); this.c.fillRect(X0 - hw, Y0 + dy, hw * 2 + 1, 1); }
    }
    ring(x, y, r, w, color, a, add, sy) {
      const f = this.fill(color, a); if (!f) return; sy = sy || 1; const R = Math.round(this.S(r)); if (R <= 0) return;
      const Wd = Math.max(1, Math.round(this.S(w))); const Ri = R - Wd; const X0 = this.X(x), Y0 = this.Y(y); this.c.fillStyle = f; const ry = Math.max(1, Math.round(R * sy));
      for (let dy = -ry; dy <= ry; dy++) {
        const yy = dy / sy; const ho = Math.floor(Math.sqrt(Math.max(0, R * R - yy * yy + R * 0.8)));
        if (Ri > 0 && Math.abs(yy) < Ri) { const hi = Math.floor(Math.sqrt(Math.max(0, Ri * Ri - yy * yy + Ri * 0.8))); if (ho - hi > 0) { this.c.fillRect(X0 - ho, Y0 + dy, ho - hi, 1); this.c.fillRect(X0 + hi + 1, Y0 + dy, ho - hi, 1); } }
        else this.c.fillRect(X0 - ho, Y0 + dy, ho * 2 + 1, 1);
      }
    }
    line(x0, y0, x1, y1, w, color, a) {
      const lv = this.level(a); if (lv <= 0) return;
      let X0 = this.X(x0), Y0 = this.Y(y0); const X1 = this.X(x1), Y1 = this.Y(y1); const s = Math.max(1, Math.round(this.S(w)));
      const dx = Math.abs(X1 - X0), dy = -Math.abs(Y1 - Y0), sx = X0 < X1 ? 1 : -1, sy = Y0 < Y1 ? 1 : -1; let err = dx + dy, guard = 0; this.c.fillStyle = color;
      for (;;) {
        if (lv >= 16 || BAYER[((Y0 & 3) << 2) | (X0 & 3)] < lv) this.c.fillRect(X0 - (s >> 1), Y0 - (s >> 1), s, s);
        if ((X0 === X1 && Y0 === Y1) || ++guard > 1500) break; const e2 = 2 * err; if (e2 >= dy) { err += dy; X0 += sx; } if (e2 <= dx) { err += dx; Y0 += sy; }
      }
    }
    polyline(p, w, color, a) { for (let i = 2; i < p.length; i += 2) this.line(p[i - 2], p[i - 1], p[i], p[i + 1], w, color, a); }
    fillPoly(xs, ys, style, ox, oy) {
      const n = xs.length; let minY = Infinity, maxY = -Infinity;
      for (let i = 0; i < n; i++) { if (ys[i] < minY) minY = ys[i]; if (ys[i] > maxY) maxY = ys[i]; }
      const y0 = Math.max(0, Math.floor(minY + oy)), y1 = Math.min(this.H - 1, Math.ceil(maxY + oy)); const sp = this.spans; this.c.fillStyle = style;
      for (let y = y0; y <= y1; y++) {
        const sy = y + 0.5 - oy; sp.length = 0;
        for (let i = 0, j = n - 1; i < n; j = i++) { const yi = ys[i], yj = ys[j]; if ((yi > sy) !== (yj > sy)) sp.push(xs[i] + ((sy - yi) * (xs[j] - xs[i])) / (yj - yi)); }
        sp.sort((p, q) => p - q);
        for (let k = 0; k + 1 < sp.length; k += 2) { const a0 = Math.round(sp[k] + ox), a1 = Math.round(sp[k + 1] + ox); if (a1 > a0) this.c.fillRect(a0, y, a1 - a0, 1); }
      }
    }
    poly(p, color, a, add, outline, ow, strokeOnly) {
      const n = p.length >> 1; const xs = new Array(n), ys = new Array(n);
      for (let i = 0; i < n; i++) { xs[i] = this.fx(p[i * 2]); ys[i] = this.fy(p[i * 2 + 1]); }
      if (strokeOnly) { const q = []; for (let i = 0; i <= n; i++) q.push(p[(i % n) * 2], p[(i % n) * 2 + 1]); this.polyline(q, 1, color, a); return; }
      const f = this.fill(color, a); if (!f) return;
      if (outline) { const o = this.fill(outline, a); if (o) { this.fillPoly(xs, ys, o, -1, 0); this.fillPoly(xs, ys, o, 1, 0); this.fillPoly(xs, ys, o, 0, -1); this.fillPoly(xs, ys, o, 0, 1); } }
      this.fillPoly(xs, ys, f, 0, 0);
    }
    soft(x, y, r, color, a) { this.disk(x, y, r * 0.55, color, a * 0.8); }
    text(str, x, y, size, color, a, outline) {
      if (!str || this.level(a) < 7) return; const px = Math.max(6, Math.round(this.S(size)));
      const key = str + '|' + px + '|' + color + '|' + (outline || ''); let bmp = this.txt.get(key);
      if (!bmp) { if (this.txt.size > 96) this.txt.clear(); bmp = pixelText(str, px, color, outline); this.txt.set(key, bmp); }
      this.c.drawImage(bmp, this.X(x) - (bmp.width >> 1), this.Y(y) - (bmp.height >> 1));
    }
  }
  function pixelText(str, px, color, outline) {
    const cv = document.createElement('canvas'); const g = cv.getContext('2d', { willReadFrequently: true }); const font = '900 ' + px + 'px ' + FONT;
    g.font = font; const w = Math.ceil(g.measureText(str).width) + 6; const h = Math.ceil(px * 1.35) + 6;
    cv.width = w; cv.height = h; g.font = font; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#fff'; g.fillText(str, w / 2, h / 2);
    const img = g.getImageData(0, 0, w, h); const d = img.data; const col = rgb(color); const oc = outline ? rgb(outline) : null;
    const m = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) m[i] = d[i * 4 + 3] > 110 ? 1 : 0;
    for (let i = 0; i < w * h; i++) {
      const o = i * 4, x = i % w;
      if (m[i]) { d[o] = col[0]; d[o + 1] = col[1]; d[o + 2] = col[2]; d[o + 3] = 255; continue; }
      const nb = oc && ((x > 0 && m[i - 1]) || (x < w - 1 && m[i + 1]) || (i >= w && m[i - w]) || (i < w * h - w && m[i + w]));
      if (nb) { d[o] = oc[0]; d[o + 1] = oc[1]; d[o + 2] = oc[2]; d[o + 3] = 255; } else d[o + 3] = 0;
    }
    g.putImageData(img, 0, 0); return cv;
  }

  class Preview {
    constructor(canvas, opts) {
      this.cv = canvas; this.ctx = canvas.getContext('2d');
      this.buf = document.createElement('canvas'); this.bctx = this.buf.getContext('2d');
      this.sg = new SmoothG(this.ctx); this.pg = new PixelG(this.bctx);
      this.onPhase = (opts && opts.onPhase) || function () {};
      const F = () => new Float32Array(MAXP);
      this.x = F(); this.y = F(); this.vx = F(); this.vy = F(); this.life = F(); this.max = F(); this.size = F(); this.rot = F(); this.vr = F(); this.a1 = F(); this.a2 = F();
      this.kind = new Uint8Array(MAXP); this.col = new Uint8Array(MAXP); this.cur = 0;
      this.comets = []; for (let i = 0; i < 8; i++) this.comets.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, hx: new Float32Array(8), hy: new Float32Array(8), n: 0, t: 0 });
      this.coins = []; for (let i = 0; i < 16; i++) this.coins.push({ t0: 0, dur: 1, sx: 0, sy: 0, cx: 0, cy: 0, done: false, hx: new Float32Array(6), hy: new Float32Array(6), n: 0 });
      this.hits = []; this.bolts = []; this.cracks = []; this.miniRings = [];
      this.proj = { x: 0, y: 0, hx: new Float32Array(8), hy: new Float32Array(8), n: 0, t: 0 };
      this.d = null; this.tier = 1; this.speed = 1;
      this.reduce = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
      this.auto = !this.reduce;
      this.phase = 'idle'; this.pt = 0; this.tt = 0; this.charge = 0; this.held = false; this.manual = false;
      this.acc = 0; this.drawAcc = 0; this.last = 0; this.tick = 0; this.dirty = true; this.emberAcc = 0; this.orbitSpawned = 0;
      this.coinCount = 0; this.hudBump = -1e9; this.targetHitAt = -1e9; this.castAt = -1e9; this.impactAt = -1e9; this.boltT = 0;
      this.r = makeRng(1); this.j = makeRng(7);
      this.resize();
      if (window.ResizeObserver) new ResizeObserver(() => this.resize()).observe(canvas); else window.addEventListener('resize', () => this.resize());
      canvas.addEventListener('pointerdown', (e) => { e.preventDefault(); this.press(); });
      window.addEventListener('pointerup', () => { this.held = false; });
      window.addEventListener('pointercancel', () => { this.held = false; });
      this.loop = this.loop.bind(this); requestAnimationFrame(this.loop);
    }
    resize() {
      const r = this.cv.getBoundingClientRect(); const dpr = Math.min(3, window.devicePixelRatio || 1);
      const w = Math.max(1, Math.round(r.width * dpr)), h = Math.max(1, Math.round(r.height * dpr));
      if (this.cv.width !== w || this.cv.height !== h) { this.cv.width = w; this.cv.height = h; }
      this.dirty = true;
    }
    setSpec(d) {
      const styleChanged = !this.d || this.d.style !== d.style;
      this.d = d; this.tier = Math.min(Math.max(1, this.tier), d.tiers);
      const c = d.colors; const bg = c.bg;
      this.C = {
        bg, hi: c.highlight, body: c.subject, bodyLight: mix(c.subject, c.highlight, 0.4), acc: c.accents.slice(), accDark: c.accents.map((a) => mix(a, bg, 0.55)),
        ink: mix(bg, '#000000', 0.45), smoke: mix(mix(c.subject, c.highlight, 0.3), bg, 0.2),
      };
      this.pg.dither = !d.pixel || d.s.dither !== false;
      this.W = d.pixel ? d.pixelW : 320; this.H = d.pixel ? d.pixelH : 240;
      if (styleChanged) this.sg.cache.clear();
      this.layout(); this.restart(); this.dirty = true;
    }
    setTier(t) { if (!this.d) return; this.tier = Math.min(Math.max(1, t), this.d.tiers); this.play(); }
    setSpeed(s) { this.speed = s; }
    setAuto(b) { this.auto = b; if (b && (this.phase === 'done' || this.phase === 'idle')) this.restart(); }
    on(id) { const m = this.d.minTier[id]; return m !== undefined && this.tier >= m; }
    counts() { return this.d.tierList[this.tier - 1]; }
    accent() { return this.C.acc[this.tier - 1]; }
    colorOf(ci) { return ci < 4 ? this.C.acc[ci] : ci === 9 ? this.C.body : ci === 10 ? this.C.hi : ci >= 20 ? GEMS[(ci - 20) % GEMS.length] : this.C.hi; }

    /* 장면 배치 */
    layout() {
      const d = this.d, W = this.W, H = this.H, px = d.pixel;
      const v = d.view.id; const dl = d.delivery.id;
      this.scene = v === 'board' ? 'board' : v === 'ui' ? 'ui' : 'stage'; this.topdown = v === 'topdown';
      this.floorY = this.scene === 'stage' && !this.topdown ? Math.round(H * 0.8) : H * 3;
      if (this.scene === 'board') {
        this.cols = 7; this.rows = 6; const cell = Math.floor(Math.min((W * 0.92) / 7, (H * 0.9) / 6));
        this.cell = cell; this.bx = Math.round((W - cell * 7) / 2); this.by = Math.round((H - cell * 6) / 2); this.unit = cell;
      } else this.unit = px ? Math.max(4, Math.round(H * 0.16)) : H * 0.16;
      const u = this.unit;
      this.caster = { x: Math.round(W * 0.2), y: this.topdown ? Math.round(H * 0.66) : this.floorY };
      this.foe = { x: Math.round(W * 0.74), y: this.topdown ? Math.round(H * 0.5) : this.floorY };
      this.hud = { x: Math.round(W - u * 1.5), y: Math.round(u * 0.75) };
      this.chest = { x: Math.round(W * 0.34), y: Math.round(H * 0.74) };
      const foeC = { x: this.foe.x, y: this.foe.y - u * 0.45 };
      this.staffUse = this.scene === 'stage' && ['projectile', 'beam', 'bolts', 'sky'].includes(dl);
      if (this.scene === 'board') {
        this.srcCell = 2 * 7 + 3; const sc = this.cellCenter(this.srcCell);
        this.A = sc; this.S = dl === 'projectile' || dl === 'beam' ? { x: W * 0.5, y: H + u * 0.3 } : dl === 'sky' ? { x: sc.x, y: -u } : sc;
      } else if (this.scene === 'ui') {
        this.A = { x: this.chest.x, y: this.chest.y - u * 0.35 }; this.S = this.A;
        if (dl === 'projectile' || dl === 'beam' || dl === 'bolts') this.S = { x: W * 0.08, y: H * 0.5 };
        if (dl === 'sky') this.S = { x: this.A.x, y: -u };
      } else if (dl === 'aura' || (dl === 'loop' && d.e.id !== 'ambient')) {
        this.A = { x: this.caster.x, y: this.caster.y - u * 0.9 }; this.S = this.A;
      } else if (dl === 'loop') {
        this.A = { x: W * 0.5, y: H * 0.42 }; this.S = this.A;
      } else {
        this.A = foeC; this.S = dl === 'sky' ? { x: foeC.x, y: -u } : this.staffUse ? this.staffTip(0, 1) : foeC;
      }
      this.dest = this.hud;
      this.buildBoard(); this.buildHits();
    }
    cellCenter(i) { const c = i % 7, r = (i / 7) | 0; return { x: this.bx + (c + 0.5) * this.cell, y: this.by + (r + 0.5) * this.cell }; }
    buildBoard() {
      this.gem = new Uint8Array(42); this.removed = new Uint8Array(42); this.dropAt = new Float32Array(42);
      if (this.scene !== 'board') return;
      const rng = makeRng(4242); for (let i = 0; i < 42; i++) this.gem[i] = Math.floor(rng() * 6);
      const k0 = 4; this.gem[this.srcCell] = k0;
      for (let i = 0; i < 42; i++) if (i !== this.srcCell && this.gem[i] === k0) this.gem[i] = (k0 + 1 + Math.floor(rng() * 5)) % 6;
      if (this.d.area.id === 'match3') { this.gem[this.srcCell - 1] = k0; this.gem[this.srcCell + 1] = k0; }
      if (this.d.area.id === 'color') { const picks = [1, 6, 9, 20, 26, 33, 38]; picks.forEach((i) => { this.gem[i] = k0; }); }
    }
    buildHits() {
      const d = this.d, area = d.area.id, u = this.unit, W = this.W, H = this.H; const hits = [];
      if (this.scene === 'board') {
        const c0 = this.srcCell % 7, r0 = (this.srcCell / 7) | 0; const add = (c, r) => { if (c < 0 || c > 6 || r < 0 || r > 5) return; const i = r * 7 + c; if (hits.some((h) => h.cell === i)) return; const p = this.cellCenter(i); hits.push({ x: p.x, y: p.y, cell: i, dist: Math.max(Math.abs(c - c0), Math.abs(r - r0)) }); };
        if (area === 'point') add(c0, r0);
        else if (area === 'match3') { add(c0, r0); add(c0 - 1, r0); add(c0 + 1, r0); }
        else if (area === 'area3') { for (let r = -1; r <= 1; r++) for (let c = -1; c <= 1; c++) add(c0 + c, r0 + r); }
        else if (area === 'row') { for (let c = 0; c < 7; c++) add(c, r0); }
        else if (area === 'cross') { add(c0, r0); for (let c = 0; c < 7; c++) add(c, r0); for (let r = 0; r < 6; r++) add(c0, r); }
        else if (area === 'cross3') { add(c0, r0); for (let k = -1; k <= 1; k++) { for (let c = 0; c < 7; c++) add(c, r0 + k); for (let r = 0; r < 6; r++) add(c0 + k, r); } }
        else if (area === 'color') { add(c0, r0); for (let i = 0; i < 42; i++) if (this.gem[i] === this.gem[this.srcCell]) add(i % 7, (i / 7) | 0); }
        else if (area === 'scatter') { add(c0, r0); const rng = makeRng(77); while (hits.length < 7) add(Math.floor(rng() * 7), Math.floor(rng() * 6)); }
        else { for (let r = 0; r < 6; r++) for (let c = 0; c < 7; c++) add(c, r); }
      } else {
        const A = this.A; const sp = u * 1.1; const maxY = this.floorY - 2; const add = (x, y, dist) => { if (x < 2 || x > W - 2 || y < 2 || y > Math.min(H - 2, maxY)) return; hits.push({ x, y, cell: -1, dist }); };
        const rng = makeRng(88);
        if (area === 'point') add(A.x, A.y, 0);
        else if (area === 'match3') { add(A.x, A.y, 0); add(A.x - sp, A.y, 1); add(A.x + sp, A.y, 1); }
        else if (area === 'area3') { for (let r = -1; r <= 1; r++) for (let c = -1; c <= 1; c++) add(A.x + c * sp, A.y + r * sp * 0.7, Math.max(Math.abs(c), Math.abs(r))); }
        else if (area === 'row') { for (let c = -3; c <= 3; c++) add(A.x + c * sp, A.y, Math.abs(c)); }
        else if (area === 'cross') { for (let c = -3; c <= 3; c++) add(A.x + c * sp, A.y, Math.abs(c)); for (let r = -3; r <= 3; r++) if (r) add(A.x, A.y + r * sp * 0.8, Math.abs(r)); }
        else if (area === 'cross3') { for (let k = -1; k <= 1; k++) { for (let c = -3; c <= 3; c++) add(A.x + c * sp, A.y + k * sp * 0.6, Math.max(Math.abs(c), Math.abs(k))); for (let r = -3; r <= 3; r++) if (Math.abs(r) > 1) add(A.x + k * sp * 0.8, A.y + r * sp * 0.7, Math.abs(r)); } }
        else if (area === 'color' || area === 'scatter') { add(A.x, A.y, 0); for (let k = 0; k < 6; k++) { const x = lerp(W * 0.38, W * 0.95, rng()), y = lerp(H * 0.22, Math.min(maxY - u * 0.4, H * 0.75), rng()); add(x, y, Math.max(1, Math.round(Math.hypot(x - A.x, y - A.y) / sp))); } }
        else { for (let r = 0; r < 3; r++) for (let c = 0; c < 6; c++) { const x = W * (0.1 + c * 0.16), y = H * 0.2 + r * (Math.min(maxY, H * 0.85) - H * 0.2) / 2.4; add(x, y, Math.max(1, Math.round(Math.hypot(x - A.x, y - A.y) / sp))); } }
        if (!hits.length) hits.push({ x: A.x, y: A.y, cell: -1, dist: 0 });
      }
      const rng = makeRng(31); const order = hits.map((_, i) => i).sort(() => rng() - 0.5);
      order.forEach((hi, k) => { hits[hi].order = k; });
      if (area !== 'scatter' && area !== 'color') hits.forEach((h) => { h.order = h.order; });
      this.hits = hits; this.maxDist = Math.max(1, ...hits.map((h) => h.dist));
    }
    hitTimes() {
      const dl = this.d.delivery.id, T = this.dur('travel'), n = this.hits.length, st = this.d.stagger;
      this.hits.forEach((h) => {
        h.fired = false; h.fireT = -1e9; h.link = 0;
        if (dl === 'sweep') h.at = (h.dist / this.maxDist) * T;
        else if (dl === 'sequence') h.at = ((h.order + 1) / (n + 1)) * T;
        else if (dl === 'bolts') { h.link = (h.order / n) * T * 0.9; h.at = T; }
        else h.at = T + h.dist * st;
      });
    }

    /* 캐릭터 포즈 */
    pose() {
      const ph = this.phase, dl = this.d.delivery.id; let r = 0, t = 0;
      if (ph === 'anticipation') r = outCubic(this.charge);
      else if (ph === 'travel' || ph === 'hitstop') { if (dl === 'aura') r = 1; else t = 1; }
      else if (ph === 'burst') { if (dl === 'aura') r = 1; else t = 1 - clamp01(this.pt / (this.dur('burst') * 0.8)); }
      else if (ph === 'afterglow' && dl === 'aura') r = 1 - clamp01(this.pt / (this.dur('afterglow') * 0.5));
      if (!this.staffUse && dl !== 'aura') { r = ph === 'anticipation' ? r * 0.4 : 0; t = 0; }
      return { r, t };
    }
    staffTip(r, t) { const p = this.staffGeom(r, t); return { x: p.tx, y: p.ty }; }
    staffGeom(r, t) {
      const s = this.unit / 15, fx = this.caster.x, fy = this.caster.y; const b = 1 - r - t;
      const pick = (i, rr, tt) => i * b + rr * r + tt * t;
      return {
        hx: fx + pick(4, 4, 8) * s, hy: fy + pick(-11, -16, -14) * s,
        bx: fx + pick(4, 3, 2) * s, by: fy + pick(0, -4, -11) * s,
        tx: fx + pick(5, 6, 17) * s, ty: fy + pick(-27, -32, -17) * s,
      };
    }
    srcPoint() { if (!this.staffUse) return this.S; const p = this.pose(); return this.staffTip(p.r, p.t); }

    /* 재생 흐름 */
    restart() {
      this.life.fill(0); this.comets.forEach((c) => { c.on = false; }); this.coins.forEach((c) => { c.done = true; c.n = 0; }); this.bolts = []; this.miniRings = [];
      this.r = makeRng(20240 + this.tier * 97); this.j = makeRng(911 + this.tier);
      this.manual = false; this.held = false; this.emberAcc = 0; this.orbitSpawned = 0; this.charge = 0; this.tt = 0; this.proj.n = 0;
      if (this.removed) this.removed.fill(0); if (this.dropAt) this.dropAt.fill(-1e9);
      this.coinCount = 0; this.hudBump = -1e9; this.targetHitAt = -1e9; this.castAt = -1e9; this.impactAt = -1e9;
      this.hitTimes(); this.makeCracks(); this.enter('idle');
    }
    play() { if (!this.d) return; this.restart(); this.enter(this.nextPhase('idle')); }
    press() {
      if (!this.d) return;
      if (this.d.s.trigger === 'hold' && this.dur('anticipation') > 0) { this.restart(); this.manual = true; this.held = true; this.enter('anticipation'); } else this.play();
    }
    dur(ph) {
      const d = this.d, st = d.stretch(this.tier);
      switch (ph) {
        case 'idle': return 450;
        case 'anticipation': return d.phases.anticipation;
        case 'travel': return d.phases.travel;
        case 'hitstop': return d.phases.hitstop * st;
        case 'burst': return Math.max(60, d.phases.burst);
        case 'afterglow': return d.phases.afterglow * st;
        case 'gap': return d.s.playback === 'loop' || d.delivery.id === 'loop' ? d.s.loopGap : 900;
        default: return 0;
      }
    }
    nextPhase(ph) {
      const order = ['idle', 'anticipation', 'travel', 'hitstop', 'burst', 'afterglow', 'gap'];
      let i = order.indexOf(ph) + 1;
      while (i < order.length && order[i] !== 'burst' && order[i] !== 'gap' && this.dur(order[i]) <= 0) i++;
      return order[i] || 'done';
    }
    enter(ph) {
      this.phase = ph; this.pt = 0;
      if (ph !== 'idle' && ph !== 'anticipation') this.charge = 1;
      if (ph === 'travel') this.onRelease();
      if (ph === 'burst') { if (this.dur('travel') <= 0) this.onRelease(); this.onImpact(); }
      if (ph === 'gap' && this.scene === 'board') { for (let i = 0; i < 42; i++) if (this.removed[i]) { this.removed[i] = 0; this.dropAt[i] = this.tick + (5 - ((i / 7) | 0)) * 25; } }
    }
    next() { const n = this.nextPhase(this.phase); if (n === 'done') { if (this.auto) this.restart(); else this.phase = 'done'; } else this.enter(n); }

    spawn(kind, x, y, vx, vy, life, size, col, vr) {
      let i = this.cur, tries = 0;
      while (this.life[i] > 0 && tries < MAXP) { i = (i + 1) % MAXP; tries++; }
      if (tries >= MAXP) return -1; this.cur = (i + 1) % MAXP;
      this.kind[i] = kind; this.x[i] = x; this.y[i] = y; this.vx[i] = vx; this.vy[i] = vy; this.life[i] = life; this.max[i] = life;
      this.size[i] = size; this.col[i] = col; this.vr[i] = vr || 0; this.rot[i] = this.r() * TAU; this.a1[i] = 0; this.a2[i] = 0; return i;
    }
    sparkBurst(x, y, n, speedMul, col) {
      const u = this.unit, px = this.d.pixel;
      for (let k = 0; k < n; k++) {
        const a = this.r() * TAU, sp = u * (1.5 + 2 * this.r()) * (speedMul || 1);
        const c = col !== undefined ? col : (this.r() < 0.7 ? this.tier - 1 : Math.floor(this.r() * this.tier));
        this.spawn(K_SPARK, x, y, Math.cos(a) * sp, Math.sin(a) * sp - (this.scene === 'stage' && !this.topdown ? u * 0.6 : 0), 0.4 + 0.4 * this.r(), px ? (this.r() < 0.3 ? 2 : 1) : u * (0.04 + 0.05 * this.r()), c, 0);
      }
    }
    makeCracks() {
      this.cracks = []; const rng = makeRng(505);
      for (let b = 0; b < 4; b++) {
        const pts = [0, 0]; let a = (b / 4) * TAU + rng() * 0.8; const seg = 4 + Math.floor(rng() * 3);
        for (let k = 0; k < seg; k++) { a += (rng() - 0.5) * 1.1; const l = 0.22 + rng() * 0.15; pts.push(pts[pts.length - 2] + Math.cos(a) * l, pts[pts.length - 1] + Math.sin(a) * l); }
        this.cracks.push(pts);
      }
    }
    zig(x0, y0, x1, y1, segs, amp) {
      const p = [x0, y0]; const dx = x1 - x0, dy = y1 - y0, L = Math.hypot(dx, dy) || 1, nx = -dy / L, ny = dx / L;
      for (let k = 1; k < segs; k++) { const t = k / segs, o = (this.j() - 0.5) * 2 * amp; p.push(x0 + dx * t + nx * o, y0 + dy * t + ny * o); }
      p.push(x1, y1); return p;
    }
    makeBolts() {
      const n = this.counts().bolts, u = this.unit, A = this.A; this.bolts = [];
      for (let b = 0; b < n; b++) { const a = this.j() * TAU, L = u * 1.2 * (0.7 + this.j() * 0.5); this.bolts.push(this.zig(A.x, A.y, A.x + Math.cos(a) * L, A.y + Math.sin(a) * L, 6, u * 0.18)); }
    }
    onRelease() {
      this.castAt = this.tick; const S = this.srcPoint(), u = this.unit;
      if (this.on('sparks') && this.d.delivery.id !== 'self') this.sparkBurst(S.x, S.y, Math.max(3, Math.round(this.counts().sparks * 0.15)), 0.6);
      for (let i = 0; i < MAXP; i++) if (this.kind[i] === K_ORBIT) this.life[i] = 0;
      this.proj.n = 0; this.proj.x = S.x; this.proj.y = S.y;
      if (this.d.delivery.id === 'collect') {
        const n = this.counts().coins, T = this.dur('travel');
        for (let k = 0; k < this.coins.length; k++) {
          const c = this.coins[k]; c.done = k >= n; c.n = 0; if (c.done) continue;
          c.t0 = (k / Math.max(1, n)) * T * 0.45; c.dur = T * 0.55; c.sx = this.S.x + (this.r() - 0.5) * u * 0.4; c.sy = this.S.y;
          c.cx = this.S.x + (this.r() - 0.3) * u * 3; c.cy = this.S.y - u * (1.6 + this.r() * 1.4);
        }
      }
    }
    onImpact() {
      this.impactAt = this.tick; const c = this.counts(), u = this.unit, A = this.A, px = this.d.pixel;
      if (this.d.delivery.id !== 'bolts' && this.d.delivery.id !== 'sweep' && this.d.delivery.id !== 'sequence' && this.on('sparks') && this.hits.length === 1) { /* 단일 hit는 fire에서 처리 */ }
      for (let k = 0; k < c.confetti; k++) { const a = -Math.PI / 2 + (this.r() - 0.5) * 1.8, sp = u * (3 + 2.4 * this.r()); this.spawn(K_CONF, A.x, A.y - u * 0.3, Math.cos(a) * sp, Math.sin(a) * sp, 1.6 + this.r(), px ? 2 : u * (0.1 + 0.06 * this.r()), Math.floor(this.r() * 4), (3 + this.r() * 6) * (this.r() < 0.5 ? -1 : 1)); }
      for (let k = 0; k < this.comets.length; k++) {
        const m = this.comets[k]; m.on = k < c.comets; if (!m.on) continue;
        const a = -Math.PI / 2 + (k - (c.comets - 1) / 2) * 0.75 + (this.r() - 0.5) * 0.3, sp = u * (3.5 + 1.5 * this.r());
        m.x = A.x; m.y = A.y; m.vx = Math.cos(a) * sp; m.vy = Math.sin(a) * sp; m.life = 0.7; m.n = 0; m.t = 0;
      }
      if (this.d.delivery.id === 'collect') this.hudBump = this.tick;
      if (this.d.delivery.id === 'sequence' || this.d.delivery.id === 'loop') { if (this.on('sparks')) this.sparkBurst(A.x, A.y, Math.round(c.sparks * 0.4)); }
      this.boltT = 0; this.makeBolts();
    }
    fire(h) {
      h.fired = true; h.fireT = this.tt; const c = this.counts(), n = this.hits.length, u = this.unit, px = this.d.pixel;
      if (this.d.delivery.id === 'collect') return;
      if (this.d.delivery.id === 'loop') { if (this.on('sparks') && this.r() < 0.35) this.sparkBurst(h.x, h.y, 1, 0.4); return; }
      if (this.on('sparks')) this.sparkBurst(h.x, h.y, Math.max(1, Math.round(c.sparks / n)));
      const shardCol = h.cell >= 0 ? 20 + this.gem[h.cell] : 9;
      const ns = this.on('shards') ? Math.max(1, Math.round(c.shards / n)) : 0;
      for (let k = 0; k < ns; k++) {
        const a = this.r() * TAU, sp = u * (0.8 + 1.2 * this.r());
        this.spawn(K_SHARD, h.x + Math.cos(a) * u * 0.15, h.y + Math.sin(a) * u * 0.15, Math.cos(a) * sp, Math.sin(a) * sp - u * 1.2, 0.7 + 0.4 * this.r(), px ? 2 + Math.floor(this.r() * 2) : u * (0.12 + 0.1 * this.r()), shardCol, (this.r() - 0.5) * 4 * TAU);
      }
      if (this.on('smoke') && c.smoke) { const every = Math.max(1, Math.round(n / c.smoke)); const k = h.order % every === 0 ? Math.max(1, Math.round(c.smoke / n)) : 0; for (let m = 0; m < k; m++) this.spawn(K_SMOKE, h.x + (this.r() - 0.5) * u * 0.5, h.y + (this.r() - 0.2) * u * 0.3, (this.r() - 0.5) * u * 0.4, -u * (0.2 + 0.3 * this.r()), 0.7 + 0.3 * this.r(), u * 0.3, 9, 0); }
      if (h.cell >= 0) this.removed[h.cell] = 1;
      if (this.scene === 'stage' && Math.hypot(h.x - this.A.x, h.y - this.A.y) < 1) this.targetHitAt = this.tick;
      if (this.d.delivery.id === 'sequence' || (this.d.delivery.id === 'sweep' && this.on('ring'))) this.miniRings.push({ x: h.x, y: h.y, t: this.tick });
    }
    fireHits(strict) { for (const h of this.hits) if (!h.fired && (strict ? h.at < this.tt : h.at <= this.tt)) this.fire(h); }

    update(dtReal) {
      if (!this.d) return;
      let dt = dtReal * this.speed;
      if (this.phase === 'burst' && this.on('slowmo') && this.pt < this.dur('burst') * 0.45) dt *= 0.35;
      const sec = dt / 1000; this.tick += dt; const dl = this.d.delivery.id; const T = this.dur('travel'), B = this.dur('burst');
      switch (this.phase) {
        case 'idle': this.pt += dt; if (this.auto && !this.manual && this.pt >= this.dur('idle')) this.next(); break;
        case 'anticipation': {
          const A = this.dur('anticipation');
          if (this.manual) { if (this.held) this.pt += dt; this.charge = clamp01(this.pt / A); if (this.charge >= 1 || !this.held) { this.next(); break; } }
          else { this.pt += dt; this.charge = clamp01(this.pt / A); if (this.pt >= A) { this.next(); break; } }
          const want = this.counts().orbit * Math.min(1, this.charge / 0.8); const S = this.srcPoint();
          while (this.orbitSpawned < want) {
            this.orbitSpawned++; const i = this.spawn(K_ORBIT, S.x, S.y, 0, 0, 6, this.d.pixel ? 1 : this.unit * (0.05 + 0.04 * this.r()), this.tier - 1, 0.8 + 0.4 * this.r());
            if (i >= 0) { this.a1[i] = this.r() * TAU; this.a2[i] = this.unit * 1.1 * (0.8 + 0.4 * this.r()); }
          }
          break;
        }
        case 'travel': {
          this.pt += dt; this.tt = this.pt; this.fireHits(true);
          if (dl === 'beam' && this.on('sparks') && this.r() < 0.5) this.sparkBurst(this.A.x, this.A.y, 1, 0.6);
          if (dl === 'projectile') {
            const S = this.srcPoint(); const p = clamp01(this.pt / T); const e = this.d.s.easing === 'smooth' ? p * p * (3 - 2 * p) : p;
            this.proj.x = lerp(S.x, this.A.x, e); this.proj.y = lerp(S.y, this.A.y, e) - Math.sin(p * Math.PI) * this.unit * 0.3;
            this.proj.t += dt; if (this.proj.t >= 16) { this.proj.t = 0; for (let h = 7; h > 0; h--) { this.proj.hx[h] = this.proj.hx[h - 1]; this.proj.hy[h] = this.proj.hy[h - 1]; } this.proj.hx[0] = this.proj.x; this.proj.hy[0] = this.proj.y; this.proj.n = Math.min(8, this.proj.n + 1); }
          }
          if (dl === 'collect') this.coinTick();
          if (this.pt >= T) { this.tt = T; this.fireHits(true); this.next(); }
          break;
        }
        case 'hitstop': this.pt += dt; if (this.pt >= this.dur('hitstop')) this.next(); return;
        case 'burst':
          this.pt += dt; this.tt = T + this.pt; this.fireHits(); this.boltT += dt;
          if (this.boltT >= 60) { this.boltT = 0; this.makeBolts(); }
          if (dl === 'aura' || dl === 'loop') this.auraTick(sec);
          if (this.pt >= B) this.next();
          break;
        case 'afterglow':
          this.pt += dt; this.tt = T + B + this.pt; this.fireHits();
          if (this.on('embers')) { this.emberAcc += sec * this.d.emberRate * (1 + 0.3 * (this.tier - 1)); while (this.emberAcc >= 1) { this.emberAcc -= 1; this.spawnEmber(); } }
          if (dl === 'aura') this.auraTick(sec * 0.5);
          if (this.pt >= this.dur('afterglow')) this.next();
          break;
        case 'gap': this.pt += dt; if (this.pt >= this.dur('gap')) this.next(); break;
        default: break;
      }
      if (dl === 'loop' && this.on('embers') && this.phase !== 'afterglow') { this.emberAcc += sec * this.d.emberRate * 0.7; while (this.emberAcc >= 1) { this.emberAcc -= 1; this.spawnEmber(); } }
      this.sim(sec);
    }
    coinTick() {
      const u = this.unit;
      for (const c of this.coins) {
        if (c.done) continue; const p = (this.pt - c.t0) / c.dur; if (p < 0) continue;
        if (p >= 1) { c.done = true; this.coinCount += 1; this.hudBump = this.tick; if (this.on('sparks')) this.sparkBurst(this.dest.x - u * 0.8, this.dest.y, 2, 0.5, 0); continue; }
        const e = p * p * (3 - 2 * p); const ix = lerp(lerp(c.sx, c.cx, e), lerp(c.cx, this.dest.x - u * 0.8, e), e), iy = lerp(lerp(c.sy, c.cy, e), lerp(c.cy, this.dest.y, e), e);
        for (let h = 5; h > 0; h--) { c.hx[h] = c.hx[h - 1]; c.hy[h] = c.hy[h - 1]; } c.hx[0] = ix; c.hy[0] = iy; c.n = Math.min(6, c.n + 1);
      }
    }
    auraTick(sec) {
      const u = this.unit, A = this.A; this.emberAcc += sec * (10 + 6 * this.tier);
      while (this.emberAcc >= 1) { this.emberAcc -= 1; const a = this.r() * TAU, rr = u * (0.3 + 0.6 * this.r()); this.spawn(K_EMBER, A.x + Math.cos(a) * rr, (this.scene === 'stage' && !this.topdown ? this.caster.y : A.y + u * 0.5) - this.r() * u * 0.4, (this.r() - 0.5) * u * 0.1, -u * (0.8 + this.r() * 0.9), 0.9 + this.r() * 0.5, this.d.pixel ? 1 : u * (0.04 + 0.04 * this.r()), Math.floor(this.r() * this.tier), 0); }
    }
    spawnEmber() {
      const u = this.unit, W = this.W, H = this.H; let x, y;
      if (this.d.delivery.id === 'loop') {
        if (this.scene === 'board') { const edge = Math.floor(this.r() * 2); x = edge ? this.bx + this.r() * this.cell * 7 : (this.r() < 0.5 ? this.bx : this.bx + this.cell * 7); y = edge ? this.by + this.cell * 6 : this.by + this.r() * this.cell * 6; }
        else { x = this.r() * W; y = H * (0.3 + 0.6 * this.r()); }
      } else { x = this.A.x + (this.r() - 0.5) * u * 2; y = this.A.y + (this.r() - 0.2) * u; }
      this.spawn(K_EMBER, x, y, (this.r() - 0.5) * u * 0.1, -u * 0.4 * (0.7 + 0.6 * this.r()), 1.2 + this.r() * 0.4, this.d.pixel ? 1 : u * (0.03 + 0.04 * this.r()), this.tier - 1, 0);
    }
    sim(sec) {
      const u = this.unit, side = this.scene === 'stage' && !this.topdown, noGrav = this.topdown || this.scene === 'ui';
      for (let i = 0; i < MAXP; i++) {
        if (this.life[i] <= 0) continue; this.life[i] -= sec; const k = this.kind[i];
        if (k === K_ORBIT) {
          const S = this.srcPoint(); const ch = this.charge; this.a1[i] += TAU * (1 + 3 * ch) * this.vr[i] * sec; this.a2[i] -= u * (0.3 + 1.8 * ch * ch) * sec;
          if (this.a2[i] <= u * 0.12) { this.life[i] = 0; continue; }
          this.x[i] = S.x + Math.cos(this.a1[i]) * this.a2[i]; this.y[i] = S.y + Math.sin(this.a1[i]) * this.a2[i] * 0.85; continue;
        }
        const drag = k === K_SPARK ? 3 : k === K_CONF ? 1.7 : k === K_SHARD ? (noGrav ? 2.5 : 0.6) : k === K_SMOKE ? 1.2 : 0;
        const grav = noGrav ? 0 : k === K_SHARD ? u * 3 : k === K_CONF ? u * 2.2 : k === K_SPARK ? u * 0.5 : 0;
        const f = Math.max(0, 1 - drag * sec); this.vx[i] *= f; this.vy[i] = this.vy[i] * f + grav * sec;
        if (k === K_CONF) this.vx[i] += Math.sin(this.tick * 0.004 + i) * u * 1.2 * sec;
        if (k === K_EMBER) this.vx[i] += Math.sin(this.tick * 0.002 + i * 1.7) * u * 0.15 * sec;
        this.x[i] += this.vx[i] * sec; this.y[i] += this.vy[i] * sec; this.rot[i] += this.vr[i] * sec;
        if (side && (k === K_SHARD || k === K_SPARK || k === K_CONF) && this.y[i] > this.floorY - 1) { this.y[i] = this.floorY - 1; this.vy[i] *= -0.35; this.vx[i] *= 0.6; this.vr[i] *= 0.5; }
      }
      for (const m of this.comets) {
        if (!m.on) continue; m.life -= sec; if (m.life <= -0.3) { m.on = false; continue; }
        if (m.life > 0) { m.t += sec; m.vx *= 1 - 0.8 * sec; m.vy *= 1 - 0.8 * sec; m.x += m.vx * sec; m.y += m.vy * sec; if (m.t >= 0.02) { m.t = 0; for (let h = 7; h > 0; h--) { m.hx[h] = m.hx[h - 1]; m.hy[h] = m.hy[h - 1]; } m.hx[0] = m.x; m.hy[0] = m.y; m.n = Math.min(8, m.n + 1); } }
        else if (m.n > 0 && (m.t += sec) >= 0.03) { m.t = 0; m.n--; }
      }
    }

    /* 루프와 진행 표시 */
    loop(now) {
      requestAnimationFrame(this.loop);
      if (!this.d) return;
      if (!this.last) this.last = now;
      const dt = Math.min(100, now - this.last); this.last = now;
      if (document.hidden) return;
      this.acc += dt; let steps = 0;
      while (this.acc >= STEP && steps < 6) { this.update(STEP); this.acc -= STEP; steps++; }
      if (steps >= 6) this.acc = 0;
      const grid = this.d.pixel ? this.d.s.pixelFps : (this.d.s.easing === 'stepped' ? 12 : 60);
      this.drawAcc += dt;
      if (this.dirty || grid >= 60 || this.drawAcc >= 1000 / grid) { this.drawAcc = grid >= 60 ? 0 : this.drawAcc % (1000 / grid); this.dirty = false; this.draw(); this.emitPhase(); }
    }
    emitPhase() {
      const names = ['anticipation', 'travel', 'hitstop', 'burst', 'afterglow'];
      const durs = names.map((n) => this.dur(n)); let pos = -1; const idx = names.indexOf(this.phase);
      if (idx >= 0) { pos = 0; for (let i = 0; i < idx; i++) pos += durs[i]; pos += Math.min(this.pt, durs[idx]); }
      else if (this.phase === 'gap' || this.phase === 'done') pos = durs.reduce((a, b) => a + b, 0);
      this.onPhase({ phase: this.phase, pos, durs, manual: this.manual, charge: this.charge });
    }
    sinceImpact() { return this.phase === 'burst' ? this.pt : this.phase === 'afterglow' ? this.dur('burst') + this.pt : this.phase === 'gap' || this.phase === 'done' ? 1e9 : -1; }
    glowEnv() {
      switch (this.phase) {
        case 'anticipation': return 0.25 + 0.5 * this.charge;
        case 'travel': return 0.6;
        case 'hitstop': return 1;
        case 'burst': return 1 - 0.5 * clamp01(this.pt / this.dur('burst'));
        case 'afterglow': return 0.5 * (1 - clamp01(this.pt / this.dur('afterglow')));
        default: return this.d.delivery.id === 'loop' ? 0.3 : 0;
      }
    }

    /* 그리기 */
    draw() {
      const d = this.d, C = this.C, pixel = d.pixel; const G = pixel ? this.pg : this.sg;
      if (pixel) { if (this.buf.width !== this.W || this.buf.height !== this.H) { this.buf.width = this.W; this.buf.height = this.H; } G.begin(this.W, this.H); }
      else G.begin(this.W, this.H, this.cv.width, this.cv.height);
      let z = 1, sx = 0, sy = 0; const ti = this.sinceImpact(); const u = this.unit;
      if (ti >= 0 && ti < 1e8) {
        if (this.on('shake')) { const amp = (pixel ? d.shakePx : u * d.shakeUnit) * (1 + 0.25 * (this.tier - 1)); const k = 1 - clamp01(ti / 300); if (k > 0) { sx = (this.j() * 2 - 1) * amp * k; sy = (this.j() * 2 - 1) * amp * k; } }
        if (this.on('zoom')) z = 1 + (d.zoom + 0.01 * (this.tier - 1) - 1) * (1 - outCubic(clamp01(ti / 250)));
      } else if (this.phase === 'anticipation' && d.s.trigger === 'hold' && this.on('shake')) { const amp = (pixel ? 1 : u * 0.03) * this.charge * this.charge; sx = (this.j() * 2 - 1) * amp; sy = (this.j() * 2 - 1) * amp; }
      G.cam.x = sx; G.cam.y = sy; G.cam.z = z;
      if (this.phase === 'hitstop' && this.on('invert')) { this.drawInvert(G); this.present(); return; }
      G.clear(C.bg); G.world();
      this.drawScene(G, null);
      if (this.on('pulse')) this.drawPulse(G);
      if (this.on('runes')) this.drawRunes(G);
      if (this.on('cracks')) this.drawCracks(G);
      if (this.on('glow')) this.drawGlow(G);
      if (this.on('rays')) this.drawRays(G);
      this.drawActors(G);
      this.drawDelivery(G);
      this.drawParticles(G);
      this.drawComets(G);
      if (this.on('ring')) this.drawRings(G);
      if (this.on('lightning')) this.drawBolts(G);
      if (this.on('flash') && !d.fullFlash) this.drawLocalFlash(G);
      if (this.on('textPop')) this.drawText(G);
      G.screen();
      if (this.on('flash') && d.fullFlash) this.drawFullFlash(G);
      if (this.on('vignette')) this.drawVignette(G);
      this.present();
    }
    present() {
      if (!this.d.pixel) return;
      const c = this.ctx, cw = this.cv.width, ch = this.cv.height, W = this.W, H = this.H;
      const sc = Math.max(1, Math.floor(Math.min(cw / W, ch / H))); const ox = Math.floor((cw - W * sc) / 2), oy = Math.floor((ch - H * sc) / 2);
      c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over'; c.imageSmoothingEnabled = false;
      c.fillStyle = mix(this.C.bg, '#000000', 0.5); c.fillRect(0, 0, cw, ch); c.drawImage(this.buf, 0, 0, W, H, ox, oy, W * sc, H * sc);
    }

    /* 장면 */
    drawScene(G, mono) { if (this.scene === 'board') this.drawBoard(G, mono); else if (this.scene === 'ui') this.drawUI(G, mono); else this.drawStage(G, mono); }
    drawStage(G, mono) {
      const W = this.W, H = this.H, C = this.C, u = this.unit, px = this.d.pixel;
      if (mono) return;
      if (this.topdown) {
        const t = Math.max(4, Math.round(u * 1.1));
        for (let y = 0; y < H; y += t) for (let x = 0; x < W; x += t) G.rect(x, y, t, t, ((x / t + y / t) & 1) ? CH.stoneDark : mix(CH.stoneDark, CH.stone, 0.5), 1, false);
        return;
      }
      const bands = 8; const top = mix(C.bg, '#000000', 0.35), mid = C.bg, low = mix(C.bg, C.body, 0.55);
      for (let k = 0; k < bands; k++) { const t = k / (bands - 1); const col = t < 0.5 ? mix(top, mid, t * 2) : mix(mid, low, (t - 0.5) * 2); const y0 = Math.floor((this.floorY * k) / bands), y1 = Math.floor((this.floorY * (k + 1)) / bands); G.rect(-8, y0 - (k ? 0 : 8), W + 16, y1 - y0 + 1 + (k ? 0 : 8), col, 1, false); }
      const rng = makeRng(12); for (let s = 0; s < 16; s++) { const x = rng() * W, y = rng() * this.floorY * 0.7; const tw = 0.5 + 0.5 * Math.sin(this.tick * 0.003 + s * 1.9); G.dot(x, y, px ? 1 : 1.4, C.hi, 0.35 + 0.65 * tw, false); }
      const mr = Math.max(3, u * 0.55); G.disk(W * 0.84, H * 0.17, mr, CH.moon, 1, false); G.disk(W * 0.84 - mr * 0.3, H * 0.17 - mr * 0.1, mr * 0.22, mix(CH.moon, '#9a927a', 0.5), 0.8, false); G.disk(W * 0.84 + mr * 0.3, H * 0.17 + mr * 0.35, mr * 0.15, mix(CH.moon, '#9a927a', 0.5), 0.8, false);
      const fy = this.floorY; G.rect(-8, fy, W + 16, H - fy + 8, CH.stone, 1, false); G.rect(-8, fy, W + 16, px ? 1 : 1.5, CH.stoneHi, 1, false);
      const rowH = Math.max(3, Math.round((H - fy) / 2)); const bw = Math.max(6, Math.round(u * 1.4));
      for (let r = 0; r * rowH < H - fy; r++) { const y = fy + r * rowH; G.rect(0, y + rowH - 1, W, px ? 1 : 1.2, CH.stoneDark, 1, false); for (let x = (r % 2) * (bw >> 1); x < W; x += bw) G.rect(x, y + 1, px ? 1 : 1.2, rowH - 1, CH.stoneDark, 1, false); }
    }
    showCaster() { return this.scene === 'stage' && this.d.delivery.id !== 'collect'; }
    showFoe() { return this.scene === 'stage' && !['aura', 'loop', 'collect'].includes(this.d.delivery.id); }
    drawActors(G, mono) {
      if (this.scene !== 'stage') return;
      if (this.showCaster()) this.drawWizard(G, mono);
      if (this.showFoe()) {
        const flash = !mono && this.tick - this.targetHitAt < 70; let kb = 0, sq = 0;
        if (this.on('squash') && this.targetHitAt > -1e8) { const t = clamp01((this.tick - this.targetHitAt) / 450); kb = (1 - spring(t)) * this.unit * 0.35; sq = (1 - spring(t)) * 0.25; }
        this.drawSlime(G, this.foe.x + kb, this.foe.y, 1, mono, flash, sq);
        if (this.d.area.id === 'color') this.hits.forEach((h, i) => { if (i === 0 || h.fired) return; this.drawSlime(G, h.x, h.y + this.unit * 0.3, 0.55, mono, false, 0); });
      }
    }
    drawWizard(G, mono) {
      const s = this.unit / 15, fx = this.caster.x, fy = this.caster.y, C = this.C, px = this.d.pixel; const ink = mono || CH.ink;
      const bob = this.phase === 'idle' || this.phase === 'gap' || this.phase === 'done' ? (Math.floor(this.tick / 400) % 2) * (px ? 1 : s * 0.8) : 0;
      const p = this.pose(); const g = this.staffGeom(p.r, p.t);
      const sway = Math.sin(this.tick * 0.004) * s * 0.6; const P = (arr) => arr.map((v, i) => (i % 2 ? fy + (v + (v < -2 ? 0 : 0)) * s + (v < -1 ? bob : 0) : fx + v * s + (i % 2 === 0 && arr[i + 1] > -3 ? sway * 0.3 : 0)));
      const rim = this.on('rim') ? (this.phase === 'anticipation' ? this.charge : this.phase === 'travel' || this.phase === 'hitstop' ? 1 : this.phase === 'burst' ? 1 - clamp01(this.pt / this.dur('burst')) : 0) : 0;
      const outline = mono ? null : px ? (rim > 0.45 ? this.accent() : ink) : ink; const ow = px ? 1 : s * 0.9;
      G.line(g.bx, g.by, g.tx, g.ty, px ? 1 : s * 1.1, mono || CH.staff, 1, false);
      G.poly(P([-6.5, 0, 6.5, 0, 3.4, -14, -3.4, -14]), mono || CH.robeDark, 1, false, outline, ow);
      if (!mono) { G.poly(P([-6.5, 0, 0.5, 0, 0.5, -14, -3.4, -14]), CH.robe, 1, false); G.rect(fx - 6.5 * s, fy - 2 * s, 13 * s, 1.6 * s, CH.trim, 1, false); }
      G.rect(fx - 2 * s, fy - 19 * s + bob, 4.5 * s, 3.2 * s, mono || CH.skin, 1, false);
      G.poly(P([-3.2, -16.2, 3.6, -16.2, 0.4, -8.5]), mono || CH.beard, 1, false, outline, ow);
      G.poly(P([-5, -19, 5, -19, 1.8, -24.5, 5.5, -28.5, -0.6, -25.6]), mono || CH.robeDark, 1, false, outline, ow);
      if (!mono) { G.poly(P([-5, -19, 0.2, -19, -0.2, -25.2, -0.6, -25.6]), CH.robe, 1, false); G.rect(fx - 4.4 * s, fy - 20.4 * s + bob, 8.8 * s, 1.4 * s, CH.trim, 1, false); }
      G.line(fx + 1.5 * s, fy - 13 * s + bob, g.hx, g.hy, px ? 1 : s * 1.6, mono || CH.robe, 1, false);
      const gemA = mono ? 1 : 0.7 + 0.3 * Math.max(rim, this.phase === 'anticipation' ? this.charge : 0);
      G.disk(g.tx, g.ty, Math.max(1, s * 1.5), mono || this.accent(), gemA, false);
      if (!mono && rim > 0 && !px) G.poly(P([-6.5, 0, 6.5, 0, 3.4, -14, -3.4, -14]), this.accent(), rim * 0.8, true, this.accent(), s * 0.7, true);
    }
    drawSlime(G, x, feet, sc, mono, flash, sq) {
      const u = this.unit * sc, px = this.d.pixel; const w = u * 0.7 * (1 + sq), h = u * 0.85 * (1 - sq * 0.8); const p = [];
      for (let i = 0; i <= 10; i++) { const a = Math.PI + (i / 10) * Math.PI; p.push(x + Math.cos(a) * w, feet - 0.5 - Math.sin(-a) * h * (i === 0 || i === 10 ? 0.15 : 1)); }
      p.push(x + w * 0.9, feet - 0.5, x - w * 0.9, feet - 0.5);
      const body = mono || (flash ? '#ffffff' : CH.slime);
      if (this.topdown && !mono) G.ellipse(x, feet, w, w * 0.35, '#000000', 0.35, false);
      G.poly(p, body, 1, false, mono ? null : px ? CH.slimeDark : CH.slimeDark, px ? 1 : u * 0.05);
      if (!mono && !flash) { G.disk(x - w * 0.35, feet - h * 0.62, Math.max(1, u * 0.09), CH.slimeHi, 0.9, false); G.dot(x - w * 0.2, feet - h * 0.4, px ? 1 : u * 0.08, CH.ink, 1, false); G.dot(x + w * 0.25, feet - h * 0.4, px ? 1 : u * 0.08, CH.ink, 1, false); }
    }
    gemPoly(kind, x, y, r) {
      const p = []; const add = (a, rr) => p.push(x + Math.cos(a) * r * rr, y + Math.sin(a) * r * rr);
      if (kind === 0) { for (let i = 0; i < 4; i++) add(Math.PI / 4 + (i * Math.PI) / 2, 1.05); }
      else if (kind === 1) { for (let i = 0; i < 6; i++) add((i * Math.PI) / 3, 1); }
      else if (kind === 2) { add(-Math.PI / 2, 1.1); add(0, 0.8); add(Math.PI / 2, 1.1); add(Math.PI, 0.8); }
      else if (kind === 3) { for (let i = 0; i < 10; i++) add((i * TAU) / 10, 0.95); }
      else if (kind === 4) { add(-Math.PI / 2, 1.1); add(Math.PI / 6, 1); add((5 * Math.PI) / 6, 1); }
      else { for (let i = 0; i < 10; i++) add(-Math.PI / 2 + (i * Math.PI) / 5, i % 2 ? 0.5 : 1.05); }
      return p;
    }
    drawBoard(G, mono) {
      const C = this.C, px = this.d.pixel, cell = this.cell, bx = this.bx, by = this.by;
      if (!mono) {
        G.rect(bx - 2, by - 2, cell * 7 + 4, cell * 6 + 4, mix(C.bg, '#000000', 0.4), 1, false);
        for (let r = 0; r < 6; r++) for (let c = 0; c < 7; c++) G.rect(bx + c * cell, by + r * cell, cell, cell, mix(C.bg, '#ffffff', (r + c) & 1 ? 0.05 : 0.09), 1, false);
      }
      const special = this.d.e.group === 'puzzle' && ['self', 'sweep', 'bolts', 'sequence'].includes(this.d.delivery.id);
      for (let i = 0; i < 42; i++) {
        if (this.removed[i]) continue; const cc = this.cellCenter(i); let dy = 0;
        const since = this.tick - this.dropAt[i]; if (since < 0) continue; if (since < 420) { const t = since / 420; dy = -(1 - (t < 0.7 ? (t / 0.7) * (t / 0.7) : 1 - Math.sin(((t - 0.7) / 0.3) * Math.PI) * 0.12)) * cell * 2.5; }
        let sc = 1; if (i === this.srcCell && this.on('squash') && this.phase === 'anticipation') sc = 1 + 0.15 * this.charge;
        const r = cell * 0.36 * sc; const col = GEMS[this.gem[i]]; const p = this.gemPoly(this.gem[i], cc.x, cc.y + dy, r);
        if (mono) { G.poly(p, mono, 1, false); continue; }
        G.poly(p, col, 1, false, mix(col, '#000000', 0.55), px ? 1 : cell * 0.04);
        G.disk(cc.x - r * 0.3, cc.y + dy - r * 0.32, Math.max(1, r * 0.22), mix(col, '#ffffff', 0.65), 0.9, false);
        if (i === this.srcCell && special) {
          const pulse = this.phase === 'anticipation' ? this.charge : 0.4 + 0.3 * Math.sin(this.tick * 0.008);
          const star = this.gemPoly(5, cc.x, cc.y + dy, r * 0.45); G.poly(star, '#ffffff', 0.7 + 0.3 * pulse, false);
          G.ring(cc.x, cc.y + dy, cell * 0.47, px ? 1 : cell * 0.05, this.accent(), 0.5 + 0.5 * pulse, !px);
        }
      }
      if (!mono && this.on('rim') && this.d.delivery.id === 'loop') { const a = this.glowEnv() + 0.2 * Math.sin(this.tick * 0.012); const w = px ? 1 : cell * 0.08; G.rect(bx - 2, by - 2, cell * 7 + 4, w, this.accent(), a, !px); G.rect(bx - 2, by + cell * 6 + 2 - w, cell * 7 + 4, w, this.accent(), a, !px); G.rect(bx - 2, by - 2, w, cell * 6 + 4, this.accent(), a, !px); G.rect(bx + cell * 7 + 2 - w, by - 2, w, cell * 6 + 4, this.accent(), a, !px); }
    }
    drawUI(G, mono) {
      const C = this.C, u = this.unit, px = this.d.pixel, W = this.W, H = this.H;
      if (!mono) { G.rect(0, 0, W, H, mix(C.bg, '#000000', 0.1), 1, false); G.rect(W * 0.06, H * 0.26, W * 0.88, H * 0.64, mix(C.bg, '#ffffff', 0.05), 1, false); }
      const bump = clamp01((this.tick - this.hudBump) / 260); const bs = 1 + (1 - spring(bump)) * 0.25 * (this.hudBump > -1e8 ? 1 : 0);
      const hx = this.hud.x, hy = this.hud.y, hw = u * 2.3 * bs, hh = u * 0.8 * bs;
      G.rect(hx - hw / 2, hy - hh / 2, hw, hh, mono || mix(C.bg, '#000000', 0.5), 1, false);
      if (!mono) { G.poly([hx - hw / 2, hy - hh / 2, hx + hw / 2, hy - hh / 2, hx + hw / 2, hy + hh / 2, hx - hw / 2, hy + hh / 2], C.hi, 0.25, false, null, 0, true); G.disk(hx - hw / 2 + hh * 0.5, hy, hh * 0.32, CH.gold, 1, false); G.text(String(this.coinCount), hx + hh * 0.3, hy, hh * 0.6, C.hi, 1, null); }
      const cx = this.chest.x, cy = this.chest.y, cw = u * 1.5, chh = u * 1.0; let lid = 0;
      if (this.castAt > -1e8 && this.on('squash')) lid = (1 - spring(clamp01((this.tick - this.castAt) / 400))) * 0.25;
      G.rect(cx - cw / 2, cy - chh * 0.55, cw, chh * 0.55, mono || CH.chest, 1, false);
      G.rect(cx - cw / 2 * (1 + lid), cy - chh * (1.0 + lid), cw * (1 + lid), chh * 0.42, mono || CH.chestDark, 1, false);
      if (!mono) { G.rect(cx - u * 0.1, cy - chh * 0.62, u * 0.2, u * 0.28, CH.gold, 1, false); G.rect(cx - cw / 2, cy - chh * 0.58, cw, px ? 1 : u * 0.05, CH.gold, 1, false); }
    }

    /* 효과 요소 */
    drawPulse(G) {
      const dl = this.d.delivery.id; let a;
      if (dl === 'loop') { const period = 500 / (1 + 0.2 * (this.tier - 1)); a = (0.1 + 0.12 * (0.5 + 0.5 * Math.sin((this.tick / period) * TAU))) * (0.5 + this.glowEnv()); }
      else { const ti = this.sinceImpact(); a = this.phase === 'anticipation' ? 0.12 * this.charge * (0.6 + 0.4 * Math.sin(this.tick * 0.03)) : ti >= 0 && ti < 1e8 ? 0.25 * (1 - clamp01(ti / 300)) : 0; }
      if (a <= 0.01) return;
      if (this.scene === 'board') G.rect(this.bx, this.by, this.cell * 7, this.cell * 6, this.accent(), a, !this.d.pixel); else G.rect(-4, -4, this.W + 8, this.H + 8, this.accent(), a, !this.d.pixel);
    }
    runeCenter() {
      const dl = this.d.delivery.id; const u = this.unit;
      if (this.scene === 'board') return { x: dl === 'sky' ? this.A.x : this.S.x > this.W ? this.A.x : this.A.x, y: this.A.y, sy: 1, r: this.cell * 0.85 };
      if (this.scene === 'ui') return { x: this.A.x, y: this.chest.y, sy: 0.35, r: u * 1.1 };
      const feet = dl === 'sky' || dl === 'self' || dl === 'sweep' || dl === 'sequence' || dl === 'melee' ? this.foe : this.caster;
      return { x: feet.x, y: feet.y, sy: this.topdown ? 0.5 : 0.35, r: u * 1.05 };
    }
    drawRunes(G) {
      let prog = 0, a = 0; const ti = this.sinceImpact();
      if (this.phase === 'anticipation') { prog = this.charge; a = 0.5 + 0.5 * this.charge; }
      else if (this.phase === 'travel' || this.phase === 'hitstop') { prog = 1; a = 1; }
      else if (ti >= 0 && ti < 1e8) { prog = 1; a = ti < 80 ? 1 : 1 - clamp01((ti - 80) / 260); }
      else if (this.d.delivery.id === 'loop') { prog = 1; a = 0.25 + 0.2 * Math.sin(this.tick * 0.004); }
      if (a <= 0.02) return; const R = this.runeCenter(), px = this.d.pixel, col = ti >= 0 && ti < 80 ? this.C.hi : this.accent();
      G.ring(R.x, R.y, R.r, px ? 1 : this.unit * 0.06, col, a, !px, R.sy);
      G.ring(R.x, R.y, R.r * 0.72, px ? 1 : this.unit * 0.04, col, a * 0.7, !px, R.sy);
      const n = 8, shown = Math.floor(prog * n + 1e-6), rot = this.tick * 0.0006;
      for (let k = 0; k < shown; k++) { const ang = rot + (k * TAU) / n; const x = R.x + Math.cos(ang) * R.r * 0.86, y = R.y + Math.sin(ang) * R.r * 0.86 * R.sy; G.dot(x, y, px ? 2 : this.unit * 0.12, col, a, !px); }
    }
    drawCracks(G) {
      const ti = this.sinceImpact(); if (ti < 0 || ti >= 1e8) return; const f = clamp01(ti / 80); const a = 1 - clamp01((ti - 200) / Math.max(1, this.dur('afterglow') + this.dur('burst') - 200));
      if (a <= 0.02) return; const side = this.scene === 'stage' && !this.topdown; const cx = this.A.x, cy = side ? this.floorY + 1 : this.A.y; const u = this.unit;
      for (const src of this.cracks) {
        const segs = (src.length >> 1) - 1, show = Math.max(1, Math.round(f * segs)); const p = [];
        for (let k = 0; k <= show; k++) p.push(cx + src[k * 2] * u * 1.6, cy + src[k * 2 + 1] * u * (side ? 0.25 : 1.2));
        G.polyline(p, this.d.pixel ? 1 : u * 0.05, this.d.pixel ? this.accent() : this.C.hi, a, !this.d.pixel);
      }
    }
    drawGlow(G) {
      const d = this.d, C = this.C, st = d.style, env = this.glowEnv(); if (env <= 0.01) return;
      const pre = this.phase === 'anticipation' || this.phase === 'travel' || this.phase === 'idle';
      const P = pre ? this.srcPoint() : this.d.delivery.id === 'collect' ? this.dest : this.A; if (P.y > this.H + this.unit * 0.2) return;
      const r = this.unit * 0.9 * (1 + 0.15 * (this.tier - 1)) * (0.85 + 0.3 * env) * (this.d.delivery.id === 'loop' && this.scene === 'board' ? 2.2 : 1);
      const color = this.accent();
      if (st === 'pixel') { G.disk(P.x, P.y, r, C.accDark[this.tier - 1], env * 0.5); G.disk(P.x, P.y, r * 0.62, color, env * 0.55); G.disk(P.x, P.y, r * 0.3, C.hi, env * 0.7); return; }
      if (st === 'cartoon') {
        const ti = this.sinceImpact(); if (ti >= 0 && ti < 1e8) { const k = clamp01(ti / 200); const p = []; for (let i = 0; i < 24; i++) { const a = (i * TAU) / 24 + 0.1, rr = r * 1.3 * (i % 2 ? 0.55 : 1.05) * (0.6 + 0.4 * outExpo(k)); p.push(P.x + Math.cos(a) * rr, P.y + Math.sin(a) * rr); } G.poly(p, color, env, false, C.ink, this.unit * 0.06); }
        else G.disk(P.x, P.y, r * 0.6, color, env * 0.35, false); return;
      }
      if (st === 'minimal') { G.ring(P.x, P.y, r * 0.8, this.unit * 0.03, color, env * 0.8, false); G.ring(P.x, P.y, r * 0.55, this.unit * 0.02, C.hi, env * 0.5, false); return; }
      if (st === 'painterly') { for (let i = 0; i < 5; i++) { const a = this.tick * 0.0004 + (i * TAU) / 5; G.soft(P.x + Math.cos(a) * r * 0.25, P.y + Math.sin(a) * r * 0.2, r * 1.2, i % 2 ? color : C.acc[this.tier % 4], env * 0.33); } return; }
      G.soft(P.x, P.y, r * 1.3, color, env * 0.85); G.soft(P.x, P.y, r * 0.5, C.hi, env * 0.55);
    }
    drawRays(G) {
      const ti = this.sinceImpact(); if (ti < 0 || ti >= 1e8) return; const B = this.dur('burst'), Aft = this.dur('afterglow');
      const env = ti < B ? outExpo(clamp01(ti / (B * 0.5))) : 1 - clamp01((ti - B) / Math.max(1, Aft)); if (env <= 0.01) return;
      const st = this.d.style, px = this.d.pixel, u = this.unit, A = this.A;
      if (this.d.delivery.id === 'aura') {
        const w = u * (0.55 + 0.12 * this.tier) * env, top = -u, bottom = this.scene === 'stage' && !this.topdown ? this.caster.y : A.y + u;
        G.rect(A.x - w, top, w * 2, bottom - top, this.accent(), px ? env * 0.45 : env * 0.3, !px); G.rect(A.x - w * 0.4, top, w * 0.8, bottom - top, this.C.hi, px ? env * 0.6 : env * 0.35, !px); return;
      }
      const n = this.counts().rays, L = u * 2 * (0.55 + 0.45 * env), rot = this.tick * 0.00015 * TAU, wd = 0.09;
      for (let i = 0; i < n; i++) {
        const a = rot + (i * TAU) / n; const p = [A.x, A.y, A.x + Math.cos(a - wd) * L, A.y + Math.sin(a - wd) * L, A.x + Math.cos(a + wd) * L, A.y + Math.sin(a + wd) * L];
        if (st === 'minimal') G.line(A.x, A.y, A.x + Math.cos(a) * L, A.y + Math.sin(a) * L, u * 0.02, this.accent(), env * 0.7, false);
        else if (st === 'cartoon') G.poly(p, i % 2 ? this.accent() : this.C.hi, env * 0.55, false);
        else G.poly(p, this.accent(), px ? env * 0.45 : env * 0.28, !px);
      }
    }
    drawDelivery(G) {
      const dl = this.d.delivery.id, px = this.d.pixel, u = this.unit, C = this.C, A = this.A;
      const castAge = this.tick - this.castAt;
      if (castAge >= 0 && castAge < 120 && dl !== 'self' && dl !== 'aura' && dl !== 'loop') { const S = this.srcPoint(); if (S.y < this.H) G.disk(S.x, S.y, u * 0.45 * (1 - castAge / 120) + 1, C.hi, 1 - castAge / 120, !px); }
      if (this.phase === 'travel' && dl === 'projectile') {
        if (this.on('trail')) for (let h = this.proj.n - 1; h >= 0; h--) { const t = 1 - h / 8; if (px) G.dot(this.proj.hx[h], this.proj.hy[h], h < 2 ? 2 : 1, h < 2 ? C.hi : this.accent(), t); else G.disk(this.proj.hx[h], this.proj.hy[h], u * 0.16 * t, this.accent(), t, true); }
        if (!px) G.soft(this.proj.x, this.proj.y, u * 0.7, this.accent(), 0.9, true);
        G.disk(this.proj.x, this.proj.y, px ? 2 : u * 0.2, C.hi, 1, !px); if (px) G.disk(this.proj.x, this.proj.y, 3, this.accent(), 0.5);
      }
      const beamOn = dl === 'beam' && (this.phase === 'travel' || this.phase === 'hitstop' || (this.phase === 'burst' && this.pt < this.dur('burst') * 0.4));
      if (beamOn) {
        const S = this.srcPoint(); const ramp = this.phase === 'travel' ? clamp01(this.pt / 80) : this.phase === 'burst' ? 1 - this.pt / (this.dur('burst') * 0.4) : 1;
        const fl = 1 + 0.15 * Math.sin(this.tick * 0.1); const w = u * 0.35 * ramp * fl;
        if (px) { G.line(S.x, S.y, A.x, A.y, Math.max(1, Math.round(w * 1.6)), this.accent(), 1); G.line(S.x, S.y, A.x, A.y, Math.max(1, Math.round(w * 0.6)), C.hi, 1); }
        else { G.line(S.x, S.y, A.x, A.y, w * 2.2, this.accent(), 0.45, true); G.line(S.x, S.y, A.x, A.y, w, this.accent(), 0.9, true); G.line(S.x, S.y, A.x, A.y, w * 0.4, C.hi, 1, true); G.soft(A.x, A.y, u * 0.8 * ramp, this.accent(), 0.8, true); }
      }
      if (dl === 'sky' && (this.phase === 'travel' || this.phase === 'hitstop' || (this.phase === 'burst' && this.pt < 160))) {
        const p = this.phase === 'travel' ? clamp01(this.pt / this.dur('travel')) : 1; const yEnd = lerp(-u, A.y, p);
        const pts = this.on('lightning') ? this.zig(A.x + (this.j() - 0.5) * u * 0.3, -u, A.x, yEnd, 8, u * 0.35) : [A.x, -u, A.x, yEnd];
        if (!px) G.polyline(pts, u * 0.3, this.accent(), 0.5, true); G.polyline(pts, px ? 1 : u * 0.1, C.hi, 1, !px);
      }
      if (dl === 'bolts' && (this.phase === 'travel' || this.phase === 'hitstop' || (this.phase === 'burst' && this.pt < 140))) {
        const S = this.srcPoint();
        for (const h of this.hits) { if (h.link > this.tt && this.phase === 'travel') continue; const pts = this.zig(S.x, S.y, h.x, h.y, 6, u * 0.2); if (!px) G.polyline(pts, u * 0.14, this.accent(), 0.4, true); G.polyline(pts, px ? 1 : u * 0.05, C.hi, 0.9, !px); G.ring(h.x, h.y, u * 0.42, px ? 1 : u * 0.06, this.accent(), 0.8, !px); }
      }
      if (dl === 'sweep' && (this.phase === 'travel' || this.phase === 'hitstop' || (this.phase === 'burst' && this.pt < 160))) {
        const fade = this.phase === 'burst' ? 1 - this.pt / 160 : 1;
        for (const h of this.hits) { if (!h.fired || h.dist === 0) continue; const pts = this.on('lightning') ? this.zig(A.x, A.y, h.x, h.y, Math.max(2, h.dist * 2), u * 0.12) : [A.x, A.y, h.x, h.y]; if (!px) G.polyline(pts, u * 0.22, this.accent(), 0.3 * fade, true); G.polyline(pts, px ? 1 : u * 0.07, C.hi, 0.8 * fade, !px); }
      }
      if (dl === 'melee' && (this.phase === 'travel' || this.phase === 'hitstop' || (this.phase === 'burst' && this.pt < 120))) {
        const p = this.phase === 'travel' ? clamp01(this.pt / this.dur('travel')) : 1; const fade = this.phase === 'burst' ? 1 - this.pt / 120 : 1;
        const a0 = -2.4, a1 = 0.7, R = u * 0.95; const head = a0 + (a1 - a0) * outCubic(p);
        for (let sm = 0; sm < 4; sm++) { const end = head - sm * 0.28, start = Math.max(a0, end - 1.1); if (end <= a0) continue; const pts = []; for (let k = 0; k <= 8; k++) { const a = start + ((end - start) * k) / 8; pts.push(A.x - u * 0.2 + Math.cos(a) * R, A.y + Math.sin(a) * R * 0.8); } G.polyline(pts, (px ? 2 - Math.min(1, sm) : u * 0.2 * (1 - sm * 0.22)), sm === 0 ? C.hi : this.accent(), (1 - sm * 0.25) * fade, !px); }
      }
      if (dl === 'collect') {
        for (const c of this.coins) { if (!c.n) continue; if (this.on('trail')) for (let h = c.n - 1; h >= 1; h--) G.dot(c.hx[h], c.hy[h], px ? 1 : u * 0.12 * (1 - h / 6), this.accent(), 1 - h / 6, !px); if (!c.done) { G.disk(c.hx[0], c.hy[0], px ? 2 : u * 0.2, CH.gold, 1, false); G.dot(c.hx[0] - (px ? 0 : u * 0.06), c.hy[0] - (px ? 1 : u * 0.06), px ? 1 : u * 0.07, '#fff6c8', 1, false); } }
      }
      for (let i = this.miniRings.length - 1; i >= 0; i--) { const m = this.miniRings[i]; const p = (this.tick - m.t) / 300; if (p >= 1) { this.miniRings.splice(i, 1); continue; } G.ring(m.x, m.y, u * (0.2 + 0.6 * outExpo(p)), px ? 1 : u * 0.08 * (1 - p), p < 0.3 ? C.hi : this.accent(), 1 - p, !px); }
    }
    drawParticles(G) {
      const C = this.C, st = this.d.style, px = this.d.pixel, u = this.unit;
      for (let i = 0; i < MAXP; i++) {
        if (this.life[i] <= 0) continue; const f = this.life[i] / this.max[i]; const k = this.kind[i]; const x = this.x[i], y = this.y[i], s = this.size[i];
        if (k === K_SPARK || k === K_ORBIT) {
          const ci = this.col[i]; const color = k === K_ORBIT ? C.acc[ci] : f > 0.66 ? C.hi : f > 0.33 ? this.colorOf(ci) : ci < 4 ? C.accDark[ci] : mix(this.colorOf(ci), C.bg, 0.5);
          if (px) { G.dot(x, y, s, color, 1); continue; }
          let vx = this.vx[i], vy = this.vy[i]; if (k === K_ORBIT) { const ang = this.a1[i] + Math.PI / 2; vx = Math.cos(ang) * u * 1.5; vy = Math.sin(ang) * u * 1.5; }
          if (st === 'cartoon') G.disk(x, y, s * 1.5 * (0.4 + 0.6 * f), color, 1, false);
          else if (st === 'painterly') G.soft(x, y, s * 4, color, 0.45 * Math.min(1, f * 1.5), true);
          else if (st === 'minimal') G.line(x, y, x - vx * 0.02, y - vy * 0.02, u * 0.02, color, Math.min(1, f * 1.5), false);
          else G.line(x, y, x - vx * 0.03, y - vy * 0.03, s, color, Math.min(1, f * 1.6), true);
        } else if (k === K_SHARD) {
          const a = f < 0.25 ? f * 4 : 1; const body = this.colorOf(this.col[i]);
          if (px) { G.dot(x, y, s, body, a); G.dot(x - 1, y - 1, 1, mix(body, '#ffffff', 0.5), a); continue; }
          const r = this.rot[i]; const p = [x + Math.cos(r) * s, y + Math.sin(r) * s, x + Math.cos(r + 2.3) * s * 0.8, y + Math.sin(r + 2.3) * s * 0.8, x + Math.cos(r + 4.0) * s * 0.65, y + Math.sin(r + 4.0) * s * 0.65];
          if (st === 'minimal') G.poly(p, body, a, false, C.hi, u * 0.02, true); else G.poly(p, body, a, false, st === 'cartoon' ? C.ink : mix(body, '#ffffff', 0.4), st === 'cartoon' ? u * 0.05 : u * 0.02);
        } else if (k === K_EMBER) {
          const fl = 0.6 + 0.4 * Math.sin(this.tick * 0.02 + i * 2.1); const a = Math.min(1, f * 2) * fl; const color = C.acc[this.col[i] % 4];
          if (px) { G.dot(x, y, 1, f > 0.5 ? C.hi : color, a > 0.55 ? 1 : 0.5); continue; }
          if (st === 'minimal' || st === 'cartoon') G.disk(x, y, s, color, a, false); else { G.soft(x, y, s * 3.5, color, a * 0.7, true); G.disk(x, y, s * 0.55, C.hi, a, true); }
        } else if (k === K_SMOKE) {
          const r = u * (0.3 + 0.5 * (1 - f)); const a = f * 0.55;
          if (px) G.disk(x, y, r, C.smoke, a); else if (st === 'minimal') G.ring(x, y, r, u * 0.02, C.smoke, a, false); else G.soft(x, y, r * 1.6, C.smoke, a * 0.8, false);
        } else if (k === K_CONF) {
          const a = f < 0.2 ? f * 5 : 1; const cs = Math.cos(this.rot[i]); const color = cs >= 0 ? C.acc[this.col[i]] : C.accDark[this.col[i]];
          if (px) { G.dot(x, y, cs > 0.3 ? 2 : 1, color, a); continue; }
          const hw = s * 0.6, hh = s * 0.32 * Math.max(0.15, Math.abs(cs)); const r = this.rot[i] * 0.3; const c = Math.cos(r), sn = Math.sin(r);
          G.poly([x - hw * c + hh * sn, y - hw * sn - hh * c, x + hw * c + hh * sn, y + hw * sn - hh * c, x + hw * c - hh * sn, y + hw * sn + hh * c, x - hw * c - hh * sn, y - hw * sn + hh * c], color, a, false);
        }
      }
    }
    drawComets(G) {
      const px = this.d.pixel;
      for (const m of this.comets) {
        if (!m.on || m.n === 0) continue;
        for (let h = m.n - 1; h >= 0; h--) { const t = 1 - h / 8; const color = h < 2 ? this.C.hi : this.accent(); if (px) G.dot(m.hx[h], m.hy[h], h < 2 ? 2 : 1, color, t); else G.disk(m.hx[h], m.hy[h], this.unit * 0.1 * t, color, t, this.d.style !== 'cartoon'); }
      }
    }
    drawRings(G) {
      const ti = this.sinceImpact(); if (ti < 0 || ti >= 1e8) return; const n = this.counts().rings; const st = this.d.style, px = this.d.pixel; const u = this.unit, A = this.A;
      const chroma = this.on('chroma') && ti < 140 ? 1 - ti / 140 : 0; const sy = this.topdown ? 0.5 : 1;
      for (let k = 0; k < n; k++) {
        const p = (ti - k * 90) / 500; if (p < 0 || p > 1) continue;
        const r = u * 0.3 + u * 1.1 * outExpo(p) * (1 + 0.1 * (this.tier - 1)) * (this.hits.length > 3 ? 1.6 : 1); const w = u * 0.15 * (1 - p) + u * 0.02; const a = 1 - p;
        const color = k === 0 ? this.C.hi : this.C.acc[Math.min(k, this.tier) - 1];
        if (chroma > 0) { const o = px ? 1 : u * 0.04; G.ring(A.x - o, A.y, r, w, '#ff3355', chroma * a * 0.7, true, sy); G.ring(A.x + o, A.y, r, w, '#33e0ff', chroma * a * 0.7, true, sy); }
        if (px) G.ring(A.x, A.y, r, Math.max(1, w), color, a > 0.5 ? 1 : a * 2, false, sy);
        else if (st === 'minimal') G.ring(A.x, A.y, r, u * 0.02, color, a, false, sy);
        else if (st === 'cartoon') G.ring(A.x, A.y, r, w * 1.2, color, 1, false, sy);
        else { G.ring(A.x, A.y, r, w * 1.8, this.accent(), a * 0.5, true, sy); G.ring(A.x, A.y, r, w * 0.6, color, a, true, sy); }
      }
    }
    drawBolts(G) {
      if (this.phase !== 'burst' || this.pt > this.dur('burst') * 0.6) return; const a = Math.floor(this.tick / 34) % 2 ? 1 : 0.55; const px = this.d.pixel;
      for (const b of this.bolts) { if (!px) G.polyline(b, this.unit * 0.14, this.accent(), a * 0.6, true); G.polyline(b, px ? 1 : this.unit * 0.05, this.C.hi, a, !px); }
    }
    drawLocalFlash(G) {
      const fa = this.d.flashAlpha, ms = this.d.flashMs, px = this.d.pixel, u = this.unit;
      const draw = (x, y, a) => { if (a <= 0.01) return; if (px) G.disk(x, y, u * 0.9, this.C.hi, a); else if (this.d.style === 'cartoon' || this.d.style === 'minimal') G.disk(x, y, u * 0.8, this.C.hi, a * 0.9, false); else G.soft(x, y, u * 1.3, this.C.hi, Math.min(1, a * 1.3), true); };
      if (this.phase === 'hitstop') draw(this.A.x, this.A.y, fa);
      for (const h of this.hits) { if (!h.fired || this.phase === 'hitstop') continue; const age = this.tt - h.fireT; if (age >= 0 && age < ms) draw(h.x, h.y, fa * (1 - age / ms) * (this.hits.length > 6 ? 0.6 : 1)); }
    }
    drawFullFlash(G) { let a = 0; const ti = this.sinceImpact(); if (this.phase === 'hitstop') a = this.d.flashAlpha; else if (ti >= 0 && ti < 1e8) a = this.d.flashAlpha * (1 - clamp01(ti / this.d.flashMs)); if (a > 0.01) G.rect(0, 0, this.W, this.H, this.C.hi, a, this.d.style === 'neon'); }
    drawText(G) {
      const ti = this.sinceImpact(); if (ti < 60 || ti >= 1e8) return; const str = this.d.texts[this.tier - 1]; if (!str) return;
      let a = 1; if (this.phase === 'afterglow') { const Aft = this.dur('afterglow'); a = 1 - clamp01((this.pt - Aft * 0.75) / (Aft * 0.25)); }
      const k = clamp01((ti - 60) / 520); const sc = 1 + 0.6 * (1 - spring(k)); const u = this.unit;
      const size = Math.max(this.d.pixel ? 7 : 10, u * 0.6 * (1 + 0.08 * (this.tier - 1))) * sc; const st = this.d.style;
      let x = this.A.x, y = this.A.y - u * 1.35; if (this.d.delivery.id === 'collect') { x = this.dest.x; y = this.dest.y + u * 1.1; }
      x = Math.min(this.W - size * 1.2, Math.max(size * 1.2, x)); y = Math.max(size * 0.8, y);
      if (st === 'neon' || st === 'painterly') G.soft(x, y, size * 1.6, this.accent(), 0.5 * a, true);
      G.text(str, x, y, size, st === 'neon' || st === 'painterly' ? this.C.hi : this.accent(), a, st === 'minimal' ? null : this.C.ink);
    }
    drawVignette(G) {
      let a = 0; if (this.phase === 'anticipation') a = 0.6 * this.charge; else if (this.phase === 'travel' || this.phase === 'hitstop') a = 0.6; else if (this.phase === 'burst') a = 0.6 * (1 - clamp01(this.pt / 150));
      if (a <= 0.02) return; const W = this.W, H = this.H;
      if (this.d.pixel) { for (let k = 0; k < 4; k++) { const t = 3, aa = a * (1 - k / 4) * 1.4, o = k * t; G.rect(o, o, W - o * 2, t, this.C.ink, aa); G.rect(o, H - o - t, W - o * 2, t, this.C.ink, aa); G.rect(o, o + t, t, H - o * 2 - t * 2, this.C.ink, aa); G.rect(W - o - t, o + t, t, H - o * 2 - t * 2, this.C.ink, aa); } return; }
      const c = this.sg.c; this.sg.set(1, false); const gr = c.createRadialGradient(this.A.x, this.A.y, this.unit * 1.2, this.A.x, this.A.y, Math.hypot(W, H) * 0.7);
      gr.addColorStop(0, rgba(this.C.ink, 0)); gr.addColorStop(1, rgba(this.C.ink, a)); c.fillStyle = gr; c.fillRect(0, 0, W, H);
    }
    drawInvert(G) {
      const first = this.pt < this.dur('hitstop') / 2; const bgc = first ? this.C.bg : this.C.hi, fg = first ? this.C.hi : this.C.bg;
      G.clear(bgc); G.world(); const u = this.unit, A = this.A; const rj = makeRng(55);
      for (let i = 0; i < 28; i++) { const a = (i / 28) * TAU + rj() * 0.15, r0 = u * (1.2 + rj() * 0.5), r1 = u * 5; G.line(A.x + Math.cos(a) * r0, A.y + Math.sin(a) * r0, A.x + Math.cos(a) * r1, A.y + Math.sin(a) * r1, this.d.pixel ? 1 : u * (0.02 + rj() * 0.04), fg, 1, false); }
      this.drawScene(G, fg); this.drawActors(G, fg); G.screen();
    }
  }

  FX.Preview = Preview;
})();
