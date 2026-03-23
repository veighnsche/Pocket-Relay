import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

enum ConnectionWorkspaceViewport { liveLane, dormantRoster }

enum ConnectionWorkspaceBackgroundLifecycleState { inactive, hidden, paused }

enum ConnectionWorkspaceReconnectRequirement {
  savedSettings,
  transport,
  transportWithSavedSettings,
}

enum ConnectionWorkspaceRecoveryOrigin { foregroundResume, coldStart }

enum ConnectionWorkspaceTransportLossReason {
  disconnected,
  appServerExitGraceful,
  appServerExitError,
  connectFailed,
  sshConnectFailed,
  sshHostKeyMismatch,
  sshAuthenticationFailed,
  sshRemoteLaunchFailed,
}

enum ConnectionWorkspaceRecoveryOutcome {
  transportRestored,
  transportUnavailable,
  conversationRestored,
  conversationUnavailable,
  conversationRestoreFailed,
}

enum ConnectionWorkspaceTransportRecoveryPhase {
  lost,
  reconnecting,
  unavailable,
}

@immutable
class ConnectionWorkspaceRecoveryDiagnostics {
  const ConnectionWorkspaceRecoveryDiagnostics({
    this.lastBackgroundedAt,
    this.lastBackgroundedLifecycleState,
    this.lastResumedAt,
    this.lastRecoveryOrigin,
    this.lastRecoveryStartedAt,
    this.lastRecoveryCompletedAt,
    this.lastTransportLossAt,
    this.lastTransportLossReason,
    this.lastRecoveryOutcome,
  });

  final DateTime? lastBackgroundedAt;
  final ConnectionWorkspaceBackgroundLifecycleState?
  lastBackgroundedLifecycleState;
  final DateTime? lastResumedAt;
  final ConnectionWorkspaceRecoveryOrigin? lastRecoveryOrigin;
  final DateTime? lastRecoveryStartedAt;
  final DateTime? lastRecoveryCompletedAt;
  final DateTime? lastTransportLossAt;
  final ConnectionWorkspaceTransportLossReason? lastTransportLossReason;
  final ConnectionWorkspaceRecoveryOutcome? lastRecoveryOutcome;

