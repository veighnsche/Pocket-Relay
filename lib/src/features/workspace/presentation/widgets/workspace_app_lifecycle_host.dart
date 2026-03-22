import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

class WorkspaceAppLifecycleHost extends StatefulWidget {
  const WorkspaceAppLifecycleHost({
    super.key,
    required this.workspaceController,
    required this.child,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;

  @override
  State<WorkspaceAppLifecycleHost> createState() =>
      _WorkspaceAppLifecycleHostState();
}

class _WorkspaceAppLifecycleHostState extends State<WorkspaceAppLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant WorkspaceAppLifecycleHost oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(widget.workspaceController.handleAppLifecycleStateChanged(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
