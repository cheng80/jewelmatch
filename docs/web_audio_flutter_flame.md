# Flutter Web + Flame(`flame_audio`) 효과음 트러블슈팅

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

## 3. 이 프로젝트에서 쓰는 대응 요약

### 3.1 웹 효과음: `PlayerMode.mediaPlayer`

웹(`kIsWeb`)에서는 효과음만 `mediaPlayer` 모드(HTML5 `<audio>`에 가까운 경로)로 통일한다.  
BGM은 기존처럼 `FlameAudio.bgm` 을 쓴다.

구현: `SoundManager._playSfxWeb` → 풀에 담긴 `AudioPlayer`에 `play(AssetSource(...))`.

### 3.2 웹 효과음 풀 + 라운드로빈

- 상수: `_webSfxPoolSize` (기본 **6**).
- 미리 `setReleaseMode` / `setPlayerMode(mediaPlayer)` / `setAudioContext(mixWithOthers)` 로 구성해 두고, 재생마다 **다음 플레이어**에 할당한다.
- 같은 프레임에 **풀 크기보다 많은** 효과음이 겹치면 여전히 끊길 수 있으니, 필요 시 숫자만 올린다.

### 3.3 `unlockForWeb()` 패턴

- **금지:** `if (!kIsWeb || _webUnlocked) return;` 처럼 **한 번만** 호출되게 해서, 이후 포인터에서는 **풀 준비가 전혀 안 도는** 형태.
- **권장:** 웹이면 매번 `unawaited(_ensureWebSfxPool());` 를 태워, 첫 잠금 해제 후에도 풀 생성이 이어지게 한다 (실제 생성은 한 번만).

첫 사용자 입력 전 BGM·자동 재생은 기존처럼 `_webUnlocked` 로 막고, 효과음은 `playSfx` 안에서 `!_webUnlocked` 이면 return 유지.

### 3.4 앱 루트에서 포인터다운으로 잠금 해제

`lib/app.dart` (웹일 때):

- `Listener` + `onPointerDown: (_) => SoundManager.unlockForWeb()`  
- `behavior: HitTestBehavior.translucent` 로 자식이 포인터를 소비해도 상위에서 받을 수 있게 한다.

### 3.5 Flame `DragCallbacks` 로만 효과음이 나가는 경우

스와이프는 `onTapDown` 이 아니라 **`onDragUpdate`** 에서만 `playSfx` 가 나갈 수 있다.  
그때는 **`onDragStart` 맨 앞**에서 `SoundManager.unlockForWeb()` 을 한 번 더 호출해 제스처 시작과 잠금 해제·풀 준비를 맞춘다.

이 저장소: `lib/game/components/match_game_hud.dart` 의 `onDragStart`.

### 3.6 에셋(MP3) 정규화 (선택)

웹 호환을 위해 `ffmpeg` 로 **44.1 kHz 스테레오·`libmp3lame`** 등으로 통일할 수 있다.  
스크립트: `tools/reencode_mp3_web.py` (폴더 단위 일괄 재인코딩).

---

## 4. 다른 프로젝트로 옮길 때 체크리스트

1. **`sound_manager.dart`**
   - 웹: `mediaPlayer` + **풀** + `unlockForWeb` 에서 `ensure` 호출 구조.
2. **`app.dart` (또는 루트)**
   - 웹: 전역 `Listener` + `unlockForWeb` (위 3.4).
3. **드래그/스와이프 전용 입력**
   - 해당 컴포넌트 `onDragStart`(또는 동등 지점)에 `unlockForWeb` (위 3.5).
4. **버튼·라우트**
   - 이미 `unlockForWeb` + `playSfx` 를 쓰는 곳은 유지해도 된다 (중복 호출은 부담 적음).

대부분의 정책은 **`sound_manager.dart` 한 파일**에 넣을 수 있고, **제스처 경로가 Flame 드래그와만 묶인 경우**에만 HUD 등 **한두 파일**을 더 본다.

---

## 5. 관련 파일 (이 저장소)

| 파일 | 역할 |
|------|------|
| `lib/resources/sound_manager.dart` | 웹 풀·`playSfx`·`unlockForWeb` |
| `lib/app.dart` | 웹 `Listener` → `unlockForWeb` |
| `lib/game/components/match_game_hud.dart` | `onDragStart` → `unlockForWeb` |
| `tools/reencode_mp3_web.py` | MP3 일괄 재인코딩 (선택) |

---

## 6. 버전·의존성 메모

- `flame_audio` → 내부적으로 `audioplayers` 사용. 패키지 메이저 버전이 올라가면 웹 구현 세부가 달라질 수 있다.
- 문제가 **패키지 업데이트 직후**에만 생기면, 해당 버전의 `audioplayers` / `audioplayers_web` 이슈도 함께 본다.

---

*최종 정리: 웹은 “**잠금 해제 시점** + **재생 경로(mediaPlayer)** + **동시 재생(풀)**” 세 가지를 같이 맞추는 것이 안전하다.*
