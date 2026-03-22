import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
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
    ConnectionWorkspaceRecoveryStore? recoveryStore,
    WorkspaceNow? now,
  }) : _connectionRepository = connectionRepository,
       _laneBindingFactory = laneBindingFactory,
       _recoveryStore =
           recoveryStore ?? const NoopConnectionWorkspaceRecoveryStore(),
       _now = now ?? DateTime.now;

  final CodexConnectionRepository _connectionRepository;
  final ConnectionLaneBindingFactory _laneBindingFactory;
  final ConnectionWorkspaceRecoveryStore _recoveryStore;
  final WorkspaceNow _now;
  final Map<String, ConnectionLaneBinding> _liveBindingsByConnectionId =
      <String, ConnectionLaneBinding>{};
  final Map<String, ({ConnectionLaneBinding binding, VoidCallback listener})>
  _bindingRecoveryRegistrationsByConnectionId =
      <String, ({ConnectionLaneBinding binding, VoidCallback listener})>{};

  ConnectionWorkspaceState _state = const ConnectionWorkspaceState.initial();
  Future<void>? _initializationFuture;
  Future<void> _recoveryPersistence = Future<void>.value();
  bool _isDisposed = false;

  ConnectionWorkspaceState get state => _state;
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
    _isDisposed = true;

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
      unawaited(_enqueueRecoveryPersistence());
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

  Future<void> _enqueueRecoveryPersistence({DateTime? backgroundedAt}) {
    _recoveryPersistence = _recoveryPersistence
        .then((_) async {
          if (_isDisposed) {
            return;
          }
          await _recoveryStore.save(
            _selectedRecoveryStateSnapshot(backgroundedAt: backgroundedAt),
          );
        })
        .catchError((_) {});
    return _recoveryPersistence;
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
