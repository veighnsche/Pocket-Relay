import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

import 'pocket_relay_bootstrap.dart';
import 'pocket_relay_dependencies.dart';

class PocketRelayApp extends StatelessWidget {
  const PocketRelayApp({
    super.key,
    this.connectionRepository,
    this.conversationHistoryRepository,
    this.recoveryStore,
    this.appServerClient,
    this.displayWakeLockController,
    this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final CodexConnectionRepository? connectionRepository;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final ConnectionWorkspaceRecoveryStore? recoveryStore;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;
  final PocketPlatformPolicy? platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Relay',
      debugShowCheckedModeBanner: false,
      theme: buildPocketTheme(Brightness.light),
      darkTheme: buildPocketTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: PocketRelayBootstrap(
        dependencies: PocketRelayAppDependencies(
          connectionRepository: connectionRepository,
          conversationHistoryRepository: conversationHistoryRepository,
          recoveryStore: recoveryStore,
          appServerClient: appServerClient,
          displayWakeLockController: displayWakeLockController,
          platformPolicy: platformPolicy,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      ),
    );
  }
}
