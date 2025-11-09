import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable frosted-glass container used for BollyWord overlays.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.backgroundGradient,
    this.borderColor,
    this.elevationColor,
    this.blurAmount = 16,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final Gradient? backgroundGradient;
  final Color? borderColor;
  final Color? elevationColor;
  final double blurAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: elevationColor != null
            ? [
                BoxShadow(
                  color: elevationColor!,
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            decoration: BoxDecoration(
              gradient: backgroundGradient,
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.5)
                  : null,
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
