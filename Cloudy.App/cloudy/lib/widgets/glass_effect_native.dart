import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Native implementation. Uses the real liquid glass renderer on platforms
/// whose shaders compile (Android/iOS/macOS) and a backdrop-blur fallback on
/// desktop platforms where the renderer is unsupported.
Widget buildGlass({
  required Widget content,
  required double borderRadius,
  required Color tintColor,
}) {
  if (_useFallback) {
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

  return LiquidGlass.withOwnLayer(
    settings: LiquidGlassSettings(
      blur: 10,
      thickness: 10,
      glassColor: tintColor,
      lightIntensity: 1.2,
      ambientStrength: 0.08,
      saturation: 1.0,
    ),
    shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
    child: content,
  );
}

bool get _useFallback {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return false;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return true;
  }
}
