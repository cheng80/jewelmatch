import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/utils/semantics_error_guard.dart';

void main() {
  testWidgets('접근성 탭 예외를 한 번 보고하고 후속 동작을 계속 전달한다', (tester) async {
    final semantics = tester.ensureSemantics();
    final dispatcher = tester.binding.platformDispatcher;
    final previousAction = dispatcher.onSemanticsActionEvent;
    final previousError = FlutterError.onError;
    addTearDown(() {
      dispatcher.onSemanticsActionEvent = previousAction;
      FlutterError.onError = previousError;
    });
    final errors = <FlutterErrorDetails>[];
    final failure = StateError('semantics callback failed');
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ElevatedButton(
              onPressed: () => throw failure,
              child: const Text('Throw'),
            ),
            ElevatedButton(
              onPressed: () => count++,
              child: const Text('Count'),
            ),
          ],
        ),
      ),
    );
    installSemanticsErrorGuard(tester.binding);
    void tap(String label) => dispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        viewId: tester.view.viewId,
        nodeId: tester.getSemantics(find.text(label)).id,
        type: ui.SemanticsAction.tap,
      ),
    );

    FlutterError.onError = errors.add;
    try {
      tap('Throw');
      tap('Count');
      tap('Count');
    } finally {
      FlutterError.onError = previousError;
      semantics.dispose();
    }
    expect(errors, hasLength(1));
    expect(errors.single.exception, same(failure));
    expect(errors.single.stack, isNotNull);
    expect(errors.single.silent, isFalse);
    expect(count, 2);
    expect(errors, hasLength(1));
  });

  testWidgets('접근성 이벤트와 인자를 원래 콜백에 그대로 한 번 전달한다', (tester) async {
    final dispatcher = tester.binding.platformDispatcher;
    final previous = dispatcher.onSemanticsActionEvent;
    addTearDown(() => dispatcher.onSemanticsActionEvent = previous);
    final received = <ui.SemanticsActionEvent>[];
    dispatcher.onSemanticsActionEvent = received.add;
    installSemanticsErrorGuard(tester.binding);
    final action = ui.SemanticsActionEvent(
      viewId: tester.view.viewId,
      nodeId: 42,
      type: ui.SemanticsAction.setText,
      arguments: 'unchanged',
    );
    dispatcher.onSemanticsActionEvent!(action);
    expect(received, hasLength(1));
    expect(received.single, same(action));
  });
}
