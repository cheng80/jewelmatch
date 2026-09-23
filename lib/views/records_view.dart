import 'dart:math';

import 'package:easy_localization/easy_localization.dart' hide NumberFormat;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../game/jewel_game_mode.dart';
import '../game/match_board_models.dart';
import '../services/game_settings.dart';
import '../services/records/player_records.dart';
import '../services/records/records_store.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import '../widgets/obsidian_frame.dart';
import '../widgets/overlay_motion.dart';
import '../widgets/phone_frame_scaffold.dart';

final NumberFormat _fmt = NumberFormat.decimalPattern();

String _badgeKey(RecordBadge badge) =>
    'badge${badge.name[0].toUpperCase()}${badge.name.substring(1)}';

const List<String> _tierKeys = [
  'badgeTierNone',
  'badgeTierBronze',
  'badgeTierSilver',
  'badgeTierGold',
  'badgeTierDiamond',
];

const List<Color> _tierColors = [
  JewelCandyLuminaTheme.textMutedGold,
  Color(0xFFCD8B52),
  Color(0xFFCFD3D8),
  JewelCandyLuminaTheme.tertiaryGold,
  Color(0xFF7FE3F0),
];

/// 판 결과 화면의 랭크 상승, 배지 획득 알림. 기존 결과 배너 스타일을 쓴다.
class RecordsUpdateNotice extends StatelessWidget {
  const RecordsUpdateNotice({
    super.key,
    required this.update,
    this.maxLines = 2,
  });

  final RecordsUpdate? update;

  /// 결과 카드가 넘치지 않도록 알림 줄 수를 제한한다. 나머지는 기록 화면에서 본다.
  final int maxLines;

  static List<String> messages(BuildContext context, RecordsUpdate? update) {
    if (update == null) return const [];
    return [
      if (update.rankedUp)
        context.tr(
          'recordsRankUpNotice',
          namedArgs: {'rank': '${update.rankAfter}'},
        ),
      for (final earned in update.earnedBadges)
        context.tr(
          'recordsBadgeNotice',
          namedArgs: {
            'badge': context.tr(_badgeKey(earned.badge)),
            'tier': context.tr(_tierKeys[earned.tier]),
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lines = messages(context, update).take(maxLines).toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          for (final line in lines)
            AdResultBanner(success: true, message: line, fontSize: 13),
        ],
      ),
    );
  }
}

/// 누적 랭크, 모드별 최고 기록, 배지를 보여 주는 기록 화면.
class RecordsView extends StatefulWidget {
  const RecordsView({super.key});

  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  // 손상값 초기화 저장이 build마다 돌지 않도록 한 번만 읽는다.
  late final PlayerRecords records = RecordsStore.load();

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(title: Text(context.tr('recordsTitle'))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: ObsidianFrame(
            padding: const EdgeInsets.fromLTRB(34, 56, 34, 58),
            backgroundColor: JewelCandyLuminaTheme.surfaceContainer.withValues(
              alpha: 0.94,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 40),
              child: _RecordsContent(records: records),
            ),
          ),
        ),
      ),
    );
    return PhoneFrameScaffold(child: scaffold);
  }
}

class _RecordsContent extends StatelessWidget {
  const _RecordsContent({required this.records});

  final PlayerRecords records;

  int _bestScore(JewelGameMode mode) => max(
    records.bestScoreByMode[mode] ?? 0,
    GameSettings.getBestMatchScore(mode) ?? 0,
  );

