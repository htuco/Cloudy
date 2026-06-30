import 'dart:ui';

import 'package:flutter/material.dart';

/// Web / unsupported-platform fallback. This implementation deliberately does
/// NOT import `liquid_glass_renderer`, so its (web-incompatible) shaders are
/// never bundled into the web build. Visually identical to the native fallback
/// branch: a plain backdrop blur.
Widget buildGlass({
  required Widget content,
  required double borderRadius,
  required Color tintColor,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tintColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: content,
      ),
    ),
  );
}
