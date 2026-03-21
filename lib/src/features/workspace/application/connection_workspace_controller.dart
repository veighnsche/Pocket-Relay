import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';

import '../domain/connection_workspace_state.dart';

part 'connection_workspace_controller_catalog.dart';
part 'connection_workspace_controller_lane.dart';
part 'connection_workspace_controller_lifecycle.dart';

typedef ConnectionLaneBindingFactory =
    ConnectionLaneBinding Function({
      required String connectionId,
      required SavedConnection connection,
    });

class ConnectionWorkspaceController extends ChangeNotifier {
  ConnectionWorkspaceController({
    required CodexConnectionRepository connectionRepository,
    required CodexConnectionConversationStateStore
    connectionConversationStateStore,
    required ConnectionLaneBindingFactory laneBindingFactory,
  }) : _connectionRepository = connectionRepository,
       _connectionConversationStateStore = connectionConversationStateStore,
       _laneBindingFactory = laneBindingFactory;

  final CodexConnectionRepository _connectionRepository;
  final CodexConnectionConversationStateStore _connectionConversationStateStore;
  final ConnectionLaneBindingFactory _laneBindingFactory;
  final Map<String, ConnectionLaneBinding> _liveBindingsByConnectionId =
      <String, ConnectionLaneBinding>{};

  ConnectionWorkspaceState _state = const ConnectionWorkspaceState.initial();
  Future<void>? _initializationFuture;
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
    return _createWorkspaceConnection(
      this,
      profile: profile,
      secrets: secrets,
    );
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

    final liveBindings = _liveBindingsByConnectionId.values.toList();
    _liveBindingsByConnectionId.clear();
    for (final binding in liveBindings) {
      binding.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeOnce() async {
    await _initializeWorkspaceController(this);
  }

  void _applyState(ConnectionWorkspaceState nextState) {
    if (_isDisposed || nextState == _state) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }
}
