import 'package:flutter/material.dart';

import '../../resources/texture_atlas.dart';
import '../../widgets/atlas_image.dart';
import '../../widgets/overlay_motion.dart';
import '../../theme/jewel_candy_lumina_theme.dart';

/// 타이틀 전용 bitmap 레이어 버튼.
class TitleRoundButton extends StatefulWidget {
  const TitleRoundButton({
    required this.label,
    required this.panelColor,
    required this.iconFrame,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color panelColor;

  /// `UiFrames` 칸 이름.
  final String iconFrame;
  final VoidCallback onPressed;

  @override
  State<TitleRoundButton> createState() => _TitleRoundButtonState();
}

class _TitleRoundButtonState extends State<TitleRoundButton> {
  bool _pressed = false;
  static const double _width = 282;
  static const double _height = 77;
  static const double _fontSize = 25;
  static const double _iconSize = 35;
  static const double _iconLeft = 22;
  static const double _letterSpacing = 1.2;
  static const double _panelOpacity = 0.74;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      pressed: _pressed,
      child: SizedBox(
        width: _width,
        height: _height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    widget.panelColor.withValues(alpha: _panelOpacity),
                    BlendMode.modulate,
                  ),
                  child: const AtlasImage(
                    UiFrames.modeButtonPanelBase,
                    width: _width,
                    height: _height,
                    fit: BoxFit.fill,
                  ),
                ),
                const AtlasImage(
                  UiFrames.modeButtonFrameFront,
                  width: _width,
                  height: _height,
                  fit: BoxFit.fill,
                ),
                Positioned(
                  left: _iconLeft,
                  top: (_height - _iconSize) / 2,
                  child: AtlasImage(
                    widget.iconFrame,
                    width: _iconSize,
                    height: _iconSize,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 78, right: 19),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w900,
                      color: JewelCandyLuminaTheme.tertiaryGold,
                      letterSpacing: _letterSpacing,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.95),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                        Shadow(
                          color: JewelCandyLuminaTheme.goldStrong.withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TitleButtonPalette {
  const TitleButtonPalette._();

  static const Color teal = Color(0xFF1F8274);
  static const Color purple = Color(0xFF68468C);
  static const Color brown = Color(0xFF96522B);
  static const Color blue = Color(0xFF3969A0);
  static const Color charcoal = Color(0xFF484C46);
}
