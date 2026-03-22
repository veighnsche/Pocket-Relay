import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';

class WorkspaceTurnBackgroundGraceHost extends StatelessWidget {
  const WorkspaceTurnBackgroundGraceHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.backgroundGraceController =
        const MethodChannelBackgroundGraceController(),
    this.supportsBackgroundGrace,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;

  @override
  Widget build(BuildContext context) {
    return WorkspaceTurnActivityBuilder(
      workspaceController: workspaceController,
      builder: (context, hasActiveTurn) {
        return BackgroundGraceHost(
          backgroundGraceController: backgroundGraceController,
          supportsBackgroundGrace: supportsBackgroundGrace,
          keepBackgroundGraceAlive: hasActiveTurn,
          child: child,
        );
      },
    );
  }
}
