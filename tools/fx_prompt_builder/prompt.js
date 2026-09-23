/* 이펙트 프롬프트 빌더: 선택 상태를 AI 코딩 도구용 프롬프트로 변환 */
(function () {
  'use strict';
  const FX = window.FX;

  function fileBase(d) {
    const s = d.s;
    if (s.context === 'stonematch') return s.target === 'flame' ? 'lib/game/components/' : 'lib/widgets/';
    return 'lib/fx/';
  }

  FX.buildPrompt = function (state) {
    const d = FX.derive(state);
    const s = d.s;
    const ko = d.lang === 'ko';
    const L = (k, e) => (ko ? k : e);
    const out = [];
    const add = (...lines) => { lines.forEach((x) => { if (x !== null && x !== undefined && x !== false) out.push(x); }); };
    const has = (id) => d.minTier[id] !== undefined;
    const tierOf = (id) => d.minTier[id];
    const style = FX.byId(FX.STYLES, s.style);
    const trig = FX.byId(FX.TRIGGERS, s.trigger);
    const target = FX.byId(FX.TARGETS, s.target);
    const c = d.colors;
    const top = d.tiers;
    const ph = d.phases;
    const wantsHtml = s.output !== 'flutterOnly';
    const wantsDart = s.output !== 'htmlPortable';
    const base = fileBase(d);
    const P = d.pascal;
    const list = (arr) => arr.join(', ');
    const counts = (key, id) => d.tierList.slice((d.minTier[id] || 1) - 1).map((t) => t[key]).join(' / ');
    const layerName = (id) => { const l = FX.byId(FX.LAYERS, id); return ko ? l.label : l.en; };
    const code = (x) => '`' + x + '`';

    // 1. 머리말
    add(ko ? '# ' + P + ' 이펙트 제작 요청' : '# Build the ' + P + ' effect', '');
    add(L('Flutter(Dart)에서 바로 쓸 수 있는 이펙트를 만들어 줘.', 'Create an effect that can be used directly in Flutter (Dart).'));
    add(L('- 장면: ', '- Scene: ') + d.subject);
    add(L('- 용도: ' + d.p.label + '. ' + d.p.desc, '- Purpose: ' + d.p.en + '.'));
    const trigText = ko
      ? { event: '게임 코드가 play(tier)를 호출하면 시작', tap: '탭하면 시작', hold: '길게 누르는 동안 충전하고, 손을 떼거나 가득 차면 터짐', auto: '화면에 나오면 자동으로 시작' }[s.trigger]
      : trig.en;
    const playText = s.playback === 'loop'
      ? L('끝나면 ' + s.loopGap + 'ms 쉬고 반복', 'loops with a ' + s.loopGap + ' ms rest between plays')
      : L('한 번 재생하고 대기 상태로 복귀', 'plays once, then returns to idle');
    add(L('- 시작: ' + trigText + '. 재생: ' + playText + '.', '- Trigger: ' + trigText + '. Playback: ' + playText + '.'));
    add(L('- 스타일: ' + style.label + '. 목표 강도: ' + s.intensity + '/5 (' + FX.INTENSITY[d.ii] + ').', '- Style: ' + style.en + '. Target intensity: ' + s.intensity + '/5 (' + FX.INTENSITY_EN[d.ii] + ').'));
    if (top > 1) add(L('- 등급: ' + top + '단계 (' + d.tierNames.join(' < ') + ')', '- Tiers: ' + top + ' (' + d.tierNames.join(' < ') + ')'));
    add('');

    // 2. 결과물
    add(L('## 결과물', '## Deliverables'));
    let n = 1;
    if (wantsHtml) {
      add(n++ + '. ' + L(
        code(d.snake + '_preview.html') + ': 브라우저에서 바로 여는 단일 HTML 프로토타입. ' + (wantsDart ? '먼저 만들어 타이밍과 느낌을 확정한다.' : 'Flutter로 1:1 옮길 수 있게 작성한다.'),
        code(d.snake + '_preview.html') + ': a single-file HTML prototype that opens directly in a browser. ' + (wantsDart ? 'Build it first to lock the timing and feel.' : 'Write it so it can be ported to Flutter one-to-one.')
      ));
    }
    if (wantsDart) {
      add(n++ + '. ' + L(
        code(base + d.snake + '_effect.dart') + ': 모든 수치를 담은 ' + code(P + 'Spec') + ', 상태 머신과 타임라인, 그리기(' + target.label + '), ' + code(P + 'Controller') + '를 한 파일에 둔다.',
        code(base + d.snake + '_effect.dart') + ': ' + code(P + 'Spec') + ' with every number, the state machine and timeline, rendering (' + target.en + '), and ' + code(P + 'Controller') + ', all in one file.'
      ));
      if (s.deliverables.demo) add(n++ + '. ' + L(
        code(base + d.snake + '_demo.dart') + ': 등급별 재생 버튼, 다시 재생, 0.25배속 토글이 있는 확인용 화면' + (s.context === 'stonematch' ? '. 제품 라우트에 연결하지 않는 디버그 전용 파일로 둔다.' : '.'),
        code(base + d.snake + '_demo.dart') + ': a check screen with per-tier play buttons, replay, and a 0.25x speed toggle' + (s.context === 'stonematch' ? '. Keep it debug-only and do not wire it into product routes.' : '.')
      ));
      if (s.deliverables.test) add(n++ + '. ' + L(
        code('test/' + d.snake + '_effect_test.dart') + ': 등급마다 끝까지 pump했을 때 예외 없음, 완료 콜백 정확히 1회, 남은 활성 입자 0, 모션 줄이기에서 바로 끝나는지 확인한다.',
        code('test/' + d.snake + '_effect_test.dart') + ': for every tier, pump to the end and assert no exceptions, exactly one completion callback, zero live particles, and a quick finish under reduced motion.'
      ));
      if (s.deliverables.tuning) add(n++ + '. ' + L(
        '데모 화면의 수치 조절 패널: 단계 길이, 입자 수, 흔들림 폭을 슬라이더로 바꾸고, 바뀐 값을 ' + code(P + 'Spec') + ' 생성자 코드로 복사하는 버튼.',
        'A tuning panel in the demo: sliders for phase lengths, particle counts and shake, plus a button that copies the values as ' + code(P + 'Spec') + ' constructor code.'
      ));
    } else if (s.deliverables.tuning) {
      add(n++ + '. ' + L('HTML 안의 수치 조절 패널: 슬라이더로 SPEC 값을 바꾸고 JSON으로 복사.', 'A tuning panel inside the HTML: sliders that edit SPEC and copy it as JSON.'));
    }
    if (s.deliverables.sheet) add(L('각 파일 맨 위에 아래 제약 시트를 주석으로 그대로 옮긴다.', 'Copy the constraint sheet below verbatim as a comment at the top of each file.'));
    add('');

    // 3. 제약 시트
    add(L('## 제약 시트', '## Constraint sheet'), '```');
    const format = d.pixel
      ? L('논리 해상도 ' + d.pixelW + 'x' + d.pixelH + ', 물리 픽셀 기준 가장 큰 정수 배율로 확대해 가운데 정렬',
          'logical canvas ' + d.pixelW + 'x' + d.pixelH + ', scaled by the largest integer factor in physical pixels, centered')
      : L('부모 위젯 크기를 따른다. 모든 길이는 영역 짧은 변(unit) 대비 비율, 주인공 크기 0.22 unit, 투명 배경',
          'fills the parent widget; every length is a fraction of the shorter side (unit); subject size 0.22 unit; transparent background');
    const accents = c.accents.slice(0, top).join(' ');
    const palette = L('배경 ' + c.bg + ', 주인공 ' + c.subject + ', 하이라이트 ' + c.highlight + ', 등급 강조 ' + accents,
      'background ' + c.bg + ', subject ' + c.subject + ', highlight ' + c.highlight + ', tier accents ' + accents);
    const paletteRule = s.strictPalette
      ? (d.pixel && s.dither ? L('. 이 목록 밖의 색 금지, 중간 밝기는 4x4 Bayer 디더', '. No colour outside this list; in-between values use 4x4 Bayer dither')
                              : L('. 이 목록 밖의 색 금지, 밝기 단계는 이 색끼리의 혼합만', '. No colour outside this list; shades only by mixing these colours'))
      : L('. 강조색의 밝고 어두운 단계는 파생해도 된다', '. Lighter and darker steps of the accents may be derived');
    const marks = {
      pixel: L('1px 외곽선, 정사각형 입자, Bresenham 선, 스프라이트 회전 금지, 블러와 알파 그라데이션 금지', '1px outlines, square particles, Bresenham lines, no sprite rotation, no blur or alpha gradients'),
      neon: L('모든 빛은 가산 합성, 스파크는 속도 방향 스트릭, 흰 코어에서 강조색으로 번짐', 'all light is additive; sparks are velocity-aligned streaks; hot white core falling off into the accent'),
      cartoon: L('두꺼운 어두운 외곽선, 평면 2단 셀 셰이딩, 별 모양 임팩트와 속도선', 'thick dark outlines, flat two-tone cel shading, star-shaped impacts and speed lines'),
      painterly: L('미리 구운 소프트 브러시 텍스처를 낮은 불투명도로 겹침, 느린 곡선 흐름', 'pre-baked soft brush texture layered at low opacity, slow curving flow'),
      minimal: L('얇은 선과 기하 도형, 2~3색, 가산광 없음, 여백', 'thin lines and geometric primitives, 2 to 3 colours, no additive light, generous negative space'),
    }[s.style];
    const light = L('모든 빛은 주인공 중심에서 나온다. 예고에서 모이고, 임팩트에서 터지고, 여운에서 식는다', 'all light comes from the subject centre: it gathers in anticipation, bursts on impact, cools in the afterglow');
    const fpsGrid = d.pixel ? s.pixelFps : 12;
    const easeText = {
      snappy: L('폭발 요소는 easeOutExpo 계열, 처음 20% 시간에 이동량의 80%', 'burst elements use easeOutExpo-like curves: 80% of travel in the first 20% of the time'),
      elastic: L('크기와 위치는 감쇠 스프링으로 안착(오버슈트 약 12%, 1~2회 흔들림)', 'scale and position settle on a damped spring (about 12% overshoot, 1 to 2 wobbles)'),
      smooth: L('easeInOutCubic 중심의 부드러운 가감속, 급한 변화는 임팩트 순간에만', 'soft easeInOutCubic motion; sharp changes only at the impact'),
      stepped: L('값은 부드럽게 보간하고 그릴 때 ' + fpsGrid + 'fps 격자로 양자화', 'values ease smoothly but are quantized to a ' + fpsGrid + ' fps grid when drawn'),
    }[s.easing];
    const rules = L('임팩트는 한 번. 등급이 오를수록 강해지고 어떤 요소도 지정 등급 아래에서 나오지 않는다. 시드 고정 난수만. 프레임 루프 안 객체 생성 0',
      'one impact moment; effects escalate with tier and never appear below their tier; seeded randomness only; zero allocations inside the frame loop')
      + (s.trigger === 'hold' ? L('. 충전은 사용자의 손, 폭발은 보상', '; the charge is the player\'s hand, the burst is the reward') : '');
    const sound = {
      none: L('없음', 'none'),
      cues: L('이펙트는 소리를 재생하지 않고 cue 이벤트만 보낸다', 'the effect never plays audio; it only emits cue events'),
      design: L('cue 이벤트만 보내고, 소리 설계안은 따로 표로 제안', 'emit cue events only; propose the sound design separately as a table'),
    }[s.sound];
    const pad = (k) => (k + '          ').slice(0, 9);
    add(pad('FORMAT') + format);
    add(pad('PALETTE') + palette + paletteRule);
    add(pad('MARKS') + marks);
    add(pad('LIGHT') + light);
    add(pad('MOTION') + easeText + (d.pixel && s.easing !== 'stepped' ? L(', 그리기는 ' + s.pixelFps + 'fps 격자', ', drawing snaps to a ' + s.pixelFps + ' fps grid') : ''));
    add(pad('RULES') + rules);
    add(pad('SOUND') + sound);
    add('```', '');

    // 4. 렌더링
    add(L('## 렌더링', '## Rendering'));
    if (d.pixel) {
      add(L('- 논리 해상도 ' + d.pixelW + 'x' + d.pixelH + '에 그린다. Flutter에서는 ' + code('devicePixelRatio') + '를 곱한 물리 픽셀 기준으로 정수 배율을 구하고 ' + code('canvas.scale(배율 / devicePixelRatio)') + '를 적용한다. 원점도 물리 픽셀 정수 위치에 맞춘다.',
        '- Draw on a ' + d.pixelW + 'x' + d.pixelH + ' logical canvas. In Flutter compute the integer scale in physical pixels (multiply by ' + code('devicePixelRatio') + '), apply ' + code('canvas.scale(scale / devicePixelRatio)') + ', and snap the origin to a whole physical pixel.'));
      add(L('- 모든 도형은 정수 좌표 사각형 단위로 그린다(' + code('Paint.isAntiAlias = false') + '). 이미지는 ' + code('FilterQuality.none') + '. 블러, 그림자, 알파 그라데이션 금지.',
        '- Every shape is built from integer-aligned rects (' + code('Paint.isAntiAlias = false') + '). Images use ' + code('FilterQuality.none') + '. No blur, shadows, or alpha gradients.'));
      add(s.dither
        ? L('- 중간 밝기(후광, 섬광, 어둠)는 4x4 Bayer 디더 패턴으로 표현하고, 패턴 칸은 화면 격자에 고정한다.', '- In-between brightness (glow, flash, darkness) is an ordered 4x4 Bayer dither locked to the screen grid.')
        : L('- 중간 밝기는 팔레트 색 단계로만 표현한다.', '- In-between brightness uses palette steps only.'));
      add(L('- 업데이트는 60Hz로 돌리되 그릴 때 포즈와 위치를 ' + s.pixelFps + 'fps 격자로 양자화해 픽셀 애니메이션처럼 보이게 한다.',
        '- Update at 60 Hz but quantize poses and positions to ' + s.pixelFps + ' fps when drawing so it reads as pixel animation.'));
      add(L('- 입자는 1~3px 정사각형, 선은 Bresenham, 스프라이트는 회전하지 않는다(필요하면 90도 단위).', '- Particles are 1 to 3 px squares, lines are Bresenham, sprites never rotate except in 90 degree steps.'));
    } else if (s.style === 'neon') {
      add(L('- 어두운 배경 위의 빛은 모두 ' + code('BlendMode.plus') + '로 더해 겹칠수록 밝아진다. 중심은 하이라이트에 가깝고 가장자리로 갈수록 강조색이다.',
        '- All light is drawn with ' + code('BlendMode.plus') + ', so overlaps brighten. Cores sit near the highlight colour and fall off into the accent.'));
      add(L('- 글로우는 매 프레임 blur로 만들지 않는다. 초기화 때 흰색 방사형 텍스처를 한 번 구워(' + code('PictureRecorder') + '와 ' + code('toImageSync') + ') 색만 입혀 그린다.',
        '- Never blur per frame. Bake a white radial texture once at init (' + code('PictureRecorder') + ' plus ' + code('toImageSync') + ') and tint it at draw time.'));
      add(L('- 스파크는 속도 방향으로 늘어난 선(길이는 속도 x 0.03초)으로 그려 빠르기가 읽히게 한다.', '- Sparks are streaks along their velocity (length = speed x 0.03 s) so speed reads clearly.'));
    } else if (s.style === 'cartoon') {
      add(L('- 평면 채색과 두꺼운 어두운 외곽선(주인공 크기의 4%). 명암은 2단 셀 셰이딩이고 그라데이션은 없다.', '- Flat fills with thick dark outlines (4% of subject size). Two-tone cel shading, no gradients.'));
      add(L('- 임팩트 모양은 뾰족한 별 형태 폭발과 속도선이다. 스쿼시 앤 스트레치를 과장한다.', '- Impacts are spiky star bursts with speed lines. Exaggerate squash and stretch.'));
      add(L('- 가산광 대신 일반 합성(' + code('BlendMode.srcOver') + ')을 쓰고, 빠른 이동에는 1~2프레임 스미어(늘어난 잔상)를 쓴다.', '- Use normal ' + code('BlendMode.srcOver') + ' compositing; fast moves get 1 to 2 frame smears.'));
    } else if (s.style === 'painterly') {
      add(L('- 낮은 불투명도(0.15~0.4)의 부드러운 블롭을 여러 겹 쌓아 번짐을 만든다. 블롭은 미리 구운 소프트 브러시 텍스처 하나를 색만 바꿔 그린다. 런타임 blur 금지.',
        '- Build softness by stacking low-opacity (0.15 to 0.4) blobs from one pre-baked soft brush texture, tinted per colour. No runtime blur.'));
      add(L('- 움직임은 느린 이징과 곡선 궤적(부드러운 노이즈 흐름)이다. 급한 변화는 임팩트 순간에만 둔다.', '- Motion is slow easing along curved, noise-driven paths. Save sharp changes for the impact.'));
    } else {
      add(L('- 얇은 선(주인공 크기의 2~3%)과 원, 사각형, 선분만 쓴다. 2~3색, 가산광 없음.', '- Only thin strokes (2 to 3% of subject size), circles, rects and line segments. 2 to 3 colours, no additive light.'));
      add(L('- 입자 수보다 타이밍과 이징의 정확도로 완성도를 만든다. 여백을 남긴다.', '- Quality comes from precise timing and easing, not particle count. Leave negative space.'));
    }
    add(L('- 이펙트 자체는 투명 배경에 그리고 배경색 ' + c.bg + '은 데모 화면에서만 칠한다. 게임 화면 위에 겹쳐 쓰기 위해서다.',
      '- The effect itself renders on a transparent background; paint ' + c.bg + ' only in the demo so the effect can sit on top of game content.'));
    add('');

    // 5. 타임라인
    const phaseDefs = [
      { key: 'anticipation', name: 'ANTICIPATION', ms: ph.anticipation },
      { key: 'hitstop', name: 'HITSTOP', ms: ph.hitstop },
      { key: 'burst', name: 'BURST', ms: ph.burst },
      { key: 'afterglow', name: 'AFTERGLOW', ms: ph.afterglow },
    ].filter((x) => x.ms > 0);
    add(L('## 타임라인 (상태 머신)', '## Timeline (state machine)'));
    add(code('IDLE -> ' + phaseDefs.map((x) => x.name).join(' -> ') + ' -> ' + (s.playback === 'loop' ? 'IDLE (loop)' : 'DONE')));
    const idleText = s.trigger === 'hold'
      ? L('누르기 전 대기. 주인공이 2프레임 보브로 살짝 숨쉰다.', 'Waiting for a press; the subject breathes with a 2-frame bob.')
      : L('대기. 아무것도 그리지 않거나 주인공만 정지 상태로 그린다.', 'Waiting; draw nothing, or only the resting subject.');
    add('- IDLE: ' + idleText);
    const phr = (map) => d.layers.map((l) => map[l.id]).filter(Boolean);
    const antic = phr(ko ? {
      orbit: '입자가 주인공 주위를 돌며 빨라지다 중심으로 빨려 든다', cracks: '균열이 충전 25/50/75/100% 지점마다 한 가지씩 뻗는다',
      glow: '후광이 차오른다', rim: '테두리 빛이 밝아진다', squash: '주인공이 눌리며 힘을 모은다', vignette: '가장자리가 어두워져 시선이 모인다',
      shake: s.trigger === 'hold' ? '충전 후반에 미세한 떨림이 커진다' : null, zoom: s.trigger === 'hold' ? '화면이 천천히 다가간다' : null,
    } : {
      orbit: 'particles orbit the subject, speed up and get pulled into the centre', cracks: 'a crack branch grows at 25/50/75/100% charge',
      glow: 'the glow fills up', rim: 'the rim light brightens', squash: 'the subject compresses to gather force', vignette: 'edges darken to pull focus',
      shake: s.trigger === 'hold' ? 'a fine tremble grows in the late charge' : null, zoom: s.trigger === 'hold' ? 'the view slowly pushes in' : null,
    });
    const hit = phr(ko ? { invert: '임팩트 프레임 2컷(반전 실루엣)', flash: '첫 섬광 프레임 유지' } : { invert: 'two impact frames (inverted silhouettes)', flash: 'hold the first flash frame' });
    const burst = phr(ko ? {
      flash: '섬광', glow: '후광 최대', ring: '충격파 링', sparks: '스파크 방사', shards: '파편 비산', rays: '광선 펼침', lightning: '번개',
      trail: '궤적을 남기며 날아가는 빛', confetti: '색종이 분출', shake: '화면 흔들림', zoom: '줌 펀치', chroma: '색 분리',
      textPop: '결과 텍스트 등장', squash: '늘어났다가 스프링 복귀', slowmo: '지정 등급의 슬로 모션',
    } : {
      flash: 'flash', glow: 'glow peaks', ring: 'shockwave rings', sparks: 'sparks radiate', shards: 'shards scatter', rays: 'rays unfold', lightning: 'lightning',
      trail: 'light bolts fly out leaving trails', confetti: 'confetti bursts', shake: 'screen shake', zoom: 'zoom punch', chroma: 'chromatic split',
      textPop: 'result text pops in', squash: 'stretch, then spring back', slowmo: 'slow motion on its tier',
    });
    const after = phr(ko ? {
      embers: '불씨가 떠오른다', rays: '광선이 옅어진다', glow: '후광이 식는다', confetti: '색종이가 흔들리며 떨어진다', textPop: '텍스트는 안착해 유지되다 마지막 25%에 사라진다', sparks: '남은 스파크가 식어 사라진다',
    } : {
      embers: 'embers rise', rays: 'rays fade', glow: 'the glow cools', confetti: 'confetti flutters down', textPop: 'text settles, then fades in the last 25%', sparks: 'remaining sparks cool and vanish',
    });
    const holdAntic = s.trigger === 'hold'
      ? L('누르는 동안 충전값이 0에서 1로 오른다(' + ph.anticipation + 'ms에 가득). 가득 차거나 손을 떼면 다음 단계로 넘어가고 짧은 탭도 동작한다. ', 'While held, charge rises from 0 to 1 (full at ' + ph.anticipation + ' ms). Full charge or release moves on; a quick tap also works. ')
      : '';
    phaseDefs.forEach((x) => {
      let body = '';
      if (x.key === 'anticipation') body = holdAntic + (antic.length ? list(antic) : L('짧은 준비 동작', 'a short wind-up'));
      if (x.key === 'hitstop') body = L('모든 월드 움직임을 멈춘다. ', 'Freeze all world motion. ') + (hit.length ? list(hit) + '. ' : '') + L('멈춤이 임팩트의 무게를 만든다', 'The pause gives the hit its weight');
      if (x.key === 'burst') body = burst.length ? list(burst) : L('핵심 변화', 'the main change');
      if (x.key === 'afterglow') body = after.length ? list(after) : L('모든 요소가 부드럽게 사라진다', 'everything fades out softly');
      add('- ' + x.name + ' ' + x.ms + 'ms: ' + body + '.');
    });
    if (s.tierStretch && top > 1) add(L('- 등급이 1 오를 때마다 HITSTOP과 AFTERGLOW 길이가 20%씩 늘어난다.', '- Each tier step lengthens HITSTOP and AFTERGLOW by 20%.'));
    add(L('- 상태 전환은 고정 1/60초 스텝의 누적 시간으로 판단하고, 각 상태의 진행률 t(0~1)를 연출 함수에 넘긴다. 연출 함수는 t만 받는 순수 함수로 둔다.',
      '- Phase changes run on accumulated fixed 1/60 s steps; each phase passes its progress t (0 to 1) to pure functions of t that drive the visuals.'));
    add('');

    // 6. 구성 요소
    const tierTag = (id) => (top > 1 ? L(' (등급 ' + tierOf(id) + '부터)', ' (tier ' + tierOf(id) + '+)') : '');
    const detail = {
      flash: L('임팩트 첫 프레임에 하이라이트 색 섬광. ' + (d.ii >= 3 ? '화면 전체를 덮고' : '주인공 중심 반지름 0.6 unit 원 안에서만 번지고') + ' 최대 불투명도 ' + d.flashAlpha + ', ' + d.flashMs + 'ms 안에 사라진다.',
        'Highlight-colour flash on the first impact frame' + (d.ii >= 3 ? ', covering the whole frame' : ', confined to a 0.6 unit radius around the subject') + '; peak opacity ' + d.flashAlpha + ', gone within ' + d.flashMs + ' ms.'),
      glow: L('주인공 뒤 후광, 반지름 0.35 unit(등급마다 +15%). 예고에서 25%에서 75%로, 임팩트에서 100%, 여운에서 0으로.', 'Glow behind the subject, radius 0.35 unit (+15% per tier): 25% to 75% during anticipation, 100% at impact, 0 by the end of afterglow.')
        + (d.pixel ? L(' 디더 동심원 3단으로 그린다.', ' Draw it as three dithered concentric discs.') : ''),
      rays: L('광선 ' + counts('rays', 'rays') + '개(등급 순), 길이 0.7 unit, 초당 0.15회전. 폭발에서 펼쳐지고 여운 동안 사라진다.', counts('rays', 'rays') + ' rays per tier, 0.7 unit long, rotating 0.15 turns per second; they unfold in the burst and fade through the afterglow.'),
      rim: L('주인공 외곽 ' + (d.pixel ? '1px' : '0.02 unit') + ' 빛 테두리. 예고 진행률만큼 밝아지고 임팩트 직후 가장 밝다.', (d.pixel ? '1 px' : '0.02 unit') + ' rim light around the subject; brightens with anticipation progress and peaks right after impact.'),
      sparks: L('스파크 ' + counts('sparks', 'sparks') + '개(등급 순). 초속 0.6~1.4 unit로 방사, 감속 계수 3/s, 수명 0.4~0.8초. 색은 수명에 따라 하이라이트, 강조색, 어두운 강조색 순으로 단계 변화 후 소멸.',
        counts('sparks', 'sparks') + ' sparks per tier, radiating at 0.6 to 1.4 unit/s with drag 3/s and 0.4 to 0.8 s life. Colour steps highlight to accent to dark accent over life, then despawn.'),
      shards: L('조각 ' + counts('shards', 'shards') + '개(등급 순)가 초당 최대 2회전하며 흩어지고 중력 1.2 unit/s²로 떨어진다. 수명 0.7~1.1초.' + (d.shape === 'card' ? ' 카드 뒷면이 조각나 떨어져 나가며 앞면이 드러난다.' : ''),
        counts('shards', 'shards') + ' shards per tier spin up to 2 turns per second and fall with 1.2 unit/s^2 gravity; life 0.7 to 1.1 s.' + (d.shape === 'card' ? ' The card back breaks away to expose the face.' : '')),
      orbit: L('입자 ' + counts('orbit', 'orbit') + '개(등급 순)가 반지름 0.45 unit 궤도에서 시작해 충전에 따라 초당 1회전에서 4회전으로 빨라지며 중심으로 수렴. 중심에 닿으면 풀로 반납.',
        counts('orbit', 'orbit') + ' particles per tier start on a 0.45 unit orbit, spin up from 1 to 4 turns per second with charge and converge on the centre, returning to the pool when they arrive.'),
      embers: L('여운 동안 초당 ' + d.emberRate + '개씩 생성, 0.15 unit/s로 떠오르며 깜빡이고 수명 1.2초.', 'During afterglow spawn ' + d.emberRate + ' per second, rising at 0.15 unit/s with flicker, 1.2 s life.'),
      confetti: L('색종이 ' + counts('confetti', 'confetti') + '개(등급 순)가 위로 터진 뒤 좌우로 흔들리며 떨어진다. 뒤집힐 때 폭이 cos로 변하고 명암이 바뀐다. 강조색을 섞어 쓴다.',
        counts('confetti', 'confetti') + ' confetti pieces per tier burst upward, then sway down; width follows cos as they flip and the shade changes. Mix the accent colours.'),
      trail: L('빛 덩어리 ' + counts('comets', 'trail') + '개(등급 순)가 궤적을 남기며 날아간다. 이전 위치 8개를 링 버퍼로 보관해 뒤로 갈수록 작고 어둡게 그린다.',
        counts('comets', 'trail') + ' light bolts per tier fly out leaving trails; keep the last 8 positions in a ring buffer and draw them smaller and darker toward the tail.'),
      ring: L('충격파 링 ' + counts('rings', 'ring') + '개(등급 순), 90ms 간격. 반지름 0.12에서 0.57 unit(easeOutExpo), 두께 0.05 unit에서 0, 밝기 1에서 0, 수명 500ms 이하.',
        counts('rings', 'ring') + ' shockwave rings per tier, 90 ms apart; radius 0.12 to 0.57 unit (easeOutExpo), thickness 0.05 unit to 0, brightness 1 to 0, life up to 500 ms.'),
      lightning: L('중심에서 0.45 unit 밖으로 갈라지는 번개 ' + counts('bolts', 'lightning') + '줄(등급 순). 6마디 지그재그 경로를 60ms마다 다시 만들고, 코어는 하이라이트, 바깥은 강조색.',
        counts('bolts', 'lightning') + ' lightning bolts per tier fork out to 0.45 unit; rebuild each 6-segment zigzag every 60 ms, highlight core with an accent edge.'),
      cracks: L('충전 25/50/75/100% 지점마다 균열 가지 1개(4~6마디)가 뻗고, 그때마다 작은 떨림과 crack cue.' + (top > 1 ? ' 균열 빛은 충전에 따라 등급 1 강조색에서 실제 등급 색까지만 올라가 결과를 예고한다.' : ''),
        'At 25/50/75/100% charge a crack branch (4 to 6 segments) grows, each with a small jolt and a crack cue.' + (top > 1 ? ' Crack light climbs from the tier 1 accent up to the real tier colour only, hinting the outcome.' : '')),
      textPop: L('결과 텍스트(' + d.texts.filter(Boolean).join(', ') + ')가 1.6배로 튀어나와 스프링으로 1배에 안착한다. TextPainter는 재생 시작 때 한 번만 layout한다.',
        'Result text (' + d.texts.filter(Boolean).join(', ') + ') pops in at 1.6x and springs to 1x. Lay out the TextPainter once when playback starts.'),
      squash: L('예고에서 가로 +12% 세로 -12%로 눌리고, 임팩트에서 가로 -10% 세로 +15%로 늘어난 뒤 감쇠 스프링으로 복귀.', 'Compress to +12% width / -12% height in anticipation, stretch to -10% / +15% at impact, then return on a damped spring.'),
      shake: L('최대 ' + (d.pixel ? d.shakePx + 'px' : d.shakePct + '% (짧은 변 기준)') + ' 흔들림, 등급마다 +25%, 300ms 동안 감쇠. 방향은 시드 난수. 오프셋을 컨트롤러 값으로 노출해 부모가 보드 같은 원하는 위젯에 적용할 수 있게 한다.',
        'Shake up to ' + (d.pixel ? d.shakePx + ' px' : d.shakePct + '% of the shorter side') + ', +25% per tier, decaying over 300 ms with seeded direction. Expose the offset on the controller so a parent can apply it to any widget such as the board.'),
      zoom: L('임팩트에 ' + d.zoom + '배로 확대 후 250ms 동안 복귀(등급마다 +0.01). 줌 값도 컨트롤러로 노출.', 'Punch to ' + d.zoom + 'x at impact and return over 250 ms (+0.01 per tier). Expose zoom on the controller too.'),
      chroma: L('임팩트 후 140ms 동안 주인공과 밝은 요소를 빨강과 청록으로 좌우 ' + (d.pixel ? '1px' : '0.012 unit') + '씩 어긋나게 한 번 더 그린다. 전면 합성 레이어는 쓰지 않는다.',
        'For 140 ms after impact redraw the subject and bright elements offset ' + (d.pixel ? '1 px' : '0.012 unit') + ' left in red and right in cyan. No full-screen compositing layer.'),
      invert: L('HITSTOP 동안 2컷: 배경색 바탕에 하이라이트 실루엣과 속도선, 이어서 하이라이트 바탕에 배경색 실루엣. 컷당 1~2프레임.',
        'Two cuts during HITSTOP: highlight silhouette with speed lines on the background colour, then a background-colour silhouette on the highlight. 1 to 2 frames each.'),
      vignette: L('예고 진행률만큼 가장자리를 배경색으로 최대 60% 어둡게 하고 임팩트에서 걷는다.' + (d.pixel ? ' 디더 테두리로 그린다.' : ''),
        'Darken the edges toward the background colour by up to 60% with anticipation progress; clear it at impact.' + (d.pixel ? ' Draw it as a dithered border.' : '')),
      slowmo: L('이 등급에서는 폭발 초반 45% 구간을 시간 배율 0.35로 재생한다. 입자와 연출은 월드 시간, 텍스트와 UI는 실제 시간.',
        'On this tier the first 45% of the burst runs at 0.35x time. Particles and visuals use world time; text and UI use real time.'),
    };
    add(L('## 구성 요소', '## Elements'));
    d.layers.forEach((l) => add('- **' + (ko ? l.label : l.en) + '**' + tierTag(l.id) + ': ' + detail[l.id]));
    add('');

    // 7. 등급
    if (top > 1) {
      add(L('## 등급별 강화', '## Tier escalation'));
      add(L('위 등급은 아래 등급의 요소를 모두 포함하고 더한다. 어떤 요소도 지정 등급 아래에서 나오지 않는다. 최상위 등급은 따로 기억에 남는 시그니처가 있어야 한다.',
        'Each tier keeps everything from the tiers below and adds more. No element ever appears below its tier. The top tier needs a memorable signature of its own.'));
      add('');
      add(L('| 등급 | 이름 | 스파크 | 파편 | 색종이 | 최대 입자 | 새로 켜지는 요소 |', '| Tier | Name | Sparks | Shards | Confetti | Max particles | New elements |'));
      add('|---|---|---|---|---|---|---|');
      d.tierList.forEach((t, i) => {
        add('| ' + t.tier + ' | ' + d.tierNames[i] + ' | ' + t.sparks + ' | ' + t.shards + ' | ' + t.confetti + ' | ' + t.total + ' | ' + (t.newLayers.length ? t.newLayers.map(layerName).join(', ') : '-') + ' |');
      });
      add('');
    }
    if (d.maxTotal > s.maxParticles) add(L('최상위 등급 예상 입자가 예산 ' + s.maxParticles + '개를 넘는다. 넘으면 종류별로 비례 축소한다.', 'The top tier exceeds the ' + s.maxParticles + ' particle budget; scale each kind down proportionally.'), '');

    // 8. 접근성과 피드백
    add(L('## 접근성과 피드백', '## Accessibility and feedback'));
    add(s.reducedMotion === 'final'
      ? L('- ' + code('MediaQuery.disableAnimationsOf(context)') + '가 true면 연출을 건너뛰고 최종 상태를 즉시 보여 준다. 완료 콜백은 그대로 1회 호출한다.', '- When ' + code('MediaQuery.disableAnimationsOf(context)') + ' is true, skip the animation and show the final state at once; still fire the completion callback exactly once.')
      : L('- ' + code('MediaQuery.disableAnimationsOf(context)') + '가 true면 흔들림, 줌, 섬광, 색 분리, 슬로 모션을 끄고 입자를 30%로 줄인 짧은 페이드 버전으로 재생한다.', '- When ' + code('MediaQuery.disableAnimationsOf(context)') + ' is true, play a short fade version: no shake, zoom, flash, chromatic split or slow motion, and 30% of the particles.'));
    if (has('flash') || has('invert') || has('chroma')) add(L('- 밝기가 크게 바뀌는 전면 섬광과 반전은 1초에 3회를 넘기지 않는다.', '- Large full-frame brightness changes (flash, inversion) never exceed 3 per second.'));
    if (s.haptics !== 'none') add(L('- 햅틱(' + code('HapticFeedback') + '): 임팩트에서 ' + (top > 2 ? '등급 1~2는 lightImpact, 3은 mediumImpact, 4는 heavyImpact' : '등급 1은 lightImpact, 그 위는 mediumImpact') + (s.haptics === 'rich' ? '. 충전 단계나 균열마다 selectionClick' : '') + '. 웹에서는 무시될 수 있다.',
      '- Haptics (' + code('HapticFeedback') + '): at impact ' + (top > 2 ? 'lightImpact for tiers 1 to 2, mediumImpact for 3, heavyImpact for 4' : 'lightImpact for tier 1, mediumImpact above') + (s.haptics === 'rich' ? '; selectionClick at each charge step or crack' : '') + '. It may be a no-op on web.'));
    if (s.sound !== 'none') {
      const cues = (s.trigger === 'hold' ? 'chargeStart, ' : '') + (has('cracks') ? 'crack, ' : '') + 'impact, ' + (top > 1 ? 'tierReveal, ' : '');
      add(L('- 소리: 이펙트는 오디오를 직접 재생하지 않는다. ' + code('onCue(' + P + 'Cue cue, int tier)') + ' 콜백으로 ' + cues + 'complete 시점을 알려 앱의 오디오 매니저가 재생하게 한다.',
        '- Sound: the effect never plays audio itself. It calls ' + code('onCue(' + P + 'Cue cue, int tier)') + ' at ' + cues + 'and complete so the app\'s audio manager can play sounds.'));
      if (s.sound === 'design') add(L('- 각 cue에 어울리는 소리 설계(음색, 길이, 음높이 변화, 등급별 차이)를 표로 제안한다.', '- Propose a sound design table for each cue: timbre, length, pitch movement, and differences per tier.'));
    }
    add('');

    // 9. Flutter 구현
    if (wantsDart) {
      add(L('## Flutter 구현 규칙', '## Flutter implementation rules'));
      const ctrl = ['play({int tier = 1})', 'stop()', 'isPlaying', 'onComplete'];
      if (s.trigger === 'hold') ctrl.push('press()', 'release()', 'charge');
      if (s.sound !== 'none') ctrl.push('onCue');
      if (has('shake')) ctrl.push('shakeOffset');
      if (has('zoom')) ctrl.push('zoom');
      add(L('- ' + code(P + 'Spec') + ': const 생성자에 모든 길이, 시간, 개수, 색, 등급 표를 둔다. 코드 곳곳에 매직 넘버를 두지 않는다.', '- ' + code(P + 'Spec') + ': a const constructor holding every length, duration, count, colour and the tier table. No magic numbers elsewhere.'));
      add(L('- ' + code(P + 'Controller') + '(ChangeNotifier): ' + ctrl.map(code).join(', ') + '.', '- ' + code(P + 'Controller') + ' (ChangeNotifier): ' + ctrl.map(code).join(', ') + '.'));
      add(L('- 상태 머신과 입자 시뮬레이션은 위젯과 분리된 순수 Dart 클래스로 두어, 테스트에서 시간만 흘려 검증할 수 있게 한다.', '- Keep the state machine and particle simulation in plain Dart classes, separate from widgets, so tests can drive them by advancing time.'));
      if (s.target === 'flame') {
        add(L('- ' + code('PositionComponent') + '를 상속한 ' + code(P + 'Component') + '의 ' + code('update(double dt)') + '와 ' + code('render(Canvas canvas)') + '로 구현한다. dt는 1/20초로 자르고 고정 1/60초 스텝으로 나눠 처리한다.', '- Implement ' + code(P + 'Component extends PositionComponent') + ' with ' + code('update(double dt)') + ' and ' + code('render(Canvas canvas)') + '. Clamp dt to 1/20 s and consume it in fixed 1/60 s steps.'));
        add(L('- 컴포넌트를 미리 만들어 마운트해 두고 활성 여부로 재사용한다. 이벤트마다 add와 remove를 반복하지 않는다.', '- Pre-create and mount the components, then reuse them by toggling an active flag. Never add and remove per event.'));
        add(L('- 대량 입자는 이벤트마다 객체를 만드는 Flame ' + code('Particle') + ' 대신 고정 크기 typed 버퍼와 ' + code('drawRawAtlas') + '로 그린다. ' + code('priority') + '로 겹침 순서를 명시한다.', '- Draw bulk particles from fixed typed buffers with ' + code('drawRawAtlas') + ' instead of Flame ' + code('Particle') + ' objects created per event. Set draw order explicitly with ' + code('priority') + '.'));
      } else {
        add(L('- ' + code('StatefulWidget') + '과 ' + code('SingleTickerProviderStateMixin') + '의 ' + code('Ticker') + '로 경과 시간을 받는다. 고정 1/60초 누적기로 update하고 프레임 간격이 1/20초를 넘으면 잘라 낸다. 재생하지 않을 때는 Ticker를 멈춘다.', '- Use a ' + code('StatefulWidget') + ' with ' + code('SingleTickerProviderStateMixin') + ' and a ' + code('Ticker') + ' for elapsed time. Update with a fixed 1/60 s accumulator, clamp frame gaps to 1/20 s, and stop the ticker when idle.'));
        add(L('- ' + code('CustomPainter(repaint: controller)') + '로 다시 그려 ' + code('setState') + ' 없이 갱신한다. ' + code('shouldRepaint') + '는 Spec이 바뀔 때만 true.', '- Repaint through ' + code('CustomPainter(repaint: controller)') + ' instead of ' + code('setState') + '. ' + code('shouldRepaint') + ' returns true only when the Spec changes.'));
        add(L('- ' + code('RepaintBoundary') + '로 감싸 주변 위젯과 레이어를 분리하고, ' + (s.trigger === 'hold' ? '누르기 입력은 ' + code('GestureDetector') + '로 받는다.' : '입력은 ' + code('IgnorePointer') + '로 통과시킨다.'), '- Wrap it in a ' + code('RepaintBoundary') + '; ' + (s.trigger === 'hold' ? 'take press input through a ' + code('GestureDetector') + '.' : 'let input pass through with ' + code('IgnorePointer') + '.')));
      }
      if (s.target === 'shader') {
        add(L('- 후광, 광선, 왜곡, 색 분리처럼 면적이 큰 빛은 ' + code('shaders/' + d.snake + '.frag') + ' 조각 셰이더로, 입자와 파편은 CustomPainter로 그린다.', '- Draw large-area light (glow, rays, distortion, chromatic split) with a ' + code('shaders/' + d.snake + '.frag') + ' fragment shader; draw particles and shards with the CustomPainter.'));
        add(L('- 셰이더는 ' + code('#include <flutter/runtime_effect.glsl>') + '와 ' + code('FlutterFragCoord()') + '를 쓰고 uniform은 float와 sampler2D만 쓴다. ' + code('FragmentProgram.fromAsset') + '으로 한 번 로드해 ' + code('FragmentShader') + '를 재사용하고, 매 프레임 ' + code('setFloat') + '로 시간, 진행률, 등급, 크기, 색을 넘긴다.', '- The shader uses ' + code('#include <flutter/runtime_effect.glsl>') + ' and ' + code('FlutterFragCoord()') + ', with only float and sampler2D uniforms. Load once with ' + code('FragmentProgram.fromAsset') + ', reuse the ' + code('FragmentShader') + ', and push time, progress, tier, size and colours with ' + code('setFloat') + ' each frame.'));
        add(L('- pubspec의 ' + code('flutter: shaders:') + '에 파일을 등록한다. 로드 실패나 미지원 환경에서는 셰이더 없이 그리는 대체 경로로 동작한다.', '- Register the file under ' + code('flutter: shaders:') + ' in pubspec. If loading fails or shaders are unsupported, fall back to a shader-free drawing path.'));
      }
      if (s.perf.seeded) add(L('- 난수는 ' + code('Random(seed)') + '로 받아 같은 시드면 같은 연출이 나오게 한다.', '- Take randomness from ' + code('Random(seed)') + ' so the same seed replays the same effect.'));
      add(L('- ' + code('Paint') + ', ' + code('Path') + ', ' + code('TextPainter') + ', 이미지 같은 객체는 재사용하고 ' + code('dispose') + '에서 Ticker, 이미지(' + code('ui.Image.dispose') + '), 컨트롤러 구독을 정리한다.', '- Reuse ' + code('Paint') + ', ' + code('Path') + ', ' + code('TextPainter') + ' and images; in ' + code('dispose') + ' release the ticker, images (' + code('ui.Image.dispose') + ') and controller listeners.'));
      if (s.platforms.includes('web')) add(L('- 웹(Wasm의 skwasm, CanvasKit)에서 같은 결과여야 한다. 매 프레임 ' + code('saveLayer') + ', ' + code('ImageFilter.blur') + ', ' + code('MaskFilter.blur') + '를 쓰지 않고, 큰 반투명 전면 사각형은 프레임당 1개 이하로 둔다.', '- Web (Wasm skwasm and CanvasKit) must look the same. No per-frame ' + code('saveLayer') + ', ' + code('ImageFilter.blur') + ' or ' + code('MaskFilter.blur') + '; at most one large translucent full-screen rect per frame.'));
      if (s.platforms.includes('ios') || s.platforms.includes('android')) add(L('- 60Hz와 120Hz 화면에서 속도가 같아야 한다(시간 기반 업데이트). 저사양 모바일을 기준으로 예산을 잡는다.', '- Speed must match on 60 Hz and 120 Hz displays (time-based updates). Budget for low-end phones.'));
      if (s.platforms.includes('desktop')) add(L('- 창 크기를 바꾸는 중에도 비율과 선명도가 유지되어야 한다.', '- Proportions and sharpness must hold while the window resizes.'));
      add('');
    }

    // 10. 성능 예산
    add(L('## 성능 예산', '## Performance budget'));
    add(L('- 입자 최대 ' + s.maxParticles + '개, 프레임당 draw 호출 ' + s.maxDrawCalls + '회 이하, 목표 60fps.', '- At most ' + s.maxParticles + ' particles, ' + s.maxDrawCalls + ' draw calls per frame, targeting 60 fps.'));
    if (s.perf.pool) add(L('- 입자는 고정 크기 풀(' + code('Float32List') + ', ' + code('Int32List') + ')에 담아 재사용한다. 프레임 루프 안에서 ' + code('List') + ', ' + code('Offset') + ', 클로저 같은 객체를 만들지 않는다.', '- Particles live in fixed-size pools (' + code('Float32List') + ', ' + code('Int32List') + '). Allocate nothing inside the frame loop: no ' + code('List') + ', ' + code('Offset') + ' or closures.'));
    if (s.perf.atlas) add(L('- 같은 아틀라스를 쓰는 입자는 ' + code('drawRawAtlas') + ' 한 번으로 묶어 그린다.', '- Batch particles that share an atlas into a single ' + code('drawRawAtlas') + ' call.'));
    if (s.perf.noBlur) add(L('- 런타임 blur, 그림자, ' + code('saveLayer') + '를 쓰지 않는다. 부드러운 빛은 미리 구운 텍스처로 만든다.', '- No runtime blur, shadows or ' + code('saveLayer') + '; soft light comes from pre-baked textures.'));
    if (s.perf.fixedStep) add(L('- 고정 1/60초 스텝 업데이트, dt 상한 1/20초.', '- Fixed 1/60 s update steps with dt clamped to 1/20 s.'));
    if (s.perf.autoQuality) add(L('- 최근 30프레임 평균이 18ms를 넘으면 입자 수를 75%, 50%로 단계적으로 줄이고, 현재 품질 단계를 컨트롤러에서 읽을 수 있게 한다.', '- If the last 30 frames average over 18 ms, step particle counts down to 75% then 50%, and expose the current quality level on the controller.'));
    add('');

    // 11. HTML 프로토타입
    if (wantsHtml) {
      add(L('## HTML 프로토타입 규칙', '## HTML prototype rules'));
      add(L('- 단일 HTML 파일. 외부 에셋, 라이브러리, 폰트, 네트워크 요청 없음.', '- One self-contained HTML file. No external assets, libraries, fonts or network requests.'));
      add(L('- Canvas 2D에서 Flutter Canvas로 1:1 옮길 수 있는 호출만 쓴다: fillRect는 drawRect, arc는 drawCircle과 drawArc, Path2D는 Path, drawImage(부분 사각형)는 drawImageRect나 drawRawAtlas, globalCompositeOperation "lighter"는 BlendMode.plus, globalAlpha는 Paint 색 알파, save/translate/rotate/scale은 같은 이름, imageSmoothingEnabled=false는 FilterQuality.none.',
        '- Use only Canvas 2D calls with a one-to-one Flutter Canvas equivalent: fillRect to drawRect, arc to drawCircle or drawArc, Path2D to Path, drawImage with a source rect to drawImageRect or drawRawAtlas, globalCompositeOperation "lighter" to BlendMode.plus, globalAlpha to the Paint colour alpha, save/translate/rotate/scale to the same names, imageSmoothingEnabled=false to FilterQuality.none.'));
      add(L('- 쓰지 않는다: CSS 애니메이션과 필터, ctx.filter, shadowBlur, DOM 요소로 만든 이펙트, Web Audio. 소리 대신 cue 이름을 화면 구석 로그에 찍는다.', '- Do not use CSS animations or filters, ctx.filter, shadowBlur, DOM-element effects, or Web Audio. Log cue names in a corner instead of playing sound.'));
      add(L('- 모든 수치는 파일 위쪽 ' + code('SPEC') + ' 객체 하나에 모으고' + (wantsDart ? ' Dart ' + code(P + 'Spec') + '과 이름과 값을 같게 한다.' : ' 이름은 나중에 Dart로 옮길 수 있게 camelCase로 둔다.'), '- Keep every number in one ' + code('SPEC') + ' object at the top' + (wantsDart ? ', with the same names and values as the Dart ' + code(P + 'Spec') + '.' : ', named in camelCase so it ports cleanly to Dart.')));
      add(L('- requestAnimationFrame과 고정 60Hz 스텝, 루프 안 객체 생성 금지. 확인용 컨트롤: 등급 버튼, 다시 재생, 0.25배속.', '- requestAnimationFrame with a fixed 60 Hz step and no allocation in the loop. Controls: tier buttons, replay, 0.25x speed.'));
      if (wantsDart) add(L('- HTML에서 타이밍과 느낌을 확정한 뒤 Dart로 옮기고, 두 구현의 SPEC 값이 같은지 표로 보여 준다.', '- Lock timing and feel in HTML first, then port to Dart and show a table proving both SPECs match.'));
      else add(L('- 파일 끝 주석에 사용한 Canvas 2D 호출과 Flutter 대응 API 표를 붙인다.', '- End the file with a comment table mapping each Canvas 2D call used to its Flutter API.'));
      add('');
    }

    // 12. 프로젝트 맥락
    if (s.context === 'stonematch') {
      add(L('## 프로젝트 맥락 (Stone Match)', '## Project context (Stone Match)'));
      add(L('- Flutter 3.44, Dart 3.10, Flame 1.35.1 기반 8x8 매치 3 게임이다. 새 dependency를 추가하지 않는다.', '- An 8x8 match-3 game on Flutter 3.44, Dart 3.10 and Flame 1.35.1. Do not add dependencies.'));
      add(L('- 작업 전에 ' + code('docs/progress/PROJECT_STATUS.md') + '와 ' + code('docs/progress/HANDOFF.md') + '를 읽는다.', '- Read ' + code('docs/progress/PROJECT_STATUS.md') + ' and ' + code('docs/progress/HANDOFF.md') + ' first.'));
      add(L('- 기존 연출 패턴을 재사용한다: ' + code('lib/game/components/special_effect_pool.dart') + '(미리 만든 버스트를 마운트한 채 재사용), ' + code('board_juice_layer.dart') + '(고정 크기 typed 버퍼와 프레임당 ' + code('drawRawAtlas') + ' 1회), ' + code('baked_glow_atlas.dart') + '(흰 글로우를 한 번 구워 색을 입혀 ' + code('BlendMode.plus') + '로 그림), ' + code('bomb_layer_timeline.dart') + '(정규화 t를 받는 객체 생성 없는 순수 함수 타임라인).',
        '- Reuse the existing FX patterns: ' + code('lib/game/components/special_effect_pool.dart') + ' (pre-built bursts kept mounted and reused), ' + code('board_juice_layer.dart') + ' (fixed typed buffers, one ' + code('drawRawAtlas') + ' per frame), ' + code('baked_glow_atlas.dart') + ' (white glow baked once, tinted, drawn with ' + code('BlendMode.plus') + '), ' + code('bomb_layer_timeline.dart') + ' (allocation-free pure timeline of normalized t).'));
      add(L('- 모션 줄이기는 ' + code('lib/widgets/overlay_motion.dart') + '처럼 ' + code('MediaQuery.disableAnimationsOf') + '를 따른다. 성능 기준은 모바일 웹(앱인토스 WebView 포함)이다.', '- Follow ' + code('MediaQuery.disableAnimationsOf') + ' as ' + code('lib/widgets/overlay_motion.dart') + ' does. The performance baseline is mobile web, including the Apps in Toss WebView.'));
      add(L('- 사용자에게 보이는 문구에 중간점 문자를 쓰지 않는다. 임시 산출물은 ' + code('tmp/') + ' 아래 작업별 폴더에 둔다.', '- User-facing text must not contain the middle dot character. Put temporary artifacts in a task folder under ' + code('tmp/') + '.'));
      add('');
    }

    // 13. 품질 기준
    const bar = {
      1: L('은은하게: 눈에 거슬리지 않고 오래 봐도 피곤하지 않다.', 'Subtle: never distracting, comfortable to watch for a long time.'),
      2: L('산뜻하게: 짧고 또렷하게 반응해 손맛이 느껴진다.', 'Crisp: short, clear, satisfying feedback.'),
      3: L('쥬시하게: 예고와 임팩트의 대비가 분명하고 반복해서 보고 싶다.', 'Juicy: clear contrast between wind-up and hit; you want to see it again.'),
      4: L('아주 쥬시하게: 화면이 크게 반응하지만 주인공과 결과 정보는 끝까지 읽힌다.', 'Very juicy: the screen reacts hard, yet the subject and result stay readable.'),
      5: L('언리얼: 화면 전체가 반응하고 최상위 등급은 따로 기억에 남는다. 그래도 리듬이 있고 번쩍임이 과하지 않다.', 'Unreal: the whole screen reacts and the top tier is unforgettable, while keeping rhythm and avoiding excessive flashing.'),
    }[s.intensity];
    add(L('## 품질 기준', '## Quality bar'));
    add('- ' + bar);
    add(L('- 예고, 정지, 폭발, 여운의 대비가 한눈에 읽히고 임팩트 순간이 가장 밝고 크다.', '- The wind-up, freeze, burst and afterglow read at a glance; the impact is the brightest, biggest moment.'));
    add(L('- 배경 위에서 주인공 실루엣이 항상 읽힌다.', '- The subject silhouette always reads against the background.'));
    if (s.strictPalette) add(L('- 팔레트 밖 색이 한 픽셀도 없다.', '- Not a single pixel outside the palette.'));
    if (d.pixel) add(L('- 어떤 화면 크기에서도 픽셀이 선명하고 크기가 고르다.', '- Crisp, evenly sized pixels at any screen size.'));
    add(L('- 끝나면 활성 입자 0, 상태는 ' + (s.playback === 'loop' ? 'IDLE' : 'DONE') + '. 100회 반복 재생해도 메모리가 늘지 않는다.', '- When finished: zero live particles and state ' + (s.playback === 'loop' ? 'IDLE' : 'DONE') + '. Memory stays flat over 100 replays.'));
    add('');

    // 14. 완료 전 확인
    add(L('## 완료 전 확인', '## Before you finish'));
    if (wantsDart) add(L('- ' + code('flutter analyze') + ' 경고 0.', '- ' + code('flutter analyze') + ' reports no issues.'));
    if (wantsDart && s.deliverables.test) add(L('- ' + code('flutter test test/' + d.snake + '_effect_test.dart') + ' 통과.', '- ' + code('flutter test test/' + d.snake + '_effect_test.dart') + ' passes.'));
    if (top > 1) add(L('- 등급 1부터 ' + top + '까지 차례로 재생해 등급 규칙을 확인한다.', '- Play tiers 1 through ' + top + ' in order and confirm the tier rules.'));
    add(L('- 모션 줄이기를 켠 상태에서도 재생해 본다.', '- Play it once with reduced motion enabled.'));
    if (s.perf.pool) add(L('- 프레임 루프 안에 객체 생성이 없는지 코드로 확인해 목록으로 보고한다.', '- Check the frame loop for allocations and report what you checked.'));
    add(L('- 마지막에 파일 목록, 공개 API, Spec 주요 값, 알려진 한계를 요약한다. 애매한 부분은 합리적으로 정하고 요약에 적는다.', '- Finish with a summary: files, public API, key Spec values, known limits. Resolve ambiguities sensibly and list them there.'));
    return out.join('\n');
  };

  FX.buildFollowUps = function (state) {
    const d = FX.derive(state);
    const s = d.s;
    const ko = d.lang === 'ko';
    const L = (k, e) => (ko ? k : e);
    const code = (x) => '`' + x + '`';
    const topName = d.tierNames[d.tiers - 1];
    const items = [{
      title: '더 쥬시하게',
      text: L('지금 결과를 유지한 채 더 쥬시하게 만들어 줘.\n1. 예고: 긴장이 쌓이게 한다. 심장박동 같은 펄스, 수렴 입자 가속, 점점 커지는 떨림.\n2. 임팩트: 히트스톱을 살리고 섬광이나 반전 프레임으로 한 박자 강조한다.\n3. 여운: 약 0.3초 뒤 2차 충격(작은 링과 스파크)을 더한다.\n제약 시트, 성능 예산, 등급 규칙은 그대로 지키고 바뀐 점을 등급별로 정리해 줘.',
        'Keep everything that works and make it juicier.\n1. Anticipation: build tension with a heartbeat pulse, accelerating converging particles and a growing tremble.\n2. Impact: keep the hitstop and accent it with a flash or impact frame.\n3. Afterglow: add an aftershock about 0.3 s later (a small ring and sparks).\nKeep the constraint sheet, performance budget and tier rules. Summarize the changes per tier.'),
    }];
    if (d.tiers > 1) items.push({
      title: '최상위 등급 시그니처',
      text: L('최상위 등급(' + topName + ')만의 시그니처 연출을 하나 더해 줘. 예: 위에서 내려오는 광기둥, 슬로 모션, 두 번째 충격파. 아래 등급과 한눈에 구분돼야 하고 아래 등급에는 절대 나오지 않는다.',
        'Add one signature moment that only the top tier (' + topName + ') gets, such as a light pillar from above, slow motion or a second shockwave. It must be instantly distinguishable and never appear on lower tiers.'),
    });
    if (d.tiers > 2 && (s.trigger === 'hold' || s.purpose === 'reveal')) items.push({
      title: '페이크아웃 승격',
      text: L('가끔 한 단계 낮은 등급으로 공개된 뒤 약 2초 후 진짜 등급으로 승격되는 연출을 넣어 줘. 최상위 등급의 45%, 그 아래 등급의 30%에서만 일어난다. 승격 때 글리치, 두 번째 정지 프레임, 재공개를 거친다. 시드로 재현 가능해야 한다.',
        'Sometimes reveal one tier lower, then upgrade to the real tier about 2 s later: 45% of top-tier pulls and 30% of the tier below. The upgrade goes through a glitch, a second freeze frame and a re-reveal. It must be reproducible from the seed.'),
    });
    items.push({
      title: '증상 고치기',
      text: L('다음 문제가 보인다: [증상을 구체적으로. 예: 섬광 뒤 화면이 뿌옇게 남는다, 파편이 너무 작아 안 보인다].\n원인을 먼저 짚고, 제약 시트를 어기지 않는 방법으로 고쳐 줘. 고친 뒤 같은 증상이 다시 나오지 않는지 확인한 방법도 알려 줘.',
        'I see this problem: [describe it precisely, e.g. the screen stays washed out after the flash, shards are too small to read].\nExplain the cause first, then fix it without breaking the constraint sheet, and tell me how you verified the symptom is gone.'),
    });
    items.push({
      title: '성능 점검',
      text: L('모바일 웹(Wasm) 기준으로 성능을 점검해 줘. 프레임 루프 안 객체 생성, 프레임당 draw 호출 수, 최상위 등급 최대 입자 수를 확인하고 예산(입자 ' + s.maxParticles + '개, draw ' + s.maxDrawCalls + '회)을 넘는 부분을 고쳐 줘. 프레임이 느려지면 입자 수를 단계적으로 줄이는 품질 자동 하향도 넣어 줘.',
        'Audit performance for mobile web (Wasm): allocations in the frame loop, draw calls per frame, and peak particles on the top tier. Fix anything over budget (' + s.maxParticles + ' particles, ' + s.maxDrawCalls + ' draw calls) and add automatic quality steps that reduce particles when frames slow down.'),
    });
    if (s.output !== 'flutterOnly') items.push({
      title: s.output === 'htmlPortable' ? 'Flutter로 옮기기' : 'HTML과 Dart 대조',
      text: s.output === 'htmlPortable'
        ? L('이 HTML 프로토타입을 Flutter로 옮겨 줘. ' + code(d.pascal + 'Spec') + ', 컨트롤러, ' + FX.byId(FX.TARGETS, s.target).label + ' 구현을 만들고, SPEC 값과 Canvas 2D 호출이 어떤 Dart API로 옮겨졌는지 표로 보여 줘. ' + code('flutter analyze') + ' 경고 0까지 확인해 줘.',
            'Port this HTML prototype to Flutter: build ' + code(d.pascal + 'Spec') + ', the controller and ' + FX.byId(FX.TARGETS, s.target).en + '. Show a table of SPEC values and which Dart API replaced each Canvas 2D call. Get ' + code('flutter analyze') + ' to zero issues.')
        : L('HTML 프로토타입의 SPEC과 Dart ' + code(d.pascal + 'Spec') + ' 값을 표로 대조하고 다른 값을 맞춰 줘. 타이밍이 달라 보이는 구간이 있으면 원인과 수정 내용을 알려 줘.',
            'Compare the HTML SPEC with the Dart ' + code(d.pascal + 'Spec') + ' in a table and fix any mismatch. If any phase feels different in timing, explain why and what you changed.'),
    });
    items.push({
      title: '실제 화면에 연결',
      text: L('완성한 이펙트를 실제 화면에 연결해 줘: [연결할 이벤트와 위치]. ' + (s.context === 'stonematch' ? '기존 ' + code('special_effect_pool.dart') + '나 ' + code('board_juice_layer.dart') + ' 구조를 재사용하고 ' : '기존 구조를 재사용하고 ') + '새 dependency는 추가하지 않는다. 연결 후 관련 테스트와 ' + code('flutter analyze') + '를 실행해 결과를 알려 줘.',
        'Wire the finished effect into the real screen: [event and location]. ' + (s.context === 'stonematch' ? 'Reuse ' + code('special_effect_pool.dart') + ' or ' + code('board_juice_layer.dart') + ' and ' : 'Reuse the existing structure and ') + 'do not add dependencies. Run the related tests and ' + code('flutter analyze') + ' afterwards and report the results.'),
    });
    return items;
  };
})();
