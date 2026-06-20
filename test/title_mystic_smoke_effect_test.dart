import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/views/title/title_mystic_smoke_effect.dart';

void main() {
  testWidgets('mystic smoke effect renders and advances smoothly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 390,
          height: 750,
          child: TitleMysticSmokeEffect(),
        ),
      ),
    );

    expect(find.byType(TitleMysticSmokeEffect), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TitleMysticSmokeEffect),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('mystic smoke effect respects disabled animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 390,
            height: 750,
            child: TitleMysticSmokeEffect(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TitleMysticSmokeEffect), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
