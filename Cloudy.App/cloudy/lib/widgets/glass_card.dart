import 'package:flutter/material.dart';

// Conditional import: on web `dart.library.html` resolves to the stub (no
// liquid_glass_renderer dependency, so its web-incompatible shaders are never
// bundled). On native it resolves to the real renderer implementation.
import 'glass_effect_stub.dart'
    if (dart.library.io) 'glass_effect_native.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color tintColor;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(16),
    this.tintColor = const Color(0x1AFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return buildGlass(
      content: content,
      borderRadius: borderRadius,
      tintColor: tintColor,
    );
  }
}
