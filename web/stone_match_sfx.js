(() => {
  // 재생 중인 미디어 요소를 기억한다. 웹 hot restart는 Dart만 다시 시작하고 페이지는 남아
  // 이전 실행의 BGM <audio>가 계속 울린다. 앱 시작 때 stopOrphans()로 멈춘다.
  const playing = new Set();
  const originalPlay = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function (...args) {
    playing.add(this);
    const forget = () => playing.delete(this);
    this.addEventListener('pause', forget, { once: true });
    this.addEventListener('ended', forget, { once: true });
    return originalPlay.apply(this, args);
  };
  const stopOrphans = () => {
    let stopped = 0;
    for (const media of Array.from(playing)) {
      try {
        media.pause();
        media.currentTime = 0;
        stopped += 1;
      } catch (_) {}
    }
    playing.clear();
    return stopped;
  };

  const slotCount = 4;
  const slots = Array.from({ length: slotCount }, () => ({
    audio: new Audio(),
    busy: false,
    timer: 0,
    token: 0,
  }));
  const stats = { plays: 0, drops: 0, errors: 0, unlocks: 0, lastError: '' };
  let needsUnlock = true;

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) return;
    needsUnlock = true;
    for (const slot of slots) {
      slot.token += 1;
      clearTimeout(slot.timer);
      slot.timer = 0;
      slot.busy = false;
      slot.audio.pause();
      slot.audio.currentTime = 0;
      slot.audio.onended = null;
      slot.audio.onerror = null;
    }
  });

  const resolveAsset = (path) =>
    new URL(`assets/assets/audio/${path}`, document.baseURI).href;

  const recordError = (error) => {
    stats.errors += 1;
    stats.lastError = String(error?.message || error || 'unknown audio error');
  };

  const release = (slot, token, error) => {
    if (slot.token !== token) return;
    if (error) recordError(error);
    clearTimeout(slot.timer);
    slot.timer = 0;
    slot.busy = false;
    slot.audio.onended = null;
    slot.audio.onerror = null;
  };

  const initialize = (defaultPath) => {
    const url = resolveAsset(defaultPath);
    for (const slot of slots) {
      slot.audio.preload = 'auto';
      slot.audio.src = url;
      slot.audio.load();
    }
  };

  const unlock = () => {
    if (!needsUnlock) return;
    needsUnlock = false;
    stats.unlocks += 1;
    for (const slot of slots) {
      if (slot.busy) continue;
      const token = ++slot.token;
      const audio = slot.audio;
      const previousVolume = audio.volume;
      audio.volume = 0;
      audio.currentTime = 0;
      const promise = audio.play();
      promise?.then(() => {
        if (slot.token !== token || slot.busy) return;
        audio.pause();
        audio.currentTime = 0;
        audio.volume = previousVolume;
      }).catch((error) => {
        // 첫 효과음이나 화면 숨김이 unlock 재생을 대체하면 정상 취소다.
        if (slot.token === token && !slot.busy) recordError(error);
      });
    }
  };

  // 반음 상승은 playbackRate로 낸다. preservesPitch 기본값(true)이면 속도만 바뀌고
  // 피치가 유지되므로 재생마다 false로 다시 쓴다(ADR-004의 HTML Audio 4슬롯 그대로).
  // 비접두사 속성은 Safari 17+에만 있다. iOS 15/16은 webkit 접두사를 쓴다.
  // 셋 다 없으면 피치는 그대로인데 속도만 빨라지므로 rate를 1로 둔다.
  const pitchKeys = ['preservesPitch', 'webkitPreservesPitch', 'mozPreservesPitch'];
  const applyRate = (audio, rate) => {
    let supported = false;
    for (const key of pitchKeys) {
      if (key in audio) {
        audio[key] = false;
        supported = true;
      }
    }
    const safe = supported && Number.isFinite(rate) && rate > 0
      ? Math.min(2, Math.max(0.5, rate))
      : 1;
    audio.playbackRate = safe;
    return safe;
  };

  const play = (path, volume, durationMs, rate) => {
    const slot = slots.find((candidate) => !candidate.busy);
    if (!slot) {
      stats.drops += 1;
      return false;
    }

    slot.busy = true;
    const token = ++slot.token;
    const audio = slot.audio;
    const url = resolveAsset(path);
    clearTimeout(slot.timer);
    audio.pause();
    if (audio.src !== url) {
      audio.src = url;
      audio.load();
    }
    audio.volume = Math.max(0, Math.min(1, volume));
    const appliedRate = applyRate(audio, rate);
    audio.currentTime = 0;
    audio.onended = () => release(slot, token);
    audio.onerror = () => release(slot, token, audio.error);
    slot.timer = setTimeout(() => {
      if (slot.token !== token) return;
      audio.pause();
      audio.currentTime = 0;
      release(slot, token);
    }, Math.max(250, durationMs / appliedRate + 250));

    stats.plays += 1;
    audio.play()?.catch((error) => release(slot, token, error));
    return true;
  };

  const getState = () => ({
    ...stats,
    active: slots.filter((slot) => slot.busy).length,
    playingMedia: playing.size,
  });

  // 브라우저 HTTP 캐시만 채운다. 본문은 JS에서 읽고 버려 Dart 메모리로 복사하지 않는다.
  // 순서대로 하나씩 받아 첫 화면과 네트워크를 다투지 않게 한다.
  const warm = (paths) => {
    const list = Array.from(paths || []);
    const next = () => {
      const path = list.shift();
      if (!path) return;
      fetch(resolveAsset(path))
        .then((response) => (response.ok ? response.arrayBuffer() : null))
        .catch(recordError)
        .finally(next);
    };
    next();
  };

  window.stoneMatchSfx = Object.freeze({ initialize, unlock, play, warm, stopOrphans, getState });
})();
