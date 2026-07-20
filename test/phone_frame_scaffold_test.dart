import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonematch/widgets/phone_frame_scaffold.dart';

void main() {
  testWidgets('Android portrait fills the available height', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Size? logicalSize;
    EdgeInsets? logicalPadding;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(384, 832),
          padding: EdgeInsets.only(top: 28, bottom: 48),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PhoneFrame(
            child: Builder(
              builder: (context) {
                logicalSize = MediaQuery.sizeOf(context);
                logicalPadding = MediaQuery.paddingOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = null;

    expect(logicalSize, const Size(390, 845));
    expect(logicalPadding!.top, closeTo(28.4375, 0.001));
    expect(logicalPadding!.bottom, closeTo(48.75, 0.001));
  });

  testWidgets('non-Android portrait keeps the reference frame', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Size? logicalSize;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PhoneFrame(
          child: Builder(
            builder: (context) {
              logicalSize = MediaQuery.sizeOf(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    debugDefaultTargetPlatformOverride = null;

    expect(logicalSize, const Size(kPhoneFrameRefW, kPhoneFrameRefH));
  });
}
