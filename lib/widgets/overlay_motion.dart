import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/jewel_candy_lumina_theme.dart';

/// 화면과 오버레이 연출 공용 조각 (PLAN-004 T4b).
///
/// 규칙
/// - `MediaQuery.disableAnimationsOf`가 켜져 있으면 연출을 건너뛰고 최종 상태를 바로 보여 준다.
/// - 넓은 `Opacity`, `BackdropFilter`, `ShaderMask`를 쓰지 않는다.
///   `ScaleTransition`, `FadeTransition`, `SlideTransition`만 쓴다.
/// - 움직이는 영역은 `RepaintBoundary`로 격리한다.
/// - 모든 전환은 유한하다. 무한 반복이 없어 `pumpAndSettle`이 끝난다.

/// 오버레이 카드 공통 등장 전환 (짧은 스케일 + 페이드, 선택적으로 슬라이드).
///
/// [LuminaOverlayCard]가 이미 이 전환을 두르고 있다. 그 카드를 쓰는 오버레이는
/// 따로 감쌀 필요가 없다. 카드를 쓰지 않는 곳(다이얼로그, 결과 배너)에서만 직접 쓴다.
class OverlayEnterTransition extends StatefulWidget {
  const OverlayEnterTransition({
    super.key,
    required this.child,
    this.slideFrom = Offset.zero,
    this.duration = const Duration(milliseconds: 240),
    this.beginScale = 0.9,
  });

  final Widget child;

  /// 시작 위치. 자식 크기 대비 비율이다. `Offset(0, 0.12)`이면 아래에서 올라온다.
  final Offset slideFrom;

  final Duration duration;
  final double beginScale;

  @override
  State<OverlayEnterTransition> createState() => _OverlayEnterTransitionState();
}

class _OverlayEnterTransitionState extends State<OverlayEnterTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  late final Animation<double> _scale = Tween<double>(
    begin: widget.beginScale,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.slideFrom,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  final GlobalKey _paintKey = GlobalKey();
  bool _exiting = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (_DialogMotionScope.maybeOf(context) != null) return;
    if (_started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialog = _DialogMotionScope.maybeOf(context);
    if (dialog != null) {
      final animation = MediaQuery.disableAnimationsOf(context)
          ? const AlwaysStoppedAnimation<double>(1)
          : dialog.animation;
      return RepaintBoundary(
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
            child: widget.child,
          ),
        ),
      );
    }
    return RepaintBoundary(
      key: _paintKey,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(scale: _scale, child: widget.child),
        ),
      ),
    );
  }
}

/// 목록 항목을 순서대로 하나씩 등장시킨다. [index]만큼 시작이 밀린다.
///
/// 타이머 없이 컨트롤러 하나의 [Interval]로 지연을 만든다.
class StaggerReveal extends StatefulWidget {
  const StaggerReveal({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 240),
    this.slideFrom = const Offset(0, 0.3),
  });

  final int index;
  final Widget child;

  /// 항목 사이 간격.
  final Duration step;

  /// 항목 하나가 등장하는 데 걸리는 시간.
  final Duration duration;
  final Offset slideFrom;

  @override
  State<StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<StaggerReveal>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = widget.step * widget.index;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMicroseconds / (_delay + widget.duration).inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.slideFrom,
    end: Offset.zero,
  ).animate(_curve);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

/// 누르는 동안 살짝 눌리는 스케일. 누름 상태는 호출부가 가진다.
class PressScale extends StatelessWidget {
  const PressScale({
    super.key,
    required this.pressed,
    required this.child,
    this.scale = 0.94,
  });

  final bool pressed;
  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed && !MediaQuery.disableAnimationsOf(context) ? scale : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: RepaintBoundary(child: child),
    );
  }
}

/// 광고 보상 결과처럼 성공과 실패를 한눈에 구분해야 하는 짧은 메시지.
///
/// 메시지가 바뀔 때 다시 등장시키려면 호출부에서 `key: ValueKey(message)`를 준다.
class AdResultBanner extends StatelessWidget {
  const AdResultBanner({
    super.key,
    required this.success,
    required this.message,
    this.fontSize = 12,
  });

