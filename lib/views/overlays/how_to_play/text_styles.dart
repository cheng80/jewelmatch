import 'package:flutter/material.dart';

import '../../../theme/jewel_candy_lumina_theme.dart';

class HowToPlaySectionTitle extends StatelessWidget {
  const HowToPlaySectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: JewelCandyLuminaTheme.tertiaryGold,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class HowToPlayBodyText extends StatelessWidget {
  const HowToPlayBodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
