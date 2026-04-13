import 'dart:math';

import 'package:flutter/material.dart';

import 'starry_background.dart';

const double kPhoneFrameRefW = 390.0;
const double kPhoneFrameRefH = 750.0;

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          if (useSafeArea)
            SafeArea(child: framedChild)
          else
            Positioned.fill(child: framedChild),
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
