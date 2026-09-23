/* 이펙트 프롬프트 빌더: 선택 상태를 AI 코딩 도구용 프롬프트로 변환 */
(function () {
  'use strict';
  const FX = window.FX;

  FX.buildPrompt = function (state) {
    const d = FX.derive(state);
    const s = d.s;
    const ko = d.lang === 'ko';
    const L = (k, e) => (ko ? k : e);
    const out = [];
    const add = (...lines) => { lines.forEach((x) => { if (x !== null && x !== undefined && x !== false) out.push(x); }); };
    const has = (id) => d.minTier[id] !== undefined;
    const tierOf = (id) => d.minTier[id];
    const code = (x) => '`' + x + '`';
    const style = FX.byId(FX.STYLES, s.style);
    const trig = FX.byId(FX.TRIGGERS, s.trigger);
    const target = FX.byId(FX.TARGETS, s.target);
    const c = d.colors;
    const top = d.tiers;
    const ph = d.phases;
    const dl = d.delivery.id;
    const multi = d.hits > 1;
    const wantsHtml = s.output !== 'flutterOnly';
    const wantsDart = s.output !== 'htmlPortable';
    const base = 'lib/fx/';
    const P = d.pascal;
    const list = (arr) => arr.join(', ');
    const counts = (key, id) => d.tierList.slice((d.minTier[id] || 1) - 1).map((t) => t[key]).join(' / ');
    const layerName = (id) => { const l = FX.byId(FX.LAYERS, id); return ko ? l.label : l.en; };
    const px = (pxv, unitv) => (d.pixel ? pxv + 'px' : unitv + ' unit');

    // 1. 머리말
    add(ko ? '# ' + P + ' 이펙트 제작 요청' : '# Build the ' + P + ' effect', '');
    add(L('여러 게임에 다시 쓸 수 있는 이펙트를 Flutter(Dart)로 만들어 줘. 이펙트는 게임 로직과 분리하고, 발동점과 대상과 영향 지점 좌표를 입력으로 받는다.',
      'Build a reusable game effect in Flutter (Dart). Keep it independent of game logic: it takes the source, the target and the hit points as input coordinates.'));
    add(L('- 종류: ' + d.e.label + '. ' + d.e.desc, '- Type: ' + d.e.en + '.'));
    add(L('- 장면: ', '- Scene: ') + d.subject);
    add(L('- 참고: ' + d.e.ref + '. 동작 구조와 리듬만 참고하고 에셋, 로고, 고유 디자인은 따라 하지 않는다.', '- Reference: ' + d.e.refEn + '. Borrow only the structure and rhythm; do not copy assets, logos or distinctive designs.'));
    add(L('- 발동: ' + d.delivery.label + ' (' + d.delivery.desc + '). 범위: ' + d.area.label + ' (' + d.area.desc + '). 시점: ' + d.view.label + '.',
      '- Delivery: ' + d.delivery.en + '. Area: ' + d.area.en + '. View: ' + d.view.en + '.'));
    const trigText = ko ? { event: '게임 코드가 play()를 호출하면 시작', tap: '탭하면 시작', hold: '길게 누르는 동안 충전하고, 손을 떼거나 가득 차면 발동', auto: '화면에 나오면 자동으로 시작' }[s.trigger] : trig.en;
    const playText = s.playback === 'loop' ? L('끝나면 ' + s.loopGap + 'ms 쉬고 반복', 'loops with a ' + s.loopGap + ' ms rest') : L('한 번 재생하고 대기 상태로 복귀', 'plays once, then returns to idle');
    add(L('- 시작: ' + trigText + '. 재생: ' + playText + '.', '- Trigger: ' + trigText + '. Playback: ' + playText + '.'));
    add(L('- 스타일: ' + style.label + '. 목표 강도: ' + s.intensity + '/5 (' + FX.INTENSITY[d.ii] + ').', '- Style: ' + style.en + '. Target intensity: ' + s.intensity + '/5 (' + FX.INTENSITY_EN[d.ii] + ').'));
    if (top > 1) add(L('- 단계: ' + top + '단계 (' + d.tierNames.join(' < ') + ')', '- Levels: ' + top + ' (' + d.tierNames.join(' < ') + ')'));
    add('');

    // 2. 결과물
    add(L('## 결과물', '## Deliverables'));
    let n = 1;
    if (wantsHtml) add(n++ + '. ' + L(
      code(d.snake + '_preview.html') + ': 브라우저에서 바로 여는 단일 HTML 프로토타입' + (s.deliverables.demo ? '(아래 데모 장면 포함)' : '') + '. ' + (wantsDart ? '먼저 만들어 타이밍과 느낌을 확정한다.' : 'Flutter로 1:1 옮길 수 있게 작성한다.'),
      code(d.snake + '_preview.html') + ': a single-file HTML prototype' + (s.deliverables.demo ? ' with the demo scene below' : '') + '. ' + (wantsDart ? 'Build it first to lock the timing and feel.' : 'Write it so it ports to Flutter one-to-one.')));
    if (wantsDart) {
      add(n++ + '. ' + L(
        code(base + d.snake + '_effect.dart') + ': 모든 수치를 담은 ' + code(P + 'Spec') + ', 상태 머신과 타임라인, 그리기(' + target.label + '), ' + code(P + 'Controller') + '를 한 파일에 둔다. 게임 코드에 의존하지 않는다.',
        code(base + d.snake + '_effect.dart') + ': ' + code(P + 'Spec') + ' with every number, the state machine and timeline, rendering (' + target.en + ') and ' + code(P + 'Controller') + ' in one file, with no dependency on game code.'));
      if (s.deliverables.demo) add(n++ + '. ' + L(code(base + d.snake + '_demo.dart') + ': 아래 데모 장면을 그리는 확인용 화면.', code(base + d.snake + '_demo.dart') + ': a check screen that renders the demo scene below.'));
      if (s.deliverables.test) add(n++ + '. ' + L(
        code('test/' + d.snake + '_effect_test.dart') + ': 단계마다 끝까지 pump했을 때 예외 없음, onHit가 영향 지점 수만큼 정확히 호출됨, 완료 콜백 1회, 남은 활성 입자 0, 모션 줄이기에서 바로 끝나는지 확인한다.',
        code('test/' + d.snake + '_effect_test.dart') + ': for every level, pump to the end and assert no exceptions, onHit called exactly once per hit point, one completion callback, zero live particles, and a quick finish under reduced motion.'));
      if (s.deliverables.tuning) add(n++ + '. ' + L('데모의 수치 조절 패널: 단계 길이, 입자 수, 흔들림 폭을 슬라이더로 바꾸고 바뀐 값을 ' + code(P + 'Spec') + ' 생성자 코드로 복사하는 버튼.', 'A tuning panel in the demo: sliders for phase lengths, particle counts and shake, plus a button that copies the values as ' + code(P + 'Spec') + ' constructor code.'));
    } else if (s.deliverables.tuning) add(n++ + '. ' + L('HTML 안의 수치 조절 패널: 슬라이더로 SPEC 값을 바꾸고 JSON으로 복사.', 'A tuning panel inside the HTML: sliders that edit SPEC and copy it as JSON.'));
    if (s.deliverables.sheet) add(L('각 파일 맨 위에 아래 제약 시트를 주석으로 그대로 옮긴다.', 'Copy the constraint sheet below verbatim as a comment at the top of each file.'));
    add('');

    // 3. 제약 시트
    add(L('## 제약 시트', '## Constraint sheet'), '```');
    const format = d.pixel
      ? L('게임의 논리 픽셀 좌표에 그리고 화면에는 물리 픽셀 기준 정수 배율로 확대. 데모는 ' + d.pixelW + 'x' + d.pixelH + '. 모든 길이는 unit 배수',
          'draw in the game\'s logical pixel space, scaled to the screen by an integer factor in physical pixels; demo canvas ' + d.pixelW + 'x' + d.pixelH + '; every length is a multiple of unit')
      : L('부모 위젯 크기를 따르는 투명 레이어. 모든 길이는 호출자가 넘기는 unit(칸 크기, 캐릭터 키의 절반, 버튼 높이 중 하나)의 배수',
          'a transparent layer that fills its parent; every length is a multiple of the caller-supplied unit (cell size, half a character height, or button height)');
    const accents = c.accents.slice(0, top).join(' ');
    const palette = L('배경 ' + c.bg + ', 몸체 ' + c.subject + ', 하이라이트 ' + c.highlight + ', 단계 강조 ' + accents, 'background ' + c.bg + ', body ' + c.subject + ', highlight ' + c.highlight + ', level accents ' + accents);
    const paletteRule = s.strictPalette
      ? (d.pixel ? L('. 각 색의 밝고 어두운 램프를 더해 약 24색 이내, 이 밖의 색 금지' + (s.dither ? ', 중간 밝기는 4x4 Bayer 디더' : ''), '. Add light and dark ramps for about 24 colours total; nothing outside them' + (s.dither ? '; in-between values use 4x4 Bayer dither' : ''))
                 : L('. 이 목록 밖의 색 금지, 밝기 단계는 이 색끼리의 혼합만', '. No colour outside this list; shades only by mixing these colours'))
      : L('. 강조색의 밝고 어두운 단계는 파생해도 된다', '. Lighter and darker steps of the accents may be derived');
    const marks = {
      pixel: L('1px 외곽선, 정사각형 입자, Bresenham 선, 스프라이트 회전 금지, 블러와 알파 그라데이션 금지', '1px outlines, square particles, Bresenham lines, no sprite rotation, no blur or alpha gradients'),
      neon: L('모든 빛은 가산 합성, 스파크는 속도 방향 스트릭, 흰 코어에서 강조색으로 번짐', 'all light is additive; sparks are velocity-aligned streaks; hot white core falling off into the accent'),
      cartoon: L('두꺼운 어두운 외곽선, 평면 2단 셀 셰이딩, 별 모양 임팩트와 속도선', 'thick dark outlines, flat two-tone cel shading, star-shaped impacts and speed lines'),
      painterly: L('미리 구운 소프트 브러시 텍스처를 낮은 불투명도로 겹침, 느린 곡선 흐름', 'pre-baked soft brush texture layered at low opacity, slow curving flow'),
      minimal: L('얇은 선과 기하 도형, 2~3색, 가산광 없음, 여백', 'thin lines and geometric primitives, 2 to 3 colours, no additive light, generous negative space'),
    }[s.style];
    const light = L('모든 빛은 발동점과 임팩트 지점에서 나온다. 차지에서 모이고, 임팩트에서 터지고, 여운에서 식는다', 'all light comes from the source and the impact points: it gathers in the charge, bursts on impact, cools in the recovery');
    const fpsGrid = d.pixel ? s.pixelFps : 12;
    const easeText = {
      snappy: L('터지는 요소는 easeOutExpo 계열, 처음 20% 시간에 이동량의 80%', 'burst elements use easeOutExpo-like curves: 80% of travel in the first 20% of the time'),
      elastic: L('크기와 위치는 감쇠 스프링으로 안착(오버슈트 약 12%, 1~2회 흔들림)', 'scale and position settle on a damped spring (about 12% overshoot, 1 to 2 wobbles)'),
      smooth: L('easeInOutCubic 중심의 부드러운 가감속, 급한 변화는 임팩트 순간에만', 'soft easeInOutCubic motion; sharp changes only at the impact'),
      stepped: L('값은 부드럽게 보간하고 그릴 때 ' + fpsGrid + 'fps 격자로 양자화', 'values ease smoothly but are quantized to a ' + fpsGrid + ' fps grid when drawn'),
    }[s.easing];
    const rules = L('임팩트는 한 번. 단계가 오를수록 강해지고 어떤 요소도 지정 단계 아래에서 나오지 않는다. 시드 고정 난수만. 프레임 루프 안 객체 생성 0. 이펙트는 게임 상태를 바꾸지 않고 콜백으로만 알린다',
      'one impact moment; effects escalate with level and never appear below their level; seeded randomness only; zero allocations in the frame loop; the effect never mutates game state and only reports through callbacks')
      + (s.trigger === 'hold' ? L('. 충전은 사용자의 손, 발동은 보상', '; the charge is the player\'s hand, the release is the reward') : '');
    const sound = { none: L('없음', 'none'), cues: L('이펙트는 소리를 재생하지 않고 cue 이벤트만 보낸다', 'the effect never plays audio; it only emits cue events'), design: L('cue 이벤트만 보내고, 소리 설계안은 따로 표로 제안', 'emit cue events only; propose the sound design separately as a table') }[s.sound];
    const pad = (k) => (k + '          ').slice(0, 9);
    add(pad('FORMAT') + format, pad('PALETTE') + palette + paletteRule, pad('MARKS') + marks, pad('LIGHT') + light);
    add(pad('MOTION') + easeText + (d.pixel && s.easing !== 'stepped' ? L(', 그리기는 ' + s.pixelFps + 'fps 격자', ', drawing snaps to a ' + s.pixelFps + ' fps grid') : ''));
    add(pad('RULES') + rules, pad('SOUND') + sound, '```', '');

    // 4. 렌더링
    add(L('## 렌더링', '## Rendering'));
    if (d.pixel) {
      add(L('- 모든 그리기는 논리 픽셀 정수 좌표에 스냅한다. Flutter에서는 ' + code('devicePixelRatio') + '를 곱한 물리 픽셀 기준으로 정수 배율을 구해 ' + code('canvas.scale(배율 / devicePixelRatio)') + '를 적용하고, 원점도 물리 픽셀 정수 위치에 맞춘다.',
        '- Snap every draw to integer logical pixels. In Flutter compute the integer scale in physical pixels (multiply by ' + code('devicePixelRatio') + '), apply ' + code('canvas.scale(scale / devicePixelRatio)') + ', and snap the origin to a whole physical pixel.'));
      add(L('- 도형은 정수 좌표 사각형 단위로 그린다(' + code('Paint.isAntiAlias = false') + '). 이미지는 ' + code('FilterQuality.none') + '. 블러, 그림자, 알파 그라데이션 금지.', '- Build shapes from integer-aligned rects (' + code('Paint.isAntiAlias = false') + '). Images use ' + code('FilterQuality.none') + '. No blur, shadows or alpha gradients.'));
      add(s.dither ? L('- 중간 밝기(후광, 섬광, 연기, 어둠)는 4x4 Bayer 디더로 표현하고 패턴 칸은 화면 격자에 고정한다.', '- In-between brightness (glow, flash, smoke, darkness) is an ordered 4x4 Bayer dither locked to the screen grid.') : L('- 중간 밝기는 팔레트 색 단계로만 표현한다.', '- In-between brightness uses palette steps only.'));
      add(L('- 업데이트는 60Hz로 돌리되 그릴 때 위치와 포즈를 ' + s.pixelFps + 'fps 격자로 양자화해 도트 애니메이션처럼 보이게 한다.', '- Update at 60 Hz but quantize positions and poses to ' + s.pixelFps + ' fps when drawing so it reads as pixel animation.'));
      add(L('- 입자는 1~3px 정사각형, 선은 Bresenham, 스프라이트는 회전하지 않는다(필요하면 90도 단위).', '- Particles are 1 to 3 px squares, lines are Bresenham, sprites never rotate except in 90 degree steps.'));
    } else if (s.style === 'neon') {
      add(L('- 빛은 모두 ' + code('BlendMode.plus') + '로 더해 겹칠수록 밝아진다. 코어는 하이라이트, 가장자리는 강조색이다.', '- All light uses ' + code('BlendMode.plus') + ' so overlaps brighten; cores sit near the highlight and fall off into the accent.'));
      add(L('- 글로우는 매 프레임 blur로 만들지 않는다. 초기화 때 흰색 방사형 텍스처를 한 번 구워(' + code('PictureRecorder') + '와 ' + code('toImageSync') + ') 색만 입혀 그린다.', '- Never blur per frame. Bake a white radial texture once at init (' + code('PictureRecorder') + ' plus ' + code('toImageSync') + ') and tint it at draw time.'));
      add(L('- 스파크는 속도 방향으로 늘어난 선(길이는 속도 x 0.03초)으로 그린다.', '- Sparks are streaks along their velocity (length = speed x 0.03 s).'));
    } else if (s.style === 'cartoon') {
      add(L('- 평면 채색과 두꺼운 어두운 외곽선(0.08 unit). 명암은 2단 셀 셰이딩, 그라데이션 없음.', '- Flat fills with thick dark outlines (0.08 unit). Two-tone cel shading, no gradients.'));
      add(L('- 임팩트는 뾰족한 별 모양 폭발과 속도선. 스쿼시 앤 스트레치를 과장하고 빠른 이동에는 1~2프레임 스미어를 쓴다.', '- Impacts are spiky star bursts with speed lines. Exaggerate squash and stretch and smear fast moves for 1 to 2 frames.'));
    } else if (s.style === 'painterly') {
      add(L('- 낮은 불투명도(0.15~0.4)의 부드러운 블롭을 겹쳐 번짐을 만든다. 블롭은 미리 구운 소프트 브러시 텍스처 하나를 색만 바꿔 그린다. 런타임 blur 금지.', '- Stack low-opacity (0.15 to 0.4) blobs from one pre-baked soft brush texture, tinted per colour. No runtime blur.'));
      add(L('- 움직임은 느린 이징과 곡선 궤적. 급한 변화는 임팩트 순간에만 둔다.', '- Motion is slow easing on curved paths; save sharp changes for the impact.'));
    } else {
      add(L('- 얇은 선(0.05 unit)과 원, 사각형, 선분만 쓴다. 2~3색, 가산광 없음.', '- Only thin strokes (0.05 unit), circles, rects and segments. 2 to 3 colours, no additive light.'));
      add(L('- 입자 수보다 타이밍과 이징의 정확도로 완성도를 만든다.', '- Quality comes from precise timing and easing, not particle count.'));
    }
    add('');

    // 5. 좌표와 범위
    add(L('## 좌표와 범위', '## Coordinates and area'));
    add(L('- 입력: ' + code('source') + '(발동점), ' + code('target') + '(임팩트 기준점), ' + code('hits') + '(영향 지점 중심 목록), ' + code('unit') + '(길이 기준), ' + code('level') + '(단계). 모두 ' + code('play()') + ' 호출 때 받아 고정 크기 버퍼에 복사해 둔다.',
      '- Inputs: ' + code('source') + ' (origin), ' + code('target') + ' (impact anchor), ' + code('hits') + ' (hit point centres), ' + code('unit') + ' (length unit), ' + code('level') + '. All are passed to ' + code('play()') + ' and copied into fixed-size buffers.'));
    const deliveryText = {
      self: L('target에서 바로 터진다. source는 쓰지 않아도 된다.', 'Bursts at target right away; source may be unused.'),
      projectile: L('TRAVEL 동안 source에서 target까지 날아간다. 궤도는 곧거나 0.3 unit 높이의 완만한 포물선이고, 도착 순간 임팩트. 발사 순간 source에 작은 섬광과 스파크.', 'During TRAVEL a projectile flies from source to target, straight or on a gentle 0.3 unit arc; impact on arrival. A small flash and sparks at source on release.'),
      beam: L('TRAVEL 동안 source와 target을 잇는 빔을 유지한다. 굵기는 처음 80ms에 0.35 unit까지 차오르고 60ms마다 ±15% 떨린다. 코어는 하이라이트, 바깥은 강조색이며 target 쪽에서 스파크가 계속 튄다.', 'During TRAVEL hold a beam from source to target. Width reaches 0.35 unit in the first 80 ms and wobbles ±15% every 60 ms. Highlight core, accent edge, sparks spraying at target.'),
      sky: L('CHARGE 동안 target 아래에 경고 표식을 그리고, TRAVEL 동안 화면 위 가장자리에서 target까지 떨어진다.', 'During CHARGE draw a warning marker under target; during TRAVEL the strike drops from the top edge onto target.'),
      bolts: L('TRAVEL 동안 source에서 hits 각각으로 줄기가 순서대로 이어진다. 이어진 지점은 빛나며 기다리다가 IMPACT에서 한꺼번에 터진다.', 'During TRAVEL arcs link source to each hit in turn; linked points glow and wait, then all detonate at IMPACT.'),
      sweep: L('TRAVEL 동안 target에서 범위를 따라 전선이 퍼지고, 전선이 지나가는 순간 그 hit가 터진다.', 'During TRAVEL a front spreads from target along the area; each hit pops the moment the front passes it.'),
      melee: L('TRAVEL 동안 target을 가로지르는 초승달 베기 궤적(두께 0.25 unit, 1~2프레임 스미어)을 그리고, 끝나는 순간 임팩트.', 'During TRAVEL draw a crescent slash across target (0.25 unit thick, 1 to 2 frame smear); impact when it completes.'),
      aura: L('source 발밑에서 원이 퍼지고 몸을 감싸며 입자가 위로 솟는다. 날아가는 요소는 없다.', 'A ring spreads under source and motes wrap the body and rise; nothing travels.'),
      collect: L('TRAVEL 동안 source에서 수집품이 튀어나와 곡선을 그리며 target(HUD 목적지)으로 날아간다. 하나가 닿을 때마다 목적지가 살짝 튀고 숫자가 오른다.', 'During TRAVEL pickups pop out of source and arc to target (the HUD destination). Each arrival bumps the destination and ticks the counter.'),
      sequence: L('TRAVEL 동안 hits가 균등한 간격으로 하나씩 터지고, IMPACT에서 target이 마지막으로 크게 한 번 터진다.', 'During TRAVEL the hits detonate one by one at even intervals; IMPACT ends with one big burst at target.'),
      loop: L('켜져 있는 동안 CHARGE, IMPACT, RECOVER를 맥박처럼 반복하고, ' + code('stop()') + '을 부르면 RECOVER로 부드럽게 끝난다.', 'While active, cycle CHARGE, IMPACT and RECOVER like a pulse; ' + code('stop()') + ' eases out through RECOVER.'),
    }[dl];
    add(L('- 발동(' + d.delivery.label + '): ', '- Delivery (' + d.delivery.en + '): ') + deliveryText);
    const areaText = {
      point: L('target 하나', 'target alone'),
      match3: L('target과 좌우로 1 unit 떨어진 두 점', 'target plus two points 1 unit left and right'),
      area3: L('target과 8방향으로 1 unit 떨어진 점', 'target plus the 8 points 1 unit away'),
      row: L('target을 지나는 가로선 위 1 unit 간격의 점', 'points 1 unit apart on the horizontal line through target'),
      cross: L('target을 지나는 가로선과 세로선 위 1 unit 간격의 점', 'points 1 unit apart on the horizontal and vertical lines through target'),
      cross3: L('target을 중심으로 한 가로 3줄과 세로 3줄 위의 점', 'points on the three rows and three columns centred on target'),
      color: L('같은 종류로 표시된 대상들의 위치', 'the positions of every target of the chosen kind'),
      scatter: L('범위 안 무작위 점(시드 고정)', 'seeded random points inside the area'),
      all: L('판이나 화면 전체를 덮는 격자 점', 'a grid of points covering the whole board or screen'),
    }[d.area.id];
    add(L('- 범위(' + d.area.label + '): 퍼즐 판이면 해당 칸 중심을 hits로 넘기고, 판이 없는 게임의 hits는 ' + areaText + '. 최대 ' + Math.max(8, d.hits) + '개.',
      '- Area (' + d.area.en + '): on a board pass the matching cell centres as hits; without a board pass ' + areaText + '. Up to ' + Math.max(8, d.hits) + ' hits.'));
    if (multi && ['self', 'projectile', 'beam', 'sky', 'melee'].includes(dl)) add(L('- 시간차: 각 hit는 target과의 거리(판은 칸 단위 체비쇼프 거리, 그 밖은 unit 단위 거리) x ' + d.stagger + 'ms 뒤에 터져 가까운 곳부터 바깥으로 번진다.', '- Stagger: each hit fires after its distance from target (Chebyshev cells on a board, units elsewhere) x ' + d.stagger + ' ms, rippling outward.'));
    add(L('- hit가 실제로 터지는 순간마다 ' + code('onHit(int index)') + '를 호출해 게임이 칸 제거나 피해 처리를 맞추게 한다.', '- Call ' + code('onHit(int index)') + ' the moment each hit fires so the game can sync cell removal or damage.'));
    const viewText = {
      side: L('횡스크롤: 중력은 아래(파편 3 unit/s²), 불씨와 연기는 위로. 바닥선 아래로는 입자가 나가지 않고 바닥에 닿은 파편은 한 번 튕긴 뒤 멈춘다.', 'Side view: gravity pulls down (shards 3 unit/s^2), embers and smoke rise. Nothing passes below the floor line; shards bounce once and settle.'),
      topdown: L('탑다운: 중력 없이 입자가 바깥으로 퍼지다 감속한다. 높이는 위쪽 오프셋과 바닥 그림자 타원으로, 링과 마법진은 세로 0.5배로 눕혀 그린다.', 'Top-down: no gravity; particles spread and decelerate. Show height with an upward offset and a ground shadow; flatten rings and circles to 0.5x vertically.'),
      board: L('퍼즐 판: hits는 칸 중심, unit은 칸 크기. 칸 밖으로 튄 입자가 잘리지 않게 판 위 레이어에 그린다.', 'Board: hits are cell centres and unit is the cell size. Draw on a layer above the board so particles are not clipped at its edge.'),
      ui: L('UI 화면: 좌표는 위젯의 전역 위치(GlobalKey로 얻은 Rect 중심)이고 이펙트는 Overlay 위에 그린다. 목적지는 스크롤 중에도 맞도록 매 프레임 읽는 콜백으로 받는다.', 'UI: coordinates are global widget positions (Rect centres from GlobalKeys) and the effect draws in an Overlay. Take the destination as a callback read each frame so it tracks scrolling.'),
    }[d.view.id];
    add('- ' + viewText, '');

    // 6. 타임라인
    const phaseDefs = [
      { key: 'anticipation', name: 'CHARGE' }, { key: 'travel', name: 'TRAVEL' }, { key: 'hitstop', name: 'HITSTOP' }, { key: 'burst', name: 'IMPACT' }, { key: 'afterglow', name: 'RECOVER' },
    ].map((x) => Object.assign(x, { ms: ph[x.key] })).filter((x) => x.ms > 0 || x.key === 'burst');
    add(L('## 타임라인 (상태 머신)', '## Timeline (state machine)'));
    add(code('IDLE -> ' + phaseDefs.map((x) => x.name).join(' -> ') + ' -> ' + (s.playback === 'loop' || dl === 'loop' ? 'IDLE (loop)' : 'DONE')));
    add('- IDLE: ' + L('대기. 이펙트는 아무것도 그리지 않는다.', 'Waiting; the effect draws nothing.'));
    const phr = (map) => d.layers.map((l) => map[l.id]).filter(Boolean);
    const charge = phr(ko ? {
      orbit: '입자가 발동점 주위를 돌며 빨라지다 중심으로 빨려 든다', runes: '마법진이 한 칸씩 그려진다', glow: '발동점 후광이 차오른다', rim: '가까운 캐릭터와 칸에 림 라이트가 밝아진다',
      vignette: '주변이 어두워져 시선이 모인다', pulse: '맥동이 점점 빨라진다', squash: '발동점이 눌리며 힘을 모은다', shake: s.trigger === 'hold' ? '충전 후반에 미세한 떨림이 커진다' : null,
    } : {
      orbit: 'particles orbit the source, speed up and get pulled in', runes: 'the rune circle draws itself stroke by stroke', glow: 'the source glow fills up', rim: 'rim light brightens on nearby characters and cells',
      vignette: 'the surroundings darken to pull focus', pulse: 'the pulse quickens', squash: 'the source compresses to gather force', shake: s.trigger === 'hold' ? 'a fine tremble grows in the late charge' : null,
    });
    const hit = phr(ko ? { invert: '임팩트 프레임 2컷(반전 실루엣)', flash: '첫 섬광 프레임 유지' } : { invert: 'two impact frames (inverted silhouettes)', flash: 'hold the first flash frame' });
    const impact = phr(ko ? {
      flash: '섬광', glow: '후광 최대', ring: '충격파 링', sparks: '스파크 방사', shards: '파편 비산', smoke: '연기', rays: '광선', lightning: '번개', trail: d.tierList[top - 1].comets ? '궤적을 남기며 튀는 빛' : null,
      confetti: '색종이', runes: '마법진이 번쩍이고 사라짐', cracks: '균열', pulse: '화면이 강조색으로 한 번 물듦', shake: '화면 흔들림', zoom: '줌 펀치', chroma: '색 분리', textPop: '결과 텍스트', squash: '대상 반동', slowmo: '지정 단계의 슬로 모션',
    } : {
      flash: 'flash', glow: 'glow peaks', ring: 'shockwave rings', sparks: 'sparks radiate', shards: 'shards scatter', smoke: 'smoke', rays: 'rays', lightning: 'lightning', trail: d.tierList[top - 1].comets ? 'trailing streaks' : null,
      confetti: 'confetti', runes: 'the circle flares and vanishes', cracks: 'cracks', pulse: 'one accent-coloured wash', shake: 'screen shake', zoom: 'zoom punch', chroma: 'chromatic split', textPop: 'result text', squash: 'target recoil', slowmo: 'slow motion on its level',
    });
    const recover = phr(ko ? { embers: '불씨가 떠오른다', rays: '광선이 옅어진다', glow: '후광이 식는다', smoke: '연기가 흩어진다', confetti: '색종이가 흔들리며 떨어진다', textPop: '텍스트가 안착해 머물다 마지막 25%에 사라진다', sparks: '남은 스파크가 식어 사라진다' }
      : { embers: 'embers rise', rays: 'rays fade', glow: 'the glow cools', smoke: 'smoke drifts apart', confetti: 'confetti flutters down', textPop: 'text settles, then fades in the last 25%', sparks: 'remaining sparks cool and vanish' });
    const travelText = {
      projectile: L('탄환 비행' + (has('trail') ? '과 궤적' : ''), 'projectile flight' + (has('trail') ? ' with a trail' : '')), beam: L('빔 유지', 'beam held'), sky: L('위에서 낙하', 'strike falls'), bolts: L('hit마다 줄기 연결', 'arcs link each hit'),
      sweep: L('전선이 퍼지며 hit를 차례로 터뜨림', 'the front sweeps and pops hits in turn'), melee: L('베기 궤적', 'slash arc'), collect: L('수집품 비행과 흡수', 'pickups fly and are absorbed'), sequence: L('hit가 하나씩 터짐', 'hits detonate one by one'),
    }[dl];
    const holdText = s.trigger === 'hold' ? L('누르는 동안 충전값이 0에서 1로 오른다(' + ph.anticipation + 'ms에 가득). 가득 차거나 손을 떼면 발동하고 짧은 탭도 동작한다. ', 'While held, charge rises from 0 to 1 (full at ' + ph.anticipation + ' ms). Full charge or release fires; a quick tap also works. ') : '';
    phaseDefs.forEach((x) => {
      let body = '';
      if (x.key === 'anticipation') body = holdText + (charge.length ? list(charge) : L('짧은 준비 동작', 'a short wind-up'));
      if (x.key === 'travel') body = travelText || L('이동', 'travel');
      if (x.key === 'hitstop') body = L('모든 월드 움직임을 멈춘다. ', 'Freeze all world motion. ') + (hit.length ? list(hit) + '. ' : '') + L('멈춤이 임팩트의 무게를 만든다', 'The pause gives the hit its weight');
      if (x.key === 'burst') body = impact.length ? list(impact) : L('핵심 변화', 'the main change');
      if (x.key === 'afterglow') body = recover.length ? list(recover) : L('모든 요소가 부드럽게 사라진다', 'everything fades out softly');
      add('- ' + x.name + ' ' + x.ms + 'ms: ' + body + '.');
    });
    if (s.tierStretch && top > 1) add(L('- 단계가 1 오를 때마다 HITSTOP과 RECOVER가 20%씩 길어진다.', '- Each level step lengthens HITSTOP and RECOVER by 20%.'));
    add(L('- 상태 전환은 고정 1/60초 스텝의 누적 시간으로 판단하고, 각 상태의 진행률 t(0~1)를 연출 함수에 넘긴다. 연출 함수는 t만 받는 순수 함수로 둔다.', '- Phase changes run on accumulated fixed 1/60 s steps; each phase passes its progress t (0 to 1) to pure functions of t.'));
    add('');

    // 7. 구성 요소
    const tierTag = (id) => (top > 1 ? L(' (단계 ' + tierOf(id) + '부터)', ' (level ' + tierOf(id) + '+)') : '');
    const detail = {
      flash: L('임팩트 첫 프레임에 하이라이트 색 섬광. ' + (d.fullFlash ? '화면 전체를 덮고' : '영향 지점마다 반지름 1 unit 안에서만 번지고') + ' 최대 불투명도 ' + d.flashAlpha + ', ' + d.flashMs + 'ms 안에 사라진다.',
        'Highlight flash on the first impact frame' + (d.fullFlash ? ', covering the whole frame' : ', confined to 1 unit around each hit') + '; peak opacity ' + d.flashAlpha + ', gone within ' + d.flashMs + ' ms.'),
      glow: L('발동점과 target 뒤 후광, 반지름 0.9 unit(단계마다 +15%). 차지에서 25%에서 75%로, 임팩트에서 100%, 여운에서 0으로.', 'Glow behind source and target, radius 0.9 unit (+15% per level): 25% to 75% in the charge, 100% at impact, 0 by the end of recovery.') + (d.pixel ? L(' 디더 동심원 3단으로 그린다.', ' Draw it as three dithered concentric discs.') : ''),
      rays: L('광선 ' + counts('rays', 'rays') + '개(단계 순), 길이 2 unit, 초당 0.15회전. 임팩트에서 펼쳐지고 여운 동안 사라진다.', counts('rays', 'rays') + ' rays per level, 2 units long, rotating 0.15 turns per second; they unfold at impact and fade in the recovery.'),
      rim: L('이펙트 빛이 가까운 캐릭터와 칸 가장자리에 ' + px(1, 0.04) + ' 림 라이트를 준다. 차지 동안 밝아지고 임팩트 직후 최대(마법사 글의 보석 림 라이트).', 'The effect casts a ' + px(1, 0.04) + ' rim light on nearby characters and cell edges, brightening through the charge and peaking right after impact (the wizard post\'s gem rim light).'),
      pulse: L('판이나 화면 전체에 강조색을 최대 25% 덧칠하는 맥동. 지속 상태에서는 0.5초 주기이고 단계마다 20% 빨라진다.', 'A pulse that washes the board or screen with up to 25% accent colour; 0.5 s period in sustained states, 20% faster per level.'),
      sparks: L('스파크 ' + counts('sparks', 'sparks') + '개(단계 순, hit에 나눠 배분, hit당 최소 1개). 초속 1.5~3.5 unit, 감속 계수 3/s, 수명 0.4~0.8초. 수명에 따라 팔레트 색이 하이라이트, 강조색, 어두운 강조색으로 한 칸씩 바뀐 뒤 사라진다(마법사 글 방식).',
        counts('sparks', 'sparks') + ' sparks per level, split across hits (at least 1 per hit); 1.5 to 3.5 unit/s, drag 3/s, 0.4 to 0.8 s life. Each steps its palette index highlight to accent to dark accent before despawning (as in the wizard post).'),
      shards: L('조각 ' + counts('shards', 'shards') + '개(단계 순, hit당 최소 1개)가 초당 최대 2회전하며 흩어진다. 판에서는 터진 칸의 색을 쓴다. 수명 0.7~1.1초.', counts('shards', 'shards') + ' shards per level (at least 1 per hit) spin up to 2 turns per second as they scatter; on a board they take the popped cell\'s colour. 0.7 to 1.1 s life.'),
      orbit: L('입자 ' + counts('orbit', 'orbit') + '개(단계 순)가 발동점 주위 1.1 unit 궤도에서 초당 1회전에서 4회전으로 빨라지며 중심으로 빨려 든다(마법사 글의 차지 스파크).', counts('orbit', 'orbit') + ' particles per level orbit the source at 1.1 units, spinning up from 1 to 4 turns per second as they spiral in (the wizard post\'s charge sparks).'),
      embers: L('여운 동안 초당 ' + d.emberRate + '개, 0.4 unit/s로 떠오르며 깜빡이고 수명 1.2초.', 'During recovery spawn ' + d.emberRate + ' per second, rising at 0.4 unit/s with flicker, 1.2 s life.'),
      smoke: L('연기 ' + counts('smoke', 'smoke') + '개(단계 순)가 hit와 바닥에서 피어올라 반지름 0.3에서 0.8 unit로 커지며 0.8초에 걸쳐 흩어진다.' + (d.pixel ? ' 디더 원 3단으로 그린다.' : ''), counts('smoke', 'smoke') + ' smoke puffs per level rise from the hits and floor, growing from 0.3 to 0.8 unit and fading over 0.8 s.' + (d.pixel ? ' Draw them as three-step dithered discs.' : '')),
      confetti: L('색종이 ' + counts('confetti', 'confetti') + '개(단계 순)가 위로 터진 뒤 좌우로 흔들리며 떨어진다. 뒤집힐 때 폭이 cos로 변하고 명암이 바뀐다.', counts('confetti', 'confetti') + ' confetti pieces per level burst upward, then sway down; width follows cos as they flip.'),
      trail: L('날아가는 빛 뒤로 이전 위치 8개를 링 버퍼로 보관해 뒤로 갈수록 작고 어둡게 그린다.' + (d.tierList[top - 1].comets ? ' 임팩트에서 궤적을 남기며 튀는 빛 ' + counts('comets', 'trail') + '개(단계 순).' : ''), 'Keep the last 8 positions of anything flying in a ring buffer and draw them smaller and darker toward the tail.' + (d.tierList[top - 1].comets ? ' At impact ' + counts('comets', 'trail') + ' streaking bolts per level fly out.' : '')),
      ring: L('충격파 링 ' + counts('rings', 'ring') + '개(단계 순), 90ms 간격. 반지름 0.3에서 1.4 unit(easeOutExpo, 단계마다 +10%), 두께 0.15 unit에서 0, 밝기 1에서 0, 수명 500ms 이하.', counts('rings', 'ring') + ' shockwave rings per level, 90 ms apart; radius 0.3 to 1.4 unit (easeOutExpo, +10% per level), thickness 0.15 unit to 0, brightness 1 to 0, life up to 500 ms.'),
      lightning: L('번개 ' + counts('bolts', 'lightning') + '줄(단계 순). 6마디 지그재그 경로를 60ms마다 다시 만들고, 코어는 하이라이트, 바깥은 강조색.', counts('bolts', 'lightning') + ' lightning bolts per level; rebuild each 6-segment zigzag every 60 ms, highlight core with an accent edge.'),
      runes: L('CHARGE 동안 발동점이나 target 아래 반지름 1 unit 원과 룬 8개가 시계 방향으로 하나씩 그려지고, 임팩트에서 번쩍인 뒤 사라진다. 횡스크롤과 탑다운에서는 바닥면에 눕힌다(세로 0.35배).', 'During CHARGE a 1 unit circle with 8 runes draws itself clockwise under the source or target, flares at impact and vanishes. Lay it flat on the ground in side and top-down views (0.35x height).'),
      cracks: L('임팩트 지점 바닥이나 칸 표면에 균열 가지 4개가 80ms 안에 뻗고 여운 동안 옅어진다.', 'Four crack branches spread across the floor or cell surface within 80 ms of impact and fade through the recovery.'),
      textPop: L('결과 텍스트(' + d.texts.filter(Boolean).join(', ') + ')가 target 위 1 unit에서 1.6배로 튀어나와 스프링으로 1배에 안착한다. TextPainter는 재생 시작 때 한 번만 layout한다.', 'Result text (' + d.texts.filter(Boolean).join(', ') + ') pops at 1.6x one unit above target and springs to 1x. Lay out the TextPainter once when playback starts.'),
      squash: L('차지에서 발동점이 가로 +12% 세로 -12%로 눌리고, 임팩트에서 대상이 0.15 unit 밀렸다가 감쇠 스프링으로 돌아온다. 맞은 대상은 1프레임 흰색으로 번쩍인다.', 'The source compresses +12% / -12% in the charge; at impact the target is knocked 0.15 unit and springs back, flashing white for one frame.'),
      shake: L('최대 ' + (d.pixel ? d.shakePx + 'px' : d.shakeUnit + ' unit') + ' 흔들림, 단계마다 +25%, 300ms 동안 감쇠. 방향은 시드 난수. 오프셋을 컨트롤러 값으로 노출해 게임이 원하는 레이어에 적용하게 한다.', 'Shake up to ' + (d.pixel ? d.shakePx + ' px' : d.shakeUnit + ' unit') + ', +25% per level, decaying over 300 ms with seeded direction. Expose the offset on the controller so the game applies it to whatever layer it wants.'),
      zoom: L('임팩트에 ' + d.zoom + '배로 확대 후 250ms 동안 복귀(단계마다 +0.01). 값만 컨트롤러로 노출하고 적용은 게임이 정한다.', 'Punch to ' + d.zoom + 'x at impact and return over 250 ms (+0.01 per level). Expose the value on the controller; the game decides where to apply it.'),
      chroma: L('임팩트 후 140ms 동안 밝은 요소를 빨강과 청록으로 좌우 ' + px(1, 0.04) + '씩 어긋나게 한 번 더 그린다. 전면 합성 레이어는 쓰지 않는다.', 'For 140 ms after impact redraw the bright elements offset ' + px(1, 0.04) + ' left in red and right in cyan. No full-screen compositing layer.'),
      invert: L('HITSTOP 동안 2컷: 배경색 바탕에 하이라이트 실루엣과 속도선, 이어서 하이라이트 바탕에 배경색 실루엣. 컷당 1~2프레임.', 'Two cuts during HITSTOP: highlight silhouettes with speed lines on the background colour, then background-colour silhouettes on the highlight. 1 to 2 frames each.'),
      vignette: L('차지 진행률만큼 주변을 배경색으로 최대 60% 어둡게 하고 임팩트에서 걷는다(캔디크러시 컬러 폭탄처럼 발동 전 판을 어둡게).', 'Darken the surroundings toward the background colour by up to 60% with charge progress and clear it at impact (like the board dimming before a colour bomb).'),
      slowmo: L('이 단계에서는 임팩트 초반 45%를 시간 배율 0.35로 재생한다. 입자와 연출은 월드 시간, 텍스트와 UI는 실제 시간.', 'On this level the first 45% of IMPACT runs at 0.35x. Particles and visuals use world time; text and UI use real time.'),
    };
    add(L('## 구성 요소', '## Elements'));
    d.layers.forEach((l) => add('- **' + (ko ? l.label : l.en) + '**' + tierTag(l.id) + ': ' + detail[l.id]));
    add('');

    // 8. 단계
    if (top > 1) {
      add(L('## 단계별 강화', '## Level escalation'));
      add(L('위 단계는 아래 단계의 요소를 모두 포함하고 더한다. 어떤 요소도 지정 단계 아래에서 나오지 않는다. 최상위 단계는 따로 기억에 남는 시그니처가 있어야 한다.', 'Each level keeps everything below it and adds more. No element appears below its level. The top level needs a memorable signature of its own.'), '');
      add(L('| 단계 | 이름 | 스파크 | 파편 | 연기 | 색종이 | 최대 입자 | 새로 켜지는 요소 |', '| Level | Name | Sparks | Shards | Smoke | Confetti | Max particles | New elements |'), '|---|---|---|---|---|---|---|---|');
      d.tierList.forEach((t, i) => add('| ' + t.tier + ' | ' + d.tierNames[i] + ' | ' + t.sparks + ' | ' + t.shards + ' | ' + t.smoke + ' | ' + t.confetti + ' | ' + t.total + ' | ' + (t.newLayers.length ? t.newLayers.map(layerName).join(', ') : '-') + ' |'));
      add('');
    }
    if (d.maxTotal > s.maxParticles) add(L('최상위 단계 예상 입자가 예산 ' + s.maxParticles + '개를 넘는다. 넘으면 종류별로 비례 축소한다.', 'The top level exceeds the ' + s.maxParticles + ' particle budget; scale each kind down proportionally.'), '');

    // 9. 접근성과 피드백
    add(L('## 접근성과 피드백', '## Accessibility and feedback'));
    add(s.reducedMotion === 'final'
      ? L('- ' + code('MediaQuery.disableAnimationsOf(context)') + '가 true면 연출을 건너뛰고 최종 상태를 즉시 보여 준다. onHit와 완료 콜백은 그대로 호출한다.', '- When ' + code('MediaQuery.disableAnimationsOf(context)') + ' is true, skip to the final state at once; still fire onHit and the completion callback.')
      : L('- ' + code('MediaQuery.disableAnimationsOf(context)') + '가 true면 흔들림, 줌, 섬광, 색 분리, 슬로 모션을 끄고 입자를 30%로 줄인 짧은 페이드 버전으로 재생한다.', '- When ' + code('MediaQuery.disableAnimationsOf(context)') + ' is true, play a short fade version: no shake, zoom, flash, chromatic split or slow motion, 30% of the particles.'));
    if (s.strengthOption) add(L('- 이펙트 세기 ' + code('strength') + '(low, normal, high)를 컨트롤러에 두어 게임 설정에서 바꾸게 한다. high는 이 문서 수치 그대로, normal은 입자 70%와 흔들림 60%, low는 입자 40%, 흔들림 0, 섬광 50%. Tetris Effect가 줄 제거 입자 세기를 Min, Mid, Max로 고르게 하는 방식이다.',
      '- Expose an effect ' + code('strength') + ' (low, normal, high) on the controller for the game\'s settings. high uses the numbers here, normal uses 70% particles and 60% shake, low uses 40% particles, no shake and 50% flash, like Tetris Effect\'s Min, Mid and Max particle setting.'));
    if (has('flash') || has('invert') || has('chroma') || has('pulse')) add(L('- 밝기가 크게 바뀌는 전면 섬광, 반전, 맥동은 1초에 3회를 넘기지 않는다.', '- Large full-frame brightness changes (flash, inversion, pulse) never exceed 3 per second.'));
    if (s.haptics !== 'none') add(L('- 햅틱(' + code('HapticFeedback') + '): 임팩트에서 ' + (top > 2 ? '단계 1~2는 lightImpact, 3은 mediumImpact, 4는 heavyImpact' : '단계 1은 lightImpact, 그 위는 mediumImpact') + (s.haptics === 'rich' ? '. 충전 단계나 hit마다 selectionClick(초당 12회 이하)' : '') + '. 웹에서는 무시될 수 있다.',
      '- Haptics (' + code('HapticFeedback') + '): at impact ' + (top > 2 ? 'lightImpact for levels 1 to 2, mediumImpact for 3, heavyImpact for 4' : 'lightImpact for level 1, mediumImpact above') + (s.haptics === 'rich' ? '; selectionClick per charge step or hit (at most 12 per second)' : '') + '. It may be a no-op on web.'));
    if (s.sound !== 'none') {
      const cues = 'chargeStart, ' + (d.delivery.travel ? 'release, ' : '') + (multi ? 'hit, ' : '') + 'impact, ' + (top > 1 ? 'levelUp, ' : '') + 'complete';
      add(L('- 소리: 이펙트는 오디오를 직접 재생하지 않는다. ' + code('onCue(' + P + 'Cue cue, int level)') + ' 콜백으로 ' + cues + ' 시점을 알려 게임의 오디오 매니저가 재생하게 한다.' + (multi ? ' hit cue는 연속으로 올 때 음높이를 반음씩 올릴 수 있게 순번을 함께 넘긴다.' : ''),
        '- Sound: the effect never plays audio. ' + code('onCue(' + P + 'Cue cue, int level)') + ' reports ' + cues + ' so the game\'s audio manager plays sounds.' + (multi ? ' Pass the hit index with each hit cue so the game can raise the pitch a semitone per consecutive hit.' : '')));
      if (s.sound === 'design') add(L('- 각 cue에 어울리는 소리 설계(음색, 길이, 음높이 변화, 단계별 차이)를 표로 제안한다.', '- Propose a sound design table per cue: timbre, length, pitch movement, differences per level.'));
    }
    add('');

    // 10. Flutter 구현
    if (wantsDart) {
      add(L('## Flutter 구현 규칙', '## Flutter implementation rules'));
      const ctrl = ['play({int level = 1, required Offset source, required Offset target, List<Offset> hits = const [], double unit = 16})', 'stop()', 'isPlaying', 'onHit', 'onComplete'];
      if (s.trigger === 'hold') ctrl.push('press()', 'release()', 'charge');
      if (s.sound !== 'none') ctrl.push('onCue');
      if (s.strengthOption) ctrl.push('strength');
      if (has('shake')) ctrl.push('shakeOffset');
      if (has('zoom')) ctrl.push('zoom');
      add(L('- ' + code(P + 'Spec') + ': const 생성자에 모든 길이(unit 배수), 시간, 개수, 색, 단계 표를 둔다. 속성 변형(불, 얼음 등)은 Spec 인스턴스만 바꿔 만든다.', '- ' + code(P + 'Spec') + ': a const constructor with every length (in units), duration, count, colour and the level table. Element variants (fire, ice and so on) are just other Spec instances.'));
      add(L('- ' + code(P + 'Controller') + '(ChangeNotifier): ' + ctrl.map(code).join(', ') + '.', '- ' + code(P + 'Controller') + ' (ChangeNotifier): ' + ctrl.map(code).join(', ') + '.'));
      add(L('- 상태 머신과 입자 시뮬레이션은 위젯과 분리된 순수 Dart 클래스로 두어 테스트에서 시간만 흘려 검증할 수 있게 한다.', '- Keep the state machine and simulation in plain Dart classes so tests can drive them by advancing time.'));
      if (s.target === 'flame') {
        add(L('- ' + code('PositionComponent') + '를 상속한 ' + code(P + 'Component') + '의 ' + code('update(double dt)') + '와 ' + code('render(Canvas canvas)') + '로 구현한다. dt는 1/20초로 자르고 고정 1/60초 스텝으로 나눠 처리한다.', '- Implement ' + code(P + 'Component extends PositionComponent') + ' with ' + code('update(double dt)') + ' and ' + code('render(Canvas canvas)') + '. Clamp dt to 1/20 s and consume it in fixed 1/60 s steps.'));
        add(L('- 컴포넌트를 미리 만들어 마운트해 두고 활성 여부로 재사용한다. 이벤트마다 add와 remove를 반복하지 않는다. 대량 입자는 Flame ' + code('Particle') + ' 대신 고정 크기 typed 버퍼와 ' + code('drawRawAtlas') + '로 그리고 ' + code('priority') + '로 겹침 순서를 명시한다.',
          '- Pre-create and mount components and reuse them by an active flag; never add and remove per event. Draw bulk particles from typed buffers with ' + code('drawRawAtlas') + ' instead of Flame ' + code('Particle') + ' objects, and set draw order with ' + code('priority') + '.'));
      } else {
        add(L('- ' + code('StatefulWidget') + '과 ' + code('SingleTickerProviderStateMixin') + '의 ' + code('Ticker') + '로 경과 시간을 받는다. 고정 1/60초 누적기로 update하고 프레임 간격이 1/20초를 넘으면 잘라 낸다. 재생하지 않을 때는 Ticker를 멈춘다.', '- Use a ' + code('StatefulWidget') + ' with ' + code('SingleTickerProviderStateMixin') + ' and a ' + code('Ticker') + '. Update with a fixed 1/60 s accumulator, clamp frame gaps to 1/20 s, and stop the ticker when idle.'));
        add(L('- ' + code('CustomPainter(repaint: controller)') + '로 다시 그려 ' + code('setState') + ' 없이 갱신한다. ' + code('RepaintBoundary') + '로 감싸고 ' + (s.trigger === 'hold' ? '누르기 입력은 ' + code('GestureDetector') + '로 받는다.' : '입력은 ' + code('IgnorePointer') + '로 통과시킨다.'), '- Repaint through ' + code('CustomPainter(repaint: controller)') + ' without ' + code('setState') + '. Wrap it in a ' + code('RepaintBoundary') + '; ' + (s.trigger === 'hold' ? 'take press input with a ' + code('GestureDetector') + '.' : 'let input pass through with ' + code('IgnorePointer') + '.')));
      }
      if (s.target === 'shader') {
        add(L('- 후광, 빔, 왜곡, 맥동처럼 면적이 큰 빛은 ' + code('shaders/' + d.snake + '.frag') + ' 조각 셰이더로, 입자와 파편은 CustomPainter로 그린다. 셰이더는 ' + code('#include <flutter/runtime_effect.glsl>') + '와 ' + code('FlutterFragCoord()') + '를 쓰고 uniform은 float와 sampler2D만 쓴다.',
          '- Draw large-area light (glow, beams, distortion, pulse) with a ' + code('shaders/' + d.snake + '.frag') + ' fragment shader and particles with the CustomPainter. The shader uses ' + code('#include <flutter/runtime_effect.glsl>') + ' and ' + code('FlutterFragCoord()') + ' with float and sampler2D uniforms only.'));
        add(L('- ' + code('FragmentProgram.fromAsset') + '으로 한 번 로드해 ' + code('FragmentShader') + '를 재사용하고 매 프레임 ' + code('setFloat') + '로 값을 넘긴다. pubspec의 ' + code('flutter: shaders:') + '에 등록하고, 로드 실패나 미지원 환경에서는 셰이더 없이 그리는 대체 경로로 동작한다.', '- Load once with ' + code('FragmentProgram.fromAsset') + ', reuse the ' + code('FragmentShader') + ' and push values with ' + code('setFloat') + ' each frame. Register it under ' + code('flutter: shaders:') + ' and fall back to a shader-free path if loading fails.'));
      }
      if (s.perf.seeded) add(L('- 난수는 ' + code('Random(seed)') + '로 받아 같은 시드면 같은 연출이 나오게 한다.', '- Take randomness from ' + code('Random(seed)') + ' so a seed replays identically.'));
      add(L('- ' + code('Paint') + ', ' + code('Path') + ', ' + code('TextPainter') + ', 이미지는 재사용하고 ' + code('dispose') + '에서 Ticker, 이미지(' + code('ui.Image.dispose') + '), 구독을 정리한다.', '- Reuse ' + code('Paint') + ', ' + code('Path') + ', ' + code('TextPainter') + ' and images; in ' + code('dispose') + ' release the ticker, images (' + code('ui.Image.dispose') + ') and listeners.'));
      if (s.platforms.includes('web')) add(L('- 웹(Wasm의 skwasm, CanvasKit)에서도 같은 결과여야 한다. 매 프레임 ' + code('saveLayer') + ', ' + code('ImageFilter.blur') + ', ' + code('MaskFilter.blur') + '를 쓰지 않는다.', '- Web (Wasm skwasm and CanvasKit) must match. No per-frame ' + code('saveLayer') + ', ' + code('ImageFilter.blur') + ' or ' + code('MaskFilter.blur') + '.'));
      if (s.platforms.includes('ios') || s.platforms.includes('android')) add(L('- 60Hz와 120Hz 화면에서 속도가 같아야 한다(시간 기반 업데이트). 저사양 모바일 기준으로 예산을 잡는다.', '- Speed must match on 60 Hz and 120 Hz displays; budget for low-end phones.'));
      if (s.platforms.includes('desktop')) add(L('- 창 크기를 바꾸는 중에도 비율과 선명도가 유지되어야 한다.', '- Proportions and sharpness must hold while the window resizes.'));
      add('');
    }

    // 11. 성능 예산
    add(L('## 성능 예산', '## Performance budget'));
    add(L('- 입자 최대 ' + s.maxParticles + '개, 프레임당 draw 호출 ' + s.maxDrawCalls + '회 이하, 목표 60fps.', '- At most ' + s.maxParticles + ' particles, ' + s.maxDrawCalls + ' draw calls per frame, targeting 60 fps.'));
    if (s.perf.pool) add(L('- 입자는 고정 크기 풀(' + code('Float32List') + ', ' + code('Int32List') + ')에 담아 재사용한다. 프레임 루프 안에서 ' + code('List') + ', ' + code('Offset') + ', 클로저를 만들지 않는다.', '- Particles live in fixed-size pools (' + code('Float32List') + ', ' + code('Int32List') + '). Allocate nothing in the frame loop: no ' + code('List') + ', ' + code('Offset') + ' or closures.'));
    if (s.perf.atlas) add(L('- 같은 아틀라스를 쓰는 입자는 ' + code('drawRawAtlas') + ' 한 번으로 묶어 그린다.', '- Batch particles sharing an atlas into one ' + code('drawRawAtlas') + ' call.'));
    if (s.perf.noBlur) add(L('- 런타임 blur, 그림자, ' + code('saveLayer') + '를 쓰지 않는다. 부드러운 빛은 미리 구운 텍스처로 만든다.', '- No runtime blur, shadows or ' + code('saveLayer') + '; soft light comes from pre-baked textures.'));
    if (s.perf.fixedStep) add(L('- 고정 1/60초 스텝 업데이트, dt 상한 1/20초.', '- Fixed 1/60 s steps with dt clamped to 1/20 s.'));
    if (s.perf.autoQuality) add(L('- 최근 30프레임 평균이 18ms를 넘으면 입자 수를 75%, 50%로 단계적으로 줄이고 현재 품질 단계를 컨트롤러에서 읽을 수 있게 한다.', '- If the last 30 frames average over 18 ms, step particles down to 75% then 50% and expose the quality level on the controller.'));
    add('');

    // 12. HTML 프로토타입
    if (wantsHtml) {
      add(L('## HTML 프로토타입 규칙', '## HTML prototype rules'));
      add(L('- 단일 HTML 파일, 바닐라 JavaScript와 Canvas 2D. 외부 에셋, 라이브러리, 폰트, 네트워크 요청 없음(마법사 글과 같은 조건).', '- One self-contained HTML file with vanilla JavaScript and Canvas 2D. No external assets, libraries, fonts or network requests (the same constraint as the wizard post).'));
      add(L('- Flutter Canvas로 1:1 옮길 수 있는 호출만 쓴다: fillRect는 drawRect, arc는 drawCircle과 drawArc, Path2D는 Path, drawImage(부분 사각형)는 drawImageRect나 drawRawAtlas, "lighter"는 BlendMode.plus, globalAlpha는 Paint 색 알파, save/translate/rotate/scale은 같은 이름, imageSmoothingEnabled=false는 FilterQuality.none.',
        '- Use only calls with a one-to-one Flutter Canvas equivalent: fillRect to drawRect, arc to drawCircle or drawArc, Path2D to Path, drawImage with a source rect to drawImageRect or drawRawAtlas, "lighter" to BlendMode.plus, globalAlpha to the Paint colour alpha, save/translate/rotate/scale to the same names, imageSmoothingEnabled=false to FilterQuality.none.'));
      add(L('- 쓰지 않는다: CSS 애니메이션과 필터, ctx.filter, shadowBlur, DOM 요소로 만든 이펙트, Web Audio. 소리 대신 cue 이름을 화면 구석 로그에 찍는다.', '- Do not use CSS animations or filters, ctx.filter, shadowBlur, DOM-element effects or Web Audio. Log cue names in a corner instead of sound.'));
      add(L('- 모든 수치는 파일 위쪽 ' + code('SPEC') + ' 객체 하나에 모으고' + (wantsDart ? ' Dart ' + code(P + 'Spec') + '과 이름과 값을 같게 한다.' : ' camelCase 이름으로 둔다.'), '- Keep every number in one ' + code('SPEC') + ' object at the top' + (wantsDart ? ' with the same names and values as the Dart ' + code(P + 'Spec') + '.' : ' with camelCase names.')));
      add(L('- requestAnimationFrame과 고정 60Hz 스텝, 루프 안 객체 생성 금지. 확인용 컨트롤: 단계 버튼, 다시 재생, 0.25배속' + (s.strengthOption ? ', 세기 토글' : '') + '.', '- requestAnimationFrame with a fixed 60 Hz step and no allocation in the loop. Controls: level buttons, replay, 0.25x speed' + (s.strengthOption ? ', strength toggle' : '') + '.'));
      add(wantsDart ? L('- HTML에서 타이밍과 느낌을 확정한 뒤 Dart로 옮기고, 두 구현의 SPEC 값이 같은지 표로 보여 준다.', '- Lock timing and feel in HTML first, then port to Dart and show a table proving both SPECs match.') : L('- 파일 끝 주석에 사용한 Canvas 2D 호출과 Flutter 대응 API 표를 붙인다.', '- End the file with a comment table mapping each Canvas 2D call to its Flutter API.'));
      add('');
    }

    // 13. 데모 장면
    if (s.deliverables.demo) {
      add(L('## 데모 장면', '## Demo scene'));
      if (d.view.id === 'side') {
        add(L('- 마법사 글의 구성을 따른다. 짙은 남색과 보라 하늘, 깜빡이는 1px 별 몇 개, 달, 돌바닥 줄. 캐릭터 실루엣이 또렷하게 읽혀야 한다.', '- Follow the wizard post: deep blue and purple night sky, a few twinkling 1px stars, a moon, a stone floor line. Silhouettes must read clearly.'));
        add(L('- 왼쪽 시전자: 약 24x32 도트 마법사를 사각형과 픽셀 줄로 절차적으로 그린다. 구부러진 뾰족 모자, 긴 수염, 두 톤 로브와 어두운 외곽선, 끝에 보석이 달린 지팡이.', '- Caster on the left: a roughly 24x32 pixel wizard built procedurally from rects and pixel runs: bent pointed hat, long beard, two-tone robe with a darker outline, staff with a gem at the tip.'));
        add(L('- 포즈 매개변수(지팡이 각도, 팔 올림, 머리 기울기, 로브 흔들림)를 부드럽게 보간한 뒤 매 프레임 픽셀 격자로 양자화한다. CHARGE에서 지팡이를 들고, 발동 때 앞으로 내밀고, RECOVER에서 돌아온다. 이펙트 빛이 마법사에 1px 림 라이트를 준다.', '- Parameterize the pose (staff angle, arm raise, head tilt, robe sway), ease it, then quantize to the pixel grid each frame. Raise the staff in CHARGE, thrust it on release, settle in RECOVER. The effect casts a 1px rim light on the wizard.'));
        add(L('- 오른쪽 표적: 슬라임이나 허수아비. 맞으면 1프레임 흰색으로 번쩍이고 밀렸다 돌아온다.', '- Target on the right: a slime or training dummy that flashes white for a frame and recoils when hit.'));
      } else if (d.view.id === 'board') {
        add(L('- 7x6 칸 퍼즐 판. 칸마다 색과 모양이 다른 보석 자리표시(원, 마름모, 사각형, 육각형, 삼각형, 별). 발동 칸은 테두리로 표시한다.', '- A 7x6 puzzle board of placeholder gems with a different colour and shape per kind (circle, diamond, square, hexagon, triangle, star). Outline the source cell.'));
        add(L('- onHit가 온 칸은 비우고, RECOVER가 끝나면 위에서 새 보석이 떨어져 한 번 튕기며 채운다.', '- Empty each cell as its onHit arrives; after RECOVER new gems fall in from above and bounce once.'));
      } else if (d.view.id === 'topdown') {
        add(L('- 타일 바닥 위에 위에서 본 원형 시전자와 표적, 발밑 그림자 타원.', '- A tiled floor with a round caster and target seen from above, each with a ground shadow.'));
      } else {
        add(L('- 어두운 패널, 오른쪽 위 코인 HUD(아이콘과 숫자), 가운데 아래 상자. 상자를 누르면 재생한다.', '- A dark panel with a coin HUD (icon and counter) at the top right and a chest at the bottom centre that plays the effect when tapped.'));
      }
      add(L('- 캐릭터와 판은 이펙트와 분리된 자리표시다. 빼도 이펙트만 그대로 동작해야 한다. 단계 버튼, 다시 재생, 0.25배속' + (s.strengthOption ? ', 세기 토글' : '') + '을 둔다.', '- Characters and board are placeholders separate from the effect; removing them must not break it. Add level buttons, replay, 0.25x speed' + (s.strengthOption ? ' and a strength toggle' : '') + '.'));
      add('');
    }

    // 14. 품질 기준
    const bar = {
      1: L('은은하게: 눈에 거슬리지 않고 오래 봐도 피곤하지 않다.', 'Subtle: never distracting, comfortable to watch for long.'),
      2: L('산뜻하게: 짧고 또렷하게 반응해 손맛이 느껴진다.', 'Crisp: short, clear, satisfying feedback.'),
      3: L('쥬시하게: 차지와 임팩트의 대비가 분명하고 반복해서 보고 싶다.', 'Juicy: clear contrast between charge and hit; you want to see it again.'),
      4: L('아주 쥬시하게: 화면이 크게 반응하지만 캐릭터와 결과 정보는 끝까지 읽힌다.', 'Very juicy: the screen reacts hard, yet characters and results stay readable.'),
      5: L('언리얼: 화면 전체가 반응하고 최상위 단계는 따로 기억에 남는다. 그래도 리듬이 있고 번쩍임이 과하지 않다.', 'Unreal: the whole screen reacts and the top level is unforgettable, while keeping rhythm and avoiding excessive flashing.'),
    }[s.intensity];
    add(L('## 품질 기준', '## Quality bar'));
    add('- ' + bar);
    add(L('- 차지, 정지, 임팩트, 여운의 대비가 한눈에 읽히고 임팩트 순간이 가장 밝고 크다.', '- Charge, freeze, impact and recovery read at a glance; the impact is the brightest, biggest moment.'));
    add(L('- 게임과 분리되어 있다. 캐릭터나 판을 바꿔도 좌표와 unit만 넘기면 같은 품질로 동작한다.', '- It is game-agnostic: swap the characters or board, pass new coordinates and unit, and it looks just as good.'));
    if (s.strictPalette) add(L('- 팔레트 밖 색이 한 픽셀도 없다.', '- Not a single pixel outside the palette.'));
    if (d.pixel) add(L('- 어떤 화면 크기에서도 픽셀이 선명하고 크기가 고르다. 벡터 도형을 줄인 느낌이 아니라 잘 다듬은 16비트 스프라이트 애니메이션처럼 보인다.', '- Crisp, even pixels at any size; it should look like a polished 16-bit sprite animation, not scaled-down vector shapes.'));
    add(L('- 끝나면 활성 입자 0. 100회 반복 재생해도 메모리가 늘지 않는다.', '- When finished: zero live particles. Memory stays flat over 100 replays.'), '');

    // 15. 완료 전 확인
    add(L('## 완료 전 확인', '## Before you finish'));
    if (wantsDart) add(L('- ' + code('flutter analyze') + ' 경고 0.', '- ' + code('flutter analyze') + ' reports no issues.'));
    if (wantsDart && s.deliverables.test) add(L('- ' + code('flutter test test/' + d.snake + '_effect_test.dart') + ' 통과.', '- ' + code('flutter test test/' + d.snake + '_effect_test.dart') + ' passes.'));
    if (top > 1) add(L('- 단계 1부터 ' + top + '까지 차례로 재생해 단계 규칙을 확인한다.', '- Play levels 1 through ' + top + ' in order and confirm the level rules.'));
    add(L('- 모션 줄이기를 켠 상태' + (s.strengthOption ? '와 세기 low' : '') + '에서도 재생해 본다.', '- Play once with reduced motion' + (s.strengthOption ? ' and once at strength low' : '') + '.'));
    if (s.perf.pool) add(L('- 프레임 루프 안에 객체 생성이 없는지 코드로 확인해 보고한다.', '- Check the frame loop for allocations and report what you checked.'));
    add(L('- 마지막에 파일 목록, 공개 API, Spec 주요 값, 알려진 한계를 요약한다. 애매한 부분은 합리적으로 정하고 요약에 적는다.', '- Finish with a summary: files, public API, key Spec values, known limits. Resolve ambiguities sensibly and list them.'));
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
      text: L('지금 결과를 유지한 채 더 쥬시하게 만들어 줘.\n1. 차지: 긴장이 쌓이게 한다. 맥박 같은 펄스, 모이는 입자 가속, 점점 커지는 떨림.\n2. 임팩트: 히트스톱을 살리고 섬광이나 반전 프레임으로 한 박자 강조한다.\n3. 여운: 약 0.3초 뒤 2차 충격(작은 링과 스파크)을 더한다.\n제약 시트, 성능 예산, 단계 규칙은 그대로 지키고 바뀐 점을 단계별로 정리해 줘.',
        'Keep what works and make it juicier.\n1. Charge: build tension with a pulse, accelerating gathering particles and a growing tremble.\n2. Impact: keep the hitstop and accent it with a flash or impact frame.\n3. Recovery: add an aftershock about 0.3 s later (a small ring and sparks).\nKeep the constraint sheet, budget and level rules, and summarize changes per level.'),
    }, {
      title: '속성 변형 만들기',
      text: L('같은 타임라인과 코드 구조로 화염, 냉기, 번개, 독 변형을 만들어 줘. 팔레트, 입자 모양, 임팩트 모양만 바꾸고 변형은 ' + code(d.pascal + 'Spec') + ' const 인스턴스로 둔다. 데모에 변형 선택 버튼을 추가해 줘.',
        'Make fire, frost, lightning and poison variants with the same timeline and code. Change only palette, particle shapes and impact shape, and define each variant as a const ' + code(d.pascal + 'Spec') + ' instance. Add a variant picker to the demo.'),
    }, {
      title: '다른 게임에 붙이기',
      text: L('이 이펙트를 [게임 종류와 이벤트. 예: 횡스크롤 액션의 스킬 명중, 매치 3의 특수 보석 발동, 탑다운 RPG의 범위 마법]에 연결하는 어댑터를 만들어 줘. 게임 좌표에서 source, target, hits, unit을 계산하는 함수와 onHit 연결만 추가하고 이펙트 코드는 바꾸지 않는다.',
        'Write an adapter that hooks this effect into [game type and event, e.g. a skill hit in a side-scroller, a special gem in a match-3, an area spell in a top-down RPG]. Only add a function that computes source, target, hits and unit from game coordinates plus the onHit wiring; do not change the effect code.'),
    }];
    if (d.tiers > 1) items.push({
      title: '최상위 단계 시그니처',
      text: L('최상위 단계(' + topName + ')만의 시그니처 연출을 하나 더해 줘. 예: 위에서 내려오는 광기둥, 슬로 모션, 두 번째 충격파. 아래 단계와 한눈에 구분돼야 하고 아래 단계에는 나오지 않는다.',
        'Add one signature moment only the top level (' + topName + ') gets, such as a light pillar, slow motion or a second shockwave. It must be instantly distinguishable and never appear on lower levels.'),
    });
    items.push({
      title: '증상 고치기',
      text: L('다음 문제가 보인다: [증상을 구체적으로. 예: 섬광 뒤 화면이 뿌옇게 남는다, 파편이 너무 작아 안 보인다].\n원인을 먼저 짚고, 제약 시트를 어기지 않는 방법으로 고쳐 줘. 고친 뒤 같은 증상이 다시 나오지 않는지 확인한 방법도 알려 줘.',
        'I see this problem: [describe it precisely, e.g. the screen stays washed out after the flash].\nExplain the cause first, fix it without breaking the constraint sheet, and tell me how you verified it.'),
    }, {
      title: '성능 점검',
      text: L('모바일 웹(Wasm) 기준으로 성능을 점검해 줘. 프레임 루프 안 객체 생성, 프레임당 draw 호출 수, 최상위 단계 최대 입자 수를 확인하고 예산(입자 ' + s.maxParticles + '개, draw ' + s.maxDrawCalls + '회)을 넘는 부분을 고쳐 줘.',
        'Audit performance for mobile web (Wasm): allocations in the frame loop, draw calls per frame and peak particles on the top level. Fix anything over budget (' + s.maxParticles + ' particles, ' + s.maxDrawCalls + ' draw calls).'),
    });
    if (s.output !== 'flutterOnly') items.push({
      title: s.output === 'htmlPortable' ? 'Flutter로 옮기기' : 'HTML과 Dart 대조',
      text: s.output === 'htmlPortable'
        ? L('이 HTML 프로토타입을 Flutter로 옮겨 줘. ' + code(d.pascal + 'Spec') + ', 컨트롤러, ' + FX.byId(FX.TARGETS, s.target).label + ' 구현을 만들고 SPEC 값과 Canvas 2D 호출이 어떤 Dart API로 옮겨졌는지 표로 보여 줘. ' + code('flutter analyze') + ' 경고 0까지 확인해 줘.',
            'Port this HTML prototype to Flutter: build ' + code(d.pascal + 'Spec') + ', the controller and ' + FX.byId(FX.TARGETS, s.target).en + '. Show which Dart API replaced each Canvas 2D call and get ' + code('flutter analyze') + ' to zero issues.')
        : L('HTML 프로토타입의 SPEC과 Dart ' + code(d.pascal + 'Spec') + ' 값을 표로 대조하고 다른 값을 맞춰 줘.', 'Compare the HTML SPEC with the Dart ' + code(d.pascal + 'Spec') + ' in a table and fix any mismatch.'),
    });
    return items;
  };
})();
