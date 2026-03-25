import 'dart:async';

import 'package:flutter/widgets.dart';
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
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

import '../domain/connection_workspace_state.dart';

part 'connection_workspace_controller_catalog.dart';
part 'connection_workspace_controller_lane.dart';
part 'connection_workspace_controller_lifecycle.dart';
part 'connection_workspace_controller_remote_owner.dart';

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

  void _notifyBindingChange() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
    unawaited(_enqueueRecoveryPersistence());
  }

  void _registerLiveBinding(
    String connectionId,
    ConnectionLaneBinding binding,
  ) {
    _unregisterLiveBinding(connectionId);
    void listener() {
      if (_state.selectedConnectionId != connectionId) {
        return;
      }
      final snapshot = _selectedRecoveryStateSnapshot();
      if (_hasImmediateRecoveryIdentityChange(snapshot)) {
        unawaited(_queueRecoveryPersistenceSnapshot(snapshot: snapshot));
        return;
      }
      _scheduleRecoveryPersistence();
    }

    _bindingRecoveryRegistrationsByConnectionId[connectionId] = (
      binding: binding,
      listener: listener,
      appServerEventSubscription: binding.appServerClient.events.listen((
        event,
      ) {
        switch (event) {
          case CodexAppServerDisconnectedEvent(:final exitCode):
            _recordTransportLoss(
              connectionId,
              occurredAt: _now(),
              reason: switch (exitCode) {
                null => ConnectionWorkspaceTransportLossReason.disconnected,
                0 =>
                  ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
                _ => ConnectionWorkspaceTransportLossReason.appServerExitError,
              },
            );
            _markTransportReconnectRequired(connectionId);
            _setLiveReattachPhase(
              connectionId,
              ConnectionWorkspaceLiveReattachPhase.transportLost,
            );
            break;
          case CodexAppServerConnectedEvent():
            final wasRecovering = _state.requiresTransportReconnect(
              connectionId,
            );
            if (wasRecovering) {
              final hasConversationIdentity =
                  binding.sessionController.sessionState.currentThreadId
                          ?.trim()
                          .isNotEmpty ==
                      true ||
                  binding.sessionController.sessionState.rootThreadId
                          ?.trim()
                          .isNotEmpty ==
                      true;
              if (hasConversationIdentity) {
                _setLiveReattachPhase(
                  connectionId,
                  ConnectionWorkspaceLiveReattachPhase.reconnecting,
                );
              } else {
                _clearTransportReconnectRequired(connectionId);
                _clearLiveReattachPhase(connectionId);
                _completeRecoveryAttempt(
                  connectionId,
                  completedAt: _now(),
                  outcome: ConnectionWorkspaceRecoveryOutcome.transportRestored,
                );
              }
            }
            break;
          case CodexAppServerSshConnectFailedEvent():
            _recordTransportLoss(
              connectionId,
              occurredAt: _now(),
              reason: ConnectionWorkspaceTransportLossReason.sshConnectFailed,
            );
            break;
          case CodexAppServerSshHostKeyMismatchEvent():
            _recordTransportLoss(
              connectionId,
              occurredAt: _now(),
              reason: ConnectionWorkspaceTransportLossReason.sshHostKeyMismatch,
            );
            break;
          case CodexAppServerSshAuthenticationFailedEvent():
            _recordTransportLoss(
              connectionId,
              occurredAt: _now(),
              reason: ConnectionWorkspaceTransportLossReason
                  .sshAuthenticationFailed,
            );
            break;
          default:
            break;
        }
      }),
    );
    binding.sessionController.addListener(listener);
    binding.composerDraftHost.addListener(listener);
  }

  void _unregisterLiveBinding(String connectionId) {
    final registration = _bindingRecoveryRegistrationsByConnectionId.remove(
      connectionId,
    );
    if (registration == null) {
      return;
    }

    registration.binding.sessionController.removeListener(
      registration.listener,
    );
    registration.binding.composerDraftHost.removeListener(
      registration.listener,
    );
    unawaited(registration.appServerEventSubscription.cancel());
  }

  void _scheduleRecoveryPersistence() {
    if (_isDisposed) {
      return;
    }
    _recoveryPersistenceDebounceTimer?.cancel();
    _recoveryPersistenceDebounceTimer = Timer(
      _recoveryPersistenceDebounceDuration,
      () {
        _recoveryPersistenceDebounceTimer = null;
        unawaited(
          _queueRecoveryPersistenceSnapshot(
            snapshot: _selectedRecoveryStateSnapshot(),
          ),
        );
      },
    );
  }

  Future<void> _enqueueRecoveryPersistence({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) {
    _recoveryPersistenceDebounceTimer?.cancel();
    _recoveryPersistenceDebounceTimer = null;
    return _queueRecoveryPersistenceSnapshot(
      snapshot: _selectedRecoveryStateSnapshot(
        backgroundedAt: backgroundedAt,
        backgroundedLifecycleState: backgroundedLifecycleState,
      ),
    );
  }

  void _clearLiveReattachPhase(String connectionId) {
    if (_isDisposed || _state.liveReattachPhaseFor(connectionId) == null) {
      return;
    }

    _applyState(
      _state.copyWith(
        liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
          catalog: _state.catalog,
          liveConnectionIds: _state.liveConnectionIds,
          liveReattachPhasesByConnectionId:
              <String, ConnectionWorkspaceLiveReattachPhase>{
                for (final entry
                    in _state.liveReattachPhasesByConnectionId.entries)
                  if (entry.key != connectionId) entry.key: entry.value,
              },
        ),
      ),
    );
  }

  void _setLiveReattachPhase(
    String connectionId,
    ConnectionWorkspaceLiveReattachPhase phase,
  ) {
    if (_isDisposed || !_state.isConnectionLive(connectionId)) {
      return;
    }

    if (_state.liveReattachPhaseFor(connectionId) == phase) {
      return;
    }

    _applyState(
      _state.copyWith(
        liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
          catalog: _state.catalog,
          liveConnectionIds: _state.liveConnectionIds,
          liveReattachPhasesByConnectionId:
              <String, ConnectionWorkspaceLiveReattachPhase>{
                ..._state.liveReattachPhasesByConnectionId,
                connectionId: phase,
              },
        ),
      ),
    );
  }

  Future<void> _queueRecoveryPersistenceSnapshot({
    ConnectionWorkspaceRecoveryState? snapshot,
  }) {
    if (_isDisposed) {
      return _recoveryPersistence;
    }

    if (snapshot == _lastPersistedRecoveryState ||
        snapshot == _pendingRecoveryPersistenceState) {
      return _recoveryPersistence;
    }

    _pendingRecoveryPersistenceState = snapshot;
    if (_isPersistingRecoveryState) {
      return _recoveryPersistence;
    }

    _isPersistingRecoveryState = true;
    _recoveryPersistence = _drainRecoveryPersistenceQueue();
    return _recoveryPersistence;
  }

  Future<void> _drainRecoveryPersistenceQueue() async {
    try {
      while (true) {
        final snapshot = _pendingRecoveryPersistenceState;
        _pendingRecoveryPersistenceState = null;
        if (snapshot == null) {
          break;
        }
        if (snapshot == _lastPersistedRecoveryState) {
          if (_pendingRecoveryPersistenceState == null) {
            break;
          }
          continue;
        }
        try {
          await _recoveryStore.save(snapshot);
          _lastPersistedRecoveryState = snapshot;
        } catch (error, stackTrace) {
          assert(() {
            debugPrint('Failed to save workspace recovery state: $error');
            debugPrintStack(stackTrace: stackTrace);
            return true;
          }());
        }
        if (_pendingRecoveryPersistenceState == null) {
          break;
        }
      }
    } finally {
      _isPersistingRecoveryState = false;
      if (_pendingRecoveryPersistenceState != null && !_isDisposed) {
        _isPersistingRecoveryState = true;
        _recoveryPersistence = _drainRecoveryPersistenceQueue();
      }
    }
  }

  bool _hasImmediateRecoveryIdentityChange(
    ConnectionWorkspaceRecoveryState? snapshot,
  ) {
    final referenceSnapshot =
        _pendingRecoveryPersistenceState ?? _lastPersistedRecoveryState;
    return referenceSnapshot?.connectionId != snapshot?.connectionId ||
        referenceSnapshot?.selectedThreadId != snapshot?.selectedThreadId;
  }

  ConnectionWorkspaceRecoveryState? _selectedRecoveryStateSnapshot({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) {
    final selectedConnectionId = _state.selectedConnectionId;
    if (selectedConnectionId == null ||
        !_state.isConnectionLive(selectedConnectionId)) {
      return null;
    }

    final binding = _liveBindingsByConnectionId[selectedConnectionId];
    if (binding == null) {
      return null;
    }

    final selectedThreadId = _normalizedWorkspaceThreadId(
      binding.sessionController.sessionState.currentThreadId ??
          binding.sessionController.sessionState.rootThreadId ??
          binding
              .sessionController
              .historicalConversationRestoreState
              ?.threadId,
    );
    final diagnostics = _state.recoveryDiagnosticsFor(selectedConnectionId);

    return ConnectionWorkspaceRecoveryState(
      connectionId: selectedConnectionId,
      selectedThreadId: selectedThreadId,
      draftText: binding.composerDraftHost.draft.text,
      backgroundedAt: backgroundedAt ?? diagnostics?.lastBackgroundedAt,
      backgroundedLifecycleState:
          backgroundedLifecycleState ??
          diagnostics?.lastBackgroundedLifecycleState,
    );
  }

  void _markTransportReconnectRequired(String connectionId) {
    if (_isDisposed ||
        !_state.isConnectionLive(connectionId) ||
        _state.requiresTransportReconnect(connectionId)) {
      return;
    }

    _applyState(
      _state.copyWith(
        transportReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ..._state.transportReconnectRequiredConnectionIds,
                connectionId,
              },
            ),
        transportRecoveryPhasesByConnectionId:
            _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    ..._state.transportRecoveryPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceTransportRecoveryPhase.lost,
                  },
            ),
      ),
    );
  }

  void _clearTransportReconnectRequired(String connectionId) {
    if (_isDisposed || !_state.requiresTransportReconnect(connectionId)) {
      return;
    }

    _applyState(
      _state.copyWith(
        transportReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ..._state.transportReconnectRequiredConnectionIds,
              }..remove(connectionId),
            ),
        transportRecoveryPhasesByConnectionId:
            _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    for (final entry
                        in _state.transportRecoveryPhasesByConnectionId.entries)
                      if (entry.key != connectionId) entry.key: entry.value,
                  },
            ),
      ),
    );
  }

  void _setTransportRecoveryPhase(
    String connectionId,
    ConnectionWorkspaceTransportRecoveryPhase phase,
  ) {
    if (_isDisposed || !_state.isConnectionLive(connectionId)) {
      return;
    }

    if (_state.transportRecoveryPhaseFor(connectionId) == phase) {
      return;
    }

    _applyState(
      _state.copyWith(
        transportRecoveryPhasesByConnectionId:
            _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    ..._state.transportRecoveryPhasesByConnectionId,
                    connectionId: phase,
                  },
            ),
      ),
    );
  }

  void _recordLifecycleBackgroundSnapshot(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
  }) {
    _updateRecoveryDiagnostics(
      connectionId,
      (current) => current.copyWith(
        lastBackgroundedAt: occurredAt,
        lastBackgroundedLifecycleState: lifecycleState,
      ),
    );
  }

  void _recordLifecycleResume(
    String connectionId, {
    required DateTime occurredAt,
  }) {
    _updateRecoveryDiagnostics(
      connectionId,
      (current) => current.copyWith(
        lastResumedAt: occurredAt,
        clearLastBackgroundedAt: true,
        clearLastBackgroundedLifecycleState: true,
      ),
    );
  }

  void _recordTransportLoss(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceTransportLossReason reason,
  }) {
    _updateRecoveryDiagnostics(
      connectionId,
      (current) => current.copyWith(
        lastTransportLossAt: occurredAt,
        lastTransportLossReason: reason,
      ),
    );
  }

  void _recordFallbackTransportConnectFailure(
    String connectionId, {
    required DateTime occurredAt,
  }) {
    final diagnostics = _state.recoveryDiagnosticsFor(connectionId);
    final lastRecoveryStartedAt = diagnostics?.lastRecoveryStartedAt;
    final lastTransportLossAt = diagnostics?.lastTransportLossAt;
    if (lastRecoveryStartedAt != null &&
        lastTransportLossAt != null &&
        !lastTransportLossAt.isBefore(lastRecoveryStartedAt)) {
      return;
    }

    _recordTransportLoss(
      connectionId,
      occurredAt: occurredAt,
      reason: ConnectionWorkspaceTransportLossReason.connectFailed,
    );
  }

  void _beginRecoveryAttempt(
    String connectionId, {
    required DateTime startedAt,
    required ConnectionWorkspaceRecoveryOrigin origin,
  }) {
    _updateRecoveryDiagnostics(
      connectionId,
      (current) => current.copyWith(
        lastRecoveryOrigin: origin,
        lastRecoveryStartedAt: startedAt,
        clearLastRecoveryCompletedAt: true,
        clearLastRecoveryOutcome: true,
      ),
    );
  }

  void _completeRecoveryAttempt(
    String connectionId, {
    required DateTime completedAt,
    required ConnectionWorkspaceRecoveryOutcome outcome,
  }) {
    _updateRecoveryDiagnostics(
      connectionId,
      (current) => current.copyWith(
        lastRecoveryCompletedAt: completedAt,
        lastRecoveryOutcome: outcome,
      ),
    );
  }

  void _completeConversationRecoveryAttempt(
    String connectionId,
    ConnectionLaneBinding binding, {
    required DateTime completedAt,
  }) {
    final restorePhase =
        binding.sessionController.historicalConversationRestoreState?.phase;
    final outcome = switch (restorePhase) {
      ChatHistoricalConversationRestorePhase.unavailable =>
        ConnectionWorkspaceRecoveryOutcome.conversationUnavailable,
      ChatHistoricalConversationRestorePhase.failed =>
        ConnectionWorkspaceRecoveryOutcome.conversationRestoreFailed,
      _ => ConnectionWorkspaceRecoveryOutcome.conversationRestored,
    };
    _completeRecoveryAttempt(
      connectionId,
      completedAt: completedAt,
      outcome: outcome,
    );
  }

  void _completeLiveReattachRecoveryAttempt(
    String connectionId, {
    required DateTime completedAt,
  }) {
    _completeRecoveryAttempt(
      connectionId,
      completedAt: completedAt,
      outcome: ConnectionWorkspaceRecoveryOutcome.liveReattached,
    );
  }

  void _updateRecoveryDiagnostics(
    String connectionId,
    ConnectionWorkspaceRecoveryDiagnostics Function(
      ConnectionWorkspaceRecoveryDiagnostics current,
    )
    update,
  ) {
    if (_isDisposed || !_state.isConnectionLive(connectionId)) {
      return;
    }

    final currentDiagnostics =
        _state.recoveryDiagnosticsFor(connectionId) ??
        const ConnectionWorkspaceRecoveryDiagnostics();
    final nextDiagnostics = update(currentDiagnostics);
    if (nextDiagnostics == currentDiagnostics) {
      return;
    }

    _applyState(
      _state.copyWith(
        recoveryDiagnosticsByConnectionId:
            _sanitizeWorkspaceRecoveryDiagnostics(
              catalog: _state.catalog,
              liveConnectionIds: _state.liveConnectionIds,
              recoveryDiagnosticsByConnectionId:
                  <String, ConnectionWorkspaceRecoveryDiagnostics>{
                    ..._state.recoveryDiagnosticsByConnectionId,
                    connectionId: nextDiagnostics,
                  },
            ),
      ),
    );
  }
}
