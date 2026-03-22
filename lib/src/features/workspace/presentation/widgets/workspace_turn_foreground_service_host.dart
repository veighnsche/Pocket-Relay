import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';

class WorkspaceTurnForegroundServiceHost extends StatelessWidget {
  const WorkspaceTurnForegroundServiceHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.foregroundServiceController =
        const MethodChannelForegroundServiceController(),
    this.supportsForegroundService,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final ForegroundServiceController foregroundServiceController;
  final bool? supportsForegroundService;

  @override
  Widget build(BuildContext context) {
    return WorkspaceTurnActivityBuilder(
      workspaceController: workspaceController,
      builder: (context, hasTickingTurn) {
        return ForegroundServiceHost(
          foregroundServiceController: foregroundServiceController,
          supportsForegroundService: supportsForegroundService,
          keepForegroundServiceRunning: hasTickingTurn,
          child: child,
        );
      },
    );
  }
}
