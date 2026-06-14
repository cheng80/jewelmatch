import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jewelmatch/views/title/title_round_button.dart';
import 'package:jewelmatch/widgets/obsidian_frame.dart';

void main() {
  testWidgets('standard button frame paints at compact overlay height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ObsidianButtonFrame(
              width: 240,
              height: 52,
              onPressed: () {},
              child: const Text('계속하기'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('title button frame paints at its default height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TitleRoundButton(
              label: '무한',
              gradientColors: const [Colors.black, Colors.black],
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('button frame paints at narrow dialog width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ObsidianButtonFrame(
              width: 120,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () {},
              child: const Text('취소'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('button frame paints at low heights', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final height in <double>[36, 44, 50, 52, 58])
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ObsidianButtonFrame(
                      width: 180,
                      height: height,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () {},
                      child: Text('H${height.toInt()}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
