import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/item_kind.dart';
import '../../game/match_board_game.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';
import 'pause_menu_buttons.dart';

class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.06,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 30),
    ]).animate(_controller);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: LuminaOverlayCard(
          borderColor: JewelCandyLuminaTheme.goldStrong,
          shadowColor: JewelCandyLuminaTheme.tertiaryGold,
          maxCardWidth: 410,
          maxHeightFactor: 0.96,
          verticalMargin: 14,
          alignment: Alignment.topCenter,
          horizontalPadding: 20,
          verticalPadding: 16,
          innerPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('levelUpTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.goldStrong,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _LevelBadge(game: game),
              if (game.progressionNextBoardBonusCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'nextBoardBonus',
                    namedArgs: {
                      'count': '${game.progressionNextBoardBonusCount}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.tertiaryGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _StageRewardSummary(game: game),
              const SizedBox(height: 10),
              _InventoryOpenButton(onPressed: game.showStageInventory),
              const SizedBox(height: 12),
              const _SectionDivider(),
              const SizedBox(height: 10),
              Text(
                context.tr('levelUpDesc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.textParchment,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              LuminaGradientButton(
                width: 220,
                height: 42,
                fontSize: 16,
                colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
                label: context.tr('nextLevel'),
                onPressed: () {
                  SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                  game.continueAfterLevelUp();
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 48,
                height: 48,
                child: FittedBox(
                  child: PauseMenuStatsButton(
                    onPressed: () {
                      SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                      game.showGameStats();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageRewardSummary extends StatelessWidget {
  const _StageRewardSummary({required this.game});

  static const double _chipSpacing = 6;
  static const double _chipMinHeight = 34;
  static const double _maxRewardListHeight =
      (_chipMinHeight * 4) + (_chipSpacing * 3);

  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    final rewards = game.latestStageRewards;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceStoneDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.58),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('stageRewardsTitle'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          if (rewards.isEmpty)
            Text(
              context.tr('stageRewardsEmpty'),
              style: TextStyle(
                color: JewelCandyLuminaTheme.textMutedGold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _maxRewardListHeight,
              ),
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chipWidth = (constraints.maxWidth - _chipSpacing) / 2;
                    return Wrap(
                      spacing: _chipSpacing,
                      runSpacing: _chipSpacing,
                      children: [
                        for (final reward in rewards)
                          SizedBox(
                            width: chipWidth,
                            child: _RewardChip(
                              item: reward.item,
                              quantity: reward.quantity,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.item, required this.quantity});

  final ItemKind item;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceStone.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox.square(dimension: 24, child: _ItemIcon(item: item)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${_oneLineItemName(item)} x$quantity',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: JewelCandyLuminaTheme.textParchment,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _oneLineItemName(ItemKind item) => item.label.replaceAll('\n', ' ');

class _InventoryOpenButton extends StatelessWidget {
  const _InventoryOpenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('openInventory'),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AssetPaths.modeIconInventory,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('openInventory'),
                style: TextStyle(
                  color: JewelCandyLuminaTheme.tertiaryGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.72),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0),
            JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.86),
            JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.96),
            JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.86),
            JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.game});

  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${context.tr('levelLabel')} ${game.levelUpFromLevel}',
              style: TextStyle(
                color: JewelCandyLuminaTheme.textParchment.withValues(
                  alpha: 0.72,
                ),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: JewelCandyLuminaTheme.focusTeal,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              '${context.tr('levelLabel')} ${game.levelUpToLevel}',
              style: TextStyle(
                color: JewelCandyLuminaTheme.goldStrong,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemIcon extends StatelessWidget {
  const _ItemIcon({required this.item});

  final ItemKind item;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _itemIconAsset(item),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
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
