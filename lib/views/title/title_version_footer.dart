import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/jewel_candy_lumina_theme.dart';

class TitleVersionFooter extends StatelessWidget {
  const TitleVersionFooter({required this.packageInfo, super.key});

  final PackageInfo? packageInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        packageInfo != null
            ? 'Ver ${packageInfo!.version}+${packageInfo!.buildNumber}'
            : 'Ver',
        style: TextStyle(
          color: JewelCandyLuminaTheme.outlineBright.withValues(alpha: 0.65),
          fontSize: 12,
        ),
      ),
    );
  }
}
