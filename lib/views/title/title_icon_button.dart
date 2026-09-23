import 'package:flutter/material.dart';

import '../../resources/texture_atlas.dart';
import '../../widgets/atlas_image.dart';

class TitleIconButton extends StatelessWidget {
  const TitleIconButton({
    required this.iconFrame,
    required this.semanticLabel,
    required this.onPressed,
    this.iconSizeFactor = 0.58,
    super.key,
  });

  static const double size = 54;

  /// `UiFrames` 칸 이름.
  final String iconFrame;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double iconSizeFactor;

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
                const AtlasImage(
                  UiFrames.iconButtonFrame,
                  width: size,
                  height: size,
                ),
                AtlasImage(
                  iconFrame,
                  width: size * iconSizeFactor,
                  height: size * iconSizeFactor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
