import 'package:flutter/material.dart';

import '../resources/asset_paths.dart';
import '../theme/jewel_candy_lumina_theme.dart';
import 'obsidian_button_styles.dart';

class ObsidianFrame extends StatelessWidget {
  const ObsidianFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.backgroundColor,
    this.minFrameSize = 140,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double minFrameSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.72),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: JewelCandyLuminaTheme.goldStrong.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              JewelCandyLuminaTheme.surfaceContainer.withValues(alpha: 0.94),
          image: const DecorationImage(
            image: AssetImage(AssetPaths.obsidianPanelFrame),
            fit: BoxFit.fill,
            centerSlice: Rect.fromLTRB(58, 58, 334, 420),
            filterQuality: FilterQuality.high,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minFrameSize,
            minHeight: minFrameSize,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class ObsidianButtonFrame extends StatelessWidget {
  const ObsidianButtonFrame({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height = 58,
    this.padding = const EdgeInsets.symmetric(horizontal: 38),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ObsidianAntiqueButtonSurface(
        height: height,
        onPressed: onPressed,
        padding: padding,
        child: child,
      ),
    );
  }
}

class ObsidianTitleButtonFrame extends StatelessWidget {
  const ObsidianTitleButtonFrame({
    super.key,
    required this.child,
    required this.onPressed,
    this.width = 276,
    this.height = 58,
    this.padding = const EdgeInsets.symmetric(horizontal: 46),
  });

  final Widget child;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ObsidianAntiqueButtonSurface(
        height: height,
        onPressed: onPressed,
        padding: padding,
        child: child,
      ),
    );
  }
}
