import 'package:flutter/material.dart';

import '../app_colors.dart';

/// A card-like container with an embossed, raised 3D look: a soft
/// purple-tinted shadow toward the bottom-right and a light highlight
/// toward the top-left, giving surfaces a tactile, pressed-button feel.
///
/// Use this in place of a plain [Card] wherever the app shows a "box":
/// summary cards, info panels, list-item cards, and icon tiles.
class EmbossedBox extends StatelessWidget {
  const EmbossedBox({
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.color = AppColors.surface,
    this.margin,
    this.width,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFECEAF9), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.16),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            offset: const Offset(-4, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: padding != null
              ? Padding(padding: padding!, child: child)
              : child,
        ),
      ),
    );
  }
}
