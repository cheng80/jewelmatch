/* 이펙트 프롬프트 빌더: 선택지 데이터와 파생 값 계산 */
(function () {
  'use strict';
  const FX = (window.FX = window.FX || {});
  const T = (ko, en) => ({ ko, en });

  FX.STEPS = [
    { id: 'effect', label: '이펙트 종류', title: '어떤 이펙트를 만들까요?', lead: '동작 방식으로 고릅니다. 고른 종류에 맞춰 다음 단계의 추천값이 채워지고, 어느 게임에나 붙일 수 있도록 좌표와 범위를 입력으로 받는 구조로 만듭니다.' },
    { id: 'scope', label: '발동과 범위', title: '어디서 시작해 어디까지 닿나요?', lead: '발동 방식, 효과 범위, 게임 시점을 정합니다. 퍼즐 판이 없는 게임에서도 같은 범위 규칙을 좌표로 옮겨 씁니다.' },
    { id: 'style', label: '스타일', title: '어떤 방식으로 그릴까요?', lead: '마법사 도트 글처럼 낮은 해상도의 픽셀 아트가 기본입니다. 다른 방식도 고를 수 있습니다.' },
    { id: 'palette', label: '색', title: '어떤 색을 쓸까요?', lead: '속성별 팔레트에서 고르고 역할별로 바꿀 수 있습니다. 강조색은 단계 순서대로 쓰입니다.' },
    { id: 'layers', label: '구성 요소', title: '화면에 무엇이 나올까요?', lead: '많이 고를수록 화려하지만 한 번에 읽기 어려워집니다. 핵심 4~7개에 화면 연출 1~2개가 무난합니다.' },
    { id: 'timing', label: '타이밍', title: '얼마나 길게, 어떤 리듬으로?', lead: '차지, 이동, 정지, 임팩트, 여운의 길이를 정합니다. 쥬시한 느낌은 대부분 차지와 정지의 대비에서 나옵니다.' },
    { id: 'tiers', label: '강도와 단계', title: '얼마나 세게, 몇 단계로?', lead: '전체 강도와 단계 수를 정하고 요소마다 몇 단계부터 나올지 정합니다. 퍼즐이면 연쇄 수, 스킬이면 충전 단계, 타격이면 치명타로 쓰면 됩니다.' },
    { id: 'feedback', label: '접근성과 피드백', title: '설정, 햅틱, 소리', lead: '모션 줄이기, 플레이어가 고르는 이펙트 세기, 햅틱, 소리 연결 방식을 정합니다.' },
    { id: 'flutter', label: 'Flutter 구현', title: 'Flutter에서 어떻게 그릴까요?', lead: '그리기 구조, 대상 플랫폼, 성능 예산을 정합니다. 이 단계가 결과물을 Flutter에서 바로 쓸 수 있게 만듭니다.' },
    { id: 'output', label: '결과물', title: '무엇을 받을까요?', lead: '받을 파일, 이펙트 이름, 프롬프트 언어를 정합니다.' },
    { id: 'result', label: '프롬프트', title: '완성된 프롬프트', lead: '복사해서 AI 코딩 도구에 붙여 넣으세요. 결과를 본 뒤 아래 후속 프롬프트로 한 단계씩 다듬습니다.' },
  ];

  FX.TRIGGERS = [
    { id: 'event', label: '게임 이벤트', desc: '코드에서 play()를 호출', en: 'starts when game code calls play()' },
    { id: 'tap', label: '탭', desc: '누르면 바로 발동', en: 'starts on tap' },
    { id: 'hold', label: '길게 누르기', desc: '누르는 동안 충전', en: 'charges while held and fires on release or full charge' },
    { id: 'auto', label: '자동', desc: '화면에 나오면 시작', en: 'starts automatically' },
  ];
  FX.PLAYBACKS = [
    { id: 'oneShot', label: '한 번', desc: '끝나면 대기 상태로' },
    { id: 'loop', label: '반복', desc: '잠깐 쉬고 다시 재생' },
  ];

  FX.DELIVERIES = [
    { id: 'self', label: '제자리 폭발', desc: '발동한 자리에서 바로 터짐', en: 'bursts in place at the anchor', travel: false },
    { id: 'projectile', label: '탄환', desc: '발동점에서 날아가 맞은 곳에서 터짐', en: 'a projectile flies from the source and bursts on arrival', travel: true },
    { id: 'beam', label: '빔', desc: '발동점과 대상을 잇는 빛줄기', en: 'a continuous beam links source and target', travel: true },
    { id: 'sky', label: '위에서 낙하', desc: '표식이 뜬 자리에 번개나 운석이 떨어짐', en: 'a strike drops from above onto a telegraphed spot', travel: true },
    { id: 'bolts', label: '갈래 줄기', desc: '발동점에서 대상마다 줄기가 차례로 뻗음', en: 'arcs branch from the source to each hit point in turn', travel: true },
    { id: 'sweep', label: '쓸고 지나가기', desc: '발동점에서 범위를 따라 차례로 터짐', en: 'a front sweeps out from the anchor and pops hits as it passes', travel: true },
    { id: 'melee', label: '근접 타격', desc: '대상 바로 앞에서 베기 궤적', en: 'a close-range slash arc across the target', travel: true },
    { id: 'aura', label: '오라', desc: '발동점을 감싸고 위로 솟음', en: 'an aura wraps the source and rises', travel: false },
    { id: 'collect', label: '수집 비행', desc: '입자가 목적지(HUD)로 날아가 흡수', en: 'pickups fly to a HUD destination and are absorbed', travel: true },
    { id: 'sequence', label: '순차 폭발', desc: '범위 안 지점이 하나씩 차례로 터짐', en: 'points in the area detonate one after another', travel: true },
    { id: 'loop', label: '지속 상태', desc: '끄기 전까지 맥동하며 반복', en: 'a sustained state that pulses until stopped', travel: false },
  ];

  FX.AREAS = [
    { id: 'point', label: '한 점', desc: '대상 하나', en: 'a single target' },
    { id: 'match3', label: '나란한 3칸', desc: '기본 매치처럼 한 줄 3칸', en: 'three cells in a line, like a basic match' },
    { id: 'area3', label: '3x3 범위', desc: '대상과 둘레 8칸', en: 'the target and its 8 neighbours' },
    { id: 'row', label: '한 줄 전체', desc: '가로 한 줄', en: 'one full row' },
    { id: 'cross', label: '십자', desc: '가로와 세로 한 줄씩', en: 'one full row and one full column' },
    { id: 'cross3', label: '굵은 십자', desc: '가로 3줄과 세로 3줄', en: 'three rows and three columns' },
    { id: 'color', label: '같은 종류 전체', desc: '흩어진 같은 색 칸이나 같은 적', en: 'every scattered cell of the same kind' },
    { id: 'scatter', label: '무작위 여러 곳', desc: '범위 안 여러 지점', en: 'several random points in the area' },
    { id: 'all', label: '화면 전체', desc: '판이나 화면 전부', en: 'the whole board or screen' },
  ];

  FX.VIEWS = [
    { id: 'side', label: '횡스크롤', desc: '옆에서 본 장면. 중력과 바닥선이 있음', en: 'side view with gravity and a floor line' },
    { id: 'topdown', label: '탑다운', desc: '위에서 본 장면. 그림자와 바닥면 기준', en: 'top-down view with ground shadows' },
    { id: 'board', label: '퍼즐 판', desc: '칸 단위 격자 위', en: 'a cell grid puzzle board' },
    { id: 'ui', label: 'UI 화면', desc: '버튼, HUD 같은 위젯 위', en: 'on top of UI widgets and HUD' },
  ];

  FX.PALETTES = [
    { id: 'arcane', label: '비전', colors: { bg: '#0d0b1e', subject: '#2b2461', highlight: '#f5f1ff', accents: ['#8fd8ff', '#46e2d2', '#c480ff', '#ffcb52'] } },
    { id: 'fire', label: '화염', colors: { bg: '#140806', subject: '#6b2410', highlight: '#fff4d6', accents: ['#ffb347', '#ff7a1a', '#ff3b2f', '#ffe066'] } },
    { id: 'frost', label: '냉기', colors: { bg: '#06121c', subject: '#1d4e89', highlight: '#f0fbff', accents: ['#9be7ff', '#5ec8ff', '#7a9cff', '#e0f7ff'] } },
    { id: 'storm', label: '번개', colors: { bg: '#0a0c1a', subject: '#2a3160', highlight: '#ffffff', accents: ['#fff27a', '#7ae0ff', '#b89cff', '#ffffff'] } },
    { id: 'poison', label: '독', colors: { bg: '#0c1208', subject: '#2e4a1c', highlight: '#eaffd0', accents: ['#9cf05a', '#5ad06a', '#b45ae0', '#e0ff7a'] } },
    { id: 'holy', label: '신성', colors: { bg: '#15120a', subject: '#6b5a2a', highlight: '#fffdf2', accents: ['#fff1b8', '#ffd86a', '#ffc2e0', '#ffffff'] } },
    { id: 'shadow', label: '암흑', colors: { bg: '#07050c', subject: '#241a33', highlight: '#e8d8ff', accents: ['#8a5cff', '#c24dff', '#ff4d8a', '#e8d8ff'] } },
    { id: 'nature', label: '자연', colors: { bg: '#08140e', subject: '#1f4a2c', highlight: '#f4ffe8', accents: ['#8ee67a', '#4fd1a0', '#ffe27a', '#ff9ac2'] } },
    { id: 'gem', label: '보석', colors: { bg: '#0f1026', subject: '#3a8dff', highlight: '#ffffff', accents: ['#5ee0ff', '#ffd166', '#ff5c8a', '#b388ff'] } },
    { id: 'reward', label: '골드', colors: { bg: '#1a1206', subject: '#b07a1e', highlight: '#fffbe6', accents: ['#ffe08a', '#ffc933', '#ff9f1a', '#fff1a8'] } },
    { id: 'neon', label: '네온', colors: { bg: '#0a0014', subject: '#2a1466', highlight: '#ffffff', accents: ['#00f0ff', '#ff2bd6', '#b6ff00', '#ffe600'] } },
    { id: 'mono', label: '흑백', colors: { bg: '#0b0b0b', subject: '#4a4a4a', highlight: '#ffffff', accents: ['#bdbdbd', '#e0e0e0', '#ff3b3b', '#ffffff'] } },
  ];

  FX.STYLES = [
    { id: 'pixel', label: '도트 (픽셀 아트)', en: 'pixel art', desc: '마법사 글 방식. 정수 배율, 고정 팔레트, 8~12fps처럼 끊기는 움직임.' },
    { id: 'neon', label: '네온 가산광', en: 'additive neon light', desc: '어두운 배경 위에서 겹칠수록 밝아지는 빛. 보석 퍼즐, SF.' },
    { id: 'cartoon', label: '카툰 임팩트', en: 'cartoon impact', desc: '두꺼운 외곽선, 평면 채색, 과장된 스쿼시와 속도선.' },
    { id: 'painterly', label: '부드러운 번짐', en: 'soft painterly glow', desc: '낮은 불투명도의 번짐과 느린 흐름. 분위기 연출.' },
    { id: 'minimal', label: '미니멀 모션', en: 'minimal motion graphics', desc: '얇은 선과 기하 도형. 정확한 타이밍으로 세련되게.' },
  ];
  FX.PIXEL_RES = ['96x72', '128x96', '160x120', '192x144', '256x192'];
  FX.PIXEL_FPS = [8, 10, 12, 15, 24, 60];

  FX.LAYER_CATS = [
    { id: 'light', label: '빛' },
    { id: 'particle', label: '입자' },
    { id: 'shape', label: '형태와 글자' },
    { id: 'screen', label: '화면 연출' },
  ];
  FX.LAYERS = [
    { id: 'flash', cat: 'light', label: '섬광', en: 'Flash', desc: '임팩트 첫 순간의 밝은 번쩍임', weight: 1 },
    { id: 'glow', cat: 'light', label: '후광', en: 'Glow', desc: '발동점과 임팩트 뒤에서 차오르고 식는 빛', weight: 1 },
    { id: 'rays', cat: 'light', label: '광선', en: 'Light rays', desc: '중심에서 회전하며 뻗는 빛줄기', weight: 2 },
    { id: 'rim', cat: 'light', label: '림 라이트', en: 'Rim light', desc: '이펙트 빛을 받아 캐릭터와 칸 가장자리가 밝아짐', weight: 1 },
    { id: 'pulse', cat: 'light', label: '화면 맥동', en: 'Screen pulse', desc: '판이나 화면이 박자에 맞춰 물듦', weight: 2 },
    { id: 'sparks', cat: 'particle', label: '스파크', en: 'Sparks', desc: '사방으로 튀는 작은 빛 입자', weight: 1 },
    { id: 'shards', cat: 'particle', label: '파편', en: 'Shards', desc: '깨진 조각이 회전하며 흩어짐', weight: 1 },
    { id: 'orbit', cat: 'particle', label: '모이는 입자', en: 'Gathering particles', desc: '차지 동안 발동점으로 소용돌이치며 모임', weight: 1 },
    { id: 'embers', cat: 'particle', label: '불씨와 먼지', en: 'Embers and dust', desc: '여운 동안 천천히 떠오름', weight: 2 },
    { id: 'smoke', cat: 'particle', label: '연기', en: 'Smoke puffs', desc: '터진 자리와 바닥에서 피어올라 흩어짐', weight: 1 },
    { id: 'confetti', cat: 'particle', label: '색종이', en: 'Confetti', desc: '위로 터져 흔들리며 떨어짐', weight: 3 },
    { id: 'trail', cat: 'particle', label: '궤적', en: 'Trails', desc: '날아가는 빛이 남기는 잔상', weight: 1 },
    { id: 'ring', cat: 'shape', label: '충격파 링', en: 'Shockwave ring', desc: '퍼져 나가며 얇아지는 원', weight: 1 },
    { id: 'lightning', cat: 'shape', label: '번개', en: 'Lightning', desc: '지그재그로 갈라지는 전기', weight: 3 },
    { id: 'runes', cat: 'shape', label: '마법진과 표식', en: 'Runes and markers', desc: '발동점이나 대상 아래 그려지는 원과 룬', weight: 1 },
    { id: 'cracks', cat: 'shape', label: '균열', en: 'Cracks', desc: '표면이나 바닥에 번지는 금', weight: 2 },
    { id: 'textPop', cat: 'shape', label: '결과 텍스트', en: 'Result text', desc: '점수, 연쇄 수, 이름이 튀어나옴', weight: 1 },
    { id: 'squash', cat: 'shape', label: '반동', en: 'Squash and recoil', desc: '시전자, 대상, 칸이 눌렸다 튕김', weight: 1 },
    { id: 'shake', cat: 'screen', label: '화면 흔들림', en: 'Screen shake', desc: '임팩트의 물리적 무게', weight: 2 },
    { id: 'zoom', cat: 'screen', label: '줌 펀치', en: 'Zoom punch', desc: '순간 확대 후 복귀', weight: 3 },
    { id: 'chroma', cat: 'screen', label: '색 분리', en: 'Chromatic split', desc: '빨강과 청록이 잠깐 어긋남', weight: 3 },
    { id: 'invert', cat: 'screen', label: '임팩트 프레임', en: 'Impact frames', desc: '정지 순간의 반전 실루엣 컷', weight: 4 },
    { id: 'vignette', cat: 'screen', label: '주변 어둡게', en: 'Vignette', desc: '차지 동안 주변을 어둡게 해 시선을 모음', weight: 2 },
    { id: 'slowmo', cat: 'screen', label: '슬로 모션', en: 'Slow motion', desc: '임팩트 초반을 느리게 보여 줌', weight: 4 },
  ];

  FX.EASINGS = [
    { id: 'stepped', label: '계단식', desc: '도트처럼 프레임을 끊어 보여 줌' },
    { id: 'snappy', label: '빠르고 단단하게', desc: '처음 20% 시간에 대부분 이동' },
    { id: 'elastic', label: '탄성 있게', desc: '살짝 넘쳤다 되돌아옴' },
    { id: 'smooth', label: '부드럽게', desc: '천천히 가속하고 감속' },
  ];
  FX.INTENSITY = ['은은하게', '산뜻하게', '쥬시하게', '아주 쥬시하게', '언리얼'];
  FX.INTENSITY_EN = ['subtle', 'crisp', 'juicy', 'very juicy', 'unreal'];

  FX.TARGETS = [
    { id: 'customPainter', label: 'CustomPainter 위젯', en: 'a CustomPainter widget', desc: '패키지 없이 어느 Flutter 화면에나 겹쳐 붙입니다.' },
    { id: 'flame', label: 'Flame 컴포넌트', en: 'a Flame component', desc: 'Flame 게임 루프 안에서 캐릭터나 판과 함께 그립니다.' },
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
    { id: 'htmlAndFlutter', label: 'HTML 프로토타입 + Flutter', desc: '마법사 글처럼 단일 HTML로 느낌을 먼저 잡고 같은 수치로 Dart에 옮깁니다.' },
    { id: 'flutterOnly', label: 'Flutter만', desc: 'Dart 파일만 받습니다.' },
    { id: 'htmlPortable', label: 'HTML만 (Flutter 이식 규칙)', desc: '지금은 HTML로 보고, 나중에 그대로 옮길 수 있게 만듭니다.' },
  ];
  FX.DELIVERABLES = [
    { id: 'sheet', label: '제약 시트 주석', desc: '파일 맨 위에 규칙 요약을 남김' },
    { id: 'demo', label: '데모 장면', desc: '자리표시 캐릭터나 판, 단계 버튼, 0.25배속' },
    { id: 'test', label: '위젯 테스트', desc: '끝까지 재생해도 예외와 잔여 입자 없음' },
    { id: 'tuning', label: '수치 조절 패널', desc: '슬라이더로 조절하고 상수로 복사' },
  ];
  FX.REDUCED = [
    { id: 'soft', label: '짧은 페이드 버전', desc: '흔들림, 줌, 섬광, 슬로 모션을 끄고 입자를 30%로 줄임' },
    { id: 'final', label: '결과만 표시', desc: '연출 없이 최종 상태를 바로 보여 줌' },
  ];
  FX.HAPTICS = [
    { id: 'impact', label: '임팩트에만', desc: '단계가 높을수록 강하게' },
    { id: 'rich', label: '차지와 임팩트', desc: '충전 단계나 연쇄마다 짧게' },
    { id: 'none', label: '없음', desc: '햅틱을 쓰지 않습니다.' },
  ];
  FX.SOUNDS = [
    { id: 'cues', label: '타이밍 신호만', desc: '소리는 내지 않고 onCue 콜백으로 알림' },
    { id: 'design', label: '신호 + 소리 설계안', desc: '콜백과 어울리는 소리 설계를 표로 제안' },
    { id: 'none', label: '사용 안 함', desc: '소리 관련 지시를 넣지 않습니다.' },
  ];

  const SPELL = T(['기본', '충전', '최대 충전', '궁극'], ['Basic', 'Charged', 'Full charge', 'Ultimate']);
  const CHAIN = T(['1연쇄', '2연쇄', '3연쇄', '4연쇄 이상'], ['Chain 1', 'Chain 2', 'Chain 3', 'Chain 4+']);

  FX.EFFECT_GROUPS = [
    { id: 'spell', label: '마법과 액션', desc: '마법사 도트 글처럼 캐릭터가 쏘고 맞는 이펙트' },
    { id: 'puzzle', label: '퍼즐', desc: 'Bejeweled, 캔디크러시, Tetris Effect, 뿌요뿌요식 판 이펙트' },
    { id: 'common', label: '공통', desc: '장르와 상관없이 자주 쓰는 보상과 분위기' },
  ];

  FX.EFFECTS = [
    {
      id: 'castBolt', group: 'spell', label: '마력탄 발사', en: 'magic bolt cast', desc: '모았다가 쏘고 맞은 곳에서 터진다.', ref: '마법사 도트 글', refEn: 'the pixel wizard post', name: 'magic_bolt',
      subject: T('마법사가 지팡이 끝 보석에 마력을 모았다가 빛나는 탄환을 쏘아 표적에서 터뜨린다', 'a wizard gathers mana in the gem on his staff, fires a glowing bolt, and it bursts on the target'),
      delivery: 'projectile', area: 'point', view: 'side', trigger: 'auto', playback: 'loop', palette: 'arcane',
      layers: ['orbit', 'glow', 'rim', 'runes', 'flash', 'sparks', 'trail', 'ring', 'smoke', 'shake'],
      phases: { anticipation: 900, travel: 360, hitstop: 50, burst: 420, afterglow: 700 }, stagger: 40, intensity: 3, tiers: 3, tierNames: SPELL, texts: null,
    },
    {
      id: 'beam', group: 'spell', label: '광선 빔', en: 'beam', desc: '발동점과 대상을 빛줄기로 잇는다.', ref: '마법사 도트 글 응용', refEn: 'a variation on the pixel wizard post', name: 'frost_beam',
      subject: T('마법사가 지팡이를 앞으로 내밀어 얼음 광선을 쏘고, 광선이 닿은 표적이 얼어붙으며 부서진다', 'a wizard thrusts his staff forward and fires a frost beam that freezes and shatters the target'),
      delivery: 'beam', area: 'point', view: 'side', trigger: 'auto', playback: 'loop', palette: 'frost',
      layers: ['orbit', 'glow', 'rim', 'sparks', 'shards', 'ring', 'smoke', 'shake'],
      phases: { anticipation: 700, travel: 520, hitstop: 40, burst: 380, afterglow: 500 }, stagger: 40, intensity: 3, tiers: 3, tierNames: SPELL, texts: null,
    },
    {
      id: 'strike', group: 'spell', label: '낙뢰', en: 'lightning strike', desc: '표식이 뜬 자리에 위에서 번개가 떨어진다.', ref: '액션 RPG 범위 공격', refEn: 'action RPG area attacks', name: 'thunder_strike',
      subject: T('표적 발밑에 경고 마법진이 그려지고, 잠시 뒤 하늘에서 번개가 떨어져 바닥이 갈라진다', 'a warning circle appears under the target, then lightning drops from the sky and cracks the ground'),
      delivery: 'sky', area: 'point', view: 'side', trigger: 'auto', playback: 'loop', palette: 'storm',
      layers: ['runes', 'lightning', 'flash', 'ring', 'sparks', 'smoke', 'shake', 'cracks'],
      phases: { anticipation: 700, travel: 90, hitstop: 80, burst: 420, afterglow: 600 }, stagger: 40, intensity: 4, tiers: 3, tierNames: SPELL, texts: null,
    },
    {
      id: 'hitSpark', group: 'spell', label: '타격', en: 'melee hit', desc: '베기 궤적과 스파크, 피격 반동. 치명타는 따로 강조.', ref: '액션 게임 타격감', refEn: 'action game hit feel', name: 'hit_spark',
      subject: T('검이 표적을 베면 궤적이 번쩍이고 스파크가 튀며 표적이 뒤로 밀린다', 'a sword slash flashes across the target, sparks fly and the target is knocked back'),
      delivery: 'melee', area: 'point', view: 'side', trigger: 'tap', playback: 'oneShot', palette: 'holy',
      layers: ['flash', 'sparks', 'squash', 'shake', 'textPop', 'smoke', 'invert'],
      phases: { anticipation: 120, travel: 90, hitstop: 70, burst: 260, afterglow: 280 }, stagger: 40, intensity: 3, tiers: 4, tierNames: T(['약', '중', '강', '치명타'], ['Light', 'Medium', 'Heavy', 'Critical']), texts: T(['12', '25', '48', '치명타!'], ['12', '25', '48', 'CRITICAL!']),
    },
    {
      id: 'heal', group: 'spell', label: '회복과 강화', en: 'heal and buff aura', desc: '발밑 마법진에서 빛이 솟고 입자가 위로 오른다.', ref: 'RPG 회복 마법', refEn: 'RPG healing spells', name: 'heal_aura',
      subject: T('캐릭터 발밑에 마법진이 그려지고 초록빛 입자가 몸을 감싸며 위로 솟는다', 'a circle forms under the character and green motes wrap the body and rise'),
      delivery: 'aura', area: 'point', view: 'side', trigger: 'event', playback: 'oneShot', palette: 'nature',
      layers: ['runes', 'glow', 'embers', 'rim', 'sparks', 'textPop'],
      phases: { anticipation: 300, travel: 0, hitstop: 0, burst: 700, afterglow: 1100 }, stagger: 40, intensity: 2, tiers: 3, tierNames: T(['소량', '보통', '대량', '전체'], ['Small', 'Medium', 'Large', 'Full']), texts: T(['+12', '+30', '+80', 'FULL'], ['+12', '+30', '+80', 'FULL']),
    },
    {
      id: 'matchPop', group: 'puzzle', label: '기본 매치 제거', en: 'basic match clear', desc: '같은 칸 3개가 깨져 사라진다. 짧고 자주 나온다.', ref: 'Bejeweled 기본 매치', refEn: 'Bejeweled basic matches', name: 'match_pop',
      subject: T('같은 색 보석 3개가 한 줄로 맞춰져 차례로 깨지고, 빈칸은 위에서 떨어진 보석이 채운다', 'three same-coloured gems line up, shatter in turn, and new gems fall in from above'),
      delivery: 'self', area: 'match3', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'gem',
      layers: ['flash', 'sparks', 'shards', 'ring', 'textPop', 'squash'],
      phases: { anticipation: 0, travel: 0, hitstop: 30, burst: 300, afterglow: 280 }, stagger: 35, intensity: 3, tiers: 3, tierNames: CHAIN, texts: T(['+30', '+60', '+120', '+240'], ['+30', '+60', '+120', '+240']),
    },
    {
      id: 'chain', group: 'puzzle', label: '연쇄 강화', en: 'chain escalation', desc: '연쇄 수가 오를수록 빛, 입자, 글자가 커진다.', ref: '뿌요뿌요식 연쇄', refEn: 'Puyo Puyo style chains', name: 'chain_pop',
      subject: T('떨어진 보석이 다시 맞춰질 때마다 연쇄 숫자가 크게 뜨고, 연쇄가 이어질수록 폭발이 커진다', 'each cascade match flashes a bigger chain number, and bursts grow as the chain continues'),
      delivery: 'self', area: 'match3', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'gem',
      layers: ['flash', 'sparks', 'shards', 'ring', 'textPop', 'glow', 'shake', 'rays', 'zoom'],
      phases: { anticipation: 0, travel: 0, hitstop: 50, burst: 360, afterglow: 420 }, stagger: 30, intensity: 4, tiers: 4, tierNames: CHAIN, texts: T(['1연쇄', '2연쇄!', '3연쇄!!', '4연쇄!!!'], ['CHAIN 1', 'CHAIN 2!', 'CHAIN 3!!', 'CHAIN 4!!!']),
    },
    {
      id: 'areaBlast', group: 'puzzle', label: '범위 폭발', en: 'area blast', desc: '발동 칸과 둘레 8칸이 한꺼번에 터진다.', ref: 'Bejeweled Flame 보석, 캔디크러시 포장 사탕', refEn: 'Bejeweled Flame Gem, Candy Crush wrapped candy', name: 'area_blast',
      subject: T('불꽃 보석이 부풀었다가 터지며 둘레 8칸을 함께 날려 보낸다', 'a flame gem swells, then explodes and takes its 8 neighbours with it'),
      delivery: 'self', area: 'area3', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'fire',
      layers: ['glow', 'flash', 'ring', 'sparks', 'shards', 'smoke', 'shake', 'embers', 'squash'],
      phases: { anticipation: 160, travel: 0, hitstop: 70, burst: 460, afterglow: 420 }, stagger: 45, intensity: 4, tiers: 3, tierNames: CHAIN, texts: null,
    },
    {
      id: 'crossBolt', group: 'puzzle', label: '십자 번개', en: 'cross lightning', desc: '상하좌우로 번개가 뻗으며 지나간 칸을 지운다.', ref: 'Bejeweled Star 보석, 캔디크러시 줄무늬 사탕', refEn: 'Bejeweled Star Gem, Candy Crush striped candy', name: 'cross_bolt',
      subject: T('별 보석이 번쩍이며 상하좌우로 번개를 쏘고, 번개가 지나간 칸이 차례로 깨진다', 'a star gem flashes and fires lightning four ways; cells shatter as the bolts pass'),
      delivery: 'sweep', area: 'cross', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'storm',
      layers: ['glow', 'flash', 'lightning', 'sparks', 'shards', 'ring', 'shake', 'chroma'],
      phases: { anticipation: 140, travel: 260, hitstop: 50, burst: 380, afterglow: 360 }, stagger: 30, intensity: 4, tiers: 3, tierNames: CHAIN, texts: null,
    },
    {
      id: 'lineClear', group: 'puzzle', label: '줄 제거', en: 'line clear', desc: '한 줄이 번쩍인 뒤 가운데부터 바깥으로 흩어진다.', ref: 'Tetris Effect 줄 제거', refEn: 'Tetris Effect line clears', name: 'line_clear',
      subject: T('가득 찬 한 줄이 하얗게 번쩍인 뒤 가운데에서 바깥으로 블록이 입자로 흩어진다', 'a full row flashes white, then its blocks burst into particles from the centre outward'),
      delivery: 'sweep', area: 'row', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'neon',
      layers: ['flash', 'glow', 'sparks', 'shards', 'textPop', 'shake', 'pulse'],
      phases: { anticipation: 220, travel: 220, hitstop: 40, burst: 420, afterglow: 400 }, stagger: 30, intensity: 3, tiers: 4, tierNames: T(['1줄', '2줄', '3줄', '4줄'], ['1 line', '2 lines', '3 lines', '4 lines']), texts: T(['1줄', '2줄!', '3줄!!', '4줄!!!'], ['SINGLE', 'DOUBLE!', 'TRIPLE!!', 'QUAD!!!']),
    },
    {
      id: 'colorClear', group: 'puzzle', label: '같은 종류 전체 제거', en: 'clear all of a kind', desc: '주변이 어두워지고 같은 색 칸마다 줄기가 뻗은 뒤 한꺼번에 터진다.', ref: 'Bejeweled Hypercube, 캔디크러시 컬러 폭탄', refEn: 'Bejeweled Hypercube, Candy Crush colour bomb', name: 'color_clear',
      subject: T('큐브 보석이 회전하며 빛을 모으고, 판의 같은 색 보석마다 번개 줄기를 이은 뒤 한꺼번에 터뜨린다', 'a cube gem spins up, links lightning to every gem of one colour on the board, then detonates them all'),
      delivery: 'bolts', area: 'color', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'neon',
      layers: ['vignette', 'glow', 'orbit', 'lightning', 'flash', 'sparks', 'shards', 'ring', 'shake', 'zoom'],
      phases: { anticipation: 320, travel: 620, hitstop: 60, burst: 480, afterglow: 500 }, stagger: 20, intensity: 4, tiers: 3, tierNames: CHAIN, texts: null,
    },
    {
      id: 'comboBlast', group: 'puzzle', label: '특수 조합 폭발', en: 'special combo blast', desc: '두 특수 효과가 합쳐져 굵은 십자로 크게 터진다.', ref: 'Bejeweled Supernova, 캔디크러시 특수 사탕 조합', refEn: 'Bejeweled Supernova Gem, Candy Crush special candy combos', name: 'combo_blast',
      subject: T('두 특수 보석을 맞바꾸면 판이 어두워지고 멈춘 뒤, 가로 세 줄과 세로 세 줄이 한꺼번에 날아간다', 'swapping two special gems dims and freezes the board, then three rows and three columns blow away at once'),
      delivery: 'sweep', area: 'cross3', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'fire',
      layers: ['vignette', 'glow', 'flash', 'ring', 'rays', 'lightning', 'sparks', 'shards', 'smoke', 'shake', 'zoom', 'invert', 'slowmo', 'textPop'],
      phases: { anticipation: 380, travel: 280, hitstop: 110, burst: 700, afterglow: 800 }, stagger: 30, intensity: 5, tiers: 4, tierNames: CHAIN, texts: T(['콤보!', '슈퍼!', '하이퍼!', '노바!'], ['COMBO!', 'SUPER!', 'HYPER!', 'NOVA!']),
    },
    {
      id: 'feverMode', group: 'puzzle', label: '과열 상태', en: 'fever state', desc: '판 전체가 맥동하고 불씨가 솟는 지속 상태.', ref: 'Bejeweled Blazing Speed, Tetris Effect Zone', refEn: 'Bejeweled Blazing Speed, Tetris Effect Zone', name: 'fever_mode',
      subject: T('게이지가 가득 차면 판 전체가 주황빛으로 맥동하고, 가장자리에서 불씨가 솟아오르는 과열 상태가 이어진다', 'when the meter fills, the whole board pulses orange and embers rise from its edges for as long as the state lasts'),
      delivery: 'loop', area: 'all', view: 'board', trigger: 'event', playback: 'loop', palette: 'fire',
      layers: ['pulse', 'glow', 'embers', 'rim', 'sparks'],
      phases: { anticipation: 600, travel: 0, hitstop: 0, burst: 500, afterglow: 900 }, stagger: 20, intensity: 3, tiers: 3, tierNames: T(['점화', '과열', '폭주', '최고조'], ['Ignite', 'Hot', 'Blazing', 'Peak']), texts: null,
    },
    {
      id: 'finale', group: 'puzzle', label: '마무리 연출', en: 'finale bonus', desc: '남은 특수 칸이 하나씩 차례로 터지는 마지막 보너스.', ref: 'Bejeweled Last Hurrah', refEn: 'Bejeweled Last Hurrah', name: 'finale_bonus',
      subject: T('시간이 끝나면 판에 남은 특수 보석이 하나씩 차례로 터지고, 마지막에 보너스 문구가 뜬다', 'when time runs out, the remaining special gems detonate one by one, then a bonus banner appears'),
      delivery: 'sequence', area: 'scatter', view: 'board', trigger: 'event', playback: 'oneShot', palette: 'gem',
      layers: ['flash', 'ring', 'sparks', 'shards', 'smoke', 'shake', 'textPop', 'confetti'],
      phases: { anticipation: 300, travel: 1200, hitstop: 0, burst: 500, afterglow: 900 }, stagger: 30, intensity: 4, tiers: 3, tierNames: CHAIN, texts: T(['마무리!', '보너스!', '대박!', '완벽!'], ['FINISH!', 'BONUS!', 'GREAT!', 'PERFECT!']),
    },
    {
      id: 'levelUp', group: 'common', label: '레벨 업과 클리어', en: 'level up and clear', desc: '빛기둥이 솟고 글자와 색종이가 터진다.', ref: 'RPG 레벨 업, 퍼즐 스테이지 클리어', refEn: 'RPG level ups and puzzle stage clears', name: 'level_up',
      subject: T('캐릭터 발밑에서 빛기둥이 솟고 레벨 업 글자가 튀어 오르며 색종이가 터진다', 'a pillar of light rises from under the character, a LEVEL UP banner pops and confetti bursts'),
      delivery: 'aura', area: 'point', view: 'side', trigger: 'event', playback: 'oneShot', palette: 'holy',
      layers: ['glow', 'rays', 'runes', 'flash', 'sparks', 'confetti', 'textPop', 'embers', 'squash'],
      phases: { anticipation: 400, travel: 0, hitstop: 60, burst: 800, afterglow: 1400 }, stagger: 40, intensity: 4, tiers: 3, tierNames: T(['레벨 업', '연속', '달성', '최고 기록'], ['Level up', 'Streak', 'Milestone', 'Record']), texts: T(['레벨 업!', '레벨 업!!', '달성!', '최고 기록!'], ['LEVEL UP!', 'LEVEL UP!!', 'MILESTONE!', 'NEW RECORD!']),
    },
    {
      id: 'pickup', group: 'common', label: '아이템 획득', en: 'item pickup', desc: '코인이 튀어나와 HUD로 날아가고 숫자가 오른다.', ref: '코인과 재화 획득', refEn: 'coin and currency pickups', name: 'coin_pickup',
      subject: T('상자에서 코인이 튀어나와 곡선을 그리며 화면 위 HUD로 날아가고, 닿을 때마다 숫자가 한 칸씩 오른다', 'coins pop out of a chest, arc up to the HUD, and the counter ticks up as each one lands'),
      delivery: 'collect', area: 'point', view: 'ui', trigger: 'tap', playback: 'oneShot', palette: 'reward',
      layers: ['sparks', 'trail', 'glow', 'textPop', 'squash'],
      phases: { anticipation: 0, travel: 620, hitstop: 0, burst: 260, afterglow: 320 }, stagger: 40, intensity: 3, tiers: 3, tierNames: T(['1개', '소량', '대량', '잭팟'], ['One', 'Few', 'Many', 'Jackpot']), texts: T(['+1', '+10', '+100', '잭팟!'], ['+1', '+10', '+100', 'JACKPOT!']),
    },
    {
      id: 'ambient', group: 'common', label: '분위기 루프', en: 'ambient loop', desc: '배경에서 계속 도는 잔잔한 빛과 불씨.', ref: '대기 화면과 배경 연출', refEn: 'idle screens and backgrounds', name: 'ambient_motes',
      subject: T('밤하늘 아래 빛이 천천히 숨쉬고 주변에 반딧불과 먼지가 떠다닌다', 'under the night sky a light breathes slowly while fireflies and dust drift around'),
      delivery: 'loop', area: 'all', view: 'side', trigger: 'auto', playback: 'loop', palette: 'frost',
      layers: ['glow', 'embers', 'rim'],
      phases: { anticipation: 1200, travel: 0, hitstop: 0, burst: 600, afterglow: 1600 }, stagger: 40, intensity: 1, tiers: 1, tierNames: T(['잔잔함', '활발', '고조', '절정'], ['Calm', 'Lively', 'Rising', 'Peak']), texts: null,
    },
  ];

  FX.byId = (list, id) => list.find((x) => x.id === id) || list[0];
  FX.clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  FX.copyColors = (c) => ({ bg: c.bg, subject: c.subject, highlight: c.highlight, accents: c.accents.slice() });

  FX.applyEffect = function (s, effectId) {
    const e = FX.byId(FX.EFFECTS, effectId);
    const prev = FX.byId(FX.EFFECTS, s.effect);
    s.effect = e.id;
    if (!s.name || s.name === prev.name) s.name = e.name;
    s.subject = '';
    s.delivery = e.delivery; s.area = e.area; s.view = e.view;
    s.trigger = e.trigger; s.playback = e.playback;
    s.paletteId = e.palette; s.colors = FX.copyColors(FX.byId(FX.PALETTES, e.palette).colors);
    s.layers = e.layers.slice(); s.minTier = {};
    s.phases = Object.assign({}, e.phases); s.stagger = e.stagger;
    s.easing = s.style === 'pixel' ? 'stepped' : 'snappy';
    s.intensity = e.intensity; s.tiers = e.tiers; s.tierNames = ['', '', '', ''];
    return s;
  };

  FX.defaultState = function () {
    const s = {
      v: 2, step: 0, effect: 'castBolt', name: 'magic_bolt', subject: '',
      delivery: 'projectile', area: 'point', view: 'side',
      trigger: 'auto', playback: 'loop', loopGap: 600,
      style: 'pixel', pixelRes: '128x96', pixelFps: 12, dither: true,
      paletteId: 'arcane', colors: null, strictPalette: true,
      layers: [], minTier: {},
      phases: { anticipation: 900, travel: 360, hitstop: 50, burst: 420, afterglow: 700 }, stagger: 40, easing: 'stepped', tierStretch: true,
      intensity: 3, tiers: 3, tierNames: ['', '', '', ''],
      reducedMotion: 'soft', strengthOption: true, haptics: 'impact', sound: 'cues',
      target: 'customPainter', platforms: ['web', 'ios', 'android'],
      perf: { pool: true, atlas: true, noBlur: true, fixedStep: true, seeded: true, autoQuality: false },
      maxParticles: 256, maxDrawCalls: 8,
      output: 'htmlAndFlutter', deliverables: { sheet: true, demo: true, test: true, tuning: false }, lang: 'ko',
    };
    return FX.applyEffect(s, 'castBolt');
  };

  FX.snake = function (raw) {
    const s = String(raw || '').trim().replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
    if (!s) return '';
    return /^[a-z]/.test(s) ? s : 'fx_' + s;
  };
  FX.pascal = (snake) => snake.split('_').filter(Boolean).map((w) => w[0].toUpperCase() + w.slice(1)).join('');

  // 영향 지점 수(퍼즐 판 7x6 기준, 판이 없는 장면도 같은 수로 합성)
  FX.HIT_COUNT = { point: 1, match3: 3, area3: 9, row: 7, cross: 12, cross3: 30, color: 7, scatter: 6, all: 42 };

  const SPARKS = [6, 12, 20, 32, 48];
  const SHARDS = [4, 6, 8, 12, 16];
  const CONFETTI = [10, 18, 28, 40, 60];
  const ORBIT = [8, 12, 18, 26, 36];
  const SMOKE = [2, 3, 4, 6, 8];
  const EMBERS = [4, 8, 12, 18, 26];
  const FLASH_ALPHA = [0.3, 0.45, 0.6, 0.75, 0.85];
  const FLASH_MS = [60, 80, 100, 120, 140];
  const SHAKE_UNIT = [0.02, 0.04, 0.06, 0.09, 0.12];
  const SHAKE_PX = [1, 1, 2, 2, 3];
  const ZOOM = [1.01, 1.02, 1.04, 1.06, 1.08];

  FX.derive = function (s) {
    const e = FX.byId(FX.EFFECTS, s.effect);
    const lang = s.lang === 'en' ? 'en' : 'ko';
    const tiers = FX.clamp(s.tiers | 0, 1, 4);
    const ii = FX.clamp(s.intensity | 0, 1, 5) - 1;
    const delivery = FX.byId(FX.DELIVERIES, s.delivery);
    const area = FX.byId(FX.AREAS, s.area);
    const view = FX.byId(FX.VIEWS, s.view);
    const layers = FX.LAYERS.filter((l) => s.layers.includes(l.id));
    const minTier = {};
    layers.forEach((l) => { minTier[l.id] = FX.clamp((s.minTier && s.minTier[l.id]) || Math.min(l.weight, tiers), 1, tiers); });
    const on = (id, t) => minTier[id] !== undefined && t >= minTier[id];
    const mul = (t) => 1 + 0.6 * (t - 1);
    const hits = FX.HIT_COUNT[area.id] || 1;
    const hitMul = Math.min(3, 1 + Math.log2(hits) * 0.35);
    const tierList = [];
    for (let t = 1; t <= tiers; t++) {
      const c = {
        tier: t,
        sparks: on('sparks', t) ? Math.round(SPARKS[ii] * mul(t) * hitMul) : 0,
        shards: on('shards', t) ? Math.max(hits * (ii >= 2 ? 2 : 1), Math.round(SHARDS[ii] * mul(t))) : 0,
        confetti: on('confetti', t) ? Math.round(CONFETTI[ii] * mul(t)) : 0,
        orbit: on('orbit', t) ? Math.round(ORBIT[ii] * mul(t)) : 0,
        smoke: on('smoke', t) ? Math.min(24, Math.round(SMOKE[ii] * mul(t) * Math.min(3, hits))) : 0,
        comets: on('trail', t) && delivery.id !== 'projectile' && delivery.id !== 'collect' ? 1 + t : 0,
        rings: on('ring', t) ? (ii === 0 ? 1 : Math.min(t, 4)) : 0,
        rays: on('rays', t) ? 6 + 2 * (t - 1) : 0,
        bolts: on('lightning', t) ? 2 + t : 0,
        coins: delivery.id === 'collect' ? [3, 6, 10, 16][t - 1] : 0,
        newLayers: layers.filter((l) => minTier[l.id] === t).map((l) => l.id),
      };
      c.total = c.sparks + c.shards + c.confetti + c.orbit + c.smoke + c.comets * 9 + c.coins + Math.round(EMBERS[ii] * 1.2 * (on('embers', t) ? 1 : 0));
      tierList.push(c);
    }
    const snake = FX.snake(s.name) || e.name;
    const res = String(s.pixelRes || '128x96').split('x').map(Number);
    const tierNames = [];
    for (let t = 0; t < tiers; t++) tierNames.push(((s.tierNames && s.tierNames[t]) || '').trim() || e.tierNames[lang][t]);
    const texts = [];
    for (let t = 0; t < tiers; t++) texts.push(e.texts ? e.texts[lang][t] : tierNames[t]);
    const phases = Object.assign({ anticipation: 0, travel: 0, hitstop: 0, burst: 300, afterglow: 0 }, s.phases);
    if (!delivery.travel) phases.travel = 0;
    return {
      s, e, lang, tiers, ii, layers, minTier, on, tierList, delivery, area, view, hits,
      style: s.style, pixel: s.style === 'pixel', pixelW: res[0] || 128, pixelH: res[1] || 96,
      snake, pascal: FX.pascal(snake), subject: (s.subject || '').trim() || e.subject[lang],
      tierNames, texts, colors: s.colors, phases, stagger: s.stagger | 0,
      stretch: (t) => (s.tierStretch ? 1 + 0.2 * (t - 1) : 1),
      emberRate: EMBERS[ii], flashAlpha: FLASH_ALPHA[ii], flashMs: FLASH_MS[ii], fullFlash: ii >= 3,
      shakeUnit: SHAKE_UNIT[ii], shakePx: SHAKE_PX[ii], zoom: ZOOM[ii],
      maxTotal: Math.max.apply(null, tierList.map((c) => c.total)),
    };
  };
})();