  @override
  Widget build(BuildContext context) {
    final toNext = CumulativeRank.pointsToNext(records.totalScore);
    final bestLevel = max(
      records.bestLevel,
      GameSettings.getBestMatchProgressionLevel() ?? 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          context.tr('recordsRank', namedArgs: {'rank': '${records.rank}'}),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: JewelCandyLuminaTheme.textTitleGold,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _rankProgress(records.totalScore),
            minHeight: 6,
            color: JewelCandyLuminaTheme.tertiaryGold,
            backgroundColor: JewelCandyLuminaTheme.surfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          toNext == null
              ? context.tr('recordsRankMax')
              : context.tr(
                  'recordsRankNext',
                  namedArgs: {'points': _fmt.format(toNext)},
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: JewelCandyLuminaTheme.textMutedGold,
            fontSize: 13,
          ),
        ),
        _StatRow(
          label: context.tr('recordsTotalScore'),
          value: _fmt.format(records.totalScore),
        ),
        _SectionTitle(
          icon: Icons.emoji_events,
          title: context.tr('recordsBestByMode'),
        ),
        _StatRow(
          label: context.tr('modeSimple'),
          value: _fmt.format(_bestScore(JewelGameMode.simple)),
        ),
        _StatRow(
          label: context.tr('modeProgression'),
          value: context.tr(
            'recordsLevelValue',
            namedArgs: {'level': '$bestLevel'},
          ),
        ),
        _StatRow(
          label: context.tr('modeTimed'),
          value: _fmt.format(_bestScore(JewelGameMode.timed)),
        ),
        _StatRow(
          label: context.tr('recordsBestMove'),
          value: _fmt.format(records.bestMoveScore),
        ),
        _StatRow(
          label: context.tr('recordsLongestCombo'),
          value: _fmt.format(records.longestCombo),
        ),
        _StatRow(
          label: context.tr('recordsTotalRemoved'),
          value: _fmt.format(records.totalRemovedGems),
        ),
        _SectionTitle(
          icon: Icons.auto_awesome,
          title: context.tr('recordsSpecials'),
        ),
        for (final kind in recordedSpecialKinds)
          _StatRow(
            label: context.tr(_kindKey(kind)),
            value: _fmt.format(records.specialCount(kind)),
          ),
        _SectionTitle(
          icon: Icons.military_tech,
          title: context.tr('recordsBadges'),
        ),
        for (final badge in RecordBadge.values)
          _BadgeTile(badge: badge, records: records),
      ],
    );
  }

  static double _rankProgress(int total) {
    final rank = CumulativeRank.rankForScore(total);
    if (rank >= CumulativeRank.maxRank) return 1;
    final from = CumulativeRank.thresholdFor(rank);
    final to = CumulativeRank.thresholdFor(rank + 1);
    return ((total - from) / (to - from)).clamp(0.0, 1.0);
  }

  static String _kindKey(GemKind kind) => switch (kind) {
    GemKind.bomb => 'statsKindBomb',
    GemKind.star => 'statsKindStar',
    GemKind.hyper => 'statsKindHyper',
    _ => 'statsKindSupernova',
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: JewelCandyLuminaTheme.textMutedGold.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: JewelCandyLuminaTheme.outlineBright.withValues(
                  alpha: 0.85,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: JewelCandyLuminaTheme.textParchment,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: JewelCandyLuminaTheme.tertiaryGold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.records});

  final RecordBadge badge;
  final PlayerRecords records;

  @override
  Widget build(BuildContext context) {
    final tier = records.badgeTier(badge);
    final next = badge.nextThreshold(tier);
    final color = _tierColors[tier];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tier == 0 ? Icons.lock_outline : Icons.military_tech,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr(_badgeKey(badge))} (${context.tr(_tierKeys[tier])})',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.tr('${_badgeKey(badge)}Desc'),
                  style: const TextStyle(
                    color: JewelCandyLuminaTheme.textParchment,
                    fontSize: 12,
                  ),
                ),
                Text(
                  next == null
                      ? context.tr('recordsBadgeDone')
                      : context.tr(
                          'recordsBadgeProgress',
                          namedArgs: {
                            'current': _fmt.format(badge.valueOf(records)),
                            'target': _fmt.format(next),
                          },
                        ),
                  style: const TextStyle(
                    color: JewelCandyLuminaTheme.textMutedGold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
