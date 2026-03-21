import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';

class PocketTranscriptFrame extends StatelessWidget {
  const PocketTranscriptFrame({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    this.maxWidth = 700,
    this.padding = PocketSpacing.cardPadding,
    this.radius = PocketRadii.lg,
    this.shadowOpacity = 0.06,
    this.blurRadius = 10,
    this.shadowOffset = const Offset(0, 6),
    this.boxShadow,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double shadowOpacity;
  final double blurRadius;
  final Offset shadowOffset;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: PocketPanelSurface(
        padding: padding,
        radius: radius,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        boxShadow:
            boxShadow ??
            <BoxShadow>[
              BoxShadow(
                color: shadowColor.withValues(alpha: shadowOpacity),
                blurRadius: blurRadius,
                offset: shadowOffset,
              ),
            ],
        child: child,
      ),
    );
  }
}
