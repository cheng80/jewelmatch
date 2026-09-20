import 'package:flutter/material.dart';

import '../../game/jewel_game_mode.dart';
import '../../resources/asset_paths.dart';
import '../../theme/jewel_candy_lumina_theme.dart';
import '../../widgets/sprite_sheet_frame.dart';

class GameLoadingOverlay extends StatefulWidget {
  const GameLoadingOverlay({super.key, required this.gameMode});

  final JewelGameMode gameMode;

  @override
  State<GameLoadingOverlay> createState() => _GameLoadingOverlayState();
}

class _GameLoadingOverlayState extends State<GameLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    // 로딩 해제는 1.2초를 넘길 수 있다. 끝날 때까지 움직여야 먹통으로 보이지 않는다.
    // 동작 줄이기에서만 정지 상태로 둔다.
    if (_reduced) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.gameMode == JewelGameMode.timed
        ? JewelCandyLuminaTheme.goldStrong
        : JewelCandyLuminaTheme.focusTeal;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: JewelCandyLuminaTheme.surfaceContainer.withValues(
              alpha: 0.9,
            ),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: accent.withValues(alpha: 0.8),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _loadingGem(0, 0.0),
                        const SizedBox(width: 10),
                        _loadingGem(3, 0.33),
                        const SizedBox(width: 10),
                        _loadingGem(6, 0.66),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 34,
                  height: 34,
                  // 동작 줄이기에서는 값이 있는 인디케이터라 돌지 않는다.
                  child: CircularProgressIndicator(
                    value: _reduced ? 1 : null,
                    strokeWidth: 3,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '불러오는 중...',
                  style: TextStyle(
                    color: JewelCandyLuminaTheme.textHero.withValues(
                      alpha: 0.9,
                    ),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadingGem(int frameIndex, double phaseOffset) {
    final t = (_controller.value + phaseOffset) % 1.0;
    final pulse = 0.35 + 0.65 * (0.5 + 0.5 * (1 - (t * 2 - 1).abs()));
    final scale = 0.9 + pulse * 0.18;
    return Transform.scale(
      scale: scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.12 * pulse),
              blurRadius: 14,
            ),
          ],
        ),
        child: SpriteSheetFrame(
          assetPath: 'assets/images/${AssetPaths.jewelSpriteSheet}',
          frameIndex: frameIndex,
          frameSize: 128,
          size: 46,
          opacity: pulse.clamp(0.45, 1.0),
        ),
      ),
    );
  }
}
