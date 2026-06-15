# Flutter Web + Flame(`flame_audio`) 오디오 정책 메모

다른 프로젝트에서 **웹(특히 데스크톱 크롬)** 과 **모바일(Safari 등)** 에서 오디오 동작이 다르거나, 효과음만 이상할 때 참고하는 전용 문서다.  
이 저장소의 구현 기준은 `lib/resources/sound_manager.dart` 및 아래에 인용한 파일들이다.

---

## 1. 자주 나오는 증상

| 증상 | 가능한 원인 (요약) |
|------|-------------------|
| 같은 MP3인데 **일부 파일만** 웹에서 묵음 | Web Audio 경로·브라우저 디코더와 MP3 인코딩 조합 |
| **탭**으로는 효과음이 나오는데 **스와이프/드래그**로는 안 남 | user activation이 끊긴 뒤 `play()` 호출, 또는 제스처 경로 차이 |
| **모바일은 되는데 PC 크롬만** 이상 | 크롬이 오디오·제스처 정책을 더 엄격하게 적용하는 경우 |
| 효과음을 **연속 재생**하면 앞선 음이 끊김 | **단일 `AudioPlayer`** 에서 새 `play()`가 이전 재생을 덮어씀 |
| `playSfx`에 `try/catch`가 있는데도 묵음 | 재생 실패가 **비동기 Future** 쪽에서 나와 동기 `catch`로 안 잡힘 |

---

## 2. 배경 (짧게)

- **`flame_audio`의 `FlameAudio.play`** 는 기본이 `PlayerMode.lowLatency`(웹에선 Web Audio API에 가깝다). 브라우저·파일에 따라 특정 MP3만 실패할 수 있다.
- 브라우저는 **사용자 제스처(탭 등)와 같은 “활성화” 구간** 안에서 오디오 재생을 허용하는 경우가 많다. `await` 가 여러 번 끼면 그 구간 밖으로 밀려 **묵음**이 될 수 있다.
- **`AudioPlayer` 하나**는 동시에 하나의 소스만 재생한다. 연쇄 매치처럼 효과음이 겹치면 **풀(여러 개)** 이 필요하다.

---

## 3. 현재 프로젝트 정책

현재 프로젝트는 웹 오디오 대응에서 **SFX 풀링 + pointerdown re-prime** 을 현재 기준 실험 상태로 사용한다.

- 앱 루트 `Listener`의 `onPointerDown` 에서 `SoundManager.unlockForWeb()` 호출
- `unlockForWeb()`는 `_webUnlocked = true`로 전환하고, 잠금 전 요청된 BGM이 있으면 재생한다
- 웹에서는 `unlockForWeb()`가 `_primeWebSfxPools()`도 함께 호출해 SFX용 `AudioPool`들을 0볼륨 start/stop으로 재-prime한다
- `preload()` 시점에 웹 전용 `AudioPool`을 미리 생성해 `BtnSnd`, `Collect`, `Fail`, `ComboHit`, `BigMatch`, `SpecialGem`, `TimeTic`, `TimeUp`, `Start`를 재사용 플레이어로 돌린다
  - 현재 풀 크기 기준: `Collect=3`, `ComboHit=3`, `BtnSnd=2`, 나머지 주요 SFX는 `1`
- 웹에서 `playSfx()`는 가능하면 `webPool.start(volume: vol)` 경로를 사용하고, 풀에 없는 경우만 `FlameAudio.play(...)`로 폴백한다
- 콤보음(`ComboHit`)은 현재도 웹에서 별도 즉시 재생 분기 없이 기존 지연 재생(`playComboSfxDelayed`)을 유지한다

즉, 현재 저장소의 기준점은 “최소 unlock 정책”이 아니라 “**첫 pointerdown unlock + 웹 SFX 풀 초기화/재-prime**”이다.
다만 이 상태도 완전 안정은 아니며, 장시간 플레이 뒤 `Collect` 복구 실패나 `ComboHit` 누락이 간헐적으로 남을 수 있다.

### 3.1 현재 코드에서 확인할 파일

- `lib/resources/sound_manager.dart`
  - `_webUnlocked`, `_pendingBgm`
  - `_webSfxPools`, `_primeWebSfxPools()`
  - `unlockForWeb()`
  - `playBgm()` / `playBgmIfUnmuted()` / `playSfx()`
- `lib/app.dart`
  - 웹일 때 전역 `Listener`
  - `onPointerDown: (_) => SoundManager.unlockForWeb()`

### 3.2 장단점

- 장점:
  - 드래그 이후에도 탭 없이 사운드가 계속 살아 있을 가능성이 높다.
  - 자주 쓰는 SFX를 새 플레이어 생성 없이 재사용하므로 모바일 웹에서 안정성이 좋아진다.
  - 현재 프로젝트에서는 지금까지 시도한 조합 중 가장 안정적으로 재생되는 기준점이다.
- 단점:
  - 최소 unlock 정책보다 구조가 복잡하다.
  - 웹 전용 풀 구성과 re-prime 로직을 계속 문서와 함께 관리해야 한다.
  - 브라우저별로 안정성이 달라질 수 있어 회귀 테스트가 필요하다.
  - 완전한 해결 상태는 아니며, 드물게 장시간 플레이 후 일부 SFX가 다시 잠길 수 있다.

### 3.3 에셋(MP3) 정규화 (선택)

웹 호환을 위해 `ffmpeg` 로 **44.1 kHz 스테레오·`libmp3lame`** 등으로 통일할 수 있다.  
스크립트: `tools/reencode_mp3_web.py` (폴더 단위 일괄 재인코딩).

---

## 4. 문제가 다시 생기면 고려할 고급 대응

현재 저장소에서는 아래 대응 중 일부가 실제 코드에 들어가 있다. 추가 회귀가 생기면 다음 항목을 다시 검토한다.

1. 웹 SFX 풀 구성을 더 줄이거나 늘리기
2. 웹 SFX만 `PlayerMode.mediaPlayer` 로 분기
3. `unlockForWeb()` 호출 시점을 `pointerdown` 외 보조 제스처까지 넓힐지 검토
4. `ComboHit` 같은 지연 재생 SFX를 웹에서만 별도 처리할지 검토

이런 대응은 묵음, 드래그 시 미재생, 동시 재생 끊김이 실제로 재현될 때만 넣는 편이 낫다.

---

## 5. 관련 파일 (이 저장소)

| 파일 | 역할 |
|------|------|
| `lib/resources/sound_manager.dart` | 웹 SFX 풀링/prime·`playSfx`·pending BGM |
| `lib/app.dart` | 웹 `Listener` → `unlockForWeb` |
| `tools/reencode_mp3_web.py` | MP3 일괄 재인코딩 (선택) |

---

## 6. 버전·의존성 메모

- `flame_audio` → 내부적으로 `audioplayers` 사용. 패키지 메이저 버전이 올라가면 웹 구현 세부가 달라질 수 있다.
- 문제가 **패키지 업데이트 직후**에만 생기면, 해당 버전의 `audioplayers` / `audioplayers_web` 이슈도 함께 본다.

---

*최종 정리: 현재 저장소의 웹 오디오 기준점은 “**첫 포인터다운 unlock + 웹 SFX AudioPool 초기화/재-prime**”이다. 모바일 웹에서 지금까지 시도한 조합 중 가장 안정적이지만, 완전 안정 상태는 아닌 기준 실험 버전으로 기록한다.*
