import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/ranking_service.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import 'lumina_buttons.dart';
import 'lumina_overlay_card.dart';

/// 서버에서 가져온 타임 어택 랭킹 목록을 보여 주는 팝업.
///
/// [GameView] 오버레이와 [TitleView] 등에서 동일 위젯을 재사용한다.
/// 닫기 동작(게임 재개, `Navigator.pop` 등)은 [onClose]에 맡긴다.
class RankingListPopup extends StatefulWidget {
  const RankingListPopup({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  State<RankingListPopup> createState() => _RankingListPopupState();
}

class _RankingListPopupState extends State<RankingListPopup> {
  late Future<List<RankingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = RankingService.fetchList();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final listMaxH = MediaQuery.sizeOf(context).height * 0.45;

    return LuminaOverlayCard(
      borderColor: JewelCandyLuminaTheme.secondaryCyan,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('rankingTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: JewelCandyLuminaTheme.secondaryCyan,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<RankingEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: JewelCandyLuminaTheme.secondaryCyan,
                    ),
                  ),
                );
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return _centerMessage(context.tr('rankingEmpty'));
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMaxH),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (context, _) => const Divider(
                    height: 1,
                    color: Colors.white24,
                  ),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final rank = i + 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
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
                            child: Text(
                              e.name,
                              style: const TextStyle(
                                color: Color(0xFFFFFDE7),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            fmt.format(e.score),
                            style: TextStyle(
                              color: JewelCandyLuminaTheme.secondaryCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          LuminaOutlinedButton(
            label: context.tr('close'),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _centerMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
          fontSize: 16,
        ),
      ),
    );
  }
}
