import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';

class PocketRelayAppDependencies {
  const PocketRelayAppDependencies({
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

  PocketPlatformPolicy get resolvedPlatformPolicy {
    return platformPolicy ?? PocketPlatformPolicy.resolve();
  }

  PocketRelayWorkspaceBootstrap createWorkspaceBootstrap({
    CodexConnectionRepository? ownedConnectionRepository,
  }) {
    final resolvedConnectionRepository =
        connectionRepository ??
        (ownedConnectionRepository ?? SecureCodexConnectionRepository());
    final resolvedPlatformPolicy = this.resolvedPlatformPolicy;
    final resolvedRemoteOwnerInspector =
        remoteAppServerOwnerInspector ??
        const CodexSshRemoteAppServerOwnerInspector();
    final resolvedRemoteHostProbe =
        remoteAppServerHostProbe ?? resolvedRemoteOwnerInspector;
    final resolvedRemoteRuntimeDelegateFactory =
        agentAdapterRemoteRuntimeDelegateFactory ??
        ((kind) => createDefaultAgentAdapterRemoteRuntimeDelegate(
          kind,
          remoteHostProbe: resolvedRemoteHostProbe,
          remoteOwnerInspector: resolvedRemoteOwnerInspector,
        ));
    var usedInjectedAppServerClient = false;

    final workspaceController = ConnectionWorkspaceController(
      connectionRepository: resolvedConnectionRepository,
      modelCatalogStore:
          modelCatalogStore ?? SecureConnectionModelCatalogStore(),
      recoveryStore: recoveryStore ?? SecureConnectionWorkspaceRecoveryStore(),
      remoteRuntimeDelegateFactory: resolvedRemoteRuntimeDelegateFactory,
      laneBindingFactory:
          ({
            required String connectionId,
            required SavedConnection connection,
          }) {
            final injectedAgentAdapterClient =
                agentAdapterClient ?? appServerClient;
            final usingInjectedClient =
                !usedInjectedAppServerClient &&
                injectedAgentAdapterClient != null;
            if (usingInjectedClient) {
              usedInjectedAppServerClient = true;
            }

            return ConnectionLaneBinding(
              connectionId: connectionId,
              profileStore: ConnectionScopedProfileStore(
                connectionId: connectionId,
                connectionRepository: resolvedConnectionRepository,
              ),
              agentAdapterClient: usingInjectedClient
                  ? injectedAgentAdapterClient
                  : createDefaultAgentAdapterClient(
                      profile: connection.profile,
                      ownerId: connectionId,
                      remoteOwnerInspector: resolvedRemoteOwnerInspector,
                    ),
              runtimeEventMapper: createAgentAdapterRuntimeEventMapper(
                connection.profile.agentAdapter,
              ),
              initialSavedProfile: SavedProfile(
                profile: connection.profile,
                secrets: connection.secrets,
              ),
              supportsLocalConnectionMode:
                  resolvedPlatformPolicy.supportsLocalConnectionMode,
              ownsAppServerClient: !usingInjectedClient,
            );
          },
    );

    return PocketRelayWorkspaceBootstrap(
      workspaceController: workspaceController,
      ownedConnectionRepository: connectionRepository == null
          ? resolvedConnectionRepository
          : ownedConnectionRepository,
    );
  }
}

class PocketRelayWorkspaceBootstrap {
  const PocketRelayWorkspaceBootstrap({
    required this.workspaceController,
    required this.ownedConnectionRepository,
  });

  final ConnectionWorkspaceController workspaceController;
  final CodexConnectionRepository? ownedConnectionRepository;
}
