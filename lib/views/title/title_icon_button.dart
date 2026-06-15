import 'package:flutter/material.dart';

import '../../resources/asset_paths.dart';

class TitleIconButton extends StatelessWidget {
  const TitleIconButton({
    required this.iconAssetPath,
    required this.semanticLabel,
    required this.onPressed,
    this.iconSizeFactor = 0.58,
    super.key,
  });

  static const double size = 54;

  final String iconAssetPath;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double iconSizeFactor;

  String get _frameAssetPath =>
      'assets/images/${AssetPaths.obsidianIconButtonFrame}';

  String get _iconAssetPath => iconAssetPath.startsWith('assets/')
      ? iconAssetPath
      : 'assets/images/$iconAssetPath';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onPressed,
            containedInkWell: true,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  _frameAssetPath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                Image.asset(
                  _iconAssetPath,
                  width: size * iconSizeFactor,
                  height: size * iconSizeFactor,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
