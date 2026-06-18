import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/item_inventory.dart';
import '../../game/item_kind.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_overlay_card.dart';

class StageInventoryOverlay extends StatefulWidget {
  const StageInventoryOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  State<StageInventoryOverlay> createState() => _StageInventoryOverlayState();
}

class _StageInventoryOverlayState extends State<StageInventoryOverlay> {
  int _selectedLoadoutSlot = 0;

  @override
  void initState() {
    super.initState();
    final unlocked = widget.game.recentlyUnlockedLoadoutSlotIndices;
    if (unlocked.isNotEmpty) {
      _selectedLoadoutSlot = unlocked.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return LuminaOverlayCard(
      borderColor: JewelCandyLuminaTheme.goldStrong,
      shadowColor: JewelCandyLuminaTheme.tertiaryGold,
      maxCardWidth: 390,
      maxHeightFactor: 0.92,
      verticalMargin: 28,
      alignment: Alignment.center,
      horizontalPadding: 24,
      verticalPadding: 24,
      innerPadding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 38,
            child: Center(
              child: Text(
                context.tr('openInventory'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.goldStrong,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (game.hasPendingStageInventoryUnlock) ...[
            _UnlockNotice(
              unlockedSlots: game.recentlyUnlockedLoadoutSlotIndices,
            ),
            const SizedBox(height: 10),
          ],
          _StageInventoryLoadout(
            game: game,
            selectedSlotIndex: _selectedLoadoutSlot,
            onSelectSlot: (slotIndex) {
              setState(() => _selectedLoadoutSlot = slotIndex);
            },
            onEquipItem: (item) {
              setState(() {
                game.assignNextStageLoadoutSlot(_selectedLoadoutSlot, item);
              });
            },
          ),
          const SizedBox(height: 14),
          _CloseInventoryButton(
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.closeStageInventory();
            },
          ),
        ],
      ),
    );
  }
}

class _UnlockNotice extends StatelessWidget {
  const _UnlockNotice({required this.unlockedSlots});

  final List<int> unlockedSlots;

