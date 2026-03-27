import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_recovery_errors.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

import '../domain/connection_workspace_state.dart';

part 'connection_workspace_controller_lane.dart';
part 'connection_workspace_controller_remote_owner.dart';
part 'controller/app_lifecycle.dart';
part 'controller/binding_runtime.dart';
part 'controller/bootstrap.dart';
part 'controller/catalog_connections.dart';
part 'controller/conversation_selection.dart';
part 'controller/delete_connection.dart';
part 'controller/device_continuity_warnings.dart';
part 'controller/model_catalogs.dart';
part 'controller/recovery_diagnostics.dart';
part 'controller/recovery_persistence.dart';
part 'controller/reconnect.dart';
part 'controller/remote_runtime.dart';
part 'controller/state_sanitizers.dart';

typedef ConnectionLaneBindingFactory =
    ConnectionLaneBinding Function({
      required String connectionId,
      required SavedConnection connection,
    });
typedef WorkspaceNow = DateTime Function();

class ConnectionWorkspaceController extends ChangeNotifier {
  ConnectionWorkspaceController({
    required CodexConnectionRepository connectionRepository,
    required ConnectionLaneBindingFactory laneBindingFactory,
    ConnectionModelCatalogStore? modelCatalogStore,
    ConnectionWorkspaceRecoveryStore? recoveryStore,
    CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
        const CodexSshRemoteAppServerHostProbe(),
    CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
        const CodexSshRemoteAppServerOwnerInspector(),
    CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
        const CodexSshRemoteAppServerOwnerControl(),
    Duration recoveryPersistenceDebounceDuration = const Duration(
      milliseconds: 250,
    ),
    WorkspaceNow? now,
  }) : _connectionRepository = connectionRepository,
       _laneBindingFactory = laneBindingFactory,
       _modelCatalogStore =
           modelCatalogStore ?? const NoopConnectionModelCatalogStore(),
       _recoveryStore =
           recoveryStore ?? const NoopConnectionWorkspaceRecoveryStore(),
       _remoteAppServerHostProbe = remoteAppServerHostProbe,
       _remoteAppServerOwnerInspector = remoteAppServerOwnerInspector,
       _remoteAppServerOwnerControl = remoteAppServerOwnerControl,
       _recoveryPersistenceDebounceDuration =
           recoveryPersistenceDebounceDuration,
       _now = now ?? DateTime.now;

  final CodexConnectionRepository _connectionRepository;
  final ConnectionLaneBindingFactory _laneBindingFactory;
  final ConnectionModelCatalogStore _modelCatalogStore;
  final ConnectionWorkspaceRecoveryStore _recoveryStore;
  final CodexRemoteAppServerHostProbe _remoteAppServerHostProbe;
  final CodexRemoteAppServerOwnerInspector _remoteAppServerOwnerInspector;
  final CodexRemoteAppServerOwnerControl _remoteAppServerOwnerControl;
  final Duration _recoveryPersistenceDebounceDuration;
  final WorkspaceNow _now;
  final Map<String, ConnectionLaneBinding> _liveBindingsByConnectionId =
      <String, ConnectionLaneBinding>{};
  final Map<
    String,
    ({
      ConnectionLaneBinding binding,
      VoidCallback listener,
      StreamSubscription<CodexAppServerEvent> appServerEventSubscription,
    })
  >
  _bindingRecoveryRegistrationsByConnectionId =
      <
        String,
        ({
          ConnectionLaneBinding binding,
          VoidCallback listener,
          StreamSubscription<CodexAppServerEvent> appServerEventSubscription,
        })
      >{};
  final Map<String, int> _remoteRuntimeRefreshGenerationByConnectionId =
      <String, int>{};
  final Set<String> _intentionalTransportDisconnectConnectionIds = <String>{};

  ConnectionWorkspaceState _state = const ConnectionWorkspaceState.initial();
  Future<void>? _initializationFuture;
  Future<void> _recoveryPersistence = Future<void>.value();
  Timer? _recoveryPersistenceDebounceTimer;
  ConnectionWorkspaceRecoveryState? _pendingRecoveryPersistenceState;
  ConnectionWorkspaceRecoveryState? _lastPersistedRecoveryState;
  bool _isPersistingRecoveryState = false;
  bool _isDisposed = false;

  ConnectionWorkspaceState get state => _state;
  Future<void> flushRecoveryPersistence() => _enqueueRecoveryPersistence();
  ConnectionLaneBinding? get selectedLaneBinding {
    final selectedConnectionId = _state.selectedConnectionId;
    if (selectedConnectionId == null) {
      return null;
    }
    return _liveBindingsByConnectionId[selectedConnectionId];
  }

