import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/game_settings.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/obsidian_frame.dart';
import '../../widgets/overlay_motion.dart';

Future<String?> showPlayerNameDialog(BuildContext context) async {
  final result = await showMotionDialog<String>(
    context: context,
    builder: (_) => const _PlayerNameDialog(),
  );
  if (result == null) return null;
  return result.trim().isEmpty ? 'GUEST' : result.trim();
}

class _PlayerNameDialog extends StatefulWidget {
  const _PlayerNameDialog();

  @override
  State<_PlayerNameDialog> createState() => _PlayerNameDialogState();
}

class _PlayerNameDialogState extends State<_PlayerNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: GameSettings.playerName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context, [String? value]) {
    Navigator.of(context).pop(value ?? _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // 키보드가 올라오면 Dialog가 viewInsets만큼 위로 비켜난다. 남은 높이보다 크면 안쪽이 스크롤된다.
    // (예전에는 viewInsets를 0으로 덮어써서 키보드가 취소와 시작 버튼을 가렸다.)
    final keyboard = mediaQuery.viewInsets.bottom;
    // 키보드가 떠 있으면 남은 높이가 좁으므로 위아래 여백을 줄여 버튼까지 한 화면에 들어오게 한다.
    final verticalInset = keyboard > 0 ? 12.0 : 52.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 28,
        vertical: verticalInset,
      ),
      child: OverlayEnterTransition(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: (mediaQuery.size.height - keyboard - verticalInset * 2)
                .clamp(160.0, double.infinity),
          ),
          child: ObsidianFrame(
            minFrameSize: 280,
            padding: const EdgeInsets.fromLTRB(58, 50, 58, 44),
            backgroundColor: JewelCandyLuminaTheme.surfaceContainer.withValues(
              alpha: 0.97,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('enterName'),
                    style: TextStyle(
                      color: JewelCandyLuminaTheme.textTitleGold,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controller,
                    maxLength: 20,
                    autofocus: true,
                    style: const TextStyle(
                      color: JewelCandyLuminaTheme.textHero,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      hintText: 'GUEST',
                      hintStyle: TextStyle(color: Colors.white38),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: JewelCandyLuminaTheme.tertiaryGold,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: JewelCandyLuminaTheme.focusTeal,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (value) => _submit(context, value),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: ObsidianButtonFrame(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.tr('cancel'),
                              style: TextStyle(
                                color: JewelCandyLuminaTheme.textMutedGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          child: ObsidianButtonFrame(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            onPressed: () => _submit(context),
                            child: Text(
                              context.tr('startGame'),
                              style: TextStyle(
                                color: JewelCandyLuminaTheme.tertiaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