  @override
  Widget build(BuildContext context) {
    final slotNumbers = unlockedSlots.map((slot) => '${slot + 1}').join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.focusTeal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: JewelCandyLuminaTheme.focusTeal.withValues(alpha: 0.82),
          width: 1.4,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('inventorySlotUnlockedTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.focusTeal,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr(
              'inventorySlotUnlockedDesc',
              namedArgs: {'slots': slotNumbers},
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.textParchment,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageInventoryLoadout extends StatelessWidget {
  const _StageInventoryLoadout({
    required this.game,
    required this.selectedSlotIndex,
    required this.onSelectSlot,
    required this.onEquipItem,
  });

  final MatchBoardGame game;
  final int selectedSlotIndex;
  final ValueChanged<int> onSelectSlot;
  final ValueChanged<ItemKind> onEquipItem;

  @override
  Widget build(BuildContext context) {
    final loadout = game.nextStageLoadoutDraft;
    final unlockedSlots = game.recentlyUnlockedLoadoutSlotIndices;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('stageLoadoutTitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: JewelCandyLuminaTheme.goldStrong,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final slot in loadout.slots) ...[
              SizedBox.square(
                dimension: 48,
                child: _LoadoutSlotButton(
                  slot: slot,
                  selected: slot.index == selectedSlotIndex,
                  newlyUnlocked: unlockedSlots.contains(slot.index),
                  onTap: slot.open ? () => onSelectSlot(slot.index) : null,
                ),
              ),
              if (slot.index != loadout.slots.length - 1)
                const SizedBox(width: 7),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _InventoryGrid(game: game, onEquipItem: onEquipItem),
      ],
    );
  }
}

class _LoadoutSlotButton extends StatelessWidget {
  const _LoadoutSlotButton({
    required this.slot,
    required this.selected,
    required this.newlyUnlocked,
    required this.onTap,
  });

  final StageLoadoutSlot slot;
  final bool selected;
  final bool newlyUnlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final item = slot.item;
    return GestureDetector(
      onTap: onTap,
      child: _FramedItemCell(
        selected: selected,
        disabled: slot.locked,
        newlyUnlocked: newlyUnlocked,
        child: slot.locked
            ? Icon(
                Icons.lock_rounded,
                color: JewelCandyLuminaTheme.outlineBright.withValues(
                  alpha: 0.78,
                ),
                size: 24,
              )
            : item == null
            ? Text(
                context.tr('emptySlotShort'),
                style: TextStyle(
                  color: JewelCandyLuminaTheme.textMutedGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              )
            : _ItemIcon(item: item),
      ),
    );
  }
}

class _InventoryGrid extends StatelessWidget {
  const _InventoryGrid({required this.game, required this.onEquipItem});

  final MatchBoardGame game;
  final ValueChanged<ItemKind> onEquipItem;

  @override
  Widget build(BuildContext context) {
    return _InventoryPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('temporaryInventoryTitle'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.textParchment,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 2; row++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var col = 0; col < 4; col++) ...[
                      SizedBox.square(
                        dimension: 52,
                        child: _InventoryItemCell(
                          item: ItemKindMeta.phaseOneLoadout[row * 4 + col],
                          quantity: game.runInventory.quantityOf(
                            ItemKindMeta.phaseOneLoadout[row * 4 + col],
                          ),
                          enabled: game.isInventoryItemAvailable(
                            ItemKindMeta.phaseOneLoadout[row * 4 + col],
                          ),
                          selected: game.nextStageLoadoutDraft.contains(
                            ItemKindMeta.phaseOneLoadout[row * 4 + col],
                          ),
                          onTap: () => onEquipItem(
                            ItemKindMeta.phaseOneLoadout[row * 4 + col],
                          ),
                        ),
                      ),
                      if (col != 3) const SizedBox(width: 8),
                    ],
                  ],
                ),
                if (row == 0) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItemCell extends StatelessWidget {
  const _InventoryItemCell({
    required this.item,
    required this.quantity,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final ItemKind item;
  final int quantity;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: _FramedItemCell(
        selected: selected,
        disabled: !enabled,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: _ItemIcon(item: item, disabled: !enabled),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: _QuantityBadge(quantity: quantity),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            JewelCandyLuminaTheme.surfaceStone.withValues(alpha: 0.88),
            JewelCandyLuminaTheme.surfaceStoneDark.withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.68),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: JewelCandyLuminaTheme.surface.withValues(alpha: 0.65),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: child,
        ),
      ),
    );
  }
}

class _CloseInventoryButton extends StatelessWidget {
  const _CloseInventoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: JewelCandyLuminaTheme.tertiaryGold,
          side: BorderSide(
            color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.82),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: JewelCandyLuminaTheme.surfaceStoneDark.withValues(
            alpha: 0.72,
          ),
        ),
        child: Text(
          context.tr('close'),
          style: TextStyle(
            color: JewelCandyLuminaTheme.tertiaryGold,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _FramedItemCell extends StatelessWidget {
  const _FramedItemCell({
    required this.child,
    this.selected = false,
    this.disabled = false,
    this.newlyUnlocked = false,
  });

  final Widget child;
  final bool selected;
  final bool disabled;
  final bool newlyUnlocked;

  @override
  Widget build(BuildContext context) {
    final cell = AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color:
              (disabled
                      ? JewelCandyLuminaTheme.surfaceStoneDark
                      : JewelCandyLuminaTheme.surfaceStone)
                  .withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: newlyUnlocked
                ? JewelCandyLuminaTheme.focusTeal
                : selected
                ? JewelCandyLuminaTheme.focusTeal
                : JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.62),
            width: selected || newlyUnlocked ? 2 : 1,
          ),
          boxShadow: newlyUnlocked
              ? [
                  BoxShadow(
                    color: JewelCandyLuminaTheme.focusTeal.withValues(
                      alpha: 0.72,
                    ),
                    blurRadius: 13,
                    spreadRadius: 1.5,
                  ),
                ]
              : null,
        ),
        child: Padding(padding: const EdgeInsets.all(5), child: child),
      ),
    );
    if (!newlyUnlocked) return cell;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: cell,
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item, this.disabled = false});

  final ItemKind item;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.32 : 1,
      child: Image.asset(
        _itemIconAsset(item),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  const _QuantityBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.tertiaryGold,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A1606), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        quantity > 99 ? '99+' : '$quantity',
        style: const TextStyle(
          color: Color(0xFF211204),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _itemIconAsset(ItemKind item) => switch (item) {
  ItemKind.runeHammer => 'assets/images/${AssetPaths.itemIconRuneHammer}',
  ItemKind.ancientBomb => 'assets/images/${AssetPaths.itemIconAncientBomb}',
  ItemKind.thorHammer => 'assets/images/${AssetPaths.itemIconThorHammer}',
  ItemKind.hyperCube => 'assets/images/${AssetPaths.itemIconHyperCube}',
  ItemKind.prismTransform =>
    'assets/images/${AssetPaths.itemIconPrismTransform}',
  ItemKind.fateShuffle => 'assets/images/${AssetPaths.itemIconFateShuffle}',
  ItemKind.timeSlip => 'assets/images/${AssetPaths.itemIconTimeSlip}',
  ItemKind.hintPlus => 'assets/images/${AssetPaths.itemIconHintPlus}',
};