  ConnectionLaneBinding? bindingForConnectionId(String connectionId) {
    return _liveBindingsByConnectionId[connectionId];
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<SavedConnection> loadSavedConnection(String connectionId) {
    return _loadWorkspaceSavedConnection(this, connectionId);
  }

  Future<String> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _createWorkspaceConnection(this, profile: profile, secrets: secrets);
  }

  Future<void> saveSavedConnection({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceSavedConnection(
      this,
      connectionId: connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<void> saveLiveConnectionEdits({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceLiveConnectionEdits(
      this,
      connectionId: connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<ConnectionModelCatalog?> loadConnectionModelCatalog(
    String connectionId,
  ) {
    return _loadWorkspaceConnectionModelCatalog(this, connectionId);
  }

  Future<void> saveConnectionModelCatalog(ConnectionModelCatalog catalog) {
    return _saveWorkspaceConnectionModelCatalog(this, catalog);
  }

  Future<ConnectionModelCatalog?> loadLastKnownConnectionModelCatalog() {
    return _loadWorkspaceLastKnownConnectionModelCatalog(this);
  }

  Future<void> saveLastKnownConnectionModelCatalog(
    ConnectionModelCatalog catalog,
  ) {
    return _saveWorkspaceLastKnownConnectionModelCatalog(this, catalog);
  }

  Future<void> reconnectConnection(String connectionId) {
    return _reconnectWorkspaceLane(this, connectionId);
  }

  Future<void> disconnectConnection(String connectionId) {
    return _disconnectWorkspaceConnection(this, connectionId);
  }

  Future<ConnectionRemoteRuntimeState> refreshRemoteRuntime({
    required String connectionId,
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return _refreshWorkspaceRemoteRuntime(
      this,
      connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<ConnectionRemoteRuntimeState> startRemoteServer({
    required String connectionId,
  }) {
    return _startWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<ConnectionRemoteRuntimeState> stopRemoteServer({
    required String connectionId,
  }) {
    return _stopWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<ConnectionRemoteRuntimeState> restartRemoteServer({
    required String connectionId,
  }) {
    return _restartWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state) {
    return _handleWorkspaceAppLifecycleState(this, state);
  }

  Future<void> resumeConversation({
    required String connectionId,
    required String threadId,
  }) {
    return _resumeWorkspaceConversationSelection(
      this,
      connectionId: connectionId,
      threadId: threadId,
    );
  }

  Future<void> deleteSavedConnection(String connectionId) {
    return _deleteWorkspaceSavedConnection(this, connectionId);
  }

  Future<void> instantiateConnection(String connectionId) {
    return _instantiateWorkspaceLiveConnection(this, connectionId);
  }

  void selectConnection(String connectionId) {
    _selectWorkspaceConnection(this, connectionId);
  }

  void showSavedConnections() {
    _showWorkspaceSavedConnections(this);
  }

  void setForegroundServiceWarning(PocketUserFacingError? warning) {
    _setWorkspaceForegroundServiceWarning(this, warning);
  }

  void setBackgroundGraceWarning(PocketUserFacingError? warning) {
    _setWorkspaceBackgroundGraceWarning(this, warning);
  }

  void setWakeLockWarning(PocketUserFacingError? warning) {
    _setWorkspaceWakeLockWarning(this, warning);
  }

  void terminateConnection(String connectionId) {
    _terminateWorkspaceConnection(this, connectionId);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    final finalRecoveryPersistence = _enqueueRecoveryPersistence();
    _isDisposed = true;
    _recoveryPersistenceDebounceTimer?.cancel();
    unawaited(finalRecoveryPersistence);

    final liveBindingEntries = _liveBindingsByConnectionId.entries.toList();
    _liveBindingsByConnectionId.clear();
    for (final entry in liveBindingEntries) {
      _unregisterLiveBinding(entry.key);
      entry.value.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeOnce() async {
    await _initializeWorkspaceController(this);
  }

  bool _applyState(ConnectionWorkspaceState nextState) {
    if (_isDisposed || nextState == _state) {
      return false;
    }

    _state = nextState;
    notifyListeners();
    unawaited(_enqueueRecoveryPersistence());
    return true;
  }

  bool _applyStateWithoutRecoveryPersistence(
    ConnectionWorkspaceState nextState,
  ) {
    if (_isDisposed || nextState == _state) {
      return false;
    }

    _state = nextState;
    notifyListeners();
    return true;
  }

  void _notifyListenersInternal() {
    notifyListeners();
  }

  void _notifyBindingChange() => _notifyWorkspaceBindingChange(this);

  void _registerLiveBinding(
    String connectionId,
    ConnectionLaneBinding binding,
  ) => _registerWorkspaceLiveBinding(this, connectionId, binding);

  void _unregisterLiveBinding(String connectionId) =>
      _unregisterWorkspaceLiveBinding(this, connectionId);

  void _scheduleRecoveryPersistence() =>
      _scheduleWorkspaceRecoveryPersistence(this);

  Future<void> _enqueueRecoveryPersistence({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _enqueueWorkspaceRecoveryPersistence(
    this,
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  void _clearLiveReattachPhase(String connectionId) =>
      _clearWorkspaceLiveReattachPhase(this, connectionId);

  void _setLiveReattachPhase(
    String connectionId,
    ConnectionWorkspaceLiveReattachPhase phase,
  ) => _setWorkspaceLiveReattachPhase(this, connectionId, phase);

  Future<void> _queueRecoveryPersistenceSnapshot({
    ConnectionWorkspaceRecoveryState? snapshot,
  }) => _queueWorkspaceRecoveryPersistenceSnapshot(this, snapshot: snapshot);

  bool _hasImmediateRecoveryIdentityChange(
    ConnectionWorkspaceRecoveryState? snapshot,
  ) => _hasWorkspaceImmediateRecoveryIdentityChange(this, snapshot);

  ConnectionWorkspaceRecoveryState? _selectedRecoveryStateSnapshot({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _selectedWorkspaceRecoveryStateSnapshot(
    this,
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  void _markTransportReconnectRequired(String connectionId) =>
      _markWorkspaceTransportReconnectRequired(this, connectionId);

  void _clearTransportReconnectRequired(String connectionId) =>
      _clearWorkspaceTransportReconnectRequired(this, connectionId);

  void _setTransportRecoveryPhase(
    String connectionId,
    ConnectionWorkspaceTransportRecoveryPhase phase,
  ) => _setWorkspaceTransportRecoveryPhase(this, connectionId, phase);

  void _recordLifecycleBackgroundSnapshot(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
  }) => _recordWorkspaceLifecycleBackgroundSnapshot(
    this,
    connectionId,
    occurredAt: occurredAt,
    lifecycleState: lifecycleState,
  );

  void _recordLifecycleResume(
    String connectionId, {
    required DateTime occurredAt,
  }) => _recordWorkspaceLifecycleResume(
    this,
    connectionId,
    occurredAt: occurredAt,
  );

  void _recordTransportLoss(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceTransportLossReason reason,
  }) => _recordWorkspaceTransportLoss(
    this,
    connectionId,
    occurredAt: occurredAt,
    reason: reason,
  );

  void _recordFallbackTransportConnectFailure(
    String connectionId, {
    required DateTime occurredAt,
    required Object? error,
  }) => _recordWorkspaceFallbackTransportConnectFailure(
    this,
    connectionId,
    occurredAt: occurredAt,
    error: error,
  );

  void _beginRecoveryAttempt(
    String connectionId, {
    required DateTime startedAt,
    required ConnectionWorkspaceRecoveryOrigin origin,
  }) => _beginWorkspaceRecoveryAttempt(
    this,
    connectionId,
    startedAt: startedAt,
    origin: origin,
  );

  void _completeRecoveryAttempt(
    String connectionId, {
    required DateTime completedAt,
    required ConnectionWorkspaceRecoveryOutcome outcome,
  }) => _completeWorkspaceRecoveryAttempt(
    this,
    connectionId,
    completedAt: completedAt,
    outcome: outcome,
  );

  void _completeConversationRecoveryAttempt(
    String connectionId,
    ConnectionLaneBinding binding, {
    required DateTime completedAt,
  }) => _completeWorkspaceConversationRecoveryAttempt(
    this,
    connectionId,
    binding,
    completedAt: completedAt,
  );

  void _completeLiveReattachRecoveryAttempt(
    String connectionId, {
    required DateTime completedAt,
  }) => _completeWorkspaceLiveReattachRecoveryAttempt(
    this,
    connectionId,
    completedAt: completedAt,
  );

  void _updateRecoveryDiagnostics(
    String connectionId,
    ConnectionWorkspaceRecoveryDiagnostics Function(
      ConnectionWorkspaceRecoveryDiagnostics current,
    )
    update, {
    bool enqueueRecoveryPersistence = false,
  }) => _updateWorkspaceRecoveryDiagnostics(
    this,
    connectionId,
    update,
    enqueueRecoveryPersistence: enqueueRecoveryPersistence,
  );
}
