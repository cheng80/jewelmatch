# Supertonic TTS 임시 SFX 생성 가이드

Supertonic은 효과음/징글 생성기가 아니라 TTS다. 그래서 최종 게임 SFX를 만들기보다는 `Start!`, `Clear!`, `Level up!` 같은 짧은 음성 콜아웃을 임시 자산으로 만들 때 사용한다. 나중에 전용 SFX를 받으면 같은 파일명으로 덮어쓰거나 코드 상수만 새 파일명으로 바꾼다.

## 준비

```bash
python3 -m venv /tmp/supertonic-sfx
/tmp/supertonic-sfx/bin/python -m pip install --upgrade pip
/tmp/supertonic-sfx/bin/python -m pip install supertonic
```

첫 실행 때 Hugging Face에서 `Supertone/supertonic-3` 모델을 내려받는다. 네트워크가 필요하고, 비로그인 상태에서는 속도 제한이 걸릴 수 있다.

## 생성 스크립트

아래 스크립트는 Flutter/Flame에서 바로 쓸 수 있는 44.1kHz, 16bit, mono WAV를 만든다. `LevelUp.wav`는 첫 어택이 잘리지 않도록 앞에 120ms 무음을 붙인다.

```bash
/tmp/supertonic-sfx/bin/python - <<'PY'
from pathlib import Path
import wave
import numpy as np
from supertonic import TTS

out_dir = Path("assets/audio/sfx")
out_dir.mkdir(parents=True, exist_ok=True)

tts = TTS(model="supertonic-3")

items = {
    "Start.wav": ("Start!", "F3", 1.18, 0.08, 0),
    "Clear.wav": ("Clear!", "F3", 1.18, 0.08, 0),
    "LevelUp.wav": ("Next level!", "F5", 1.06, 0.24, 120),
}

def save_padded(path, audio, sample_rate, lead_ms):
    flat = audio.squeeze().astype(np.float32)
    lead = np.zeros(int(sample_rate * lead_ms / 1000), dtype=np.float32)
    padded = np.concatenate([lead, flat])
    pcm16 = (np.clip(padded, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm16.tobytes())

for filename, (text, voice, speed, silence, lead_ms) in items.items():
    style = tts.get_voice_style(voice)
    wav, duration = tts.synthesize(
        text,
        voice_style=style,
        total_steps=8,
        speed=speed,
        silence_duration=silence,
        lang="en",
    )
    path = out_dir / filename
    if lead_ms:
        save_padded(path, wav, tts.sample_rate, lead_ms)
    else:
        tts.save_audio(wav, str(path))
    print(f"{path} {duration[0] + lead_ms / 1000:.3f}s")
PY
```

## Flutter/Flame 연결

`AssetPaths`에 경로를 둔다.

```dart
static const String sfxStart = 'sfx/Start.wav';
static const String sfxClear = 'sfx/Clear.wav';
static const String sfxLevelUp = 'sfx/LevelUp.wav';
```

`SoundManager.preload()`에 추가한다.

```dart
FlameAudio.audioCache.load(AssetPaths.sfxStart),
FlameAudio.audioCache.load(AssetPaths.sfxClear),
FlameAudio.audioCache.load(AssetPaths.sfxLevelUp),
```

웹에서는 `FlameAudio.createPool`에도 등록한다.

```dart
SoundManager._webSfxPools[AssetPaths.sfxLevelUp] =
    await FlameAudio.createPool(
      AssetPaths.sfxLevelUp,
      minPlayers: 1,
      maxPlayers: 1,
    );
```

사용 지점에서는 전용 상수를 재생한다.

```dart
SoundManager.playSfx(AssetPaths.sfxLevelUp);
```

## 확인

```bash
file assets/audio/sfx/Start.wav assets/audio/sfx/Clear.wav assets/audio/sfx/LevelUp.wav
flutter analyze
flutter test
flutter build web --release
```

웹에서 확인할 때는 네트워크 요청에 `assets/assets/audio/sfx/LevelUp.wav`가 200으로 뜨는지 본다.

## 교체 전략

- 임시 TTS를 유지: 현재 파일 그대로 사용한다.
- 전문 SFX로 교체: 같은 파일명(`Start.wav`, `Clear.wav`, `LevelUp.wav`)으로 덮어쓴다.
- 파일명을 바꾸는 경우: `AssetPaths` 상수만 새 경로로 변경한다.

Supertonic은 음성 콜아웃용으로만 사용하고, 보석 폭발/버튼/징글 같은 비언어 효과음은 별도 SFX 소스에서 보충한다.
