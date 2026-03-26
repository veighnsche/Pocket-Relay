import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_foreground_service_host.dart';
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
  Object? _workspaceInitializationError;

  @override
  void initState() {
    super.initState();
    _workspaceController = _createWorkspaceController();
    unawaited(_initializeWorkspaceController(_workspaceController));
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
    _workspaceInitializationError = null;
    setState(() {});
    unawaited(_initializeWorkspaceController(_workspaceController));
    unawaited(_flushAndDisposeWorkspaceController(previousWorkspaceController));
  }

  @override
  void dispose() {
    unawaited(_flushAndDisposeWorkspaceController(_workspaceController));
    super.dispose();
  }

  ConnectionWorkspaceController _createWorkspaceController() {
    final bootstrap = widget.dependencies.createWorkspaceBootstrap(
      ownedConnectionRepository: _ownedConnectionRepository,
    );
    _ownedConnectionRepository = bootstrap.ownedConnectionRepository;
    return bootstrap.workspaceController;
  }

  Future<void> _initializeWorkspaceController(
    ConnectionWorkspaceController controller,
  ) async {
    try {
      await controller.initialize();
      if (!mounted || !identical(controller, _workspaceController)) {
        return;
      }
      if (_workspaceInitializationError != null) {
        setState(() {
          _workspaceInitializationError = null;
        });
      }
    } catch (error) {
      debugPrint('Pocket Relay workspace initialization failed: $error');
      if (!mounted || !identical(controller, _workspaceController)) {
        return;
      }
      setState(() {
        _workspaceInitializationError = error;
      });
    }
  }

  Future<void> _retryWorkspaceInitialization() async {
    final previousWorkspaceController = _workspaceController;
    _workspaceController = _createWorkspaceController();
    setState(() {
      _workspaceInitializationError = null;
    });
    unawaited(_initializeWorkspaceController(_workspaceController));
    await _flushAndDisposeWorkspaceController(previousWorkspaceController);
  }

  Future<void> _flushAndDisposeWorkspaceController(
    ConnectionWorkspaceController controller,
  ) async {
    await controller.flushRecoveryPersistence();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    final platformPolicy = dependencies.resolvedPlatformPolicy;

    if (_workspaceInitializationError != null &&
        _workspaceController.state.isLoading) {
      return PocketRelayBootstrapShell(
        message: 'Pocket Relay could not finish loading your workspace.',
        isLoading: false,
        action: FilledButton(
          key: const ValueKey('retry_workspace_bootstrap'),
          onPressed: _retryWorkspaceInitialization,
          child: const Text('Retry'),
        ),
      );
    }

    return WorkspaceTurnForegroundServiceHost(
      workspaceController: _workspaceController,
      foregroundServiceController:
          dependencies.foregroundServiceController ??
          const MethodChannelForegroundServiceController(),
      supportsForegroundService:
          platformPolicy.supportsActiveTurnForegroundService,
      child: WorkspaceTurnBackgroundGraceHost(
        workspaceController: _workspaceController,
        backgroundGraceController:
            dependencies.backgroundGraceController ??
            const MethodChannelBackgroundGraceController(),
        supportsBackgroundGrace: platformPolicy.supportsFiniteBackgroundGrace,
        child: WorkspaceAppLifecycleHost(
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
        ),
      ),
    );
  }
}
