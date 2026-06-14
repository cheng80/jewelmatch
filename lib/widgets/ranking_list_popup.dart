import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/ranking_service.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import 'lumina_buttons.dart';
import 'lumina_overlay_card.dart';

/// 서버에서 가져온 레벨/타임 랭킹 목록을 보여 주는 팝업.
///
/// [GameView] 오버레이와 [TitleView] 등에서 동일 위젯을 재사용한다.
/// 닫기 동작(게임 재개, `Navigator.pop` 등)은 [onClose]에 맡긴다.
class RankingListPopup extends StatefulWidget {
  const RankingListPopup({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<RankingListPopup> createState() => _RankingListPopupState();
}

class _RankingListPopupState extends State<RankingListPopup> {
  late final Future<List<RankingEntry>> _levelFuture;
  late final Future<List<RankingEntry>> _timeFuture;

  @override
  void initState() {
    super.initState();
    _levelFuture = RankingService.fetchList(mode: RankingMode.level);
    _timeFuture = RankingService.fetchList(mode: RankingMode.time);
  }

  @override
  Widget build(BuildContext context) {
    final listMaxH = MediaQuery.sizeOf(context).height * 0.285;

    return DefaultTabController(
      length: 2,
      child: LuminaOverlayCard(
        borderColor: JewelCandyLuminaTheme.borderTimeUp,
        maxHeightFactor: 0.78,
        verticalMargin: 48,
        alignment: const Alignment(0, -0.08),
        horizontalPadding: 26,
        verticalPadding: 24,
        innerPadding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('rankingTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: JewelCandyLuminaTheme.textTitleGold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: JewelCandyLuminaTheme.surfaceVariant.withValues(
                  alpha: 0.58,
                ),
                border: Border.all(
                  color: JewelCandyLuminaTheme.tertiaryGold.withValues(
                    alpha: 0.78,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2D2920),
                      JewelCandyLuminaTheme.goldStrong,
                      Color(0xFF6F3D24),
                    ],
                  ),
                  border: Border.all(
                    color: JewelCandyLuminaTheme.goldStrong,
                    width: 1.4,
                  ),
                ),
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFFFFF4C4),
                unselectedLabelColor: JewelCandyLuminaTheme.tertiaryGold,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: context.tr('rankingLevelTab')),
                  Tab(text: context.tr('rankingTimeTab')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: listMaxH,
              child: TabBarView(
                children: [
                  _RankingList(
                    future: _levelFuture,
                    mode: RankingMode.level,
                    emptyText: context.tr('rankingEmpty'),
                  ),
                  _RankingList(
                    future: _timeFuture,
                    mode: RankingMode.time,
                    emptyText: context.tr('rankingEmpty'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: LuminaOutlinedButton(
                width: 240,
                label: context.tr('close'),
                onPressed: widget.onClose,
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.future,
    required this.mode,
    required this.emptyText,
  });

  final Future<List<RankingEntry>> future;
  final RankingMode mode;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RankingEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(
              color: JewelCandyLuminaTheme.focusTeal,
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return _CenterMessage(emptyText);
        }
        return ListView.separated(
          primary: false,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const ClampingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (context, _) =>
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          itemBuilder: (context, i) {
            final e = list[i];
            final rank = i + 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 3
                            ? JewelCandyLuminaTheme.goldStrong
                            : JewelCandyLuminaTheme.tertiaryGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.name,
                          style: const TextStyle(
                            color: Color(0xFFFFFDE7),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatScore(context, e.score),
                          style: TextStyle(
                            color: JewelCandyLuminaTheme.textParchment,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatScore(BuildContext context, int score) {
    if (mode == RankingMode.level) {
      return '${context.tr('levelLabel')} $score';
    }
    return NumberFormat.decimalPattern().format(score);
  }
}

class _CenterMessage extends StatelessWidget {
  const _CenterMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
