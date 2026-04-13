import 'dart:math';

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
  });

  final Widget child;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final framedChild = Center(child: PhoneFrame(child: child));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: useSafeArea
          ? SafeArea(child: framedChild)
          : framedChild,
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
        final logicalChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: const Size(kPhoneFrameRefW, kPhoneFrameRefH),
          ),
          child: SizedBox(
            width: kPhoneFrameRefW,
            height: kPhoneFrameRefH,
            child: child,
          ),
        );
        final fittedScale = min(
          constraints.maxWidth / kPhoneFrameRefW,
          constraints.maxHeight / kPhoneFrameRefH,
        );
        final frameW = kPhoneFrameRefW * fittedScale;
        final frameH = kPhoneFrameRefH * fittedScale;

        return SizedBox(
          width: frameW,
          height: frameH,
          child: FittedBox(fit: BoxFit.contain, child: logicalChild),
        );
      },
    );
  }
}
