import 'package:flutter/material.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';

import 'pocket_relay_bootstrap.dart';
import 'pocket_relay_dependencies.dart';

class PocketRelayApp extends StatelessWidget {
  const PocketRelayApp({
    super.key,
    this.connectionRepository,
    this.modelCatalogStore,
    this.conversationHistoryRepository,
    this.recoveryStore,
    this.agentAdapterClient,
    @Deprecated('Use agentAdapterClient instead.') this.appServerClient,
    this.agentAdapterRemoteRuntimeDelegateFactory,
    @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
    this.remoteAppServerHostProbe,
    @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
    this.remoteAppServerOwnerInspector,
    this.backgroundGraceController,
    this.foregroundServiceController,
    this.displayWakeLockController,
    this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final CodexConnectionRepository? connectionRepository;
  final ConnectionModelCatalogStore? modelCatalogStore;
  final WorkspaceConversationHistoryRepository? conversationHistoryRepository;
  final ConnectionWorkspaceRecoveryStore? recoveryStore;
  final AgentAdapterClient? agentAdapterClient;
  @Deprecated('Use agentAdapterClient instead.')
  final AgentAdapterClient? appServerClient;
  final AgentAdapterRemoteRuntimeDelegateFactory?
  agentAdapterRemoteRuntimeDelegateFactory;
  @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
  final CodexRemoteAppServerHostProbe? remoteAppServerHostProbe;
  @Deprecated('Use agentAdapterRemoteRuntimeDelegateFactory instead.')
  final CodexRemoteAppServerOwnerInspector? remoteAppServerOwnerInspector;
  final BackgroundGraceController? backgroundGraceController;
  final ForegroundServiceController? foregroundServiceController;
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
          modelCatalogStore: modelCatalogStore,
          conversationHistoryRepository: conversationHistoryRepository,
          recoveryStore: recoveryStore,
          agentAdapterClient: agentAdapterClient ?? appServerClient,
          agentAdapterRemoteRuntimeDelegateFactory:
              agentAdapterRemoteRuntimeDelegateFactory,
          remoteAppServerHostProbe: remoteAppServerHostProbe,
          remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
          backgroundGraceController: backgroundGraceController,
          foregroundServiceController: foregroundServiceController,
          displayWakeLockController: displayWakeLockController,
          platformPolicy: platformPolicy,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      ),
    );
  }
}
