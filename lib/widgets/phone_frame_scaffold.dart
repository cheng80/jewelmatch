import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kPhoneFrameRefW = 390.0;
const double kPhoneFrameRefH = 750.0;

/// 고정 비율 프레임 래퍼. StarryBackground는 App 레벨에서 1개만 관리하므로
/// 여기서는 Scaffold 배경을 투명으로 두어 앱 배경이 비쳐 보이게 한다.
class PhoneFrameScaffold extends StatelessWidget {
  const PhoneFrameScaffold({
    super.key,
    required this.child,
    this.useSafeArea = true,
    this.backgroundOverlay,
  });

  final Widget child;
  final bool useSafeArea;
  final Widget? backgroundOverlay;

  @override
  Widget build(BuildContext context) {
    final framedChild = Center(child: PhoneFrame(child: child));
    final frame = useSafeArea ? SafeArea(child: framedChild) : framedChild;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: backgroundOverlay == null
          ? frame
          : Stack(
              children: [
                Positioned.fill(child: backgroundOverlay!),
                Positioned.fill(child: frame),
              ],
            ),
    );
  }
}

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthScale = constraints.maxWidth / kPhoneFrameRefW;
        final heightScale = constraints.maxHeight / kPhoneFrameRefH;
        final isAndroidPortrait =
            !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.android &&
            constraints.maxHeight > constraints.maxWidth;
        final fillsExtraPortraitHeight =
            isAndroidPortrait && widthScale < heightScale;
        final fittedScale = min(widthScale, heightScale);
        final logicalHeight = fillsExtraPortraitHeight
            ? constraints.maxHeight / widthScale
            : kPhoneFrameRefH;
        final sourceMediaQuery = MediaQuery.of(context);
        final logicalPaddingScale = fillsExtraPortraitHeight
            ? 1 / fittedScale
            : 1.0;
        final logicalChild = MediaQuery(
          data: sourceMediaQuery.copyWith(
            size: Size(kPhoneFrameRefW, logicalHeight),
            padding: sourceMediaQuery.padding * logicalPaddingScale,
            viewPadding: sourceMediaQuery.viewPadding * logicalPaddingScale,
            viewInsets: sourceMediaQuery.viewInsets * logicalPaddingScale,
            systemGestureInsets:
                sourceMediaQuery.systemGestureInsets * logicalPaddingScale,
          ),
          child: SizedBox(
            width: kPhoneFrameRefW,
            height: logicalHeight,
            child: child,
          ),
        );
        final frameW = kPhoneFrameRefW * fittedScale;
        final frameH = logicalHeight * fittedScale;

        return SizedBox(
          width: frameW,
          height: frameH,
          child: FittedBox(fit: BoxFit.contain, child: logicalChild),
        );
      },
    );
  }
}
