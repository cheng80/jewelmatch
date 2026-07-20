import 'dart:async';

class NativeSfxSlot {
  const NativeSfxSlot._(this.index, this.generation);

  final int index;
  final int generation;
}

class NativeSfxSlotPool {
  NativeSfxSlotPool(int size)
    : assert(size > 0),
      _slots = List<_SlotState>.generate(size, (_) => _SlotState());

  final List<_SlotState> _slots;

  NativeSfxSlot? reserve() {
    for (var index = 0; index < _slots.length; index++) {
      final state = _slots[index];
      if (state.busy) continue;
      state.busy = true;
      state.generation++;
      return NativeSfxSlot._(index, state.generation);
    }
    return null;
  }

  Future<void> start(
    NativeSfxSlot slot, {
    required Duration duration,
    required Future<void> Function() onStart,
    required Future<void> Function() onStop,
  }) async {
    try {
      await onStart();
      if (!_isCurrent(slot)) return;

      Timer? releaseTimer;
      releaseTimer = Timer(duration, () {
        unawaited(_stop(slot, releaseTimer!, onStop));
      });
      _state(slot)!.timer = releaseTimer;
    } catch (_) {
      release(slot);
    }
  }

  void release(NativeSfxSlot slot) {
    final state = _state(slot);
    if (state == null) return;
    state.timer?.cancel();
    state.timer = null;
    state.busy = false;
  }

  Future<void> _stop(
    NativeSfxSlot slot,
    Timer releaseTimer,
    Future<void> Function() onStop,
  ) async {
    final state = _state(slot);
    if (state == null || !identical(state.timer, releaseTimer)) return;
    try {
      await onStop();
    } catch (_) {
      // A failed stop must not permanently reserve the slot.
    } finally {
      final current = _state(slot);
      if (current != null && identical(current.timer, releaseTimer)) {
        current.timer = null;
        current.busy = false;
      }
    }
  }

  _SlotState? _state(NativeSfxSlot slot) {
    if (slot.index < 0 || slot.index >= _slots.length) return null;
    final state = _slots[slot.index];
    if (!state.busy || state.generation != slot.generation) return null;
    return state;
  }

  bool _isCurrent(NativeSfxSlot slot) => _state(slot) != null;
}

class _SlotState {
  bool busy = false;
  int generation = 0;
  Timer? timer;
}
