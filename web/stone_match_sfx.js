(() => {
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
  const applyRate = (audio, rate) => {
    const safe = Number.isFinite(rate) && rate > 0 ? Math.min(2, Math.max(0.5, rate)) : 1;
    audio.preservesPitch = false;
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
  });

  window.stoneMatchSfx = Object.freeze({ initialize, unlock, play, getState });
})();
