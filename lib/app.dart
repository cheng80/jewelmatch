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
import 'services/game_settings.dart';
import 'services/wakelock_service.dart';
import 'theme/app_theme.dart';
import 'vm/settings_notifier.dart';
import 'widgets/phone_frame_scaffold.dart';
import 'widgets/starry_background.dart';

const bool _qaPerfAutorun = bool.fromEnvironment('QA_PERF_AUTORUN');
const String _qaPerfLabel = String.fromEnvironment('QA_PERF_LABEL');

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
              if (showFps || _fpsQueryRequested || _qaPerfAutorun)
                Positioned(
                  left: placeOutsideFrame
                      ? (constraints.maxWidth + frameWidth) / 2 + 12
                      : null,
                  right: placeOutsideFrame ? null : 12,
                  bottom: placeOutsideFrame ? 12 : 112,
                  child: const IgnorePointer(child: _FpsPanel()),
                ),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      root = Listener(
        onPointerDown: (_) {
          SoundManager.unlockForWeb();
          WakelockService.apply(GameSettings.keepScreenOn);
        },
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

class FpsWindowStats {
  FpsWindowStats({this.windowMicros = 30000000});

  final int windowMicros;
  final List<_FpsWindowSample> _samples = <_FpsWindowSample>[];

  void add({
    required int atMicros,
    required int frames,
    required int elapsedMicros,
    required double maxGapMs,
  }) {
    if (frames <= 0 || elapsedMicros <= 0) return;
    _samples.add(_FpsWindowSample(atMicros, frames, elapsedMicros, maxGapMs));
    final cutoff = atMicros - windowMicros;
    while (_samples.isNotEmpty && _samples.first.atMicros < cutoff) {
      _samples.removeAt(0);
    }
  }

  double get averageFps {
    var frames = 0;
    var elapsedMicros = 0;
    for (final sample in _samples) {
      frames += sample.frames;
      elapsedMicros += sample.elapsedMicros;
    }
    return elapsedMicros == 0 ? 0 : frames * 1000000 / elapsedMicros;
  }

  double get lowFps => _samples.isEmpty
      ? 0
      : _samples.map((sample) => sample.fps).reduce(math.min);

  double get maxGapMs => _samples.isEmpty
      ? 0
      : _samples.map((sample) => sample.maxGapMs).reduce(math.max);
}

class _FpsWindowSample {
  const _FpsWindowSample(
    this.atMicros,
    this.frames,
    this.elapsedMicros,
    this.maxGapMs,
  );

  final int atMicros;
  final int frames;
  final int elapsedMicros;
  final double maxGapMs;

  double get fps => frames * 1000000 / elapsedMicros;
}

class _FpsPanel extends StatefulWidget {
  const _FpsPanel();

  @override
  State<_FpsPanel> createState() => _FpsPanelState();
}

class _FpsPanelState extends State<_FpsPanel>
    with SingleTickerProviderStateMixin {
  final List<FrameTiming> _timings = <FrameTiming>[];
  final FpsWindowStats _windowStats = FpsWindowStats();
  late final Ticker _ticker;
  double _fps = 0;
  double _frameMs = 0;
  int? _sampleStartedAt;
  int? _previousTickAt;
  int _sampleFrames = 0;
  double _sampleMaxGapMs = 0;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _registered) return;
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _registered = true;
    });
  }

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds;
    final previousTickAt = _previousTickAt;
    _previousTickAt = now;
    if (previousTickAt != null) {
      _sampleMaxGapMs = math.max(
        _sampleMaxGapMs,
        (now - previousTickAt) / 1000,
      );
    }

    final startedAt = _sampleStartedAt;
    if (startedAt == null) {
      _sampleStartedAt = now;
      return;
    }
    _sampleFrames += 1;
    final elapsedMicros = now - startedAt;
    if (elapsedMicros < 500000) return;

    final fps = _sampleFrames * 1000000 / elapsedMicros;
    _windowStats.add(
      atMicros: now,
      frames: _sampleFrames,
      elapsedMicros: elapsedMicros,
      maxGapMs: _sampleMaxGapMs,
    );
    _sampleStartedAt = now;
    _sampleFrames = 0;
    _sampleMaxGapMs = 0;
    setState(() => _fps = fps);
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
    final frameMs = avgMicros / 1000;
    if ((frameMs - _frameMs).abs() < 0.2) return;
    setState(() => _frameMs = frameMs);
  }

  @override
  void dispose() {
    _ticker.dispose();
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
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_qaPerfLabel.isNotEmpty) ...[
                    Text(_qaPerfLabel),
                    const SizedBox(width: 8),
                  ],
                  Text(_fps > 0 ? 'FPS ${_fps.toStringAsFixed(1)}' : 'FPS --'),
                  const SizedBox(width: 8),
                  Text(
                    _frameMs > 0 ? '${_frameMs.toStringAsFixed(1)} ms' : '--',
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _windowStats.averageFps > 0
                    ? '30s AVG ${_windowStats.averageFps.toStringAsFixed(1)}  '
                          'LOW ${_windowStats.lowFps.toStringAsFixed(1)}  '
                          'GAP ${_windowStats.maxGapMs.toStringAsFixed(0)} ms'
                    : '30s AVG --  LOW --  GAP --',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
