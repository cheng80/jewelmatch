/* 이펙트 프롬프트 빌더: 단계 화면, 상태 저장, 미리보기와 프롬프트 연결 */
(function () {
  'use strict';
  const FX = window.FX;
  const KEY = 'fxPromptBuilder.v1';
  const $ = (sel, root) => (root || document).querySelector(sel);
  const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const PHASE_KO = { idle: '대기', anticipation: '예고', hitstop: '정지', burst: '폭발', afterglow: '여운', gap: '끝', done: '끝' };
  const LAST = FX.STEPS.length - 1;
  const panel = $('#panel');

  let state = load();

  function normalize(s) {
    const def = FX.defaultState();
    const out = Object.assign({}, def, s);
    out.perf = Object.assign({}, def.perf, s.perf || {});
    out.deliverables = Object.assign({}, def.deliverables, s.deliverables || {});
    out.phases = Object.assign({}, def.phases, s.phases || {});
    out.colors = s.colors && Array.isArray(s.colors.accents) && s.colors.accents.length === 4 ? FX.copyColors(s.colors) : def.colors;
    out.tierNames = (Array.isArray(s.tierNames) ? s.tierNames : []).concat(['', '', '', '']).slice(0, 4).map((x) => String(x || ''));
    out.layers = Array.isArray(s.layers) ? s.layers.filter((id) => FX.LAYERS.some((l) => l.id === id)) : def.layers;
    out.platforms = Array.isArray(s.platforms) ? s.platforms.filter((id) => FX.PLATFORMS.some((p) => p.id === id)) : def.platforms;
    out.minTier = s.minTier && typeof s.minTier === 'object' ? Object.assign({}, s.minTier) : {};
    if (!FX.PURPOSES.some((p) => p.id === out.purpose)) out.purpose = def.purpose;
    out.step = FX.clamp(out.step | 0, 0, LAST);
    out.v = 1;
    return out;
  }
  function load() {
    try { const raw = localStorage.getItem(KEY); if (raw) { const s = JSON.parse(raw); if (s && s.v === 1) return normalize(s); } } catch (e) { /* 저장소 접근 실패는 기본값으로 */ }
    return FX.defaultState();
  }
  function save() { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* 무시 */ } }

  function setPath(obj, path, v) {
    const keys = path.split('.'); let o = obj;
    for (let i = 0; i < keys.length - 1; i++) { if (o[keys[i]] == null) o[keys[i]] = {}; o = o[keys[i]]; }
    o[keys[keys.length - 1]] = v;
  }

  /* 공통 조각 */
  function group(title, inner, hint, cls) {
    return '<fieldset class="group' + (cls ? ' ' + cls : '') + '"><legend>' + esc(title) + '</legend>' + (hint ? '<p class="hint">' + esc(hint) + '</p>' : '') + inner + '</fieldset>';
  }
  function radioCards(name, items, cur, o) {
    o = o || {};
    return '<div class="cards ' + (o.cls || '') + '">' + items.map((it) =>
      '<label class="card"><input type="radio" name="' + name + '" value="' + esc(it.id) + '" data-bind="' + name + '"' + (it.id === cur ? ' checked' : '') + (o.rerender ? ' data-rerender' : '') + '>'
      + '<span class="card-body">' + (o.visual ? o.visual(it) : '') + '<strong>' + esc(it.label) + '</strong>' + (it.desc ? '<small>' + esc(it.desc) + '</small>' : '') + '</span></label>').join('') + '</div>';
  }
  function seg(name, items, cur, rerender, label) {
    const curItem = items.find((x) => String(x.id) === String(cur));
    return '<div class="seg" role="radiogroup"' + (label ? ' aria-label="' + esc(label) + '"' : '') + '>' + items.map((it) =>
      '<label><input type="radio" name="' + name + '" value="' + esc(it.id) + '" data-bind="' + name + '"' + (String(it.id) === String(cur) ? ' checked' : '') + (rerender ? ' data-rerender' : '') + (typeof it.id === 'number' ? ' data-type="number"' : '') + '><span>' + esc(it.label) + '</span></label>').join('') + '</div>'
      + (curItem && curItem.desc ? '<small class="seg-desc">' + esc(curItem.desc) + '</small>' : '');
  }
  function checkCard(attrs, checked, label, desc, badge) {
    return '<label class="card check"><input type="checkbox" ' + attrs + (checked ? ' checked' : '') + '><span class="card-body"><strong>' + esc(label) + (badge ? ' <em class="badge">' + esc(badge) + '</em>' : '') + '</strong>' + (desc ? '<small>' + esc(desc) + '</small>' : '') + '</span></label>';
  }
  function fmt(path, v) {
    if (path.indexOf('phases.') === 0 || path === 'loopGap') return v + 'ms';
    if (path === 'intensity') return v + ' (' + FX.INTENSITY[v - 1] + ')';
    if (path === 'maxParticles') return v + '개';
    if (path === 'maxDrawCalls') return v + '회';
    return String(v);
  }
  function range(path, label, min, max, step, val, hint) {
    const id = 'r-' + path.replace(/\./g, '-');
    return '<div class="range"><label for="' + id + '">' + esc(label) + '</label><output data-for="' + path + '" for="' + id + '">' + esc(fmt(path, val)) + '</output>'
      + '<input id="' + id + '" type="range" min="' + min + '" max="' + max + '" step="' + step + '" value="' + val + '" data-bind="' + path + '">' + (hint ? '<small>' + esc(hint) + '</small>' : '') + '</div>';
  }
  function note(text, kind) { return '<p class="note' + (kind ? ' note-' + kind : '') + '">' + esc(text) + '</p>'; }

  const STYLE_VIS = {
    pixel: 'background:repeating-conic-gradient(#2b2461 0 25%,#46e2d2 0 50%) 0 0/10px 10px',
    neon: 'background:radial-gradient(circle,#fff 0 5%,#5ee0ff 11%,rgba(94,224,255,.28) 26%,transparent 52%),#0a0d1c',
    cartoon: 'background:radial-gradient(circle,#ffd166 0 26%,#1b1b1b 27% 32%,transparent 33%),#ff7aa2',
    painterly: 'background:radial-gradient(circle at 36% 46%,rgba(155,231,255,.65),transparent 46%),radial-gradient(circle at 64% 56%,rgba(196,128,255,.6),transparent 50%),#0b1422',
    minimal: 'background:radial-gradient(circle,transparent 0 29%,#e9ecf3 30% 31.5%,transparent 32.5%),linear-gradient(90deg,transparent 49.5%,rgba(233,236,243,.35) 49.5% 50.5%,transparent 50.5%),#10131b',
  };
  function swatches(c) { return '<span class="swatches">' + [c.bg, c.subject, c.highlight].concat(c.accents).map((x) => '<i style="background:' + esc(x) + '"></i>').join('') + '</span>'; }

  /* 단계별 화면 */
  const R = {};
  R.purpose = function () {
    const p = FX.byId(FX.PURPOSES, state.purpose);
    return group('용도', radioCards('purpose', FX.PURPOSES, state.purpose, { rerender: true, cls: 'cards-wide' }), '용도를 바꾸면 스타일, 색, 구성 요소, 타이밍, 등급이 그 용도의 추천값으로 바뀝니다.')
      + '<div class="field"><label for="f-subject">장면 설명</label><textarea id="f-subject" rows="2" data-bind="subject" placeholder="' + esc(p.subject.ko) + '">' + esc(state.subject) + '</textarea>'
      + '<small>무엇이 어떻게 터지는지 한 문장으로 적습니다. 비워 두면 흐린 예시 문장이 그대로 들어갑니다.</small></div>'
      + '<div class="row2">' + group('시작 방식', seg('trigger', FX.TRIGGERS, state.trigger, true, '시작 방식')) + group('재생', seg('playback', FX.PLAYBACKS, state.playback, true, '재생')) + '</div>';
  };
  R.style = function () {
    let html = group('그리는 방식', radioCards('style', FX.STYLES, state.style, { rerender: true, visual: (it) => '<span class="vis" style="' + STYLE_VIS[it.id] + '"></span>' }));
    if (state.style === 'pixel') {
      html += group('픽셀 설정',
        '<div class="row3"><div class="field"><label for="f-res">논리 해상도</label><select id="f-res" data-bind="pixelRes">' + FX.PIXEL_RES.map((r) => '<option' + (r === state.pixelRes ? ' selected' : '') + '>' + r + '</option>').join('') + '</select></div>'
        + '<div class="field"><label for="f-fps">움직임 프레임</label><select id="f-fps" data-bind="pixelFps" data-type="number">' + FX.PIXEL_FPS.map((f) => '<option value="' + f + '"' + (f === state.pixelFps ? ' selected' : '') + '>' + f + 'fps 느낌</option>').join('') + '</select></div>'
        + '<label class="toggle"><input type="checkbox" data-bind="dither"' + (state.dither ? ' checked' : '') + '> 중간 밝기는 디더로</label></div>',
        'X 글의 마법사 프롬프트처럼 낮은 해상도에 그리고 정수 배율로 확대합니다. 업데이트는 60Hz, 그리기는 고른 프레임으로 끊어 픽셀 애니메이션처럼 보이게 합니다.');
    }
    return html;
  };
  R.palette = function () {
    const presets = FX.PALETTES.map((p) => Object.assign({ desc: '' }, p));
    let html = group('팔레트', radioCards('paletteId', presets, state.paletteId, { rerender: true, cls: 'cards-compact', visual: (it) => swatches(it.colors) }), state.paletteId === 'custom' ? '직접 바꾼 색을 쓰는 중입니다. 프리셋을 누르면 그 색으로 돌아갑니다.' : '');
    const c = state.colors;
    const role = (path, label, val, dim) => '<label class="color' + (dim ? ' is-dim' : '') + '"><input type="color" value="' + esc(val) + '" data-bind="' + path + '"><span>' + esc(label) + '<code data-hex="' + path + '">' + esc(val) + '</code></span></label>';
    html += group('역할별 색',
      '<div class="colors">' + role('colors.bg', '배경', c.bg) + role('colors.subject', '주인공', c.subject) + role('colors.highlight', '하이라이트', c.highlight)
      + c.accents.map((a, i) => role('colors.accents.' + i, '강조 ' + (i + 1) + (i < state.tiers ? '' : ' (안 씀)'), a, i >= state.tiers)).join('') + '</div>',
      '강조 1은 등급 1, 강조 2는 등급 2에 쓰입니다. 등급 수보다 뒤에 있는 강조색은 프롬프트에 들어가지 않습니다.');
    html += '<label class="toggle"><input type="checkbox" data-bind="strictPalette"' + (state.strictPalette ? ' checked' : '') + '> 팔레트 밖 색 금지</label>'
      + '<p class="hint">켜면 프롬프트에 "이 목록 밖의 색 금지"가 들어갑니다. 픽셀 스타일에서 권장합니다.</p>';
    return html;
  };
  R.layers = function () {
    const rec = FX.byId(FX.PURPOSES, state.purpose).layers;
    let html = '';
    FX.LAYER_CATS.forEach((cat) => {
      const items = FX.LAYERS.filter((l) => l.cat === cat.id);
      html += group(cat.label, '<div class="cards cards-check">' + items.map((l) => checkCard('data-list="layers" value="' + l.id + '" data-rerender', state.layers.includes(l.id), l.label, l.desc, rec.includes(l.id) ? '추천' : '')).join('') + '</div>');
    });
    const n = state.layers.length;
    let msg = note('고른 요소 ' + n + '개. 추천 표시는 지금 용도의 기본 구성입니다.');
    if (n === 0) msg = note('요소를 하나 이상 고르세요. 아무것도 없으면 주인공만 보입니다.', 'warn');
    else if (n > 12) msg = note('요소가 ' + n + '개입니다. 한 번에 너무 많으면 임팩트가 흐려질 수 있어 다음 단계에서 높은 등급으로 미루는 것을 권합니다.', 'warn');
    return msg + html;
  };
  function timelineHtml() {
    const ph = state.phases; const segs = [['anticipation', '예고', 'a'], ['hitstop', '정지', 'h'], ['burst', '폭발', 'b'], ['afterglow', '여운', 'g']];
    const total = segs.reduce((s, x) => s + ph[x[0]], 0) || 1;
    return '<div class="timeline" aria-hidden="true">' + segs.map((x) => (ph[x[0]] > 0 ? '<i class="tl-' + x[2] + '" style="flex:' + ph[x[0]] + '"></i>' : '')).join('') + '</div>'
      + '<p class="legend">' + segs.map((x) => '<span class="lg-' + x[2] + '">' + x[1] + ' ' + ph[x[0]] + 'ms</span>').join('') + '<span>합계 ' + (total / 1000).toFixed(2) + '초</span></p>'
      + (state.tierStretch && state.tiers > 1 ? '<p class="hint">최상위 등급은 정지와 여운이 ' + 20 * (state.tiers - 1) + '% 길어집니다.</p>' : '');
  }
  R.timing = function () {
    const hold = state.trigger === 'hold';
    let html = '<div id="timeline-box">' + timelineHtml() + '</div>';
    html += group('단계 길이',
      range('phases.anticipation', hold ? '예고 (최대 충전 시간)' : '예고', 0, 3000, 20, state.phases.anticipation, hold ? '길게 누르는 동안 이 시간에 걸쳐 충전됩니다.' : '힘을 모으는 준비 동작. 0이면 바로 터집니다.')
      + range('phases.hitstop', '정지 (히트스톱)', 0, 300, 10, state.phases.hitstop, '임팩트 순간 모든 움직임을 멈춥니다. 40~120ms가 무게감을 줍니다.')
      + range('phases.burst', '폭발', 100, 2000, 20, state.phases.burst, '링, 스파크, 파편이 가장 크게 움직이는 구간.')
      + range('phases.afterglow', '여운', 0, 4000, 20, state.phases.afterglow, '불씨, 색종이, 텍스트가 가라앉는 구간.')
      + (state.playback === 'loop' ? range('loopGap', '반복 사이 쉬는 시간', 0, 3000, 50, state.loopGap) : ''), '', 'ranges');
    html += group('움직임 곡선', seg('easing', FX.EASINGS, state.easing, true, '움직임 곡선'));
    html += '<label class="toggle"><input type="checkbox" data-bind="tierStretch" data-rerender' + (state.tierStretch ? ' checked' : '') + '> 등급이 오를수록 정지와 여운을 길게</label>';
    return html;
  };
  function tierDynHtml() {
    const d = FX.derive(state);
    let html = '';
    if (d.tiers > 1 && d.layers.length) {
      const opts = (id) => { let o = ''; for (let t = 1; t <= d.tiers; t++) o += '<option value="' + t + '"' + (d.minTier[id] === t ? ' selected' : '') + '>' + t + '. ' + esc(d.tierNames[t - 1]) + '부터</option>'; return o; };
      html += group('요소별 시작 등급', '<div class="mintier">' + d.layers.map((l) => '<label class="mt"><span>' + esc(l.label) + '</span><select data-bind="minTier.' + l.id + '" data-type="number" data-rerender-part>' + opts(l.id) + '</select></label>').join('') + '</div>',
        '어떤 요소도 지정한 등급 아래에서는 나오지 않습니다. 위 등급은 아래 등급의 요소를 모두 가집니다.');
    } else if (d.tiers === 1) {
      html += note('등급이 1개라 고른 요소가 항상 모두 나옵니다.');
    }
    html += group('등급별 입자 수', '<div class="table-wrap"><table class="counts"><thead><tr><th scope="col">등급</th><th scope="col">스파크</th><th scope="col">파편</th><th scope="col">색종이</th><th scope="col">수렴</th><th scope="col">최대 입자</th></tr></thead><tbody>'
      + d.tierList.map((t, i) => '<tr><th scope="row">' + t.tier + '. ' + esc(d.tierNames[i]) + '</th><td>' + t.sparks + '</td><td>' + t.shards + '</td><td>' + t.confetti + '</td><td>' + t.orbit + '</td><td' + (t.total > state.maxParticles ? ' class="over"' : '') + '>' + t.total + '</td></tr>').join('')
      + '</tbody></table></div>' + (d.maxTotal > state.maxParticles ? note('최상위 등급이 입자 예산 ' + state.maxParticles + '개를 넘습니다. 프롬프트에는 비례 축소 지시가 들어갑니다. Flutter 구현 단계에서 예산을 올리거나 강도를 낮출 수 있습니다.', 'warn') : ''));
    return html;
  }
  R.tiers = function () {
    const p = FX.byId(FX.PURPOSES, state.purpose);
    let html = group('강도', range('intensity', '전체 강도', 1, 5, 1, state.intensity, '입자 수, 흔들림 폭, 섬광 세기, 줌 크기가 함께 바뀝니다.'));
    html += group('등급 수', seg('tiers', [1, 2, 3, 4].map((n) => ({ id: n, label: n + '단계' })), state.tiers, true, '등급 수'));
    if (state.tiers > 1) {
      let names = '';
      for (let i = 0; i < state.tiers; i++) names += '<label class="field tn"><span>등급 ' + (i + 1) + '</span><input type="text" data-bind="tierNames.' + i + '" value="' + esc(state.tierNames[i]) + '" placeholder="' + esc(p.tierNames.ko[i]) + '"></label>';
      html += group('등급 이름', '<div class="tiernames">' + names + '</div>', '비워 두면 흐린 기본 이름을 씁니다. 결과 텍스트와 등급 표에 들어갑니다.');
    }
    return html + '<div id="tier-dyn">' + tierDynHtml() + '</div>';
  };
  R.feedback = function () {
    return group('모션 줄이기 설정을 켠 사용자', radioCards('reducedMotion', FX.REDUCED, state.reducedMotion), 'Flutter의 MediaQuery.disableAnimationsOf 값을 따릅니다.')
      + group('햅틱', radioCards('haptics', FX.HAPTICS.map((h) => Object.assign({}, h, { desc: h.desc || '햅틱을 쓰지 않습니다.' })), state.haptics))
      + group('소리', radioCards('sound', FX.SOUNDS.map((h) => Object.assign({}, h, { desc: h.desc || '소리 관련 지시를 넣지 않습니다.' })), state.sound), 'HTML의 Web Audio는 Flutter로 옮겨지지 않아서, 이펙트는 타이밍 신호만 보내고 소리는 앱의 오디오 매니저가 맡게 합니다.');
  };
  R.flutter = function () {
    const d = FX.derive(state);
    let html = group('그리기 구조', radioCards('target', FX.TARGETS, state.target, { rerender: true }));
    html += group('대상 플랫폼', '<div class="chips">' + FX.PLATFORMS.map((p) => '<label class="chip"><input type="checkbox" data-list="platforms" value="' + p.id + '"' + (state.platforms.includes(p.id) ? ' checked' : '') + '><span>' + esc(p.label) + '</span></label>').join('') + '</div>');
    html += group('성능 규칙', '<div class="chips">' + FX.PERF.map((p) => '<label class="chip"><input type="checkbox" data-bind="perf.' + p.id + '"' + (state.perf[p.id] ? ' checked' : '') + '><span>' + esc(p.label) + '</span></label>').join('') + '</div>', '기본으로 켜진 규칙은 이 저장소 이펙트 코드가 이미 쓰는 방식입니다.');
    html += group('성능 예산', range('maxParticles', '입자 최대 개수', 64, 1024, 32, state.maxParticles, '최상위 등급 예상 ' + d.maxTotal + '개') + range('maxDrawCalls', '프레임당 draw 호출', 2, 24, 1, state.maxDrawCalls), '', 'ranges');
    html += group('프로젝트 맥락', radioCards('context', FX.CONTEXTS, state.context, { rerender: true }), state.context === 'stonematch' ? '기존 풀, 구운 글로우 아틀라스, 순수 함수 타임라인 파일을 프롬프트에 직접 적어 같은 패턴을 쓰게 합니다.' : '');
    return html;
  };
  function fileInfoHtml() {
    const d = FX.derive(state);
    const base = state.context === 'stonematch' ? (state.target === 'flame' ? 'lib/game/components/' : 'lib/widgets/') : 'lib/fx/';
    const files = [];
    if (state.output !== 'flutterOnly') files.push(d.snake + '_preview.html');
    if (state.output !== 'htmlPortable') { files.push(base + d.snake + '_effect.dart'); if (state.deliverables.demo) files.push(base + d.snake + '_demo.dart'); if (state.deliverables.test) files.push('test/' + d.snake + '_effect_test.dart'); }
    return '<p class="hint">클래스 이름: <code>' + esc(d.pascal) + 'Spec</code>, <code>' + esc(d.pascal) + 'Controller</code></p><ul class="files">' + files.map((f) => '<li><code>' + esc(f) + '</code></li>').join('') + '</ul>';
  }
  R.output = function () {
    let html = group('받을 형태', radioCards('output', FX.OUTPUTS, state.output, { rerender: true }));
    html += group('함께 받을 것', '<div class="cards cards-check">' + FX.DELIVERABLES.map((x) => checkCard('data-bind="deliverables.' + x.id + '" data-rerender', state.deliverables[x.id], x.label, x.desc)).join('') + '</div>');
    html += '<div class="row2"><div class="field"><label for="f-name">이펙트 이름 (영문)</label><input id="f-name" type="text" data-bind="name" value="' + esc(state.name) + '" spellcheck="false" autocomplete="off"><small>파일과 클래스 이름에 쓰입니다. 영문 소문자와 밑줄로 바뀝니다.</small><div id="file-info">' + fileInfoHtml() + '</div></div>'
      + group('프롬프트 언어', seg('lang', [{ id: 'ko', label: '한국어' }, { id: 'en', label: 'English' }], state.lang, true, '프롬프트 언어') + '<p class="hint">두 글의 원문 프롬프트는 영어입니다. 어느 쪽이든 같은 수치가 들어갑니다.</p>') + '</div>';
    return html;
  };
  R.result = function () {
    const text = FX.buildPrompt(state);
    const lines = text.split('\n').length;
    let html = '<div class="result-actions"><button type="button" class="btn primary" data-action="copy-prompt">프롬프트 복사</button>'
      + '<button type="button" class="btn" data-action="download-prompt">.md로 저장</button>'
      + '<button type="button" class="btn ghost" data-action="export-config">설정 저장 (JSON)</button>'
      + '<span class="meta">' + text.length.toLocaleString('ko-KR') + '자, ' + lines + '줄</span></div>';
    html += '<label class="sr-only" for="prompt-out">완성된 프롬프트</label><textarea id="prompt-out" class="prompt-out" readonly spellcheck="false">' + esc(text) + '</textarea>';
    const fu = FX.buildFollowUps(state);
    html += '<section class="followups" aria-labelledby="fu-title"><h3 id="fu-title">다음에 보낼 후속 프롬프트</h3><p class="hint">첫 결과를 본 뒤 하나씩 이어서 보내세요. 참고한 대화도 "더 쥬시하게"와 증상 지적을 반복하며 완성도를 올렸습니다.</p><div class="fu-grid">'
      + fu.map((f, i) => '<article class="fu"><header><h4>' + esc(f.title) + '</h4><button type="button" class="btn small" data-action="copy-followup" data-index="' + i + '">복사</button></header><pre>' + esc(f.text) + '</pre></article>').join('') + '</div></section>';
    return html;
  };

  /* 렌더링 */
  function summary(i) {
    switch (FX.STEPS[i].id) {
      case 'purpose': return FX.byId(FX.PURPOSES, state.purpose).label;
      case 'style': return FX.byId(FX.STYLES, state.style).label;
      case 'palette': return state.paletteId === 'custom' ? '직접 고른 색' : FX.byId(FX.PALETTES, state.paletteId).label;
      case 'layers': return state.layers.length + '개';
      case 'timing': { const p = state.phases; return ((p.anticipation + p.hitstop + p.burst + p.afterglow) / 1000).toFixed(2) + '초'; }
      case 'tiers': return '강도 ' + state.intensity + ', ' + state.tiers + '단계';
      case 'feedback': return FX.byId(FX.REDUCED, state.reducedMotion).label;
      case 'flutter': return FX.byId(FX.TARGETS, state.target).label;
      case 'output': return FX.byId(FX.OUTPUTS, state.output).label;
      default: return state.lang === 'ko' ? '한국어' : 'English';
    }
  }
  function renderRail() {
    $('#steps').innerHTML = FX.STEPS.map((st, i) => {
      const cls = i === state.step ? 'is-current' : i < state.step ? 'is-done' : '';
      return '<li><button type="button" data-action="goto" data-step="' + i + '" class="' + cls + '"' + (i === state.step ? ' aria-current="step"' : '') + '><span class="num">' + (i + 1) + '</span><span class="lbl">' + esc(st.label) + '</span><span class="sum">' + esc(summary(i)) + '</span></button></li>';
    }).join('');
  }
  function renderStep(focusHeading) {
    const st = FX.STEPS[state.step];
    const active = document.activeElement && panel.contains(document.activeElement) ? document.activeElement : null;
    const keep = active ? { bind: active.getAttribute('data-bind'), list: active.getAttribute('data-list'), value: active.value, type: active.type } : null;
    const next = FX.STEPS[state.step + 1];
    panel.innerHTML = '<header class="step-head"><p class="eyebrow">단계 ' + (state.step + 1) + ' / ' + FX.STEPS.length + '</p><h2 id="step-title" tabindex="-1">' + esc(st.title) + '</h2><p class="lead">' + esc(st.lead) + '</p></header>'
      + '<div class="step-body">' + R[st.id]() + '</div>'
      + '<footer class="step-nav"><button type="button" class="btn" data-action="prev"' + (state.step === 0 ? ' disabled' : '') + '>이전</button>'
      + (next ? '<button type="button" class="btn primary" data-action="next">다음: ' + esc(next.label) + '</button>' : '<button type="button" class="btn" data-action="goto" data-step="0">처음 단계로</button>') + '</footer>';
    if (focusHeading) { $('#step-title').focus({ preventScroll: true }); return; }
    if (keep && (keep.bind || keep.list)) {
      const sel = keep.list ? '[data-list="' + keep.list + '"][value="' + CSS.escape(keep.value) + '"]'
        : (keep.type === 'radio' ? '[data-bind="' + keep.bind + '"][value="' + CSS.escape(keep.value) + '"]' : '[data-bind="' + keep.bind + '"]');
      const el = panel.querySelector(sel); if (el) el.focus({ preventScroll: true });
    }
  }
  function goto(i) {
    state.step = FX.clamp(i, 0, LAST); save(); renderRail(); renderStep(true);
    const top = panel.getBoundingClientRect().top + window.scrollY - 12; if (window.scrollY > top) window.scrollTo({ top, behavior: 'auto' });
  }

  let outTimer = 0;
  function commit(rerender) {
    save();
    if (rerender) renderStep(false);
    renderRail();
    clearTimeout(outTimer); outTimer = setTimeout(applyOutputs, 50);
  }
  function applyOutputs() {
    const d = FX.derive(state);
    preview.setSpec(d);
    renderTierButtons(d);
    $('#hold-hint').hidden = state.trigger !== 'hold';
    if ($('#live').open) $('#live-prompt').textContent = FX.buildPrompt(state);
  }
  function renderTierButtons(d) {
    const box = $('#tier-buttons');
    let html = '';
    for (let t = 1; t <= d.tiers; t++) html += '<button type="button" class="btn small tier" data-tier="' + t + '" aria-pressed="' + (preview.tier === t) + '">' + esc(d.tierNames[t - 1]) + '</button>';
    box.innerHTML = html; box.hidden = d.tiers < 2;
  }

  /* 입력 처리 */
  function onInput(e) {
    const el = e.target;
    const discrete = el.type === 'radio' || el.type === 'checkbox' || el.tagName === 'SELECT';
    if (discrete && e.type !== 'change') return;
    if (!discrete && e.type !== 'input') return;
    if (el.dataset.list) {
      const list = state[el.dataset.list]; const v = el.value; const i = list.indexOf(v);
      if (el.checked && i < 0) list.push(v); if (!el.checked && i >= 0) list.splice(i, 1);
      if (el.dataset.list === 'layers') state.layers = FX.LAYERS.map((l) => l.id).filter((id) => state.layers.includes(id));
      commit(el.hasAttribute('data-rerender')); return;
    }
    const path = el.dataset.bind; if (!path) return;
    if (el.type === 'radio' && !el.checked) return;
    let v = el.type === 'checkbox' ? el.checked : (el.dataset.type === 'number' || el.type === 'range') ? Number(el.value) : el.value;
    if (path === 'purpose') { FX.applyPurpose(state, v); commit(true); return; }
    if (path === 'paletteId') { state.paletteId = v; state.colors = FX.copyColors(FX.byId(FX.PALETTES, v).colors); commit(true); return; }
    if (path === 'style') {
      state.style = v;
      if (v === 'pixel') { state.strictPalette = true; state.easing = 'stepped'; } else if (state.easing === 'stepped') state.easing = FX.byId(FX.PURPOSES, state.purpose).easing;
      commit(true); return;
    }
    if (path === 'context' && v === 'stonematch') state.target = 'flame';
    if (path.indexOf('colors.') === 0) {
      setPath(state, path, v); state.paletteId = 'custom';
      const code = panel.querySelector('[data-hex="' + path + '"]'); if (code) code.textContent = v;
      panel.querySelectorAll('input[name="paletteId"]').forEach((r) => { r.checked = false; });
      commit(false); return;
    }
    if (path.indexOf('minTier.') === 0) { state.minTier[path.slice(8)] = v; save(); $('#tier-dyn').innerHTML = tierDynHtml(); panel.querySelector('[data-bind="' + path + '"]').focus(); commit(false); return; }
    setPath(state, path, v);
    if (el.type === 'range') { const out = panel.querySelector('output[data-for="' + path + '"]'); if (out) out.textContent = fmt(path, v); }
    if (path.indexOf('phases.') === 0 || path === 'loopGap') { const box = $('#timeline-box'); if (box) box.innerHTML = timelineHtml(); }
    if (path === 'intensity' || path === 'maxParticles') { const box = $('#tier-dyn'); if (box) box.innerHTML = tierDynHtml(); }
    if (path === 'name' || path.indexOf('deliverables.') === 0) { const box = $('#file-info'); if (box) box.innerHTML = fileInfoHtml(); }
    commit(el.hasAttribute('data-rerender'));
  }
  panel.addEventListener('input', onInput);
  panel.addEventListener('change', onInput);

  /* 버튼 */
  function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove('show'), 1800); }
  function copyText(text, okMsg) {
    const done = () => toast(okMsg || '복사했습니다');
    const fallback = () => {
      const ta = document.createElement('textarea'); ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select();
      let ok = false; try { ok = document.execCommand('copy'); } catch (e) { ok = false; } ta.remove(); if (ok) done(); else toast('복사하지 못했습니다. 글을 직접 선택해 복사하세요');
    };
    if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(done, fallback); else fallback();
  }
  function download(name, text, type) {
    const url = URL.createObjectURL(new Blob([text], { type: type || 'text/plain;charset=utf-8' }));
    const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function importConfig(text) {
    try {
      const s = JSON.parse(text); if (!s || typeof s !== 'object' || s.v !== 1) throw new Error('형식');
      state = normalize(s); state.step = LAST; save(); renderRail(); renderStep(true); applyOutputs(); toast('설정을 불러왔습니다'); return true;
    } catch (e) { toast('불러오지 못했습니다. 이 도구에서 저장한 JSON인지 확인하세요'); return false; }
  }
  document.addEventListener('click', (e) => {
    const b = e.target.closest('[data-action], [data-tier]'); if (!b) return;
    if (b.dataset.tier) { preview.setTier(Number(b.dataset.tier)); document.querySelectorAll('#tier-buttons [data-tier]').forEach((x) => x.setAttribute('aria-pressed', String(x === b))); return; }
    const d = FX.derive(state);
    switch (b.dataset.action) {
      case 'next': goto(state.step + 1); break;
      case 'prev': goto(state.step - 1); break;
      case 'goto': goto(Number(b.dataset.step)); break;
      case 'copy-prompt': copyText(FX.buildPrompt(state), '프롬프트를 복사했습니다'); break;
      case 'download-prompt': download(d.snake + '_prompt.md', FX.buildPrompt(state), 'text/markdown;charset=utf-8'); break;
      case 'export-config': download(d.snake + '_fx_config.json', JSON.stringify(state, null, 2), 'application/json'); break;
      case 'copy-followup': copyText(FX.buildFollowUps(state)[Number(b.dataset.index)].text, '후속 프롬프트를 복사했습니다'); break;
      case 'replay': preview.play(); break;
      case 'import': $('#import-text').value = ''; $('#import-dialog').showModal(); break;
      case 'import-apply': if (importConfig($('#import-text').value)) $('#import-dialog').close(); break;
      case 'import-close': $('#import-dialog').close(); break;
      case 'reset':
        if (window.confirm('처음부터 다시 고를까요? 지금 선택은 사라집니다.')) { state = FX.defaultState(); save(); renderRail(); renderStep(true); applyOutputs(); toast('처음 상태로 돌렸습니다'); }
        break;
      default: break;
    }
  });
  $('#import-file').addEventListener('change', (e) => {
    const f = e.target.files && e.target.files[0]; if (!f) return;
    f.text().then((t) => { if (importConfig(t)) $('#import-dialog').close(); }); e.target.value = '';
  });
  $('#slow').addEventListener('change', (e) => preview.setSpeed(e.target.checked ? 0.25 : 1));
  $('#auto').addEventListener('change', (e) => preview.setAuto(e.target.checked));
  $('#live').addEventListener('toggle', () => { if ($('#live').open) $('#live-prompt').textContent = FX.buildPrompt(state); });

  /* 미리보기 진행 표시 */
  let segKey = '';
  function updatePhase(info) {
    const label = $('#phase-label');
    const txt = info.phase === 'anticipation' && info.manual ? '충전 ' + Math.round(info.charge * 100) + '%' : PHASE_KO[info.phase] || '';
    if (label.textContent !== txt) { label.textContent = txt; label.dataset.phase = info.phase; }
    const key = info.durs.join(',');
    const bar = $('#phasebar');
    if (key !== segKey) {
      segKey = key; const cls = ['a', 'h', 'b', 'g'];
      bar.querySelectorAll('i').forEach((el, i) => { el.style.flexGrow = String(info.durs[i]); el.hidden = info.durs[i] <= 0; el.className = 'tl-' + cls[i]; });
    }
    const total = info.durs.reduce((a, b) => a + b, 0) || 1;
    const head = $('#playhead');
    head.style.left = (info.pos < 0 ? 0 : Math.min(100, (info.pos / total) * 100)) + '%';
    head.hidden = info.pos < 0;
  }

  const preview = new FX.Preview($('#preview'), { onPhase: updatePhase });
  $('#auto').checked = preview.auto;
  renderRail();
  renderStep(false);
  applyOutputs();
  window.FX_APP = { get state() { return state; }, preview };
})();
