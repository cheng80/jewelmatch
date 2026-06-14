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
}
