import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

import '../domain/connection_workspace_state.dart';

part 'connection_workspace_controller_catalog.dart';
part 'connection_workspace_controller_lane.dart';
part 'connection_workspace_controller_lifecycle.dart';

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
       _recoveryPersistenceDebounceDuration =
           recoveryPersistenceDebounceDuration,
       _now = now ?? DateTime.now;

  final CodexConnectionRepository _connectionRepository;
  final ConnectionLaneBindingFactory _laneBindingFactory;
  final ConnectionModelCatalogStore _modelCatalogStore;
  final ConnectionWorkspaceRecoveryStore _recoveryStore;
  final Duration _recoveryPersistenceDebounceDuration;
  final WorkspaceNow _now;
  final Map<String, ConnectionLaneBinding> _liveBindingsByConnectionId =
      <String, ConnectionLaneBinding>{};
  final Map<String, ({ConnectionLaneBinding binding, VoidCallback listener})>
  _bindingRecoveryRegistrationsByConnectionId =
      <String, ({ConnectionLaneBinding binding, VoidCallback listener})>{};

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

  Future<void> saveDormantConnection({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceDormantConnection(
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

  Future<void> deleteDormantConnection(String connectionId) {
    return _deleteWorkspaceDormantConnection(this, connectionId);
  }

  Future<void> instantiateConnection(String connectionId) {
    return _instantiateWorkspaceLiveConnection(this, connectionId);
  }

  void selectConnection(String connectionId) {
    _selectWorkspaceConnection(this, connectionId);
  }

  void showDormantRoster() {
    _showWorkspaceDormantRoster(this);
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

  Future<void> _enqueueRecoveryPersistence({DateTime? backgroundedAt}) {
    _recoveryPersistenceDebounceTimer?.cancel();
    _recoveryPersistenceDebounceTimer = null;
    return _queueRecoveryPersistenceSnapshot(
      snapshot: _selectedRecoveryStateSnapshot(backgroundedAt: backgroundedAt),
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

    return ConnectionWorkspaceRecoveryState(
      connectionId: selectedConnectionId,
      selectedThreadId: selectedThreadId,
      draftText: binding.composerDraftHost.draft.text,
      backgroundedAt: backgroundedAt,
    );
  }
}
