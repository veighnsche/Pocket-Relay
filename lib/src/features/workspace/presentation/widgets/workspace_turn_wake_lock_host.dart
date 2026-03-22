import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';

class WorkspaceTurnWakeLockHost extends StatelessWidget {
  const WorkspaceTurnWakeLockHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.displayWakeLockController =
        const WakelockPlusDisplayWakeLockController(),
    this.supportsWakeLock,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final DisplayWakeLockController displayWakeLockController;
  final bool? supportsWakeLock;

  @override
  Widget build(BuildContext context) {
    return WorkspaceTurnActivityBuilder(
      workspaceController: workspaceController,
      builder: (context, hasActiveTurn) {
        return DisplayWakeLockHost(
          displayWakeLockController: displayWakeLockController,
          supportsWakeLock: supportsWakeLock,
          keepDisplayAwake: hasActiveTurn,
          child: child,
        );
      },
    );
  }
}
