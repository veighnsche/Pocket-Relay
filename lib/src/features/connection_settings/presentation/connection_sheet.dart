import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

class ConnectionSheet extends StatelessWidget {
  const ConnectionSheet({
    super.key,
    required this.platformBehavior,
    required this.viewModel,
    required this.actions,
  });

  final PocketPlatformBehavior platformBehavior;
  final ConnectionSettingsHostViewModel viewModel;
  final ConnectionSettingsHostActions actions;

  @override
  Widget build(BuildContext context) {
    return ConnectionSettingsSheetSurface(
      isDesktopPresentation: platformBehavior.isDesktopExperience,
      viewModel: viewModel,
      actions: actions,
    );
  }
}
