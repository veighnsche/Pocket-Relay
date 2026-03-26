import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';

part 'chat_empty_state_body_desktop.dart';
part 'chat_empty_state_body_mobile.dart';
part 'chat_empty_state_body_support.dart';

class ChatEmptyStateBody extends StatelessWidget {
  const ChatEmptyStateBody({
    super.key,
    required this.isConfigured,
    required this.connectionMode,
    required this.platformBehavior,
    required this.onConfigure,
    this.onSelectConnectionMode,
    this.supplementalContent,
  });

  final bool isConfigured;
  final ConnectionMode connectionMode;
  final PocketPlatformBehavior platformBehavior;
  final VoidCallback onConfigure;
  final ValueChanged<ConnectionMode>? onSelectConnectionMode;
  final Widget? supplementalContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = platformBehavior.isDesktopExperience;
        final maxWidth = isDesktop ? 820.0 : 640.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 24,
            vertical: isDesktop ? 28 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isDesktop
                    ? _buildDesktopShell(context, constraints.maxWidth)
                    : _buildMobileShell(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
