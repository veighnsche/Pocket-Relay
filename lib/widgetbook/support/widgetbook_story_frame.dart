import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

class WidgetbookStoryFrame extends StatelessWidget {
  const WidgetbookStoryFrame.card({
    super.key,
    required this.child,
    this.maxWidth = 860,
    this.alignment = Alignment.centerLeft,
    this.fillHeight = false,
  });

  const WidgetbookStoryFrame.fill({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.center,
    this.fillHeight = true,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[palette.backgroundTop, palette.backgroundBottom],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Align(
              alignment: alignment,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? constraints.maxWidth,
                ),
                child: child,
              ),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: fillHeight ? constraints.maxHeight - 48 : 0,
                ),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}