  ConnectionWorkspaceRecoveryDiagnostics copyWith({
    DateTime? lastBackgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? lastBackgroundedLifecycleState,
    DateTime? lastResumedAt,
    ConnectionWorkspaceRecoveryOrigin? lastRecoveryOrigin,
    DateTime? lastRecoveryStartedAt,
    DateTime? lastRecoveryCompletedAt,
    DateTime? lastTransportLossAt,
    ConnectionWorkspaceTransportLossReason? lastTransportLossReason,
    ConnectionWorkspaceRecoveryOutcome? lastRecoveryOutcome,
    bool clearLastBackgroundedAt = false,
    bool clearLastBackgroundedLifecycleState = false,
    bool clearLastResumedAt = false,
    bool clearLastRecoveryOrigin = false,
    bool clearLastRecoveryStartedAt = false,
    bool clearLastRecoveryCompletedAt = false,
    bool clearLastTransportLossAt = false,
    bool clearLastTransportLossReason = false,
    bool clearLastRecoveryOutcome = false,
  }) {
    return ConnectionWorkspaceRecoveryDiagnostics(
      lastBackgroundedAt: clearLastBackgroundedAt
          ? null
          : (lastBackgroundedAt ?? this.lastBackgroundedAt),
      lastBackgroundedLifecycleState: clearLastBackgroundedLifecycleState
          ? null
          : (lastBackgroundedLifecycleState ??
                this.lastBackgroundedLifecycleState),
      lastResumedAt: clearLastResumedAt
          ? null
          : (lastResumedAt ?? this.lastResumedAt),
      lastRecoveryOrigin: clearLastRecoveryOrigin
          ? null
          : (lastRecoveryOrigin ?? this.lastRecoveryOrigin),
      lastRecoveryStartedAt: clearLastRecoveryStartedAt
          ? null
          : (lastRecoveryStartedAt ?? this.lastRecoveryStartedAt),
      lastRecoveryCompletedAt: clearLastRecoveryCompletedAt
          ? null
          : (lastRecoveryCompletedAt ?? this.lastRecoveryCompletedAt),
      lastTransportLossAt: clearLastTransportLossAt
          ? null
          : (lastTransportLossAt ?? this.lastTransportLossAt),
      lastTransportLossReason: clearLastTransportLossReason
          ? null
          : (lastTransportLossReason ?? this.lastTransportLossReason),
      lastRecoveryOutcome: clearLastRecoveryOutcome
          ? null
          : (lastRecoveryOutcome ?? this.lastRecoveryOutcome),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceRecoveryDiagnostics &&
        other.lastBackgroundedAt == lastBackgroundedAt &&
        other.lastBackgroundedLifecycleState ==
            lastBackgroundedLifecycleState &&
        other.lastResumedAt == lastResumedAt &&
        other.lastRecoveryOrigin == lastRecoveryOrigin &&
        other.lastRecoveryStartedAt == lastRecoveryStartedAt &&
        other.lastRecoveryCompletedAt == lastRecoveryCompletedAt &&
        other.lastTransportLossAt == lastTransportLossAt &&
        other.lastTransportLossReason == lastTransportLossReason &&
        other.lastRecoveryOutcome == lastRecoveryOutcome;
  }

  @override
  int get hashCode => Object.hash(
    lastBackgroundedAt,
    lastBackgroundedLifecycleState,
    lastResumedAt,
    lastRecoveryOrigin,
    lastRecoveryStartedAt,
    lastRecoveryCompletedAt,
    lastTransportLossAt,
    lastTransportLossReason,
    lastRecoveryOutcome,
  );
}

class ConnectionWorkspaceState {
  const ConnectionWorkspaceState({
    required this.isLoading,
    required this.catalog,
    required this.liveConnectionIds,
    required this.selectedConnectionId,
    required this.viewport,
    required this.savedSettingsReconnectRequiredConnectionIds,
    required this.transportReconnectRequiredConnectionIds,
    required this.transportRecoveryPhasesByConnectionId,
    required this.recoveryDiagnosticsByConnectionId,
    required this.remoteRuntimeByConnectionId,
  });

  const ConnectionWorkspaceState.initial()
    : isLoading = true,
      catalog = const ConnectionCatalogState.empty(),
      liveConnectionIds = const <String>[],
      selectedConnectionId = null,
      viewport = ConnectionWorkspaceViewport.liveLane,
      savedSettingsReconnectRequiredConnectionIds = const <String>{},
      transportReconnectRequiredConnectionIds = const <String>{},
      transportRecoveryPhasesByConnectionId =
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      recoveryDiagnosticsByConnectionId =
          const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
      remoteRuntimeByConnectionId =
          const <String, ConnectionRemoteRuntimeState>{};

  final bool isLoading;
  final ConnectionCatalogState catalog;
  final List<String> liveConnectionIds;
  final String? selectedConnectionId;
  final ConnectionWorkspaceViewport viewport;
  final Set<String> savedSettingsReconnectRequiredConnectionIds;
  final Set<String> transportReconnectRequiredConnectionIds;
  final Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByConnectionId;
  final Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByConnectionId;
  final Map<String, ConnectionRemoteRuntimeState> remoteRuntimeByConnectionId;

  Set<String> get reconnectRequiredConnectionIds => <String>{
    ...savedSettingsReconnectRequiredConnectionIds,
    ...transportReconnectRequiredConnectionIds,
  };

  List<String> get dormantConnectionIds {
    return <String>[
      for (final connectionId in catalog.orderedConnectionIds)
        if (!liveConnectionIds.contains(connectionId)) connectionId,
    ];
  }

  bool isConnectionLive(String connectionId) {
    return liveConnectionIds.contains(connectionId);
  }

  bool requiresReconnect(String connectionId) {
    return requiresSavedSettingsReconnect(connectionId) ||
        requiresTransportReconnect(connectionId);
  }

  bool requiresSavedSettingsReconnect(String connectionId) {
    return savedSettingsReconnectRequiredConnectionIds.contains(connectionId);
  }

  bool requiresTransportReconnect(String connectionId) {
    return transportReconnectRequiredConnectionIds.contains(connectionId);
  }

  ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhaseFor(
    String connectionId,
  ) {
    return transportRecoveryPhasesByConnectionId[connectionId];
  }

  ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnosticsFor(
    String connectionId,
  ) {
    return recoveryDiagnosticsByConnectionId[connectionId];
  }

