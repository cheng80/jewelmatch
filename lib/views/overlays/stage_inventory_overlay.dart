import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../ads/ad_reward_policy.dart';
import '../../ads/ad_service.dart';
import '../../game/item_inventory.dart';
import '../../game/item_kind.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../resources/texture_atlas.dart';
import '../../services/event_logger.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/atlas_image.dart';
import '../../widgets/lumina_overlay_card.dart';
import '../../widgets/overlay_motion.dart';

class StageInventoryOverlay extends StatefulWidget {
  const StageInventoryOverlay({
    super.key,
    required this.game,
    required this.adService,
    required this.adRewardPolicy,
  });

  final MatchBoardGame game;
  final AdService adService;
  final AdRewardPolicy adRewardPolicy;

  @override
  State<StageInventoryOverlay> createState() => _StageInventoryOverlayState();
}

class _StageInventoryOverlayState extends State<StageInventoryOverlay> {
  int _selectedLoadoutSlot = 0;
  ItemKind? _selectedRefillItem;
  bool _showingAd = false;
  String? _adMessage;
  bool _adGranted = false;

  @override
  void initState() {
    super.initState();
    final unlocked = widget.game.recentlyUnlockedLoadoutSlotIndices;
    if (unlocked.isNotEmpty) {
      _selectedLoadoutSlot = unlocked.first;
    }
    unawaited(_syncRefillStatus());
  }

  Future<void> _syncRefillStatus() async {
    await widget.adRewardPolicy.syncRefillStatus();
    if (mounted) setState(() {});
  }

  Future<void> _refillWithAd() async {
    final item = _selectedRefillItem;
    if (item == null ||
        _showingAd ||
        widget.adService.rewardedState != RewardedAdState.ready ||
        !widget.adRewardPolicy.canRefill(widget.game.runInventory, item)) {
      return;
    }
    SoundManager.pauseBgm(onlyIfCurrent: AssetPaths.bgmMain);
    setState(() {
      _showingAd = true;
      _adMessage = null;
    });
    final result = await widget.adService.showRewarded(AdPlacement.refillItem);
    if (!mounted) return;
    final outcome = await widget.adRewardPolicy.grantRefillVerified(
      widget.game.runInventory,
      item,
      result,
    );
    final granted = outcome == RefillGrantOutcome.granted;
    EventLogger.instance.log('ad_reward', {
      'placement': 'refill_item',
      'result': result.name,
      'granted': granted,
      'outcome': outcome.name,
      'item': item.name,
    });
    // 서버 확인 중 오버레이가 닫혀도 배경음과 다음 광고 준비는 이어 간다.
    SoundManager.resumeBgm(onlyIfCurrent: AssetPaths.bgmMain);
    unawaited(widget.adService.preloadRewarded());
    if (!mounted) return;
    setState(() {
      _showingAd = false;
      _selectedRefillItem = granted ? null : item;
      _adGranted = granted;
      _adMessage = context.tr(switch (outcome) {
        RefillGrantOutcome.granted => 'adItemGranted',
        RefillGrantOutcome.adNotCompleted => 'adRewardNotGranted',
        RefillGrantOutcome.limitReached => 'adRefillLimitReached',
        RefillGrantOutcome.rejected => 'adRefillUnavailable',
      });
    });
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
      enterSlide: const Offset(0, 0.12),
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
            selectedRefillItem: _selectedRefillItem,
            onSelectSlot: (slotIndex) {
              setState(() => _selectedLoadoutSlot = slotIndex);
            },
            onEquipItem: (item) {
              setState(() {
                game.assignNextStageLoadoutSlot(_selectedLoadoutSlot, item);
              });
            },
            onSelectEmptyItem: (item) {
              if (widget.adService.rewardedState ==
                  RewardedAdState.unavailable) {
                return;
              }
              setState(() {
                _selectedRefillItem = item;
                _adMessage = null;
              });
            },
          ),
          if (_selectedRefillItem != null) ...[
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: widget.adService,
              builder: (context, _) {
                final limitReached = widget.adRewardPolicy.isRefillLimitReached;
                final ready =
                    widget.adService.rewardedState == RewardedAdState.ready &&
                    !_showingAd &&
                    !limitReached &&
                    widget.adRewardPolicy.canRefill(
                      game.runInventory,
                      _selectedRefillItem!,
                    );
                return SizedBox(
                  width: 220,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: ready ? _refillWithAd : null,
                    child: Text(
                      _showingAd
                          ? context.tr('adPlaying')
                          : limitReached
                          ? context.tr('adRefillLimitReached')
                          : ready
                          ? context.tr('watchAdGetItem')
                          : context.tr('adLoading'),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              widget.adRewardPolicy.isRefillLimitReached
                  ? context.tr(
                      'adRefillResetHint',
                      namedArgs: {
                        'count': '${widget.adRewardPolicy.dailyRefillLimit}',
                      },
                    )
                  : context.tr(
                      'adRefillRemaining',
                      namedArgs: {
                        'count':
                            '${widget.adRewardPolicy.remainingRefillsToday}',
                      },
                    ),
              style: TextStyle(
                color: JewelCandyLuminaTheme.textMutedGold,
                fontSize: 11,
              ),
            ),
          ],
          if (_adMessage != null) ...[
            const SizedBox(height: 6),
            AdResultBanner(
              key: ValueKey(_adMessage),
              success: _adGranted,
              message: _adMessage!,
            ),
          ],
          const SizedBox(height: 14),
          _CloseInventoryButton(
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              runOverlayExit(context, () => game.closeStageInventory());
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
    required this.selectedRefillItem,
    required this.onSelectSlot,
    required this.onEquipItem,
    required this.onSelectEmptyItem,
  });

  final MatchBoardGame game;
  final int selectedSlotIndex;
  final ItemKind? selectedRefillItem;
  final ValueChanged<int> onSelectSlot;
  final ValueChanged<ItemKind> onEquipItem;
  final ValueChanged<ItemKind> onSelectEmptyItem;

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
        _InventoryGrid(
          game: game,
          selectedRefillItem: selectedRefillItem,
          onEquipItem: onEquipItem,
          onSelectEmptyItem: onSelectEmptyItem,
        ),
      ],
    );
  }
}

