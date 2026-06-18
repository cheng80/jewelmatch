import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/game/item_inventory.dart';
import 'package:stonematch/game/item_kind.dart';

void main() {
  test('phase 2 run inventory starts with onboarding items', () {
    final inventory = RunInventory.phase2Initial();

    expect(inventory.quantityOf(ItemKind.runeHammer), 1);
    expect(inventory.quantityOf(ItemKind.ancientBomb), 1);
    expect(inventory.quantityOf(ItemKind.thorHammer), 0);
  });

  test('run inventory adds and consumes item counts', () {
    final inventory = RunInventory();

    expect(inventory.tryConsume(ItemKind.hyperCube), isFalse);
    inventory.add(ItemKind.hyperCube, 2);
    expect(inventory.quantityOf(ItemKind.hyperCube), 2);
    expect(inventory.tryConsume(ItemKind.hyperCube), isTrue);
    expect(inventory.quantityOf(ItemKind.hyperCube), 1);
  });

  test('phase 2 loadout fills two open slots and locks the rest', () {
    final inventory = RunInventory({
      ItemKind.hintPlus: 1,
      ItemKind.runeHammer: 1,
      ItemKind.ancientBomb: 1,
    });

    final loadout = StageLoadout.phase2Default(inventory);

    expect(loadout.slots, hasLength(4));
    expect(loadout.slots[0].item, ItemKind.runeHammer);
    expect(loadout.slots[1].item, ItemKind.ancientBomb);
    expect(loadout.slots[2].locked, isTrue);
    expect(loadout.slots[3].locked, isTrue);
  });

  test('phase 2 loadout can unlock third and fourth slots', () {
    final inventory = RunInventory({
      ItemKind.runeHammer: 1,
      ItemKind.ancientBomb: 1,
      ItemKind.thorHammer: 1,
      ItemKind.hyperCube: 1,
    });

    final threeSlotLoadout = StageLoadout.phase2Default(
      inventory,
      openSlotCount: 3,
    );

    expect(threeSlotLoadout.openSlotCount, 3);
    expect(threeSlotLoadout.slots[2].locked, isFalse);
    expect(threeSlotLoadout.slots[3].locked, isTrue);

    final fourSlotLoadout = StageLoadout.phase2Default(
      inventory,
      openSlotCount: 4,
    );

    expect(fourSlotLoadout.openSlotCount, 4);
    expect(fourSlotLoadout.slots[3].locked, isFalse);
    expect(fourSlotLoadout.slots[3].item, ItemKind.hyperCube);
  });

  test('phase 2 loadout assignment uses available allowed items only', () {
    final inventory = RunInventory({
      ItemKind.runeHammer: 1,
      ItemKind.timeSlip: 1,
    });
    final loadout = StageLoadout.fromOpenItems([ItemKind.runeHammer, null]);

    final unchangedUnavailable = loadout.assignOpenSlot(
      slotIndex: 1,
      item: ItemKind.hyperCube,
      inventory: inventory,
      isAllowed: (_) => true,
    );
    expect(unchangedUnavailable.slots[1].item, isNull);

    final unchangedDisallowed = loadout.assignOpenSlot(
      slotIndex: 1,
      item: ItemKind.timeSlip,
      inventory: inventory,
      isAllowed: (_) => false,
    );
    expect(unchangedDisallowed.slots[1].item, isNull);

    final changed = loadout.assignOpenSlot(
      slotIndex: 1,
      item: ItemKind.timeSlip,
      inventory: inventory,
      isAllowed: (_) => true,
    );
    expect(changed.slots[1].item, ItemKind.timeSlip);
  });

  test('phase 2 loadout assignment can use unlocked slots', () {
    final inventory = RunInventory({
      ItemKind.runeHammer: 1,
      ItemKind.ancientBomb: 1,
      ItemKind.thorHammer: 1,
    });
    final loadout = StageLoadout.fromOpenItems([
      ItemKind.runeHammer,
      ItemKind.ancientBomb,
      null,
    ], openSlotCount: 3);

    final changed = loadout.assignOpenSlot(
      slotIndex: 2,
      item: ItemKind.thorHammer,
      inventory: inventory,
      isAllowed: (_) => true,
    );

    expect(changed.slots[2].item, ItemKind.thorHammer);
  });

  test('phase 2 loadout unlock keeps new slots empty', () {
    final loadout = StageLoadout.fromOpenItems([
      ItemKind.runeHammer,
      ItemKind.ancientBomb,
    ]);

    final unlocked = loadout.withOpenSlotCount(3);

    expect(unlocked.openSlotCount, 3);
    expect(unlocked.slots[0].item, ItemKind.runeHammer);
    expect(unlocked.slots[1].item, ItemKind.ancientBomb);
    expect(unlocked.slots[2].locked, isFalse);
    expect(unlocked.slots[2].item, isNull);
    expect(unlocked.slots[3].locked, isTrue);
  });
}
