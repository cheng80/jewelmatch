import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/jewel_candy_lumina_theme.dart';
import '../utils/sfx_play_log.dart';

/// 심플 모드 게임 화면 하단: 효과음 로그 스크롤 + 전체 복사 버튼.
class SfxPlayLogPanel extends StatelessWidget {
  const SfxPlayLogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  size: 16,
                  color: JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  '효과음 로그',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final t = SfxPlayLog.fullText;
                    if (t.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('복사할 로그가 없습니다.')),
                      );
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: t));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그를 클립보드에 복사했습니다.')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '전체 복사',
                    style: TextStyle(
                      color: JewelCandyLuminaTheme.tertiaryGold.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          SizedBox(
            height: 96,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: SfxPlayLog.lines,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '재생 시 여기에 기록됩니다.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: SelectableText(
                    entries.join('\n'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 10,
                      height: 1.25,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