/// 장착 순간 슬롯이 튀고 아이콘이 자리 잡는다 (TP-063).
///
/// 처음 그릴 때는 튀지 않는다. 아이템이 바뀌어 들어올 때만 다시 돈다.
class _LoadoutSlotButton extends StatefulWidget {
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
  State<_LoadoutSlotButton> createState() => _LoadoutSlotButtonState();
}

class _LoadoutSlotButtonState extends State<_LoadoutSlotButton>
    with SingleTickerProviderStateMixin {
  static const Duration _popDuration = Duration(milliseconds: 420);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: _popDuration,
    value: 1,
  );
  late final Animation<double> _popScale = Tween<double>(
    begin: 1.22,
    end: 1,
  ).animate(CurvedAnimation(parent: _pop, curve: Curves.elasticOut));

  @override
  void didUpdateWidget(_LoadoutSlotButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final item = widget.slot.item;
    if (item == null || item == oldWidget.slot.item) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pop.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _pop.value = 1;
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final item = slot.item;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _popScale,
          child: _FramedItemCell(
            selected: widget.selected,
            disabled: slot.locked,
            newlyUnlocked: widget.newlyUnlocked,
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
                : OverlayEnterTransition(
                    key: ValueKey(item),
                    beginScale: 0.6,
                    duration: const Duration(milliseconds: 220),
                    child: _ItemIcon(item: item),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InventoryGrid extends StatelessWidget {
  const _InventoryGrid({
    required this.game,
    required this.selectedRefillItem,
    required this.onEquipItem,
    required this.onSelectEmptyItem,
  });

  static const int _columnCount = 4;
  static const int _rowCount = 2;
  static const double _preferredCellSize = 52;
  static const double _preferredGap = 8;
  static const double _minGap = 5;

  final MatchBoardGame game;
  final ItemKind? selectedRefillItem;
  final ValueChanged<ItemKind> onEquipItem;
  final ValueChanged<ItemKind> onSelectEmptyItem;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final preferredWidth =
                  (_preferredCellSize * _columnCount) +
                  (_preferredGap * (_columnCount - 1));
              final gap = constraints.maxWidth >= preferredWidth
                  ? _preferredGap
                  : _minGap;
              final cellSize = constraints.maxWidth >= preferredWidth
                  ? _preferredCellSize
                  : (constraints.maxWidth - (gap * (_columnCount - 1))) /
                        _columnCount;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < _rowCount; row++) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var col = 0; col < _columnCount; col++) ...[
                          SizedBox.square(
                            dimension: cellSize,
                            child: _InventoryItemCell(
                              item: ItemKindMeta
                                  .phaseOneLoadout[row * _columnCount + col],
                              quantity: game.runInventory.quantityOf(
                                ItemKindMeta.phaseOneLoadout[row *
                                        _columnCount +
                                    col],
                              ),
                              enabled: game.isInventoryItemAvailable(
                                ItemKindMeta.phaseOneLoadout[row *
                                        _columnCount +
                                    col],
                              ),
                              selected:
                                  game.nextStageLoadoutDraft.contains(
                                    ItemKindMeta.phaseOneLoadout[row *
                                            _columnCount +
                                        col],
                                  ) ||
                                  selectedRefillItem ==
                                      ItemKindMeta.phaseOneLoadout[row *
                                              _columnCount +
                                          col],
                              onTap: () {
                                final item = ItemKindMeta
                                    .phaseOneLoadout[row * _columnCount + col];
                                if (game.runInventory.quantityOf(item) == 0) {
                                  onSelectEmptyItem(item);
                                } else {
                                  onEquipItem(item);
                                }
                              },
                            ),
                          ),
                          if (col != _columnCount - 1) SizedBox(width: gap),
                        ],
                      ],
                    ),
                    if (row == 0) SizedBox(height: gap),
                  ],
                ],
              );
            },
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
      onTap: onTap,
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
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
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
    if (!newlyUnlocked || MediaQuery.disableAnimationsOf(context)) return cell;
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
      child: AtlasImage(UiFrames.itemIcon(item)),
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
