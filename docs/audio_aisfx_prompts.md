# AISFX 효과음 · Soundverse BGM 생성 가이드 (Jewel Match)

이 문서는 `assets/audio/sfx/` **효과음**에 대응하는 목록과, [AISFX](https://aisfx.org/)용 **영문 프롬프트**, 그리고 `assets/audio/music/` **BGM**은 [Soundverse.ai](https://www.soundverse.ai)용 **영문 프롬프트**를 정리한 것이다.  
게임 톤: **캐주얼 매치-3**, 밝은 캔디/주얼 느낌. SFX는 과하지 않은 길이(0.3~1.5초 전후 권장).

---

## 1. 효과음 파일·코드 매핑 (전체)

| 파일명 | `AssetPaths` | 게임 내 용도 (현재 코드) |
|--------|--------------|---------------------------|
| `BtnSnd.mp3` | `sfxBtnSnd` | 타이틀·게임 오버레이 등 **UI 버튼** 탭 |
| `Start.mp3` | `sfxStart` | 인트로 보드 채움 완료 후 **라운드 시작** (`roundStart`) |
| `Collect.mp3` | `sfxCollect` | 유효한 스왑으로 **매치 연출 시작**할 때 |
| `TimeUp.mp3` | `sfxTimeUp` | **타임 오버** (`TimeUp` 오버레이) — 클리어/승리 팡파르 아님 |
| `TimeTic.mp3` | `sfxTimeTic` | **타임 모드**에서 남은 시간이 **10초 이하**일 때, 정수 초가 줄어들 때마다 1회 |
| `Fail.mp3` | `sfxFail` | **무효 스왑**(매치 없이 되돌아갈 때) |

※ 저시간 틱 상한(초)은 `MatchBoardGame.timedLowTimeTickMaxSeconds`(기본 10)로 조절.

---

## 2. 파일별 AISFX 프롬프트 (영문)

AISFX는 짧고 구체적인 영문 설명이 잘 맞는 경우가 많다. 아래는 **무음 구간 없이** 내보내기 쉽게 짧게 잡았다.

### `BtnSnd.mp3` — UI 버튼

- **프롬프트:**  
  `Short soft UI click for mobile puzzle game, light plastic or glass tap, bright and friendly, no harsh attack, 0.2 seconds, mono or subtle stereo, no music`
- **보조 키워드 (옵션):** casual game, jewel theme, positive

---

### `Start.mp3` — 라운드 시작

- **프롬프트:**  
  `Cheerful magical sparkle “go” stinger for match-3 puzzle game start, rising chime with soft bell and glitter shimmer, cute and energetic, about 0.8 seconds, no voice, no drums`
- **톤:** 스타트 알림 느낌, 과한 팡파르는 피함.

---

### `Collect.mp3` — 매치(유효 스왑)

- **프롬프트:**  
  `Satisfying gem pop and soft crystalline chime when gems match in a casual puzzle game, bright glassy tone, quick decay, roughly 0.4 to 0.7 seconds, playful, no explosion, no harsh noise`
- **톤:** “보석이 맞았다”는 보상감.

---

### `TimeUp.mp3` — 타임 오버 (시간 종료)

- **의도:** 스테이지 클리어·성공 스팅이 **아니다**. “시간이 다 됐다”는 **라운드 종료** 알림.
- **프롬프트:**  
  `Time ran out sting for casual puzzle game, soft neutral tone-out or gentle downward bloop, slightly disappointing but not celebratory, no victory fanfare, no sparkle explosion, about 0.8 to 1.2 seconds, no alarm siren, no voice`
- **피할 것:** triumphant brass, level-clear chime, bright success sparkle — **클리어 SFX와 혼동되면 안 됨**.

---

### `TimeTic.mp3` — 저시간 카운트다운 틱

- **재생:** 남은 시간이 `timedLowTimeTickMaxSeconds`(기본 10) 이하일 때, **매 정수 초**가 줄어들 때마다 1회(10→9→…→1).
- **프롬프트:**  
  `Very short soft digital tick or light clock tick for countdown timer in puzzle game, subtle and non-annoying, 0.1 to 0.15 seconds, low volume character, no echo`
- **톤:** 짧고 반복 들어도 부담 없게.

---

### `Fail.mp3` — 무효 스왑

- **재생:** 스왑 후 매치가 없어 **보드가 원위치**일 때.
- **프롬프트:**  
  `Soft negative feedback blip for invalid move in puzzle game, gentle rubber bounce or dull glass clink, slightly lower pitch, about 0.25 seconds, not harsh, not buzzer`
- **톤:** 벌점 느낌 최소화, **가벼운 거절** 정도.

---

## 3. 생성 후 체크리스트

1. **포맷:** 프로젝트는 현재 **MP3** 경로(`*.mp3`)로 연결되어 있다. AISFX가 WAV만 주면 변환하거나 `asset_paths`·프리로드를 WAV로 통일한다.  
2. **길이:** 너무 긴 파일은 페이드 아웃·트림 권장.  
3. **볼륨:** 게임 내 `GameSettings.sfxVolume`과 함께 들어보고, 클립 피크가 심하면 노멀라이즈.  
4. **라이선스:** AISFX 플랜에 따른 상업 이용·크레딧 조건을 [공식 사이트](https://aisfx.org/)에서 확인한다.

---

## 4. BGM — [Soundverse.ai](https://www.soundverse.ai)용 프롬프트

메뉴·인게임 루프는 `assets/audio/music/`의 **WAV**로 연결된다 (`AssetPaths.bgmMenu`, `bgmMain`).  
생성·내보내기는 [Soundverse.ai](https://www.soundverse.ai) 등에 아래 **영문 프롬프트**를 넣어 쓰면 된다.

**공통 믹스 팁:** 효과음(AISFX)과 겹칠 때를 대비해 BGM은 **과한 베이스·킥**을 피하고, **중·고역 위주의 밝은 패드·벨** 쪽이 SFX와 섞기 쉽다. 루프 트랙이면 **시작·끝이 자연스럽게 이어지게** 편집하거나, Soundverse에서 “seamless loop”를 요청한다.

---

### `Menu_BGM.wav` — 타이틀·메뉴

- **역할:** 타이틀·설정 등 **비플레이** 화면. 차분하고 환영하는 느낌, 플레이 압박 없음.
- **Soundverse 프롬프트 (영문):**  
  `Relaxing loopable background music for casual jewel match-3 puzzle game main menu, soft sparkly synth pads and gentle bell-like tones, warm and inviting, light and airy, no heavy bass, no drums, medium slow tempo around 90 BPM, seamless loop, no vocals, family friendly`

---

### `Main_BGM.wav` — 인게임(보드)

- **역할:** 매치 플레이 중 **집중을 방해하지 않는** 업비트 루프. 메뉴보다 살짝 더 리듬감 있어도 됨.
- **Soundverse 프롬프트 (영문):**  
  `Upbeat loopable instrumental background for mobile match-3 gem puzzle gameplay, playful plucks and soft chimes, subtle light percussion if any, energetic but not chaotic, bright candy-jewel mood, avoid loud kicks and sub bass, around 100 to 115 BPM, seamless loop, no vocals, no sudden drops, casual game OST`

---

### 내보내기 후

1. 파일명을 `Menu_BGM.wav`, `Main_BGM.wav`로 맞추거나 `asset_paths.dart`와 동일한 경로로 둔다.  
2. **라이선스:** Soundverse 플랜에 따른 상업 이용·크레딧은 [공식 사이트](https://www.soundverse.ai) 기준으로 확인한다.
