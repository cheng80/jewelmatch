import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../game/match_board_game.dart';
import '../../game/match_board_logic.dart';
import '../../resources/asset_paths.dart';
import '../../resources/sound_manager.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/lumina_buttons.dart';
import '../../widgets/lumina_overlay_card.dart';

class GameStatsOverlay extends StatelessWidget {
  const GameStatsOverlay({super.key, required this.game});

  final MatchBoardGame game;

  @override
  Widget build(BuildContext context) {
    final stats = game.board.stats;
    final numberFormat = NumberFormat.decimalPattern(
      context.locale.toLanguageTag(),
    );
    String n(int value) => numberFormat.format(value);

    return LuminaOverlayCard(
      borderColor: JewelCandyLuminaTheme.tertiaryGold,
      shadowColor: JewelCandyLuminaTheme.goldStrong,
      maxCardWidth: 410,
      maxHeightFactor: 0.82,
      verticalMargin: 58,
      horizontalPadding: 26,
      verticalPadding: 22,
      innerPadding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 42),
              Expanded(
                child: Text(
                  context.tr('statsTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.textTitleGold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Tooltip(
                message: context.tr('close'),
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: JewelCandyLuminaTheme.textParchment,
                  ),
                  onPressed: () {
                    SoundManager.playSfx(AssetPaths.sfxBtnSnd);
                    game.closeGameStats();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatGrid(
            rows: [
              _StatRow(context.tr('score'), n(game.board.score)),
              _StatRow(context.tr('statsValidSwaps'), n(stats.validSwaps)),
              _StatRow(context.tr('statsMatchGroups'), n(stats.matchGroups)),
              _StatRow(context.tr('statsRemovedGems'), n(stats.removedGems)),
              _StatRow(
                context.tr('statsRemovedSpecials'),
                n(stats.removedSpecialGems),
              ),
              _StatRow(
                context.tr('statsCreatedSpecials'),
                n(stats.specialGemsCreated),
              ),
              _StatRow(
                context.tr('statsActivatedSpecials'),
                n(stats.specialGemsActivated),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BreakdownSection(
            title: context.tr('statsRemovedBreakdown'),
            counts: stats.removedByKind,
            numberFormat: n,
          ),
          const SizedBox(height: 14),
          _BreakdownSection(
            title: context.tr('statsCreatedBreakdown'),
            counts: stats.specialCreatedByKind,
            numberFormat: n,
            includeNormal: false,
          ),
          const SizedBox(height: 14),
          _BreakdownSection(
            title: context.tr('statsActivatedBreakdown'),
            counts: stats.specialActivatedByKind,
            numberFormat: n,
            includeNormal: false,
          ),
          const SizedBox(height: 20),
          LuminaGradientButton(
            width: 230,
            height: 50,
            colors: JewelCandyLuminaTheme.buttonShuffleCyanLime,
            label: context.tr('close'),
            onPressed: () {
              SoundManager.playSfx(AssetPaths.sfxBtnSnd);
              game.closeGameStats();
            },
          ),
        ],
      ),
    );
  }
}

class _StatRow {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.rows});

  final List<_StatRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceVariant.withValues(alpha: 0.58),
        border: Border.all(
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _StatLine(row: rows[i], showDivider: i != rows.length - 1),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.row, required this.showDivider});

  final _StatRow row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: JewelCandyLuminaTheme.tertiaryGold.withValues(
                    alpha: 0.18,
                  ),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: TextStyle(
                  color: JewelCandyLuminaTheme.textParchment.withValues(
                    alpha: 0.84,
                  ),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              row.value,
              style: TextStyle(
                color: JewelCandyLuminaTheme.goldStrong,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.title,
    required this.counts,
    required this.numberFormat,
    this.includeNormal = true,
  });

  final String title;
  final Map<GemKind, int> counts;
  final String Function(int value) numberFormat;
  final bool includeNormal;

  @override
  Widget build(BuildContext context) {
    final kinds = [
      if (includeNormal) GemKind.normal,
      GemKind.bomb,
      GemKind.star,
      GemKind.hyper,
      GemKind.supernova,
      GemKind.row,
      GemKind.col,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: JewelCandyLuminaTheme.tertiaryGold,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in kinds)
              _KindCountChip(
                label: _kindLabel(context, kind),
                value: numberFormat(counts[kind] ?? 0),
              ),
          ],
        ),
      ],
    );
  }

  String _kindLabel(BuildContext context, GemKind kind) {
    return switch (kind) {
      GemKind.normal => context.tr('statsKindNormal'),
      GemKind.row => context.tr('statsKindRow'),
      GemKind.col => context.tr('statsKindCol'),
      GemKind.bomb => context.tr('statsKindBomb'),
      GemKind.star => context.tr('statsKindStar'),
      GemKind.hyper => context.tr('statsKindHyper'),
      GemKind.supernova => context.tr('statsKindSupernova'),
    };
  }
}

class _KindCountChip extends StatelessWidget {
  const _KindCountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 102,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.66),
        border: Border.all(
          color: JewelCandyLuminaTheme.borderPause.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: JewelCandyLuminaTheme.textParchment.withValues(
                alpha: 0.78,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: JewelCandyLuminaTheme.goldStrong,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
