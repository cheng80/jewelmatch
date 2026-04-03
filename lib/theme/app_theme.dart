import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import 'jewel_candy_lumina_theme.dart';

/// 앱 전역 테마. 게임 [JewelCandyLuminaTheme]과 동일한 팔레트·폰트(HUAngduIpsul140)로 통일한다.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AssetPaths.fontAngduIpsul140,
    colorScheme: ColorScheme.dark(
      primary: JewelCandyLuminaTheme.primaryPink,
      onPrimary: Colors.white,
      primaryContainer: JewelCandyLuminaTheme.surfaceVariant,
      onPrimaryContainer: Colors.white,
      secondary: JewelCandyLuminaTheme.secondaryCyan,
      onSecondary: Colors.black,
      secondaryContainer: JewelCandyLuminaTheme.surfaceContainer,
      onSecondaryContainer: Colors.white,
      tertiary: JewelCandyLuminaTheme.tertiaryGold,
      surface: JewelCandyLuminaTheme.surface,
      onSurface: Colors.white,
      surfaceContainerHighest: JewelCandyLuminaTheme.surfaceContainer,
      error: const Color(0xFFFFB4AB),
      onError: Colors.black,
      outline: JewelCandyLuminaTheme.outlineBright,
    ),
    scaffoldBackgroundColor: JewelCandyLuminaTheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: JewelCandyLuminaTheme.surfaceContainer,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontFamily: AssetPaths.fontAngduIpsul140,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: JewelCandyLuminaTheme.surfaceVariant,
      contentTextStyle: const TextStyle(
        fontFamily: AssetPaths.fontAngduIpsul140,
        color: Colors.white,
        fontSize: 16,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: JewelCandyLuminaTheme.secondaryCyan,
      textColor: Colors.white.withValues(alpha: 0.95),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return JewelCandyLuminaTheme.secondaryCyan;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return JewelCandyLuminaTheme.secondaryCyan.withValues(alpha: 0.45);
        }
        return Colors.white24;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: JewelCandyLuminaTheme.secondaryCyan,
      inactiveTrackColor: Colors.white24,
      thumbColor: JewelCandyLuminaTheme.primaryPink,
      overlayColor: WidgetStateColor.resolveWith(
        (states) => JewelCandyLuminaTheme.primaryPink.withValues(alpha: 0.2),
      ),
    ),
  );
}
