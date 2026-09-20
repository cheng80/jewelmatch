import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/resources/asset_paths.dart';
import 'package:stonematch/views/title/title_round_button.dart';
import 'package:stonematch/widgets/overlay_motion.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  for (final reduced in [false, true]) {
    testWidgets('card and stagger settle, reduced=$reduced', (tester) async {
      await tester.pumpWidget(
        host(
          const OverlayEnterTransition(
            slideFrom: Offset(0, .12),
            child: StaggerReveal(index: 3, child: Text('content')),
          ),
          reduced: reduced,
        ),
      );
      final fades = find.descendant(
        of: find.byType(OverlayEnterTransition),
        matching: find.byType(FadeTransition),
      );
      expect(
        tester
            .widgetList<FadeTransition>(fades)
            .every((w) => w.opacity.value == 1),
        reduced,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<FadeTransition>(fades)
            .every((w) => w.opacity.value == 1),
        isTrue,
      );
      expect(
        tester
            .widget<ScaleTransition>(
              find.descendant(
                of: find.byType(OverlayEnterTransition),
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value,
        1,
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets(
      'title press cancel restores scale without action, reduced=$reduced',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          host(
            TitleRoundButton(
              label: 'play',
              panelColor: Colors.teal,
              iconAssetPath: AssetPaths.modeIconSimple,
              onPressed: () => calls++,
            ),
            reduced: reduced,
          ),
        );
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('play')),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          reduced ? 1 : .94,
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
        await tester.tap(find.text('play'));
        await tester.pumpAndSettle();
        expect(calls, 1);
      },
    );

    testWidgets(
      'exit action is immediate and ghost does not block input, reduced=$reduced',
      (tester) async {
        var calls = 0;
        var taps = 0;
        var visible = true;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) => Stack(
                alignment: Alignment.center,
                children: [
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('underneath'),
                  ),
                  if (visible)
                    OverlayEnterTransition(
                      child: TextButton(
                        onPressed: () => runOverlayExit(context, () {
                          calls++;
                          setState(() => visible = false);
                        }),
                        child: const Text('close'),
                      ),
                    ),
                ],
              ),
            ),
            reduced: reduced,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('close'));
        expect(calls, 1);
        await tester.pump();
        expect(find.byType(RawImage), reduced ? findsNothing : findsOneWidget);
        await tester.tap(find.text('underneath'));
        expect(taps, 1);
        await tester.pumpAndSettle();
        expect(find.byType(RawImage), findsNothing);
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('dialog reverse completes once, reduced=$reduced', (
      tester,
    ) async {
      var completions = 0;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              child: const Text('open'),
              onPressed: () async {
                final result = await showMotionDialog<int>(
                  context: context,
                  builder: (context) => Center(
                    child: Material(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, 7),
                        child: const Text('done'),
                      ),
                    ),
                  ),
                );
                expect(result, 7);
                completions++;
              },
            ),
          ),
          reduced: reduced,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.text('done'), findsNothing);
      expect(completions, 1);
    });
  }

  testWidgets('changing reduced motion during entry finishes all transitions', (
    tester,
  ) async {
    Widget content(bool reduced) => host(
      const OverlayEnterTransition(
        child: StaggerReveal(index: 4, child: Text('content')),
      ),
      reduced: reduced,
    );
    await tester.pumpWidget(content(false));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(content(true));
    expect(
      tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(OverlayEnterTransition),
              matching: find.byType(FadeTransition),
            ),
          )
          .every((w) => w.opacity.value == 1),
      isTrue,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('stagger reveals first reward before later reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            StaggerReveal(index: 0, child: Text('first')),
            StaggerReveal(index: 3, child: Text('last')),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final values = tester
        .widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(StaggerReveal),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((w) => w.opacity.value)
        .toList();
    expect(values.first, greaterThan(0));
    expect(values.last, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('two close taps in the same frame execute the action only once', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => OverlayEnterTransition(
            child: TextButton(
              onPressed: () => runOverlayExit(context, () => calls++),
              child: const Text('close'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    await tester.tap(find.text('close'));
    expect(calls, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('exit can retry after an action throws or retains the card', (
    tester,
  ) async {
    var calls = 0;
    Object? error;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => OverlayEnterTransition(
            child: TextButton(
              onPressed: () {
                try {
                  runOverlayExit(context, () {
                    calls++;
                    if (calls == 1) throw StateError('action failed');
                  });
                } catch (caught) {
                  error = caught;
                }
              },
              child: const Text('close'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    expect(error, isA<StateError>());
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    expect(calls, 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    expect(calls, 3);
    await tester.pumpAndSettle();
  });

  testWidgets('feedback can be removed before its entry is first built', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAdSuccessFeedback(context, 'reward'),
            child: const Text('reward'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('reward'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('snapshot failure still runs the action and permits retry', (
    tester,
  ) async {
    late BuildContext exitContext;
    var calls = 0;
    final messages = <String?>[];
    final originalDebugPrint = debugPrint;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            exitContext = context;
            return const OverlayEnterTransition(child: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    debugPrint = (message, {wrapWidth}) => messages.add(message);
    try {
      // A painted zero-size boundary cannot produce an image.
      runOverlayExit(exitContext, () => calls++);
      expect(calls, 1);
      expect(
        messages.any(
          (message) =>
              message?.contains('Overlay exit snapshot unavailable:') ?? false,
        ),
        isTrue,
      );
      await tester.pump();
      expect(find.byType(RawImage), findsNothing);
      runOverlayExit(exitContext, () => calls++);
      expect(calls, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  testWidgets('feedback survives source route removal and expires once', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      showAdSuccessFeedback(context, 'granted');
                      Navigator.of(context).pop();
                    },
                    child: const Text('finish'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('finish'));
    await tester.pumpAndSettle();
    expect(find.text('finish'), findsNothing);
    expect(find.text('granted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('granted'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exit snapshot follows a scaled phone frame', (tester) async {
    var visible = true;
    await tester.pumpWidget(
      host(
        Transform.scale(
          scale: 1.2,
          child: StatefulBuilder(
            builder: (context, setState) => visible
                ? OverlayEnterTransition(
                    child: SizedBox(
                      width: 100,
                      height: 60,
                      child: TextButton(
                        onPressed: () => runOverlayExit(
                          context,
                          () => setState(() => visible = false),
                        ),
                        child: const Text('close'),
                      ),
                    ),
                  )
                : const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byType(TextButton);
    final origin = tester.getTopLeft(button);
    await tester.tap(find.text('close'));
    await tester.pump();
    final ghost = find.byType(RawImage);
    expect(tester.getTopLeft(ghost), origin);
    expect(tester.getSize(ghost), const Size(120, 72));
    await tester.pumpAndSettle();
    expect(ghost, findsNothing);
  });

  testWidgets('feedback and exit survive immediate root disposal', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => OverlayEnterTransition(
            child: TextButton(
              onPressed: () {
                showAdSuccessFeedback(context, 'reward');
                runOverlayExit(context, () {});
              },
              child: const Text('close'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('close'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
