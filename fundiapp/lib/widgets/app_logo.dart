// lib/widgets/app_logo.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool forceLight; // true = always white logo (for dark bg)
  final bool forceDark;  // true = always dark logo (for light bg)

  const AppLogo({
    super.key,
    this.size = 100,
    this.forceLight = false,
    this.forceDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkBg = forceLight ||
        (!forceDark && Theme.of(context).brightness == Brightness.dark);

    // Light SVG on dark bg, dark SVG on light bg
    final asset = isDarkBg
        ? 'assets/icons/nearbyfundi-logo.svg'
        : 'assets/icons/nearbyfundi-logo-dark.svg';

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}