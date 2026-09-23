/* 이펙트 프롬프트 빌더: 선택지 데이터와 파생 값 계산 */
(function () {
  'use strict';
  const FX = (window.FX = window.FX || {});

  FX.STEPS = [
    { id: 'purpose', label: '용도', title: '무엇을 위한 이펙트인가요?', lead: '어떤 순간에 무엇이 터지는지 정합니다. 고른 용도에 맞춰 다음 단계의 추천값이 채워집니다.' },
    { id: 'style', label: '스타일', title: '어떤 방식으로 그릴까요?', lead: '프롬프트의 렌더링 규칙과 Flutter 그리기 방식이 여기서 갈립니다.' },
    { id: 'palette', label: '색', title: '어떤 색을 쓸까요?', lead: '색을 역할별로 정합니다. 강조색은 등급 순서대로 쓰입니다.' },
    { id: 'layers', label: '구성 요소', title: '화면에 무엇이 나올까요?', lead: '많이 고를수록 화려하지만 한 번에 읽기 어려워집니다. 핵심 3~6개에 화면 연출 1~2개가 무난합니다.' },
    { id: 'timing', label: '타이밍', title: '얼마나 길게, 어떤 리듬으로?', lead: '예고, 정지, 폭발, 여운의 길이를 정합니다. 쥬시한 느낌은 대부분 예고와 정지의 대비에서 나옵니다.' },
    { id: 'tiers', label: '강도와 등급', title: '얼마나 세게, 몇 단계로?', lead: '전체 강도와 등급 수를 정하고, 요소마다 몇 등급부터 나올지 정합니다.' },
    { id: 'feedback', label: '접근성과 피드백', title: '모션 줄이기와 손끝 반응', lead: '모션 줄이기 설정을 켠 사용자, 햅틱, 소리를 어떻게 다룰지 정합니다.' },
    { id: 'flutter', label: 'Flutter 구현', title: 'Flutter에서 어떻게 그릴까요?', lead: '그리기 구조, 대상 플랫폼, 성능 예산을 정합니다. 이 단계가 결과물을 Flutter에서 바로 쓸 수 있게 만듭니다.' },
    { id: 'output', label: '결과물', title: '무엇을 받을까요?', lead: '받을 파일, 이펙트 이름, 프롬프트 언어를 정합니다.' },
    { id: 'result', label: '프롬프트', title: '완성된 프롬프트', lead: '복사해서 AI 코딩 도구에 붙여 넣으세요. 결과를 본 뒤 아래 후속 프롬프트로 한 단계씩 다듬습니다.' },
  ];

  FX.TRIGGERS = [
    { id: 'event', label: '게임 이벤트', desc: '코드에서 play()를 호출', en: 'starts when game code calls play(tier)' },
    { id: 'tap', label: '탭', desc: '누르면 바로 터짐', en: 'starts on tap' },
    { id: 'hold', label: '길게 누르기', desc: '누르는 동안 충전', en: 'charges while held and bursts on release or full charge' },
    { id: 'auto', label: '자동', desc: '화면에 나오면 시작', en: 'starts automatically' },
  ];

  FX.PLAYBACKS = [
    { id: 'oneShot', label: '한 번', desc: '끝나면 대기 상태로' },
    { id: 'loop', label: '반복', desc: '잠깐 쉬고 다시 재생' },
  ];

  FX.PALETTES = [
    { id: 'gem', label: '보석', colors: { bg: '#0f1026', subject: '#3a8dff', highlight: '#ffffff', accents: ['#5ee0ff', '#ffd166', '#ff5c8a', '#b388ff'] } },
    { id: 'arcane', label: '밤하늘 마법', colors: { bg: '#0d0b1e', subject: '#2b2461', highlight: '#f5ecd9', accents: ['#d6deec', '#46e2d2', '#c480ff', '#ffcb52'] } },
    { id: 'fire', label: '불꽃', colors: { bg: '#140806', subject: '#8a3414', highlight: '#fff4d6', accents: ['#ffb347', '#ff7a1a', '#ff3b2f', '#ffe066'] } },
    { id: 'frost', label: '얼음', colors: { bg: '#06121c', subject: '#1d4e89', highlight: '#f0fbff', accents: ['#9be7ff', '#5ec8ff', '#7a9cff', '#e0f7ff'] } },
    { id: 'neon', label: '네온', colors: { bg: '#0a0014', subject: '#2a1466', highlight: '#ffffff', accents: ['#00f0ff', '#ff2bd6', '#b6ff00', '#ffe600'] } },
    { id: 'reward', label: '골드 보상', colors: { bg: '#1a1206', subject: '#f2b33d', highlight: '#fffbe6', accents: ['#ffe08a', '#ffc933', '#ff9f1a', '#fff1a8'] } },
    { id: 'mono', label: '흑백 임팩트', colors: { bg: '#0b0b0b', subject: '#4a4a4a', highlight: '#ffffff', accents: ['#bdbdbd', '#e0e0e0', '#ff3b3b', '#ffffff'] } },
  ];

  FX.STYLES = [
    { id: 'pixel', label: '픽셀 아트', en: 'pixel art', desc: '정수 배율, 고정 팔레트, 계단식 움직임. 레트로 게임 느낌.' },
    { id: 'neon', label: '네온 가산광', en: 'additive neon light', desc: '어두운 배경 위에서 겹칠수록 밝아지는 빛. 보석, 마법, SF.' },
    { id: 'cartoon', label: '카툰 임팩트', en: 'cartoon impact', desc: '두꺼운 외곽선, 평면 채색, 과장된 스쿼시와 속도선.' },
    { id: 'painterly', label: '부드러운 번짐', en: 'soft painterly glow', desc: '낮은 불투명도의 번짐과 느린 흐름. 분위기 연출.' },
    { id: 'minimal', label: '미니멀 모션', en: 'minimal motion graphics', desc: '얇은 선과 기하 도형. 정확한 타이밍으로 세련되게.' },
  ];

  FX.PIXEL_RES = ['64x64', '96x72', '128x96', '160x120', '256x192'];
  FX.PIXEL_FPS = [8, 10, 12, 15, 24, 60];

  FX.LAYER_CATS = [
    { id: 'light', label: '빛' },
    { id: 'particle', label: '입자' },
    { id: 'shape', label: '형태와 글자' },
    { id: 'screen', label: '화면 연출' },
  ];

  FX.LAYERS = [
    { id: 'flash', cat: 'light', label: '섬광', en: 'Flash', desc: '임팩트 첫 순간의 밝은 번쩍임', weight: 1 },
    { id: 'glow', cat: 'light', label: '후광', en: 'Glow', desc: '주인공 뒤에서 차오르고 식는 빛', weight: 1 },
    { id: 'rays', cat: 'light', label: '광선', en: 'Light rays', desc: '중심에서 회전하며 뻗는 빛줄기', weight: 2 },
    { id: 'rim', cat: 'light', label: '테두리 빛', en: 'Rim light', desc: '주인공 가장자리가 밝아짐', weight: 1 },
    { id: 'sparks', cat: 'particle', label: '스파크', en: 'Sparks', desc: '사방으로 튀는 작은 빛 입자', weight: 1 },
    { id: 'shards', cat: 'particle', label: '파편', en: 'Shards', desc: '깨진 조각이 회전하며 흩어짐', weight: 1 },
    { id: 'orbit', cat: 'particle', label: '수렴 입자', en: 'Converging particles', desc: '예고 동안 중심으로 빨려 듦', weight: 1 },
    { id: 'embers', cat: 'particle', label: '불씨와 먼지', en: 'Embers and dust', desc: '여운 동안 천천히 떠오름', weight: 2 },
    { id: 'confetti', cat: 'particle', label: '색종이', en: 'Confetti', desc: '위로 터져 흔들리며 떨어짐', weight: 3 },
    { id: 'trail', cat: 'particle', label: '궤적', en: 'Trails', desc: '날아가는 빛이 남기는 잔상', weight: 2 },
    { id: 'ring', cat: 'shape', label: '충격파 링', en: 'Shockwave ring', desc: '퍼져 나가며 얇아지는 원', weight: 1 },
    { id: 'lightning', cat: 'shape', label: '번개', en: 'Lightning', desc: '지그재그로 갈라지는 전기', weight: 3 },
    { id: 'cracks', cat: 'shape', label: '균열', en: 'Cracks', desc: '충전하며 표면에 번지는 금', weight: 1 },
    { id: 'textPop', cat: 'shape', label: '결과 텍스트', en: 'Result text', desc: '점수나 등급 이름이 튀어나옴', weight: 1 },
    { id: 'squash', cat: 'shape', label: '스쿼시 앤 스트레치', en: 'Squash and stretch', desc: '눌렸다 늘어나며 튕기는 몸체', weight: 1 },
    { id: 'shake', cat: 'screen', label: '화면 흔들림', en: 'Screen shake', desc: '임팩트의 물리적 무게', weight: 2 },
    { id: 'zoom', cat: 'screen', label: '줌 펀치', en: 'Zoom punch', desc: '순간 확대 후 복귀', weight: 3 },
    { id: 'chroma', cat: 'screen', label: '색 분리', en: 'Chromatic split', desc: '빨강과 청록이 잠깐 어긋남', weight: 3 },
    { id: 'invert', cat: 'screen', label: '임팩트 프레임', en: 'Impact frames', desc: '정지 순간의 반전 실루엣 컷', weight: 4 },
    { id: 'vignette', cat: 'screen', label: '주변 어둡게', en: 'Vignette', desc: '예고 동안 시선을 중심으로', weight: 2 },
    { id: 'slowmo', cat: 'screen', label: '슬로 모션', en: 'Slow motion', desc: '폭발 초반을 느리게 보여 줌', weight: 4 },
  ];

  FX.EASINGS = [
    { id: 'snappy', label: '빠르고 단단하게', desc: '처음 20% 시간에 대부분 이동' },
    { id: 'elastic', label: '탄성 있게', desc: '살짝 넘쳤다 되돌아옴' },
    { id: 'smooth', label: '부드럽게', desc: '천천히 가속하고 감속' },
    { id: 'stepped', label: '계단식', desc: '프레임 수를 줄인 픽셀 느낌' },
  ];

  FX.INTENSITY = ['은은하게', '산뜻하게', '쥬시하게', '아주 쥬시하게', '언리얼'];
  FX.INTENSITY_EN = ['subtle', 'crisp', 'juicy', 'very juicy', 'unreal'];

  FX.TARGETS = [
    { id: 'customPainter', label: 'CustomPainter 위젯', en: 'a CustomPainter widget', desc: '패키지 없이 어느 Flutter 화면에나 겹쳐 붙입니다.' },
    { id: 'flame', label: 'Flame 컴포넌트', en: 'a Flame component', desc: 'Flame 게임 루프 안에서 보드나 캐릭터와 함께 그립니다.' },
    { id: 'shader', label: '셰이더 + CustomPainter', en: 'a fragment shader plus CustomPainter', desc: '넓은 빛과 왜곡은 GPU 셰이더로, 입자는 페인터로 그립니다.' },
  ];

  FX.PLATFORMS = [
    { id: 'web', label: '웹 (Wasm)' },
    { id: 'ios', label: 'iOS' },
    { id: 'android', label: 'Android' },
    { id: 'desktop', label: '데스크톱' },
  ];

  FX.PERF = [
    { id: 'pool', label: '고정 크기 풀, 루프 안 객체 생성 0' },
    { id: 'atlas', label: 'drawRawAtlas로 입자 묶어 그리기' },
    { id: 'noBlur', label: '런타임 blur와 saveLayer 금지' },
    { id: 'fixedStep', label: '고정 60Hz 스텝과 dt 상한' },
    { id: 'seeded', label: '시드 고정 난수' },
    { id: 'autoQuality', label: '느려지면 입자 수 자동 감소' },
  ];

  FX.OUTPUTS = [
    { id: 'htmlAndFlutter', label: 'HTML 프로토타입 + Flutter', desc: '브라우저에서 느낌을 먼저 잡고 같은 수치로 Dart에 옮깁니다.' },
    { id: 'flutterOnly', label: 'Flutter만', desc: 'Dart 파일만 받습니다.' },
    { id: 'htmlPortable', label: 'HTML만 (Flutter 이식 규칙)', desc: '지금은 HTML로 보고, 나중에 그대로 옮길 수 있게 만듭니다.' },
  ];

  FX.DELIVERABLES = [
    { id: 'sheet', label: '제약 시트 주석', desc: '파일 맨 위에 규칙 요약을 남김' },
    { id: 'demo', label: '확인용 데모 화면', desc: '등급 버튼과 0.25배속' },
    { id: 'test', label: '위젯 테스트', desc: '끝까지 재생해도 예외와 잔여 입자 없음' },
    { id: 'tuning', label: '수치 조절 패널', desc: '슬라이더로 조절하고 상수로 복사' },
  ];

  FX.REDUCED = [
    { id: 'soft', label: '짧은 페이드 버전', desc: '흔들림, 줌, 섬광, 슬로 모션을 끄고 입자를 30%로 줄임' },
    { id: 'final', label: '결과만 표시', desc: '연출 없이 최종 상태를 바로 보여 줌' },
  ];
  FX.HAPTICS = [
    { id: 'impact', label: '임팩트에만', desc: '등급이 높을수록 강하게' },
    { id: 'rich', label: '충전과 임팩트', desc: '균열이나 충전 단계마다 짧게' },
    { id: 'none', label: '없음', desc: '' },
  ];
  FX.SOUNDS = [
    { id: 'cues', label: '타이밍 신호만', desc: '소리는 내지 않고 onCue 콜백으로 알림' },
    { id: 'design', label: '신호 + 소리 설계안', desc: '콜백과 어울리는 소리 설계를 표로 제안' },
    { id: 'none', label: '사용 안 함', desc: '' },
  ];
  FX.CONTEXTS = [
    { id: 'none', label: '일반 Flutter 프로젝트', desc: '어느 저장소에나 붙일 수 있는 독립 코드' },
    { id: 'stonematch', label: 'Stone Match (이 저장소)', desc: 'Flame 1.35 구조와 기존 연출 패턴을 따르게 함' },
  ];

  const T = (ko, en) => ({ ko, en });

  FX.PURPOSES = [
    {
      id: 'matchBurst', label: '매치 파편', en: 'match clear burst', desc: '같은 색이 맞춰져 사라지는 순간. 짧고 자주 반복됩니다.', shape: 'gem', name: 'gem_burst',
      subject: T('같은 색 보석 3개가 한 줄로 맞춰져 터지며 사라진다', 'three same-colored gems line up, burst and disappear'),
      trigger: 'event', playback: 'oneShot', style: 'neon', palette: 'gem',
      layers: ['flash', 'glow', 'sparks', 'shards', 'ring', 'textPop'],
      phases: { anticipation: 0, hitstop: 40, burst: 320, afterglow: 260 }, easing: 'snappy', intensity: 3, tiers: 3,
      tierNames: T(['3개 매치', '4개 매치', '5개 매치', '연쇄 콤보'], ['Match 3', 'Match 4', 'Match 5', 'Chain combo']),
      texts: ['+300', '+600', '+1200', 'COMBO!'],
    },
    {
      id: 'specialBlast', label: '특수 폭발', en: 'special gem blast', desc: '폭탄, 번개, 초신성처럼 판 전체가 반응하는 큰 한 방.', shape: 'gem', name: 'special_blast',
      subject: T('특수 보석이 발동해 주변 칸을 휩쓰는 폭발을 일으킨다', 'a special gem triggers a blast that sweeps the surrounding tiles'),
      trigger: 'event', playback: 'oneShot', style: 'neon', palette: 'fire',
      layers: ['glow', 'flash', 'ring', 'sparks', 'shards', 'rays', 'embers', 'shake', 'lightning', 'zoom'],
      phases: { anticipation: 140, hitstop: 70, burst: 460, afterglow: 420 }, easing: 'snappy', intensity: 4, tiers: 3,
      tierNames: T(['폭탄', '번개', '초신성', '연쇄 폭발'], ['Bomb', 'Lightning', 'Supernova', 'Chain blast']),
      texts: ['BOOM!', 'ZAP!', 'SUPERNOVA!', 'CHAIN!'],
    },
    {
      id: 'reveal', label: '보상 공개', en: 'reward reveal', desc: '카드나 상자를 길게 눌러 열고 등급이 드러나는 순간.', shape: 'card', name: 'card_reveal',
      subject: T('뒷면인 카드를 길게 누르면 균열이 번지다 깨지며 앞면과 등급이 드러난다', 'holding a face-down card spreads cracks until it shatters and reveals the face and its rarity'),
      trigger: 'hold', playback: 'oneShot', style: 'neon', palette: 'arcane',
      layers: ['orbit', 'cracks', 'glow', 'rim', 'flash', 'invert', 'shards', 'ring', 'rays', 'sparks', 'confetti', 'shake', 'zoom', 'textPop', 'vignette', 'slowmo'],
      phases: { anticipation: 1400, hitstop: 110, burst: 720, afterglow: 1500 }, easing: 'elastic', intensity: 5, tiers: 4,
      tierNames: T(['일반', '희귀', '영웅', '전설'], ['Common', 'Rare', 'Epic', 'Legendary']),
      texts: null,
    },
    {
      id: 'spell', label: '스킬 시전', en: 'spell cast', desc: '힘을 모았다가 쏘아 보내는 마법이나 기술. 반복 재생에 어울립니다.', shape: 'orb', name: 'spell_cast',
      subject: T('지팡이 끝 보석에 마력이 모였다가 빛나는 탄환으로 발사된다', 'magic gathers in the gem on a staff tip, then fires as a glowing projectile'),
      trigger: 'auto', playback: 'loop', style: 'pixel', palette: 'arcane',
      layers: ['orbit', 'glow', 'rim', 'flash', 'sparks', 'trail', 'ring', 'shake'],
      phases: { anticipation: 900, hitstop: 50, burst: 520, afterglow: 600 }, easing: 'snappy', intensity: 3, tiers: 2,
      tierNames: T(['기본', '충전', '궁극', '초월'], ['Basic', 'Charged', 'Ultimate', 'Transcendent']),
      texts: ['CAST!', 'CHARGED!', 'ULTIMATE!', 'BEYOND!'],
    },
    {
      id: 'celebration', label: '클리어 축하', en: 'level clear celebration', desc: '레벨 클리어나 신기록처럼 보상을 크게 알리는 장면.', shape: 'star', name: 'level_clear',
      subject: T('별 배지가 튀어 오르며 클리어를 알리고 화면에 축하가 쏟아진다', 'a star badge pops up to announce the clear while celebration rains over the screen'),
      trigger: 'event', playback: 'oneShot', style: 'cartoon', palette: 'reward',
      layers: ['squash', 'flash', 'rays', 'sparks', 'confetti', 'textPop', 'glow', 'ring'],
      phases: { anticipation: 200, hitstop: 0, burst: 900, afterglow: 1800 }, easing: 'elastic', intensity: 4, tiers: 3,
      tierNames: T(['별 1개', '별 2개', '별 3개', '신기록'], ['1 star', '2 stars', '3 stars', 'New record']),
      texts: ['CLEAR!', 'GREAT!', 'PERFECT!', 'NEW RECORD!'],
    },
    {
      id: 'uiFeedback', label: 'UI 피드백', en: 'UI feedback', desc: '버튼 탭, 코인 획득처럼 작고 빠른 반응.', shape: 'button', name: 'reward_pop',
      subject: T('버튼을 누르면 살짝 눌렸다 튀어 오르며 작은 빛과 입자가 번진다', 'a button squashes when pressed, springs back and releases a small glint and particles'),
      trigger: 'tap', playback: 'oneShot', style: 'minimal', palette: 'gem',
      layers: ['squash', 'glow', 'sparks', 'ring', 'textPop'],
      phases: { anticipation: 60, hitstop: 0, burst: 220, afterglow: 180 }, easing: 'elastic', intensity: 2, tiers: 2,
      tierNames: T(['탭', '획득', '대량 획득', '잭팟'], ['Tap', 'Collect', 'Big collect', 'Jackpot']),
      texts: ['+1', '+10', '+100', 'JACKPOT!'],
    },
    {
      id: 'ambient', label: '분위기 루프', en: 'ambient loop', desc: '대기 화면이나 배경에서 계속 도는 잔잔한 움직임.', shape: 'orb', name: 'ambient_glow',
      subject: T('화면 중앙의 빛이 천천히 숨쉬고 주변에 먼지와 불씨가 떠다닌다', 'a light at the center breathes slowly while dust and embers drift around it'),
      trigger: 'auto', playback: 'loop', style: 'painterly', palette: 'frost',
      layers: ['glow', 'embers', 'rim'],
      phases: { anticipation: 1200, hitstop: 0, burst: 600, afterglow: 1600 }, easing: 'smooth', intensity: 1, tiers: 1,
      tierNames: T(['평온', '활발', '고조', '절정'], ['Calm', 'Lively', 'Rising', 'Peak']),
      texts: ['', '', '', ''],
    },
  ];

  FX.byId = (list, id) => list.find((x) => x.id === id) || list[0];
  FX.clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

  FX.copyColors = (c) => ({ bg: c.bg, subject: c.subject, highlight: c.highlight, accents: c.accents.slice() });

  FX.applyPurpose = function (s, purposeId) {
    const p = FX.byId(FX.PURPOSES, purposeId);
    const prev = FX.byId(FX.PURPOSES, s.purpose);
    s.purpose = p.id;
    if (!s.name || s.name === prev.name) s.name = p.name;
    s.subject = '';
    s.trigger = p.trigger;
    s.playback = p.playback;
    s.style = p.style;
    s.paletteId = p.palette;
    s.colors = FX.copyColors(FX.byId(FX.PALETTES, p.palette).colors);
    s.strictPalette = p.style === 'pixel';
    s.layers = p.layers.slice();
    s.minTier = {};
    s.phases = Object.assign({}, p.phases);
    s.easing = p.style === 'pixel' ? 'stepped' : p.easing;
    s.intensity = p.intensity;
    s.tiers = p.tiers;
    s.tierNames = ['', '', '', ''];
    return s;
  };

  FX.defaultState = function () {
    const s = {
      v: 1, step: 0, purpose: 'matchBurst', name: 'gem_burst', subject: '',
      trigger: 'event', playback: 'oneShot', loopGap: 600,
      style: 'neon', pixelRes: '128x96', pixelFps: 12, dither: true,
      paletteId: 'gem', colors: null, strictPalette: false,
      layers: [], minTier: {},
      phases: { anticipation: 0, hitstop: 40, burst: 320, afterglow: 260 }, easing: 'snappy', tierStretch: true,
      intensity: 3, tiers: 3, tierNames: ['', '', '', ''],
      reducedMotion: 'soft', haptics: 'impact', sound: 'cues',
      target: 'customPainter', platforms: ['web', 'ios', 'android'],
      perf: { pool: true, atlas: true, noBlur: true, fixedStep: true, seeded: true, autoQuality: false },
      maxParticles: 256, maxDrawCalls: 8, context: 'none',
      output: 'htmlAndFlutter', deliverables: { sheet: true, demo: true, test: true, tuning: false }, lang: 'ko',
    };
    return FX.applyPurpose(s, 'matchBurst');
  };

  FX.snake = function (raw) {
    const s = String(raw || '').trim().replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    if (!s) return '';
    return /^[a-z]/.test(s) ? s : 'fx_' + s;
  };
  FX.pascal = (snake) => snake.split('_').filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');

  const SPARKS = [6, 12, 20, 32, 48];
  const SHARDS = [4, 6, 8, 12, 16];
  const CONFETTI = [10, 18, 28, 40, 60];
  const ORBIT = [8, 12, 18, 26, 36];
  const EMBERS = [4, 8, 12, 18, 26];
  const FLASH_ALPHA = [0.3, 0.45, 0.6, 0.75, 0.85];
  const FLASH_MS = [60, 80, 100, 120, 140];
  const SHAKE_PCT = [0.3, 0.6, 1.0, 1.6, 2.4];
  const SHAKE_PX = [1, 1, 2, 2, 3];
  const ZOOM = [1.01, 1.02, 1.04, 1.06, 1.08];

  FX.derive = function (s) {
    const p = FX.byId(FX.PURPOSES, s.purpose);
    const lang = s.lang === 'en' ? 'en' : 'ko';
    const tiers = FX.clamp(s.tiers | 0, 1, 4);
    const ii = FX.clamp(s.intensity | 0, 1, 5) - 1;
    const layers = FX.LAYERS.filter((l) => s.layers.includes(l.id));
    const minTier = {};
    layers.forEach((l) => { minTier[l.id] = FX.clamp((s.minTier && s.minTier[l.id]) || Math.min(l.weight, tiers), 1, tiers); });
    const on = (id, t) => minTier[id] !== undefined && t >= minTier[id];
    const mul = (t) => 1 + 0.6 * (t - 1);
    const tierList = [];
    for (let t = 1; t <= tiers; t++) {
      const c = {
        tier: t,
        sparks: on('sparks', t) ? Math.round(SPARKS[ii] * mul(t)) : 0,
        shards: on('shards', t) ? Math.round(SHARDS[ii] * mul(t)) : 0,
        confetti: on('confetti', t) ? Math.round(CONFETTI[ii] * mul(t)) : 0,
        orbit: on('orbit', t) ? Math.round(ORBIT[ii] * mul(t)) : 0,
        comets: on('trail', t) ? 1 + t : 0,
        rings: on('ring', t) ? (ii === 0 ? 1 : Math.min(t, 4)) : 0,
        rays: on('rays', t) ? 6 + 2 * (t - 1) : 0,
        bolts: on('lightning', t) ? 2 + t : 0,
        newLayers: layers.filter((l) => minTier[l.id] === t).map((l) => l.id),
      };
      c.total = c.sparks + c.shards + c.confetti + c.orbit + c.comets * 9 + Math.round(EMBERS[ii] * 1.2 * (on('embers', t) ? 1 : 0));
      tierList.push(c);
    }
    const snake = FX.snake(s.name) || p.name;
    const res = String(s.pixelRes || '128x96').split('x').map(Number);
    const subjectDefault = p.subject[lang];
    const tierNames = [];
    for (let t = 0; t < tiers; t++) tierNames.push(((s.tierNames && s.tierNames[t]) || '').trim() || p.tierNames[lang][t]);
    const texts = [];
    for (let t = 0; t < tiers; t++) texts.push(p.texts ? p.texts[t] : tierNames[t]);
    return {
      s, p, lang, tiers, ii, layers, minTier, on, tierList,
      style: s.style, pixel: s.style === 'pixel', pixelW: res[0] || 128, pixelH: res[1] || 96,
      snake, pascal: FX.pascal(snake), subject: (s.subject || '').trim() || subjectDefault,
      tierNames, texts, colors: s.colors, phases: s.phases, shape: p.shape,
      stretch: (t) => (s.tierStretch ? 1 + 0.2 * (t - 1) : 1),
      emberRate: EMBERS[ii], flashAlpha: FLASH_ALPHA[ii], flashMs: FLASH_MS[ii],
      shakePct: SHAKE_PCT[ii], shakePx: SHAKE_PX[ii], zoom: ZOOM[ii],
      maxTotal: Math.max.apply(null, tierList.map((c) => c.total)),
    };
  };
})();

