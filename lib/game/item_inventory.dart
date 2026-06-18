import 'item_kind.dart';

class RunInventory {
  RunInventory([Map<ItemKind, int>? initialCounts])
    : _counts = {
        for (final item in ItemKind.values) item: 0,
        ...?initialCounts,
      };

  factory RunInventory.phase2Initial() =>
      RunInventory({ItemKind.runeHammer: 1, ItemKind.ancientBomb: 1});

  final Map<ItemKind, int> _counts;

  int quantityOf(ItemKind item) => _counts[item] ?? 0;

  bool get hasAnyAvailable =>
      ItemKind.values.any((item) => quantityOf(item) > 0);

  Map<ItemKind, int> snapshot() => Map<ItemKind, int>.unmodifiable(_counts);

  void add(ItemKind item, [int quantity = 1]) {
    if (quantity <= 0) return;
    _counts[item] = quantityOf(item) + quantity;
  }

  bool tryConsume(ItemKind item) {
    final current = quantityOf(item);
    if (current <= 0) return false;
    _counts[item] = current - 1;
    return true;
  }
}

class StageLoadoutSlot {
  const StageLoadoutSlot({
    required this.index,
    required this.item,
    required this.locked,
  });

  final int index;
  final ItemKind? item;
  final bool locked;

  bool get open => !locked;
}

class StageLoadout {
  const StageLoadout._(this.slots);

  factory StageLoadout.phase2Default(
    RunInventory inventory, {
    int openSlotCount = phase2InitialOpenSlotCount,
  }) {
    final normalizedOpenSlotCount = _normalizeOpenSlotCount(openSlotCount);
    final selected = <ItemKind?>[];
    for (final item in phase2Priority) {
      if (inventory.quantityOf(item) <= 0) continue;
      selected.add(item);
      if (selected.length == normalizedOpenSlotCount) break;
    }
    while (selected.length < normalizedOpenSlotCount) {
      selected.add(null);
    }
    return StageLoadout.fromOpenItems(
      selected,
      openSlotCount: normalizedOpenSlotCount,
    );
  }

  factory StageLoadout.fromOpenItems(
    List<ItemKind?> openItems, {
    int openSlotCount = phase2InitialOpenSlotCount,
  }) {
    final normalizedOpenSlotCount = _normalizeOpenSlotCount(openSlotCount);
    final normalized = <ItemKind?>[];
    final seen = <ItemKind>{};
    for (final item in openItems.take(normalizedOpenSlotCount)) {
      if (item != null && seen.add(item)) {
        normalized.add(item);
      } else {
        normalized.add(null);
      }
    }
    while (normalized.length < normalizedOpenSlotCount) {
      normalized.add(null);
    }
    return StageLoadout._([
      for (var i = 0; i < phase2SlotCount; i++)
        StageLoadoutSlot(
          index: i,
          item: i < normalizedOpenSlotCount ? normalized[i] : null,
          locked: i >= normalizedOpenSlotCount,
        ),
    ]);
  }

  static const int phase2SlotCount = 4;
  static const int phase2InitialOpenSlotCount = 2;
  static const int phase2Slot3UnlockClearLevel = 6;
  static const int phase2Slot4UnlockClearLevel = 12;

  static const List<ItemKind> phase2Priority = [
    ItemKind.runeHammer,
    ItemKind.ancientBomb,
    ItemKind.thorHammer,
    ItemKind.hyperCube,
    ItemKind.prismTransform,
    ItemKind.timeSlip,
    ItemKind.fateShuffle,
    ItemKind.hintPlus,
  ];

  final List<StageLoadoutSlot> slots;

  int get openSlotCount => slots.where((slot) => slot.open).length;

  List<ItemKind> get openItems => [
    for (final slot in slots)
      if (slot.open && slot.item != null) slot.item!,
  ];

  bool contains(ItemKind item) => openItems.contains(item);

  StageLoadout withOpenSlotCount(int openSlotCount) {
    return StageLoadout.fromOpenItems([
      for (final slot in slots)
        if (slot.open) slot.item,
    ], openSlotCount: openSlotCount);
  }

  StageLoadout assignOpenSlot({
    required int slotIndex,
    required ItemKind item,
    required RunInventory inventory,
    required bool Function(ItemKind item) isAllowed,
  }) {
    final currentOpenSlotCount = openSlotCount;
    if (slotIndex < 0 || slotIndex >= currentOpenSlotCount) return this;
    if (inventory.quantityOf(item) <= 0 || !isAllowed(item)) return this;
    final updated = [
      for (var i = 0; i < currentOpenSlotCount; i++)
        i == slotIndex ? item : slots[i].item,
    ];
    for (var i = 0; i < updated.length; i++) {
      if (i != slotIndex && updated[i] == item) {
        updated[i] = null;
      }
    }
    return StageLoadout.fromOpenItems(
      updated,
      openSlotCount: currentOpenSlotCount,
    );
  }

  static int _normalizeOpenSlotCount(int openSlotCount) =>
      openSlotCount.clamp(phase2InitialOpenSlotCount, phase2SlotCount);
}
