import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_config.dart';
import 'resources/sound_manager.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'widgets/starry_background.dart';

/// 앱의 루트 위젯. 테마, 라우팅 등 앱 전체 설정을 담당한다.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
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
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Positioned.fill(child: StarryBackground.instance),
          Positioned.fill(child: app),
          if (kDebugMode)
            Positioned(
              top: 12,
              right: 12,
              child: IgnorePointer(
                child: _DebugFpsPanel(),
              ),
            ),
        ],
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

class _DebugFpsPanel extends StatefulWidget {
  const _DebugFpsPanel();

  @override
  State<_DebugFpsPanel> createState() => _DebugFpsPanelState();
}

class _DebugFpsPanelState extends State<_DebugFpsPanel> {
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

    var totalMicros = 0;
    for (final t in _timings) {
      totalMicros += t.totalSpan.inMicroseconds;
    }
    if (totalMicros <= 0) return;

    final avgMicros = totalMicros / _timings.length;
    final fps = 1000000 / avgMicros;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('DEBUG FPS'),
              const SizedBox(height: 4),
              Text(_fps > 0 ? '${_fps.toStringAsFixed(1)} fps' : 'measuring...'),
              Text(_frameMs > 0 ? '${_frameMs.toStringAsFixed(1)} ms' : '--'),
            ],
          ),
        ),
      ),
    );
  }
}
