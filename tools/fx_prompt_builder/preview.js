/* 이펙트 프롬프트 빌더: 선택값을 그대로 보여 주는 캔버스 미리보기 */
(function () {
  'use strict';
  const FX = window.FX;
  const MAXP = 1024;
  const STEP = 1000 / 60;
  const TAU = Math.PI * 2;
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  const K_SPARK = 1, K_SHARD = 2, K_EMBER = 3, K_CONF = 4, K_ORBIT = 5;
  const FONT = '"Apple SD Gothic Neo", "Noto Sans KR", system-ui, -apple-system, sans-serif';

  function makeRng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  function rgb(h) { const n = parseInt(String(h).slice(1, 7), 16) || 0; return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
  function mix(a, b, t) {
    const A = rgb(a), B = rgb(b);
    return '#' + A.map((v, i) => Math.round(v + (B[i] - v) * t).toString(16).padStart(2, '0')).join('');
  }
  function rgba(h, a) { const c = rgb(h); return 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')'; }
  const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
  const outExpo = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));
  const outCubic = (t) => 1 - Math.pow(1 - t, 3);
  const inOutCubic = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
  const spring = (t) => (t <= 0 ? 0 : 1 - Math.exp(-6 * t) * Math.cos(10 * t));

  /* 부드러운 스타일: 표시 캔버스에 논리 320x240 좌표로 그린다 */
  class SmoothG {
    constructor(ctx) { this.c = ctx; this.cam = { x: 0, y: 0, z: 1 }; this.cache = new Map(); }
    begin(W, H, cw, ch) {
      this.k = Math.min(cw / W, ch / H); this.ox = (cw - W * this.k) / 2; this.oy = (ch - H * this.k) / 2;
      this.W = W; this.H = H; this.cx = W / 2; this.cy = H / 2; this.c.imageSmoothingEnabled = true;
    }
    screen() { this.c.setTransform(this.k, 0, 0, this.k, this.ox, this.oy); }
    world() {
      const k = this.k, z = this.cam.z;
      this.c.setTransform(k * z, 0, 0, k * z, this.ox + k * (this.cx + this.cam.x - this.cx * z), this.oy + k * (this.cy + this.cam.y - this.cy * z));
    }
    set(a, add) { this.c.globalAlpha = a < 0 ? 0 : a > 1 ? 1 : a; this.c.globalCompositeOperation = add ? 'lighter' : 'source-over'; }
    clear(color) { const c = this.c; c.setTransform(1, 0, 0, 1, 0, 0); this.set(1, false); c.fillStyle = color; c.fillRect(0, 0, c.canvas.width, c.canvas.height); }
    rect(x, y, w, h, color, a, add) { if (a <= 0.003) return; this.set(a, add); this.c.fillStyle = color; this.c.fillRect(x, y, w, h); }
    dot(x, y, s, color, a, add) { this.rect(x - s / 2, y - s / 2, s, s, color, a, add); }
    disk(x, y, r, color, a, add) { if (a <= 0.003 || r <= 0) return; this.set(a, add); const c = this.c; c.fillStyle = color; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
    ring(x, y, r, w, color, a, add) { if (a <= 0.003 || r <= 0) return; this.set(a, add); const c = this.c; c.strokeStyle = color; c.lineWidth = w; c.beginPath(); c.arc(x, y, r, 0, TAU); c.stroke(); }
    line(x0, y0, x1, y1, w, color, a, add) {
      if (a <= 0.003) return; this.set(a, add); const c = this.c;
      c.strokeStyle = color; c.lineWidth = w; c.lineCap = 'round'; c.beginPath(); c.moveTo(x0, y0); c.lineTo(x1, y1); c.stroke();
    }
    polyline(p, w, color, a, add) {
      if (a <= 0.003) return; this.set(a, add); const c = this.c;
      c.strokeStyle = color; c.lineWidth = w; c.lineCap = 'round'; c.lineJoin = 'round';
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
        s = document.createElement('canvas'); s.width = s.height = 64; const g = s.getContext('2d');
        const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
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

  /* 픽셀 스타일: 저해상도 버퍼에 정수 사각형만으로 그리고, 중간 밝기는 Bayer 디더 */
  class PixelG {
    constructor(ctx) { this.c = ctx; this.cam = { x: 0, y: 0, z: 1 }; this.pat = new Map(); this.txt = new Map(); this.dither = true; this.useCam = false; this.spans = []; }
    begin(W, H) {
      this.W = W; this.H = H; this.cx = W / 2; this.cy = H / 2; const c = this.c;
      c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over'; c.imageSmoothingEnabled = false;
    }
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
    rect(x, y, w, h, color, a) { const f = this.fill(color, a); if (!f) return; this.c.fillStyle = f; this.c.fillRect(Math.round(x), Math.round(y), Math.max(1, Math.round(w)), Math.max(1, Math.round(h))); }
    dot(x, y, sz, color, a) {
      const f = this.fill(color, a); if (!f) return; const s = Math.max(1, Math.round(this.S(sz)));
      this.c.fillStyle = f; this.c.fillRect(this.X(x) - (s >> 1), this.Y(y) - (s >> 1), s, s);
    }
    disk(x, y, r, color, a) {
      const f = this.fill(color, a); if (!f) return; const R = Math.round(this.S(r)); const X0 = this.X(x), Y0 = this.Y(y);
      this.c.fillStyle = f; if (R <= 0) { this.c.fillRect(X0, Y0, 1, 1); return; }
      for (let dy = -R; dy <= R; dy++) { const hw = Math.floor(Math.sqrt(R * R - dy * dy + R * 0.8)); this.c.fillRect(X0 - hw, Y0 + dy, hw * 2 + 1, 1); }
    }
    ring(x, y, r, w, color, a) {
      const f = this.fill(color, a); if (!f) return; const R = Math.round(this.S(r)); if (R <= 0) return;
      const Wd = Math.max(1, Math.round(this.S(w))); const Ri = R - Wd; const X0 = this.X(x), Y0 = this.Y(y); this.c.fillStyle = f;
      for (let dy = -R; dy <= R; dy++) {
        const ho = Math.floor(Math.sqrt(R * R - dy * dy + R * 0.8));
        if (Ri > 0 && Math.abs(dy) < Ri) {
          const hi = Math.floor(Math.sqrt(Ri * Ri - dy * dy + Ri * 0.8));
          if (ho - hi > 0) { this.c.fillRect(X0 - ho, Y0 + dy, ho - hi, 1); this.c.fillRect(X0 + hi + 1, Y0 + dy, ho - hi, 1); }
        } else this.c.fillRect(X0 - ho, Y0 + dy, ho * 2 + 1, 1);
      }
    }
    line(x0, y0, x1, y1, w, color, a) {
      const lv = this.level(a); if (lv <= 0) return;
      let X0 = this.X(x0), Y0 = this.Y(y0); const X1 = this.X(x1), Y1 = this.Y(y1); const s = Math.max(1, Math.round(this.S(w)));
      const dx = Math.abs(X1 - X0), dy = -Math.abs(Y1 - Y0), sx = X0 < X1 ? 1 : -1, sy = Y0 < Y1 ? 1 : -1;
      let err = dx + dy, guard = 0; this.c.fillStyle = color;
      for (;;) {
        if (lv >= 16 || BAYER[((Y0 & 3) << 2) | (X0 & 3)] < lv) this.c.fillRect(X0 - (s >> 1), Y0 - (s >> 1), s, s);
        if ((X0 === X1 && Y0 === Y1) || ++guard > 1200) break;
        const e2 = 2 * err; if (e2 >= dy) { err += dy; X0 += sx; } if (e2 <= dx) { err += dx; Y0 += sy; }
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
      this.comets = [];
      for (let i = 0; i < 8; i++) this.comets.push({ on: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, hx: new Float32Array(8), hy: new Float32Array(8), n: 0, t: 0 });
      this.bolts = []; this.boltT = 0; this.cracks = [];
      this.d = null; this.tier = 1; this.speed = 1;
      this.reduce = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
      this.auto = !this.reduce;
      this.phase = 'idle'; this.pt = 0; this.charge = 0; this.held = false; this.manual = false;
      this.acc = 0; this.drawAcc = 0; this.last = 0; this.tick = 0; this.dirty = true; this.emberAcc = 0; this.orbitSpawned = 0;
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
        bg, hi: c.highlight, subject: c.subject, subjectLight: mix(c.subject, c.highlight, 0.4), outline: mix(c.subject, '#000000', 0.6),
        acc: c.accents.slice(), accDark: c.accents.map((a) => mix(a, bg, 0.55)), ink: mix(bg, '#000000', 0.45),
      };
      this.pg.dither = !d.pixel || d.s.dither !== false;
      this.W = d.pixel ? d.pixelW : 320; this.H = d.pixel ? d.pixelH : 240; this.U = Math.min(this.W, this.H);
      this.cx = this.W / 2; this.subY = this.H / 2 + this.U * 0.05; this.S = this.U * 0.22;
      if (styleChanged) this.sg.cache.clear();
      this.restart(); this.dirty = true;
    }
    setTier(t) { if (!this.d) return; this.tier = Math.min(Math.max(1, t), this.d.tiers); this.play(); }
    setSpeed(s) { this.speed = s; }
    setAuto(b) { this.auto = b; if (b && (this.phase === 'done' || this.phase === 'idle')) this.restart(); }
    on(id) { const m = this.d.minTier[id]; return m !== undefined && this.tier >= m; }
    counts() { return this.d.tierList[this.tier - 1]; }
    accent() { return this.C.acc[this.tier - 1]; }

    restart() {
      this.life.fill(0); this.comets.forEach((c) => { c.on = false; }); this.bolts = [];
      this.r = makeRng(20240 + this.tier * 97); this.j = makeRng(911 + this.tier);
      this.manual = false; this.held = false; this.emberAcc = 0; this.orbitSpawned = 0; this.charge = 0;
      this.makeCracks(); this.enter('idle');
    }
    play() { if (!this.d) return; this.restart(); this.enter(this.nextPhase('idle')); }
    press() {
      if (!this.d) return;
      if (this.d.s.trigger === 'hold' && this.dur('anticipation') > 0) { this.restart(); this.manual = true; this.held = true; this.enter('anticipation'); }
      else this.play();
    }
    dur(ph) {
      const d = this.d, st = d.stretch(this.tier);
      switch (ph) {
        case 'idle': return 450;
        case 'anticipation': return d.phases.anticipation;
        case 'hitstop': return d.phases.hitstop * st;
        case 'burst': return Math.max(60, d.phases.burst);
        case 'afterglow': return d.phases.afterglow * st;
        case 'gap': return d.s.playback === 'loop' ? d.s.loopGap : 900;
        default: return 0;
      }
    }
    nextPhase(ph) {
      const order = ['idle', 'anticipation', 'hitstop', 'burst', 'afterglow', 'gap'];
      let i = order.indexOf(ph) + 1;
      while (i < order.length && order[i] !== 'burst' && order[i] !== 'gap' && this.dur(order[i]) <= 0) i++;
      return order[i] || 'done';
    }
    enter(ph) {
      this.phase = ph; this.pt = 0;
      if (ph === 'hitstop' || ph === 'burst') this.charge = 1;
      if (ph === 'burst') this.onBurst();
    }
    next() {
      const n = this.nextPhase(this.phase);
      if (n === 'done') { if (this.auto) this.restart(); else this.phase = 'done'; } else this.enter(n);
    }

    spawn(kind, x, y, vx, vy, life, size, col, vr) {
      let i = this.cur, tries = 0;
      while (this.life[i] > 0 && tries < MAXP) { i = (i + 1) % MAXP; tries++; }
      if (tries >= MAXP) return -1;
      this.cur = (i + 1) % MAXP;
      this.kind[i] = kind; this.x[i] = x; this.y[i] = y; this.vx[i] = vx; this.vy[i] = vy; this.life[i] = life; this.max[i] = life;
      this.size[i] = size; this.col[i] = col; this.vr[i] = vr || 0; this.rot[i] = this.r() * TAU; this.a1[i] = 0; this.a2[i] = 0;
      return i;
    }
    makeCracks() {
      this.cracks = [];
      for (let b = 0; b < 4; b++) {
        const pts = [(this.r() - 0.5) * 0.25, (this.r() - 0.5) * 0.25]; let a = (b / 4) * TAU + this.r() * 0.8; const seg = 4 + Math.floor(this.r() * 3);
        for (let k = 0; k < seg; k++) { a += (this.r() - 0.5) * 1.1; const l = 0.14 + this.r() * 0.1; pts.push(pts[pts.length - 2] + Math.cos(a) * l, pts[pts.length - 1] + Math.sin(a) * l); }
        this.cracks.push(pts);
      }
    }
    makeBolts() {
      const n = this.counts().bolts; this.bolts = [];
      for (let b = 0; b < n; b++) {
        const a = this.j() * TAU, L = this.U * 0.45 * (0.7 + this.j() * 0.4); const pts = [this.cx, this.subY];
        for (let k = 1; k <= 6; k++) {
          const t = k / 6, off = k === 6 ? 0 : (this.j() - 0.5) * this.U * 0.08;
          pts.push(this.cx + Math.cos(a) * L * t - Math.sin(a) * off, this.subY + Math.sin(a) * L * t + Math.cos(a) * off);
        }
        this.bolts.push(pts);
      }
    }

    onBurst() {
      const c = this.counts(), U = this.U, S = this.S, cx = this.cx, cy = this.subY, px = this.d.pixel, t = this.tier;
      for (let i = 0; i < MAXP; i++) if (this.kind[i] === K_ORBIT) this.life[i] = 0;
      for (let k = 0; k < c.sparks; k++) {
        const a = this.r() * TAU, sp = U * (0.6 + 0.8 * this.r());
        const col = this.r() < 0.7 ? t - 1 : Math.floor(this.r() * t);
        this.spawn(K_SPARK, cx, cy, Math.cos(a) * sp, Math.sin(a) * sp, 0.4 + 0.4 * this.r(), px ? (this.r() < 0.3 ? 2 : 1) : U * (0.006 + 0.008 * this.r()), col, 0);
      }
      const card = this.d.shape === 'card';
      for (let k = 0; k < c.shards; k++) {
        const ox = (this.r() - 0.5) * S * (card ? 1.1 : 1.3), oy = (this.r() - 0.5) * S * (card ? 1.6 : 1.3);
        const a = Math.atan2(oy, ox) + (this.r() - 0.5) * 0.6, sp = U * (0.3 + 0.5 * this.r());
        this.spawn(K_SHARD, cx + ox, cy + oy, Math.cos(a) * sp, Math.sin(a) * sp - U * 0.3, 0.7 + 0.4 * this.r(), px ? 2 + Math.floor(this.r() * 2) : S * (0.1 + 0.1 * this.r()), 9, (this.r() - 0.5) * 4 * TAU);
      }
      for (let k = 0; k < c.confetti; k++) {
        const a = -Math.PI / 2 + (this.r() - 0.5) * 1.8, sp = U * (0.9 + 0.8 * this.r());
        this.spawn(K_CONF, cx, cy - S * 0.2, Math.cos(a) * sp, Math.sin(a) * sp, 1.6 + this.r(), px ? 2 : U * (0.014 + 0.01 * this.r()), Math.floor(this.r() * 4), (3 + this.r() * 6) * (this.r() < 0.5 ? -1 : 1));
      }
      for (let k = 0; k < this.comets.length; k++) {
        const m = this.comets[k]; m.on = k < c.comets; if (!m.on) continue;
        const a = -Math.PI / 2 + (k - (c.comets - 1) / 2) * 0.75 + (this.r() - 0.5) * 0.3, sp = U * (1.1 + 0.5 * this.r());
        m.x = cx; m.y = cy; m.vx = Math.cos(a) * sp; m.vy = Math.sin(a) * sp; m.life = 0.75; m.n = 0; m.t = 0;
      }
      this.boltT = 0; this.makeBolts();
    }

    update(dtReal) {
      if (!this.d) return;
      let dt = dtReal * this.speed;
      if (this.phase === 'burst' && this.on('slowmo') && this.pt < this.dur('burst') * 0.45) dt *= 0.35;
      const sec = dt / 1000; this.tick += dt;
      switch (this.phase) {
        case 'idle':
          this.pt += dt; if (this.auto && !this.manual && this.pt >= this.dur('idle')) this.next();
          break;
        case 'anticipation': {
          const A = this.dur('anticipation');
          if (this.manual) { if (this.held) this.pt += dt; this.charge = clamp01(this.pt / A); if (this.charge >= 1 || !this.held) { this.next(); break; } }
          else { this.pt += dt; this.charge = clamp01(this.pt / A); if (this.pt >= A) { this.next(); break; } }
          const want = this.counts().orbit * Math.min(1, this.charge / 0.8);
          while (this.orbitSpawned < want) {
            this.orbitSpawned++; const i = this.spawn(K_ORBIT, this.cx, this.subY, 0, 0, 6, this.d.pixel ? 1 : this.U * (0.006 + 0.006 * this.r()), this.tier - 1, 0.8 + 0.4 * this.r());
            if (i >= 0) { this.a1[i] = this.r() * TAU; this.a2[i] = this.U * 0.45 * (0.85 + 0.25 * this.r()); }
          }
          break;
        }
        case 'hitstop':
          this.pt += dt; if (this.pt >= this.dur('hitstop')) this.next();
          return;
        case 'burst':
          this.pt += dt; this.boltT += dt;
          if (this.boltT >= 60) { this.boltT = 0; this.makeBolts(); }
          if (this.pt >= this.dur('burst')) this.next();
          break;
        case 'afterglow':
          this.pt += dt;
          if (this.on('embers')) { this.emberAcc += sec * this.d.emberRate * (1 + 0.3 * (this.tier - 1)); while (this.emberAcc >= 1) { this.emberAcc -= 1; this.spawnEmber(); } }
          if (this.pt >= this.dur('afterglow')) this.next();
          break;
        case 'gap':
          this.pt += dt; if (this.pt >= this.dur('gap')) this.next();
          break;
        default: break;
      }
      if (this.d.p.id === 'ambient' && this.on('embers') && this.phase !== 'afterglow') {
        this.emberAcc += sec * this.d.emberRate * 0.6; while (this.emberAcc >= 1) { this.emberAcc -= 1; this.spawnEmber(); }
      }
      this.sim(sec);
    }
    spawnEmber() {
      const U = this.U;
      this.spawn(K_EMBER, this.cx + (this.r() - 0.5) * U * 0.8, this.subY + (this.r() - 0.2) * U * 0.3, (this.r() - 0.5) * U * 0.05, -U * 0.15 * (0.7 + 0.6 * this.r()), 1.2 + this.r() * 0.4, this.d.pixel ? 1 : U * (0.005 + 0.006 * this.r()), this.tier - 1, 0);
    }
    sim(sec) {
      const U = this.U, pixel = this.d.pixel;
      for (let i = 0; i < MAXP; i++) {
        if (this.life[i] <= 0) continue;
        this.life[i] -= sec; const k = this.kind[i];
        if (k === K_ORBIT) {
          const ch = this.charge; this.a1[i] += TAU * (1 + 3 * ch) * this.vr[i] * sec; this.a2[i] -= U * (0.08 + 0.55 * ch * ch) * sec;
          if (this.a2[i] <= this.S * 0.22) { this.life[i] = 0; continue; }
          this.x[i] = this.cx + Math.cos(this.a1[i]) * this.a2[i]; this.y[i] = this.subY + Math.sin(this.a1[i]) * this.a2[i] * 0.85;
          continue;
        }
        const drag = k === K_SPARK ? 3 : k === K_CONF ? 1.7 : k === K_SHARD ? 0.6 : 0;
        const grav = k === K_SHARD ? U * 1.2 : k === K_CONF ? U * 0.9 : k === K_SPARK ? U * (pixel ? 0.35 : 0.15) : 0;
        const f = Math.max(0, 1 - drag * sec);
        this.vx[i] *= f; this.vy[i] = this.vy[i] * f + grav * sec;
        if (k === K_CONF) this.vx[i] += Math.sin(this.tick * 0.004 + i) * U * 0.45 * sec;
        if (k === K_EMBER) this.vx[i] += Math.sin(this.tick * 0.002 + i * 1.7) * U * 0.06 * sec;
        this.x[i] += this.vx[i] * sec; this.y[i] += this.vy[i] * sec; this.rot[i] += this.vr[i] * sec;
      }
      for (const m of this.comets) {
        if (!m.on) continue; m.life -= sec; if (m.life <= -0.3) { m.on = false; continue; }
        if (m.life > 0) {
          m.t += sec; m.vx *= 1 - 0.8 * sec; m.vy *= 1 - 0.8 * sec; m.x += m.vx * sec; m.y += m.vy * sec;
          if (m.t >= 0.02) { m.t = 0; for (let h = 7; h > 0; h--) { m.hx[h] = m.hx[h - 1]; m.hy[h] = m.hy[h - 1]; } m.hx[0] = m.x; m.hy[0] = m.y; m.n = Math.min(8, m.n + 1); }
        } else if (m.n > 0 && (m.t += sec) >= 0.03) { m.t = 0; m.n--; }
      }
    }

    // 진행 상태 도우미
    burstT() { return this.phase === 'burst' ? this.pt : (this.phase === 'afterglow' ? this.dur('burst') + this.pt : (this.phase === 'gap' || this.phase === 'done' ? 1e9 : -1)); }
    envGlow() {
      const bt = this.dur('burst');
      switch (this.phase) {
        case 'idle': return this.d.p.id === 'ambient' ? 0.35 : (this.d.s.trigger === 'hold' ? 0.12 : 0);
        case 'anticipation': return 0.25 + 0.5 * this.charge;
        case 'hitstop': return 1;
        case 'burst': return 1 - 0.5 * clamp01(this.pt / bt);
        case 'afterglow': return 0.5 * (1 - clamp01(this.pt / this.dur('afterglow')));
        default: return this.d.p.id === 'ambient' ? 0.35 : 0;
      }
    }

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
      if (this.dirty || grid >= 60 || this.drawAcc >= 1000 / grid) {
        this.drawAcc = grid >= 60 ? 0 : this.drawAcc % (1000 / grid); this.dirty = false;
        this.draw(); this.emitPhase();
      }
    }
    emitPhase() {
      const names = ['anticipation', 'hitstop', 'burst', 'afterglow'];
      const durs = names.map((n) => this.dur(n)); let pos = -1; const idx = names.indexOf(this.phase);
      if (idx >= 0) { pos = 0; for (let i = 0; i < idx; i++) pos += durs[i]; pos += Math.min(this.pt, durs[idx]); }
      else if (this.phase === 'gap' || this.phase === 'done') pos = durs.reduce((a, b) => a + b, 0);
      this.onPhase({ phase: this.phase, pos, durs, manual: this.manual, charge: this.charge });
    }

    draw() {
      const d = this.d, C = this.C, pixel = d.pixel; const G = pixel ? this.pg : this.sg;
      if (pixel) { if (this.buf.width !== this.W || this.buf.height !== this.H) { this.buf.width = this.W; this.buf.height = this.H; } G.begin(this.W, this.H); }
      else G.begin(this.W, this.H, this.cv.width, this.cv.height);
      // 카메라
      let z = 1, sx = 0, sy = 0; const tb = this.burstT();
      if (tb >= 0 && tb < 1e8) {
        if (this.on('shake')) {
          const amp = (pixel ? d.shakePx : (this.U * d.shakePct) / 100) * (1 + 0.25 * (this.tier - 1)); const k = 1 - clamp01(tb / 300);
          if (k > 0) { sx = (this.j() * 2 - 1) * amp * k; sy = (this.j() * 2 - 1) * amp * k; }
        }
        if (this.on('zoom')) z = 1 + (d.zoom + 0.01 * (this.tier - 1) - 1) * (1 - outCubic(clamp01(tb / 250)));
      } else if (this.phase === 'anticipation' && d.s.trigger === 'hold') {
        if (this.on('shake')) { const amp = (pixel ? 1 : this.U * 0.005) * this.charge * this.charge; sx = (this.j() * 2 - 1) * amp; sy = (this.j() * 2 - 1) * amp; }
        if (this.on('zoom')) z = 1 + (d.zoom - 1) * 0.6 * this.charge;
      }
      G.cam.x = sx; G.cam.y = sy; G.cam.z = z;

      if (this.phase === 'hitstop' && this.on('invert')) { this.drawInvert(G); this.present(); return; }
      G.clear(C.bg); G.world();
      if (this.on('rays')) this.drawRays(G);
      if (this.on('glow')) this.drawGlow(G);
      this.drawSubject(G);
      this.drawParticles(G);
      this.drawComets(G);
      if (this.on('ring')) this.drawRings(G);
      if (this.on('lightning')) this.drawBolts(G);
      if (this.on('textPop')) this.drawText(G);
      if (this.on('flash') && !this.fullFlash()) this.drawFlashLocal(G);
      G.screen();
      if (this.on('flash') && this.fullFlash()) this.drawFlash(G);
      if (this.on('vignette')) this.drawVignette(G);
      this.present();
    }
    present() {
      if (!this.d.pixel) return;
      const c = this.ctx, cw = this.cv.width, ch = this.cv.height, W = this.W, H = this.H;
      const sc = Math.max(1, Math.floor(Math.min(cw / W, ch / H))); const ox = Math.floor((cw - W * sc) / 2), oy = Math.floor((ch - H * sc) / 2);
      c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = 1; c.globalCompositeOperation = 'source-over'; c.imageSmoothingEnabled = false;
      c.fillStyle = this.C.bg; c.fillRect(0, 0, cw, ch); c.drawImage(this.buf, 0, 0, W, H, ox, oy, W * sc, H * sc);
    }

    shapePoly(sh, cx, cy, S, sx, sy) {
      const p = [];
      const add = (x, y) => p.push(cx + x * S * sx, cy + y * S * sy);
      if (sh === 'gem') { add(-0.45, -0.6); add(0.45, -0.6); add(0.82, -0.15); add(0, 0.9); add(-0.82, -0.15); }
      else if (sh === 'card') { const w = 0.62, h = 0.88, c = 0.1; add(-w + c, -h); add(w - c, -h); add(w, -h + c); add(w, h - c); add(w - c, h); add(-w + c, h); add(-w, h - c); add(-w, -h + c); }
      else if (sh === 'star') { for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, r = i % 2 ? 0.42 : 0.95; add(Math.cos(a) * r, Math.sin(a) * r); } }
      else if (sh === 'button') { for (let i = 0; i <= 8; i++) { const a = Math.PI / 2 + (i * Math.PI) / 8; add(-0.7 + Math.cos(a) * 0.36, Math.sin(a) * 0.36); } for (let i = 0; i <= 8; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 8; add(0.7 + Math.cos(a) * 0.36, Math.sin(a) * 0.36); } }
      else return null;
      return p;
    }
    subjectState() {
      const d = this.d, ph = this.phase; let sx = 1, sy = 1, sc = 1, oy = 0;
      if (this.on('squash')) {
        if (ph === 'anticipation') { sx = 1 + 0.12 * this.charge; sy = 1 - 0.12 * this.charge; }
        else if (ph === 'hitstop') { sx = 1.12; sy = 0.88; }
        else { const tb = this.burstT(); if (tb >= 0 && tb < 1e8) { const e = 1 - spring(clamp01(tb / 480)); sx = 1 - 0.1 * e; sy = 1 + 0.15 * e; } }
      }
      if (d.shape === 'star' && ph === 'idle') sc = spring(clamp01(this.pt / 420));
      if (ph === 'idle' && d.s.trigger === 'hold') oy = (Math.floor(this.tick / 420) % 2) * (d.pixel ? 1 : this.U * 0.006);
      if (d.p.id === 'ambient') sc *= 1 + 0.06 * Math.sin(this.tick * 0.0022);
      return { sx, sy, sc, oy };
    }
    drawSubject(G) {
      const d = this.d, C = this.C, ph = this.phase, sh = d.shape, st = d.style;
      const gone = sh === 'gem' && (ph === 'burst' || ph === 'afterglow' || ph === 'gap' || ph === 'done');
      if (gone) return;
      const s = this.subjectState(); const cx = this.cx, cy = this.subY + s.oy, S = this.S * s.sc;
      let sx = s.sx, face = 'back';
      if (sh === 'card') {
        const tb = this.burstT();
        if (tb >= 0) {
          const p = clamp01(tb / (this.dur('burst') * 0.55)); const turns = this.tier >= 3 ? 3 : 1;
          const e = d.s.easing === 'elastic' ? spring(p) : d.s.easing === 'smooth' ? inOutCubic(p) : outExpo(p);
          const cs = Math.cos(e * Math.PI * turns); face = cs < 0 ? 'front' : 'back'; sx *= Math.max(0.05, Math.abs(cs));
          if (tb >= 1e8) { face = 'front'; sx = s.sx; }
        }
      }
      const rimA = this.on('rim') ? (ph === 'anticipation' ? this.charge : ph === 'hitstop' ? 1 : ph === 'burst' ? 1 - clamp01(this.pt / this.dur('burst')) : ph === 'idle' && d.p.id === 'ambient' ? 0.5 : 0) : 0;
      const tb = this.burstT(); const chroma = this.on('chroma') && tb >= 0 && tb < 140 ? 1 - tb / 140 : 0;
      const body = sh === 'card' && face === 'front' ? mix(C.bg, this.accent(), 0.3) : sh === 'star' ? this.accent() : C.subject;
      const pts = this.shapePoly(sh, cx, cy, S, sx, s.sy);
      const outline = st === 'cartoon' ? C.ink : st === 'pixel' ? (rimA > 0.4 ? this.accent() : C.outline) : null;
      const ow = st === 'cartoon' ? S * 0.09 : 1;
      if (chroma > 0) {
        const off = this.d.pixel ? 1 : this.U * 0.012;
        if (pts) { const l = pts.map((v, i) => (i % 2 ? v : v - off)), r = pts.map((v, i) => (i % 2 ? v : v + off)); G.poly(l, '#ff3355', 0.7 * chroma, true); G.poly(r, '#33e0ff', 0.7 * chroma, true); }
        else { G.disk(cx - off, cy, S * 0.55, '#ff3355', 0.7 * chroma, true); G.disk(cx + off, cy, S * 0.55, '#33e0ff', 0.7 * chroma, true); }
      }
      if (!pts) {
        // 구슬
        if (st === 'minimal') { G.ring(cx, cy, S * 0.55, this.U * 0.008, C.hi, 1, false); }
        else {
          if (outline) G.disk(cx, cy, S * 0.55 + (st === 'cartoon' ? ow / 2 : 1), outline, 1, false);
          G.disk(cx, cy, S * 0.55, body, 1, false); G.disk(cx - S * 0.18, cy - S * 0.18, S * 0.18, C.subjectLight, 0.9, false);
          G.disk(cx, cy, S * 0.3, this.accent(), 0.35 + 0.65 * Math.max(rimA, this.charge), st !== 'cartoon');
        }
        if (rimA > 0 && !this.d.pixel) G.ring(cx, cy, S * 0.58, this.U * 0.01, this.accent(), rimA, true);
        return;
      }
      if (st === 'minimal') G.poly(pts, body, 1, false, C.hi, this.U * 0.008, true);
      else G.poly(pts, body, 1, false, st === 'cartoon' || st === 'pixel' ? outline : null, ow);
      // 세부 무늬
      if (sh === 'gem' && st !== 'minimal') { const t = this.shapePoly('gem', cx, cy, S, sx, s.sy); G.poly([t[0], t[1], t[2], t[3], t[4], t[5], t[8], t[9]], C.subjectLight, 0.9, false); }
      if (sh === 'card') {
        const ih = S * 0.7 * s.sy, iw = S * 0.48 * sx;
        if (face === 'back') {
          G.poly([cx - iw, cy - ih, cx + iw, cy - ih, cx + iw, cy + ih, cx - iw, cy + ih], C.hi, 0.18, false, null, 0, st !== 'pixel');
          G.poly([cx, cy - S * 0.32 * s.sy, cx + S * 0.26 * sx, cy, cx, cy + S * 0.32 * s.sy, cx - S * 0.26 * sx, cy], mix(C.subject, C.hi, 0.55), 1, false);
        } else if (sx > 0.3) {
          G.poly([cx - iw, cy - ih, cx + iw, cy - ih, cx + iw, cy + ih, cx - iw, cy + ih], this.accent(), 1, false, null, 0, true);
          const star = this.shapePoly('star', cx, cy - S * 0.08, S * 0.42, sx, s.sy); G.poly(star, this.accent(), 1, false);
          G.poly([cx - iw * 0.8, cy + ih * 0.62, cx + iw * 0.8, cy + ih * 0.62, cx + iw * 0.8, cy + ih * 0.78, cx - iw * 0.8, cy + ih * 0.78], C.hi, 0.8, false);
        }
      }
      if (sh === 'button') G.text('OK', cx, cy + S * 0.02, S * 0.42, C.hi, 1, st === 'cartoon' ? C.ink : null);
      if (sh === 'star' && st !== 'minimal') { const inner = this.shapePoly('star', cx, cy + S * 0.04, S * 0.55, sx, s.sy); G.poly(inner, mix(this.accent(), C.hi, 0.45), 0.9, false); }
      if (rimA > 0 && !this.d.pixel) G.poly(pts, this.accent(), rimA, true, this.accent(), this.U * 0.012, true);
      if (this.on('cracks') && (ph === 'anticipation' || ph === 'hitstop') && face === 'back') this.drawCracks(G, cx, cy, S, sx, s.sy);
    }
    drawCracks(G, cx, cy, S, sx, sy) {
      const ch = this.phase === 'hitstop' ? 1 : this.charge; const hint = Math.min(this.tier, 1 + Math.floor(ch * this.tier - 1e-6));
      const color = this.C.acc[Math.max(0, hint - 1)]; const w = this.d.pixel ? 1 : this.U * 0.008;
      for (let b = 0; b < this.cracks.length; b++) {
        const f = clamp01((ch - b * 0.25) / 0.25); if (f <= 0) continue; const src = this.cracks[b]; const segs = (src.length >> 1) - 1; const show = f * segs;
        const p = [];
        for (let k = 0; k <= segs; k++) {
          if (k > show + 1) break; let x = src[k * 2], y = src[k * 2 + 1];
          if (k > show) { const t = show - (k - 1); x = src[(k - 1) * 2] + (x - src[(k - 1) * 2]) * t; y = src[(k - 1) * 2 + 1] + (y - src[(k - 1) * 2 + 1]) * t; }
          p.push(cx + x * S * 0.9 * sx, cy + y * S * 1.1 * sy);
        }
        if (p.length >= 4) { if (!this.d.pixel) G.polyline(p, w * 2.4, color, 0.45, true); G.polyline(p, w, this.d.pixel ? color : this.C.hi, 1, !this.d.pixel); }
      }
    }
    drawGlow(G) {
      const d = this.d, C = this.C, st = d.style; const env = this.envGlow(); if (env <= 0.01) return;
      const color = this.phase === 'anticipation' && this.on('cracks') ? this.C.acc[Math.max(0, Math.min(this.tier, 1 + Math.floor(this.charge * this.tier - 1e-6)) - 1)] : this.accent();
      const r = this.U * 0.35 * (1 + 0.15 * (this.tier - 1)) * (0.85 + 0.3 * env); const cx = this.cx, cy = this.subY;
      if (st === 'pixel') { G.disk(cx, cy, r, C.accDark[this.tier - 1], env * 0.55); G.disk(cx, cy, r * 0.66, color, env * 0.6); G.disk(cx, cy, r * 0.34, C.hi, env * 0.7); return; }
      if (st === 'cartoon') {
        const tb = this.burstT(); if (tb >= 0 && tb < 1e8) { const k = clamp01(tb / 200); const p = []; for (let i = 0; i < 24; i++) { const a = (i * TAU) / 24 + 0.1, rr = r * (i % 2 ? 0.55 : 1.05) * (0.6 + 0.4 * outExpo(k)); p.push(cx + Math.cos(a) * rr, cy + Math.sin(a) * rr); } G.poly(p, color, env, false, C.ink, this.U * 0.01); }
        else G.disk(cx, cy, r * 0.7, color, env * 0.35, false);
        return;
      }
      if (st === 'minimal') { G.ring(cx, cy, r * 0.8, this.U * 0.005, color, env * 0.8, false); G.ring(cx, cy, r * 0.55, this.U * 0.003, C.hi, env * 0.5, false); return; }
      if (st === 'painterly') { for (let i = 0; i < 5; i++) { const a = this.tick * 0.0004 + (i * TAU) / 5; G.soft(cx + Math.cos(a) * r * 0.25, cy + Math.sin(a) * r * 0.2, r * 1.1, i % 2 ? color : C.acc[(this.tier) % 4], env * 0.35); } G.soft(cx, cy, r * 0.5, C.hi, env * 0.35); return; }
      G.soft(cx, cy, r * 1.25, color, env * 0.85); G.soft(cx, cy, r * 0.55, C.hi, env * 0.55);
    }
    drawRays(G) {
      const tb = this.burstT(); if (tb < 0) return; const B = this.dur('burst'), A = this.dur('afterglow');
      let env = tb < B ? outExpo(clamp01(tb / (B * 0.5))) : 1 - clamp01((tb - B) / Math.max(1, A)); if (tb >= 1e8) env = 0; if (env <= 0.01) return;
      const n = this.counts().rays; const L = this.U * 0.7 * (0.55 + 0.45 * env); const rot = this.tick * 0.00015 * TAU; const w = 0.09; const st = this.d.style; const cx = this.cx, cy = this.subY;
      for (let i = 0; i < n; i++) {
        const a = rot + (i * TAU) / n; const p = [cx, cy, cx + Math.cos(a - w) * L, cy + Math.sin(a - w) * L, cx + Math.cos(a + w) * L, cy + Math.sin(a + w) * L];
        if (st === 'minimal') G.line(cx, cy, cx + Math.cos(a) * L, cy + Math.sin(a) * L, this.U * 0.003, this.accent(), env * 0.7, false);
        else if (st === 'cartoon') G.poly(p, i % 2 ? this.accent() : this.C.hi, env * 0.55, false);
        else if (st === 'pixel') G.poly(p, this.accent(), env * 0.45, false);
        else G.poly(p, this.accent(), env * 0.28, true);
      }
    }
    drawRings(G) {
      const tb = this.burstT(); if (tb < 0 || tb >= 1e8) return; const n = this.counts().rings; const st = this.d.style, px = this.d.pixel; const U = this.U;
      const chroma = this.on('chroma') && tb < 140 ? 1 - tb / 140 : 0;
      for (let k = 0; k < n; k++) {
        const p = (tb - k * 90) / 500; if (p < 0 || p > 1) continue;
        const r = U * 0.12 + U * 0.45 * outExpo(p) * (1 + 0.1 * (this.tier - 1)); const w = U * 0.05 * (1 - p) + U * 0.004; const a = 1 - p;
        const color = k === 0 ? this.C.hi : this.C.acc[Math.min(k, this.tier) - 1];
        if (chroma > 0) { const o = px ? 1 : U * 0.012; G.ring(this.cx - o, this.subY, r, w, '#ff3355', chroma * a * 0.7, true); G.ring(this.cx + o, this.subY, r, w, '#33e0ff', chroma * a * 0.7, true); }
        if (px) G.ring(this.cx, this.subY, r, Math.max(1, w), color, a > 0.5 ? 1 : a * 2);
        else if (st === 'minimal') G.ring(this.cx, this.subY, r, U * 0.004, color, a, false);
        else if (st === 'cartoon') G.ring(this.cx, this.subY, r, w * 1.2, color, 1, false);
        else { G.ring(this.cx, this.subY, r, w * 1.8, this.accent(), a * 0.5, true); G.ring(this.cx, this.subY, r, w * 0.6, color, a, true); }
      }
    }
    drawBolts(G) {
      if (this.phase !== 'burst' || this.pt > this.dur('burst') * 0.6) return; const a = Math.floor(this.tick / 34) % 2 ? 1 : 0.55; const px = this.d.pixel;
      for (const b of this.bolts) { if (!px) G.polyline(b, this.U * 0.018, this.accent(), a * 0.6, true); G.polyline(b, px ? 1 : this.U * 0.006, this.C.hi, a, !px); }
    }
    drawParticles(G) {
      const C = this.C, st = this.d.style, px = this.d.pixel, U = this.U;
      for (let i = 0; i < MAXP; i++) {
        if (this.life[i] <= 0) continue; const f = this.life[i] / this.max[i]; const k = this.kind[i]; const x = this.x[i], y = this.y[i], s = this.size[i];
        if (k === K_SPARK || k === K_ORBIT) {
          const ci = this.col[i]; const color = k === K_ORBIT ? C.acc[ci] : f > 0.66 ? C.hi : f > 0.33 ? C.acc[ci] : C.accDark[ci];
          if (px) { G.dot(x, y, s, color, 1); continue; }
          let vx = this.vx[i], vy = this.vy[i];
          if (k === K_ORBIT) { const ang = this.a1[i] + Math.PI / 2; vx = Math.cos(ang) * U * 0.5; vy = Math.sin(ang) * U * 0.5; }
          if (st === 'cartoon') G.disk(x, y, s * 1.5 * (0.4 + 0.6 * f), color, 1, false);
          else if (st === 'painterly') G.soft(x, y, s * 4, color, 0.45 * Math.min(1, f * 1.5), true);
          else if (st === 'minimal') G.line(x, y, x - vx * 0.02, y - vy * 0.02, U * 0.004, color, Math.min(1, f * 1.5), false);
          else G.line(x, y, x - vx * 0.03, y - vy * 0.03, s, color, Math.min(1, f * 1.6), true);
        } else if (k === K_SHARD) {
          const a = f < 0.25 ? f * 4 : 1;
          if (px) { G.dot(x, y, s, C.subject, a); G.dot(x - 1, y - 1, 1, C.subjectLight, a); continue; }
          const r = this.rot[i]; const p = [x + Math.cos(r) * s, y + Math.sin(r) * s, x + Math.cos(r + 2.3) * s * 0.8, y + Math.sin(r + 2.3) * s * 0.8, x + Math.cos(r + 4.0) * s * 0.65, y + Math.sin(r + 4.0) * s * 0.65];
          const body = this.d.shape === 'card' ? C.subject : C.subject;
          if (st === 'minimal') G.poly(p, body, a, false, C.hi, U * 0.004, true);
          else G.poly(p, body, a, false, st === 'cartoon' ? C.ink : C.subjectLight, st === 'cartoon' ? U * 0.008 : U * 0.004);
        } else if (k === K_EMBER) {
          const fl = 0.6 + 0.4 * Math.sin(this.tick * 0.02 + i * 2.1); const a = Math.min(1, f * 2) * fl; const color = C.acc[this.col[i]];
          if (px) { G.dot(x, y, 1, f > 0.5 ? C.hi : color, a > 0.55 ? 1 : 0.5); continue; }
          if (st === 'minimal' || st === 'cartoon') G.disk(x, y, s, color, a, false);
          else { G.soft(x, y, s * 3.5, color, a * 0.7, true); G.disk(x, y, s * 0.55, C.hi, a, true); }
        } else if (k === K_CONF) {
          const a = f < 0.2 ? f * 5 : 1; const cs = Math.cos(this.rot[i]); const color = cs >= 0 ? C.acc[this.col[i]] : C.accDark[this.col[i]];
          if (px) { if (cs > 0.3) G.dot(x, y, 2, color, a); else G.dot(x, y, 1, color, a); continue; }
          const hw = s * 0.6, hh = s * 0.32 * Math.max(0.15, Math.abs(cs)); const r = this.rot[i] * 0.3; const c = Math.cos(r), sn = Math.sin(r);
          G.poly([x - hw * c + hh * sn, y - hw * sn - hh * c, x + hw * c + hh * sn, y + hw * sn - hh * c, x + hw * c - hh * sn, y + hw * sn + hh * c, x - hw * c - hh * sn, y - hw * sn + hh * c], color, a, false);
        }
      }
    }
    drawComets(G) {
      const px = this.d.pixel;
      for (const m of this.comets) {
        if (!m.on || m.n === 0) continue;
        for (let h = m.n - 1; h >= 0; h--) {
          const t = 1 - h / 8; const color = h < 2 ? this.C.hi : this.accent();
          if (px) G.dot(m.hx[h], m.hy[h], h < 2 ? 2 : 1, color, t);
          else G.disk(m.hx[h], m.hy[h], this.U * 0.018 * t, color, t, this.d.style !== 'cartoon');
        }
        if (!px && m.life > 0) G.soft(m.x, m.y, this.U * 0.06, this.accent(), 0.8, true);
      }
    }
    drawText(G) {
      const tb = this.burstT(); if (tb < 60 || tb >= 1e8) return; const str = this.d.texts[this.tier - 1]; if (!str) return;
      let a = 1; if (this.phase === 'afterglow') { const A = this.dur('afterglow'); a = 1 - clamp01((this.pt - A * 0.75) / (A * 0.25)); }
      const k = clamp01((tb - 60) / 520); const sc = 1 + 0.6 * (1 - spring(k)); const size = this.U * 0.11 * (1 + 0.08 * (this.tier - 1)) * sc;
      const st = this.d.style; const y = this.subY - this.U * 0.36;
      if (st === 'neon' || st === 'painterly') G.soft(this.cx, y, size * 1.6, this.accent(), 0.5 * a, true);
      G.text(str, this.cx, y, size, st === 'neon' || st === 'painterly' ? this.C.hi : this.accent(), a, st === 'minimal' ? null : this.C.ink);
    }
    fullFlash() { return this.d.ii >= 3; }
    flashAlpha() { return this.phase === 'hitstop' ? this.d.flashAlpha : this.phase === 'burst' ? this.d.flashAlpha * (1 - clamp01(this.pt / this.d.flashMs)) : 0; }
    drawFlash(G) {
      const a = this.flashAlpha();
      if (a > 0.01) G.rect(0, 0, this.W, this.H, this.C.hi, a, this.d.style === 'neon');
    }
    drawFlashLocal(G) {
      const a = this.flashAlpha(); if (a <= 0.01) return;
      if (this.d.pixel) G.disk(this.cx, this.subY, this.U * 0.45, this.C.hi, a);
      else if (this.d.style === 'cartoon' || this.d.style === 'minimal') G.disk(this.cx, this.subY, this.U * 0.5, this.C.hi, a * 0.9, false);
      else G.soft(this.cx, this.subY, this.U * 0.6, this.C.hi, Math.min(1, a * 1.3), true);
    }
    drawVignette(G) {
      let a = 0; if (this.phase === 'anticipation') a = 0.6 * this.charge; else if (this.phase === 'hitstop') a = 0.6; else if (this.phase === 'burst') a = 0.6 * (1 - clamp01(this.pt / 150));
      if (a <= 0.02) return; const W = this.W, H = this.H;
      if (this.d.pixel) { for (let k = 0; k < 4; k++) { const t = 3, aa = a * (1 - k / 4) * 1.4, o = k * t; G.rect(o, o, W - o * 2, t, this.C.ink, aa); G.rect(o, H - o - t, W - o * 2, t, this.C.ink, aa); G.rect(o, o + t, t, H - o * 2 - t * 2, this.C.ink, aa); G.rect(W - o - t, o + t, t, H - o * 2 - t * 2, this.C.ink, aa); } return; }
      const c = this.sg.c; this.sg.set(1, false); const gr = c.createRadialGradient(this.cx, this.subY, this.U * 0.3, this.cx, this.subY, Math.hypot(W, H) * 0.55);
      gr.addColorStop(0, rgba(this.C.ink, 0)); gr.addColorStop(1, rgba(this.C.ink, a)); c.fillStyle = gr; c.fillRect(0, 0, W, H);
    }
    drawInvert(G) {
      const first = this.pt < this.dur('hitstop') / 2; const bgc = first ? this.C.bg : this.C.hi, fg = first ? this.C.hi : this.C.bg;
      G.clear(bgc); G.world(); const U = this.U, cx = this.cx, cy = this.subY; const rj = makeRng(55);
      for (let i = 0; i < 28; i++) { const a = (i / 28) * TAU + rj() * 0.15, r0 = U * (0.3 + rj() * 0.1), r1 = U * 0.95; G.line(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0, cx + Math.cos(a) * r1, cy + Math.sin(a) * r1, this.d.pixel ? 1 : U * (0.004 + rj() * 0.006), fg, 1, false); }
      const s = this.subjectState(); const pts = this.shapePoly(this.d.shape, cx, cy + s.oy, this.S * s.sc, s.sx, s.sy);
      if (pts) G.poly(pts, fg, 1, false); else G.disk(cx, cy, this.S * 0.55, fg, 1, false);
      G.screen();
    }
  }

  FX.Preview = Preview;
})();
