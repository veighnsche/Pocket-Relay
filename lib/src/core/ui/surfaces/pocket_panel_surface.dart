import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';

class PocketPanelSurface extends StatelessWidget {
  const PocketPanelSurface({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.padding = EdgeInsets.zero,
    this.radius = PocketRadii.lg,
    this.gradient,
    this.boxShadow = const <BoxShadow>[],
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: PocketRadii.circular(radius),
        border: Border.all(color: borderColor),
        gradient: gradient,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
