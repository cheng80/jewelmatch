import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/game_settings.dart';
import '../../theme/jewel_candy_lumina_theme.dart';

Future<String?> showPlayerNameDialog(BuildContext context) async {
  final controller = TextEditingController(text: GameSettings.playerName);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final mediaQuery = MediaQuery.of(ctx);
      return MediaQuery(
        data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
        child: AlertDialog(
          backgroundColor: JewelCandyLuminaTheme.surfaceContainer.withValues(
            alpha: 0.97,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: JewelCandyLuminaTheme.borderPause,
              width: 2,
            ),
          ),
          title: Text(
            context.tr('enterName'),
            style: TextStyle(
              color: JewelCandyLuminaTheme.secondaryCyan,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              maxLength: 20,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20),
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
                    color: JewelCandyLuminaTheme.secondaryCyan,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                context.tr('cancel'),
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(
                context.tr('startGame'),
                style: TextStyle(
                  color: JewelCandyLuminaTheme.tertiaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (result == null) return null;
  return result.trim().isEmpty ? 'GUEST' : result.trim();
}