  final bool success;
  final String message;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? JewelCandyLuminaTheme.focusTeal
        : JewelCandyLuminaTheme.dangerRed;
    return OverlayEnterTransition(
      beginScale: 0.82,
      duration: const Duration(milliseconds: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            size: fontSize + 5,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: success
                    ? JewelCandyLuminaTheme.textParchment
                    : JewelCandyLuminaTheme.textMutedGold,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드의 마지막 프레임만 160ms 남긴다. 게임 콜백과 입력은 기다리지 않는다.
/// 상태를 가진 오버레이를 복제하지 않아 광고, 제출, 타이머가 재실행되지 않는다.
void runOverlayExit(BuildContext context, VoidCallback action) {
  _OverlayEnterTransitionState? motion;
  void visit(Element element) {
    if (motion != null) return;
    if (element is StatefulElement &&
        element.state is _OverlayEnterTransitionState) {
      motion = element.state as _OverlayEnterTransitionState;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  if (motion?._exiting ?? false) return;
  if (motion != null) motion!._exiting = true;
  // Dialog routes already reverse their card transition; do not add a ghost.
  if (_DialogMotionScope.maybeOf(context) == null) {
    try {
      _showOverlayExit(context, motion);
    } catch (error) {
      // A renderer may reject a snapshot. Decoration must never block the action.
      debugPrint('Overlay exit snapshot unavailable: $error');
    }
  }
  try {
    action();
  } catch (_) {
    // Failed actions must remain retryable even before the next frame.
    if (motion != null) motion!._exiting = false;
    rethrow;
  }
  // Some callers retain the card. Deduplicate only the current frame, rather
  // than permanently disabling a still-mounted screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (motion?.mounted ?? false) motion!._exiting = false;
  });
  WidgetsBinding.instance.scheduleFrame();
}

void _showOverlayExit(
  BuildContext context,
  _OverlayEnterTransitionState? motion,
) {
  if (!MediaQuery.disableAnimationsOf(context)) {
    final boundary = motion?._paintKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (boundary is RenderRepaintBoundary &&
        boundary.hasSize &&
        overlay != null) {
      // debugNeedsPaint throws without assertions; keep this check debug-only.
      var needsPaint = false;
      assert(() {
        needsPaint = boundary.debugNeedsPaint;
        return true;
      }());
      if (needsPaint) return;
      final origin = boundary.localToGlobal(
        Offset.zero,
        ancestor: overlay.context.findRenderObject(),
      );
      final corner = boundary.localToGlobal(
        boundary.size.bottomRight(Offset.zero),
        ancestor: overlay.context.findRenderObject(),
      );
      final size = Size(corner.dx - origin.dx, corner.dy - origin.dy);
      final image = boundary.toImageSync(pixelRatio: 1);
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => Positioned(
          left: origin.dx,
          top: origin.dy,
          width: size.width,
          height: size.height,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: _ExitFrame(
                image: image,
                onDone: () {
                  entry.remove();
                  entry.dispose();
                },
              ),
            ),
          ),
        ),
      );
      overlay.insert(entry);
    }
  }
}

class _ExitFrame extends StatefulWidget {
  const _ExitFrame({required this.image, required this.onDone});
  final ui.Image image;
  final VoidCallback onDone;
  @override
  State<_ExitFrame> createState() => _ExitFrameState();
}

class _ExitFrameState extends State<_ExitFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 160),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(
      opacity: ReverseAnimation(_controller),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.94).animate(_controller),
        child: RawImage(image: widget.image),
      ),
    ),
  );
}

/// 이어하기 성공은 결과 화면이 즉시 닫힌 뒤에도 작은 체크 표시로 남긴다.
void showAdSuccessFeedback(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final top = MediaQuery.paddingOf(context).top + 24;
  final media = MediaQuery.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: JewelCandyLuminaTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: MediaQuery(
                data: media,
                child: AdResultBanner(success: true, message: message),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 900), () {
    entry.remove();
    entry.dispose();
  });
}

/// Supplies a route animation to the bounded card, leaving the scrim static.
class _DialogMotionScope extends InheritedWidget {
  const _DialogMotionScope({required this.animation, required super.child});
  final Animation<double> animation;

  static _DialogMotionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DialogMotionScope>();

  @override
  bool updateShouldNotify(_DialogMotionScope oldWidget) =>
      animation != oldWidget.animation;
}

/// The builder's card must use OverlayEnterTransition (LuminaOverlayCard does).
Future<T?> showMotionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: reduced
        ? Duration.zero
        : const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced || MediaQuery.disableAnimationsOf(context),
      ),
      child: _DialogMotionScope(animation: animation, child: child),
    ),
  );
}
