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

현재 프로젝트는 웹 오디오 대응을 **최소 unlock 정책**으로 유지한다.

- 앱 루트 `Listener`의 **첫 `onPointerDown`** 에서 `SoundManager.unlockForWeb()` 호출
- `unlockForWeb()`는 `_webUnlocked = true`로 전환하고, 잠금 전 요청된 BGM이 있으면 재생
- 웹에서도 SFX/BGM 재생 API는 네이티브와 동일하게 `FlameAudio.play(...)`, `FlameAudio.bgm.play(...)` 경로 사용
- 웹 잠금 전에는 `playSfx()` / `playBgmIfUnmuted()`가 return 하여 자동 재생만 막음

즉, 이 저장소는 더 이상 웹 전용 SFX 풀, `mediaPlayer` 분기, 0볼륨 prime, 드래그 시작 추가 unlock을 기본 정책으로 쓰지 않는다.

### 3.1 현재 코드에서 확인할 파일

- `lib/resources/sound_manager.dart`
  - `_webUnlocked`, `_pendingBgm`
  - `unlockForWeb()`
  - `playBgm()` / `playBgmIfUnmuted()` / `playSfx()`
- `lib/app.dart`
  - 웹일 때 전역 `Listener`
  - `onPointerDown: (_) => SoundManager.unlockForWeb()`

### 3.2 장단점

- 장점:
  - 구조가 단순하다.
  - 모바일/네이티브와 동작 모델이 가깝다.
  - 웹 전용 예외 처리가 적어 유지보수가 쉽다.
- 단점:
  - 드래그/스와이프 경로의 제스처 타이밍 문제를 별도 보정하지 않는다.
  - 브라우저/MP3 인코딩 조합에 따라 일부 웹 효과음이 불안정할 수 있다.
  - 동시 재생이 많은 경우 단일 기본 경로의 한계가 드러날 수 있다.

### 3.3 에셋(MP3) 정규화 (선택)

웹 호환을 위해 `ffmpeg` 로 **44.1 kHz 스테레오·`libmp3lame`** 등으로 통일할 수 있다.  
스크립트: `tools/reencode_mp3_web.py` (폴더 단위 일괄 재인코딩).

---

## 4. 문제가 다시 생기면 고려할 고급 대응

현재 저장소에서는 제거했지만, 아래 대응은 다른 프로젝트 또는 회귀 발생 시 다시 검토할 수 있다.

1. 웹 SFX만 `PlayerMode.mediaPlayer` 로 분기
2. 웹 전용 `AudioPlayer` 풀 + 라운드로빈 재생
3. 첫 제스처 시 0볼륨 SFX prime
4. 드래그/스와이프 시작 지점의 추가 `unlockForWeb()`

이런 대응은 묵음, 드래그 시 미재생, 동시 재생 끊김이 실제로 재현될 때만 넣는 편이 낫다.

---

## 5. 관련 파일 (이 저장소)

| 파일 | 역할 |
|------|------|
| `lib/resources/sound_manager.dart` | 최소 unlock 정책·`playSfx`·pending BGM |
| `lib/app.dart` | 웹 `Listener` → `unlockForWeb` |
| `tools/reencode_mp3_web.py` | MP3 일괄 재인코딩 (선택) |

---

## 6. 버전·의존성 메모

- `flame_audio` → 내부적으로 `audioplayers` 사용. 패키지 메이저 버전이 올라가면 웹 구현 세부가 달라질 수 있다.
- 문제가 **패키지 업데이트 직후**에만 생기면, 해당 버전의 `audioplayers` / `audioplayers_web` 이슈도 함께 본다.

---

*최종 정리: 현재 저장소는 웹에서 “**첫 포인터다운 unlock + pending BGM 보류**”만 유지하는 최소 정책을 사용한다. 추가 대응은 실제 브라우저 이슈가 재현될 때만 다시 도입한다.*
