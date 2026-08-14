import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import 'app_config.dart';
import 'resources/sound_manager.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'vm/settings_notifier.dart';
import 'widgets/phone_frame_scaffold.dart';
import 'widgets/starry_background.dart';

/// 앱의 루트 위젯. 테마, 라우팅 등 앱 전체 설정을 담당한다.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showFps = ref.watch(settingsProvider.select((s) => s.showFps));
    final app = MaterialApp.router(
      title: AppConfig.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: buildAppTheme(),
      scrollBehavior: const _AppScrollBehavior(),
      routerConfig: appRouter,
    );

    Widget root = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameScale = math.min(
            constraints.maxWidth / kPhoneFrameRefW,
            constraints.maxHeight / kPhoneFrameRefH,
          );
          final frameWidth = kPhoneFrameRefW * frameScale;
          final sideSpace = (constraints.maxWidth - frameWidth) / 2;
          final placeOutsideFrame = sideSpace >= 140;

          return Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
              Positioned.fill(child: StarryBackground.instance),
              Positioned.fill(child: app),
              if (showFps || _fpsQueryRequested)
                Positioned(
                  left: placeOutsideFrame
                      ? (constraints.maxWidth + frameWidth) / 2 + 12
                      : null,
                  right: placeOutsideFrame ? null : 12,
                  bottom: 12,
                  child: const IgnorePointer(child: _FpsPanel()),
                ),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      root = Listener(
        onPointerDown: (_) => SoundManager.unlockForWeb(),
        behavior: HitTestBehavior.translucent,
        child: root,
      );
    }
    return root;
  }

  bool get _fpsQueryRequested {
    if (!kIsWeb) return false;
    final params = Uri.base.queryParameters;
    return params['fps'] == '1' || params['qaPerf'] == '1';
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

class _FpsPanel extends StatefulWidget {
  const _FpsPanel();

  @override
  State<_FpsPanel> createState() => _FpsPanelState();
}

class _FpsPanelState extends State<_FpsPanel> {
  final List<FrameTiming> _timings = <FrameTiming>[];
  double _fps = 0;
  double _frameMs = 0;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _registered) return;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _registered = true;
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;
    _timings.addAll(timings);
    if (_timings.length > 45) {
      _timings.removeRange(0, _timings.length - 45);
    }

    if (_timings.length < 2) return;

    var totalMicros = 0;
    for (final t in _timings) {
      totalMicros += t.totalSpan.inMicroseconds;
    }
    final firstVsync = _timings.first.timestampInMicroseconds(
      ui.FramePhase.vsyncStart,
    );
    final lastVsync = _timings.last.timestampInMicroseconds(
      ui.FramePhase.vsyncStart,
    );
    final elapsedMicros = lastVsync - firstVsync;
    if (totalMicros <= 0 || elapsedMicros <= 0) return;

    final avgMicros = totalMicros / _timings.length;
    final fps = (_timings.length - 1) * 1000000 / elapsedMicros;
    final frameMs = avgMicros / 1000;
    if ((fps - _fps).abs() < 0.2 && (frameMs - _frameMs).abs() < 0.2) {
      return;
    }
    setState(() {
      _fps = fps;
      _frameMs = frameMs;
    });
  }

  @override
  void dispose() {
    if (_registered) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = _fps > 0 && _fps < 50;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger
              ? Colors.redAccent.withValues(alpha: 0.9)
              : Colors.cyanAccent.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fps > 0 ? 'FPS ${_fps.toStringAsFixed(1)}' : 'FPS --'),
              const SizedBox(width: 8),
              Text(_frameMs > 0 ? '${_frameMs.toStringAsFixed(1)} ms' : '--'),
            ],
          ),
        ),
      ),
    );
  }
}
