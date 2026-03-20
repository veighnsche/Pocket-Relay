import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart';

class PocketRelayApp extends StatefulWidget {
  const PocketRelayApp({
    super.key,
    this.connectionRepository,
    this.connectionConversationStateStore,
    this.appServerClient,
    this.displayWakeLockController,
    this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
    this.chatRootPlatformPolicy =
        const ChatRootPlatformPolicy.cupertinoFoundation(),
  });

  final CodexConnectionRepository? connectionRepository;
  final CodexConnectionConversationStateStore? connectionConversationStateStore;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;
  final PocketPlatformPolicy? platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;
  final ChatRootPlatformPolicy chatRootPlatformPolicy;

  @override
  State<PocketRelayApp> createState() => _PocketRelayAppState();
}

class _PocketRelayAppState extends State<PocketRelayApp> {
  CodexConnectionRepository? _ownedConnectionRepository;
  CodexConnectionConversationStateStore? _ownedConversationStateStore;
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
        oldWidget.connectionConversationStateStore !=
            widget.connectionConversationStateStore ||
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
    final platformPolicy = _resolvedPlatformPolicy;
    var usedInjectedAppServerClient = false;

    return ConnectionWorkspaceController(
      connectionRepository: connectionRepository,
      connectionConversationStateStore:
          widget.connectionConversationStateStore ??
          (_ownedConversationStateStore ??=
              SecureCodexConnectionConversationHistoryStore()),
      laneBindingFactory:
          ({
            required String connectionId,
            required SavedConnection connection,
            required SavedConnectionConversationState conversationState,
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
              conversationStateStore: ConnectionScopedConversationStateStore(
                connectionId: connectionId,
                conversationStateStore:
                    widget.connectionConversationStateStore ??
                    (_ownedConversationStateStore ??=
                        SecureCodexConnectionConversationHistoryStore()),
              ),
              appServerClient: usingInjectedClient
                  ? injectedAppServerClient
                  : CodexAppServerClient(),
              initialSavedProfile: SavedProfile(
                profile: connection.profile,
                secrets: connection.secrets,
              ),
              initialConversationState: conversationState,
              supportsLocalConnectionMode:
                  platformPolicy.supportsLocalConnectionMode,
              ownsAppServerClient: !usingInjectedClient,
            );
          },
    );
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
          settingsOverlayDelegate: widget.settingsOverlayDelegate,
        ),
      ),
    );
  }
}

class _PocketRelayHome extends StatelessWidget {
  const _PocketRelayHome({
    required this.workspaceController,
    required this.platformPolicy,
    required this.settingsOverlayDelegate,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: workspaceController,
      builder: (context, _) {
        final workspaceState = workspaceController.state;
        if (workspaceState.isLoading) {
          return _PocketRelayBootstrapShell(
            screenShell: platformPolicy.regionPolicy.screenShell,
          );
        }

        if (platformPolicy.behavior.isMobileExperience) {
          return ConnectionWorkspaceMobileShell(
            workspaceController: workspaceController,
            platformPolicy: platformPolicy,
            settingsOverlayDelegate: settingsOverlayDelegate,
          );
        }

        if (platformPolicy.behavior.isDesktopExperience) {
          return ConnectionWorkspaceDesktopShell(
            workspaceController: workspaceController,
            platformPolicy: platformPolicy,
            settingsOverlayDelegate: settingsOverlayDelegate,
          );
        }

        final selectedLaneBinding = workspaceController.selectedLaneBinding;
        if (selectedLaneBinding != null) {
          return ConnectionWorkspaceLiveLaneSurface(
            workspaceController: workspaceController,
            laneBinding: selectedLaneBinding,
            platformPolicy: platformPolicy,
            settingsOverlayDelegate: settingsOverlayDelegate,
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
        child: _BootstrapSplash(
          progressIndicator: const CircularProgressIndicator(strokeWidth: 2.8),
        ),
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
        child: _BootstrapBackground(
          child: _BootstrapSplash(
            progressIndicator: const CupertinoActivityIndicator(radius: 12),
            useCupertinoText: true,
          ),
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

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash({
    required this.progressIndicator,
    this.useCupertinoText = false,
  });

  final Widget progressIndicator;
  final bool useCupertinoText;

  @override
  Widget build(BuildContext context) {
    final materialTheme = Theme.of(context);
    final cupertinoTheme = useCupertinoText ? CupertinoTheme.of(context) : null;
    final titleStyle = useCupertinoText && cupertinoTheme != null
        ? cupertinoTheme.textTheme.navLargeTitleTextStyle.copyWith(
            fontSize: 33,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.white,
          )
        : materialTheme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
          );
    final bodyStyle = useCupertinoText && cupertinoTheme != null
        ? cupertinoTheme.textTheme.textStyle.copyWith(
            fontSize: 15,
            height: 1.45,
            color: CupertinoColors.systemGrey2,
          )
        : materialTheme.textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: materialTheme.colorScheme.onSurface.withValues(alpha: 0.68),
          );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(38),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.07),
                        Colors.black.withValues(alpha: 0.22),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 36,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      'assets/icons/app_icon_master.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Pocket Relay',
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
                const SizedBox(height: 10),
                Text(
                  'Remote Codex, ready before the first lane opens.',
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
                const SizedBox(height: 26),
                progressIndicator,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