  ConnectionRemoteRuntimeState? remoteRuntimeFor(String connectionId) {
    return remoteRuntimeByConnectionId[connectionId];
  }

  ConnectionWorkspaceReconnectRequirement? reconnectRequirementFor(
    String connectionId,
  ) {
    final requiresSavedSettings = requiresSavedSettingsReconnect(connectionId);
    final requiresTransport = requiresTransportReconnect(connectionId);
    if (requiresTransport) {
      return requiresSavedSettings
          ? ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings
          : ConnectionWorkspaceReconnectRequirement.transport;
    }
    if (requiresSavedSettings) {
      return ConnectionWorkspaceReconnectRequirement.savedSettings;
    }
    return null;
  }

  bool get isEmptyWorkspace => catalog.isEmpty;

  bool get isShowingLiveLane =>
      viewport == ConnectionWorkspaceViewport.liveLane;

  bool get isShowingDormantRoster =>
      viewport == ConnectionWorkspaceViewport.dormantRoster;

  ConnectionWorkspaceState copyWith({
    bool? isLoading,
    ConnectionCatalogState? catalog,
    List<String>? liveConnectionIds,
    String? selectedConnectionId,
    ConnectionWorkspaceViewport? viewport,
    Set<String>? savedSettingsReconnectRequiredConnectionIds,
    Set<String>? transportReconnectRequiredConnectionIds,
    Map<String, ConnectionWorkspaceTransportRecoveryPhase>?
    transportRecoveryPhasesByConnectionId,
    Map<String, ConnectionWorkspaceRecoveryDiagnostics>?
    recoveryDiagnosticsByConnectionId,
    Map<String, ConnectionRemoteRuntimeState>? remoteRuntimeByConnectionId,
    bool clearSelectedConnectionId = false,
  }) {
    return ConnectionWorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      liveConnectionIds: liveConnectionIds ?? this.liveConnectionIds,
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
      viewport: viewport ?? this.viewport,
      savedSettingsReconnectRequiredConnectionIds:
          savedSettingsReconnectRequiredConnectionIds ??
          this.savedSettingsReconnectRequiredConnectionIds,
      transportReconnectRequiredConnectionIds:
          transportReconnectRequiredConnectionIds ??
          this.transportReconnectRequiredConnectionIds,
      transportRecoveryPhasesByConnectionId:
          transportRecoveryPhasesByConnectionId ??
          this.transportRecoveryPhasesByConnectionId,
      recoveryDiagnosticsByConnectionId:
          recoveryDiagnosticsByConnectionId ??
          this.recoveryDiagnosticsByConnectionId,
      remoteRuntimeByConnectionId:
          remoteRuntimeByConnectionId ?? this.remoteRuntimeByConnectionId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceState &&
        other.isLoading == isLoading &&
        other.catalog == catalog &&
        listEquals(other.liveConnectionIds, liveConnectionIds) &&
        other.selectedConnectionId == selectedConnectionId &&
        other.viewport == viewport &&
        setEquals(
          other.savedSettingsReconnectRequiredConnectionIds,
          savedSettingsReconnectRequiredConnectionIds,
        ) &&
        setEquals(
          other.transportReconnectRequiredConnectionIds,
          transportReconnectRequiredConnectionIds,
        ) &&
        mapEquals(
          other.transportRecoveryPhasesByConnectionId,
          transportRecoveryPhasesByConnectionId,
        ) &&
        mapEquals(
          other.recoveryDiagnosticsByConnectionId,
          recoveryDiagnosticsByConnectionId,
        ) &&
        mapEquals(
          other.remoteRuntimeByConnectionId,
          remoteRuntimeByConnectionId,
        );
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    catalog,
    Object.hashAll(liveConnectionIds),
    selectedConnectionId,
    viewport,
    Object.hashAllUnordered(savedSettingsReconnectRequiredConnectionIds),
    Object.hashAllUnordered(transportReconnectRequiredConnectionIds),
    Object.hashAllUnordered(
      transportRecoveryPhasesByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      recoveryDiagnosticsByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      remoteRuntimeByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
