import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';

class PocketRelayApp extends StatefulWidget {
  const PocketRelayApp({
    super.key,
    this.connectionRepository,
    this.connectionHandoffStore,
    this.appServerClient,
    this.displayWakeLockController,
    this.platformPolicy,
    this.chatRootPlatformPolicy =
        const ChatRootPlatformPolicy.cupertinoFoundation(),
  });

  final CodexConnectionRepository? connectionRepository;
  final CodexConnectionHandoffStore? connectionHandoffStore;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;
  final PocketPlatformPolicy? platformPolicy;
  final ChatRootPlatformPolicy chatRootPlatformPolicy;

  @override
  State<PocketRelayApp> createState() => _PocketRelayAppState();
}

class _PocketRelayAppState extends State<PocketRelayApp> {
  CodexConnectionRepository? _ownedConnectionRepository;
  CodexConnectionHandoffStore? _ownedConnectionHandoffStore;
  CodexConnectionRepository? _ownedConnectionHandoffStoreRepository;
  late ConnectionWorkspaceController _workspaceController;

  @override
  void initState() {
    super.initState();
    _workspaceController = _createWorkspaceController();
    unawaited(_workspaceController.initialize());
  }

  @override
  void didUpdateWidget(covariant PocketRelayApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    final workspaceDependenciesChanged =
        oldWidget.connectionRepository != widget.connectionRepository ||
        oldWidget.connectionHandoffStore != widget.connectionHandoffStore ||
        oldWidget.appServerClient != widget.appServerClient ||
        oldWidget.platformPolicy != widget.platformPolicy ||
        oldWidget.chatRootPlatformPolicy != widget.chatRootPlatformPolicy;
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

  PocketPlatformPolicy get _resolvedPlatformPolicy {
    return widget.platformPolicy ??
        PocketPlatformPolicy.resolve(
          chatRootPlatformPolicy: widget.chatRootPlatformPolicy,
        );
  }

  ConnectionWorkspaceController _createWorkspaceController() {
    final connectionRepository =
        widget.connectionRepository ??
        (_ownedConnectionRepository ??= SecureCodexConnectionRepository());
    final connectionHandoffStore = _resolveConnectionHandoffStore(
      connectionRepository: connectionRepository,
    );
    final platformPolicy = _resolvedPlatformPolicy;
    var usedInjectedAppServerClient = false;

    return ConnectionWorkspaceController(
      connectionRepository: connectionRepository,
      connectionHandoffStore: connectionHandoffStore,
      laneBindingFactory:
          ({
            required String connectionId,
            required SavedConnection connection,
            required SavedConversationHandoff handoff,
          }) {
            final injectedAppServerClient = widget.appServerClient;
            final usingInjectedClient =
                !usedInjectedAppServerClient && injectedAppServerClient != null;
            if (usingInjectedClient) {
              usedInjectedAppServerClient = true;
            }

            return ConnectionLaneBinding(
              connectionId: connectionId,
              profileStore: ConnectionScopedProfileStore(
                connectionId: connectionId,
                connectionRepository: connectionRepository,
              ),
              conversationHandoffStore:
                  ConnectionScopedConversationHandoffStore(
                    connectionId: connectionId,
                    handoffStore: connectionHandoffStore,
                  ),
              appServerClient: usingInjectedClient
                  ? injectedAppServerClient
                  : CodexAppServerClient(),
              initialSavedProfile: SavedProfile(
                profile: connection.profile,
                secrets: connection.secrets,
              ),
              initialSavedConversationHandoff: handoff,
              supportsLocalConnectionMode:
                  platformPolicy.supportsLocalConnectionMode,
              ownsAppServerClient: !usingInjectedClient,
            );
          },
    );
  }

  CodexConnectionHandoffStore _resolveConnectionHandoffStore({
    required CodexConnectionRepository connectionRepository,
  }) {
    if (widget.connectionHandoffStore case final injectedHandoffStore?) {
      return injectedHandoffStore;
    }

    final ownedHandoffStore = _ownedConnectionHandoffStore;
    if (ownedHandoffStore == null ||
        _ownedConnectionHandoffStoreRepository != connectionRepository) {
      _ownedConnectionHandoffStore = SecureCodexConnectionHandoffStore(
        connectionRepository: connectionRepository,
      );
      _ownedConnectionHandoffStoreRepository = connectionRepository;
    }
    return _ownedConnectionHandoffStore!;
  }

  @override
  Widget build(BuildContext context) {
    final platformPolicy = _resolvedPlatformPolicy;

    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: DisplayWakeLockHost(
        displayWakeLockController:
            widget.displayWakeLockController ??
            const WakelockPlusDisplayWakeLockController(),
        supportsWakeLock: platformPolicy.supportsWakeLock,
        child: _PocketRelayHome(
          workspaceController: _workspaceController,
          platformPolicy: platformPolicy,
        ),
      ),
    );
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.workspaceController,
    required this.platformPolicy,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: workspaceController,
      builder: (context, _) {
        final selectedLaneBinding = workspaceController.selectedLaneBinding;
        if (selectedLaneBinding != null) {
          return ChatRootAdapter(
            laneBinding: selectedLaneBinding,
            platformPolicy: platformPolicy,
          );
        }

        return _PocketRelayBootstrapShell(
          screenShell: platformPolicy.regionPolicy.screenShell,
        );
      },
    );
  }
}

class _PocketRelayBootstrapShell extends StatelessWidget {
  const _PocketRelayBootstrapShell({required this.screenShell});

  final ChatRootScreenShellRenderer screenShell;

  @override
  Widget build(BuildContext context) {
    return switch (screenShell) {
      ChatRootScreenShellRenderer.flutter => const _FlutterBootstrapShell(),
      ChatRootScreenShellRenderer.cupertino => const _CupertinoBootstrapShell(),
    };
  }
}

class _FlutterBootstrapShell extends StatelessWidget {
  const _FlutterBootstrapShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BootstrapBackground(
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _CupertinoBootstrapShell extends StatelessWidget {
  const _CupertinoBootstrapShell();

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return CupertinoTheme(
      data: buildPocketCupertinoTheme(Theme.of(context)),
      child: CupertinoPageScaffold(
        backgroundColor: palette.backgroundTop,
        child: const _BootstrapBackground(
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
    );
  }
}

class _BootstrapBackground extends StatelessWidget {
  const _BootstrapBackground({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}
