import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart';

import 'pocket_relay_dependencies.dart';
import 'pocket_relay_shell.dart';

class PocketRelayBootstrap extends StatefulWidget {
  const PocketRelayBootstrap({super.key, required this.dependencies});

  final PocketRelayAppDependencies dependencies;

  @override
  State<PocketRelayBootstrap> createState() => _PocketRelayBootstrapState();
}

class _PocketRelayBootstrapState extends State<PocketRelayBootstrap> {
  CodexConnectionRepository? _ownedConnectionRepository;
  late ConnectionWorkspaceController _workspaceController;

  @override
  void initState() {
    super.initState();
    _workspaceController = _createWorkspaceController();
    unawaited(_workspaceController.initialize());
  }

  @override
  void didUpdateWidget(covariant PocketRelayBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final workspaceDependenciesChanged =
        oldWidget.dependencies.connectionRepository !=
            widget.dependencies.connectionRepository ||
        oldWidget.dependencies.appServerClient !=
            widget.dependencies.appServerClient ||
        oldWidget.dependencies.platformPolicy !=
            widget.dependencies.platformPolicy;
    if (!workspaceDependenciesChanged) {
      return;
    }

    final previousWorkspaceController = _workspaceController;
    _workspaceController = _createWorkspaceController();
    setState(() {});
    unawaited(_workspaceController.initialize());
    previousWorkspaceController.dispose();
  }

  @override
  void dispose() {
    _workspaceController.dispose();
    super.dispose();
  }

  ConnectionWorkspaceController _createWorkspaceController() {
    final bootstrap = widget.dependencies.createWorkspaceBootstrap(
      ownedConnectionRepository: _ownedConnectionRepository,
    );
    _ownedConnectionRepository = bootstrap.ownedConnectionRepository;
    return bootstrap.workspaceController;
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    final platformPolicy = dependencies.resolvedPlatformPolicy;

    return WorkspaceAppLifecycleHost(
      workspaceController: _workspaceController,
      child: WorkspaceTurnWakeLockHost(
        workspaceController: _workspaceController,
        displayWakeLockController:
            dependencies.displayWakeLockController ??
            const WakelockPlusDisplayWakeLockController(),
        supportsWakeLock: platformPolicy.supportsWakeLock,
        child: PocketRelayShell(
          workspaceController: _workspaceController,
          platformPolicy: platformPolicy,
          conversationHistoryRepository:
              dependencies.conversationHistoryRepository,
          settingsOverlayDelegate: dependencies.settingsOverlayDelegate,
        ),
      ),
    );
  }
}
