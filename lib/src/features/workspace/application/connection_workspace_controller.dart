import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';

import '../domain/connection_workspace_state.dart';

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

  Future<SavedConnection> loadSavedConnection(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);
    return _connectionRepository.loadConnection(normalizedConnectionId);
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<String> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    await initialize();
    final connection = await _connectionRepository.createConnection(
      profile: profile,
      secrets: secrets,
    );
    final nextCatalog = await _connectionRepository.loadCatalog();
    if (_isDisposed) {
      return connection.id;
    }

    _applyState(
      _state.copyWith(
        isLoading: false,
        catalog: nextCatalog,
        reconnectRequiredConnectionIds: _sanitizeReconnectRequiredConnectionIds(
          catalog: nextCatalog,
          liveConnectionIds: _state.liveConnectionIds,
          reconnectRequiredConnectionIds: _state.reconnectRequiredConnectionIds,
        ),
      ),
    );
    return connection.id;
  }

  Future<void> saveDormantConnection({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);
    if (_state.isConnectionLive(normalizedConnectionId)) {
      throw StateError(
        'Cannot save dormant connection settings for a live lane: '
        '$normalizedConnectionId',
      );
    }

    await _connectionRepository.saveConnection(
      SavedConnection(
        id: normalizedConnectionId,
        profile: profile,
        secrets: secrets,
      ),
    );

    final nextCatalog = await _connectionRepository.loadCatalog();
    if (_isDisposed) {
      return;
    }

    _applyState(
      _state.copyWith(
        isLoading: false,
        catalog: nextCatalog,
        reconnectRequiredConnectionIds: _sanitizeReconnectRequiredConnectionIds(
          catalog: nextCatalog,
          liveConnectionIds: _state.liveConnectionIds,
          reconnectRequiredConnectionIds: _state.reconnectRequiredConnectionIds,
        ),
      ),
    );
  }

  Future<void> saveLiveConnectionEdits({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);
    if (!_state.isConnectionLive(normalizedConnectionId)) {
      throw StateError(
        'Cannot stage live connection edits for a dormant connection: '
        '$normalizedConnectionId',
      );
    }

    await _connectionRepository.saveConnection(
      SavedConnection(
        id: normalizedConnectionId,
        profile: profile,
        secrets: secrets,
      ),
    );

    final nextCatalog = await _connectionRepository.loadCatalog();
    final liveBinding = _liveBindingsByConnectionId[normalizedConnectionId];
    final shouldRequireReconnect =
        liveBinding == null ||
        liveBinding.sessionController.profile != profile ||
        liveBinding.sessionController.secrets != secrets;
    final nextReconnectRequiredConnectionIds = <String>{
      for (final connectionId in _state.reconnectRequiredConnectionIds)
        if (connectionId != normalizedConnectionId) connectionId,
      if (shouldRequireReconnect) normalizedConnectionId,
    };
    if (_isDisposed) {
      return;
    }

    _applyState(
      _state.copyWith(
        isLoading: false,
        catalog: nextCatalog,
        reconnectRequiredConnectionIds: _sanitizeReconnectRequiredConnectionIds(
          catalog: nextCatalog,
          liveConnectionIds: _state.liveConnectionIds,
          reconnectRequiredConnectionIds: nextReconnectRequiredConnectionIds,
        ),
      ),
    );
  }

  Future<void> reconnectConnection(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    if (!_state.isConnectionLive(normalizedConnectionId) ||
        !_state.requiresReconnect(normalizedConnectionId)) {
      return;
    }

    await _reconnectWorkspaceConnection(this, normalizedConnectionId);
  }

  Future<void> resumeConversation({
    required String connectionId,
    required String threadId,
  }) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);
    final nextConversationState =
        (await _connectionConversationStateStore.loadState(
          normalizedConnectionId,
        )).copyWith(selectedThreadId: normalizedThreadId);
    await _connectionConversationStateStore.saveState(
      normalizedConnectionId,
      nextConversationState,
    );

    await _resumeWorkspaceConversation(
      this,
      normalizedConnectionId,
      activatePersistedConversation: true,
    );
  }

  Future<void> deleteDormantConnection(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);
    if (_state.isConnectionLive(normalizedConnectionId)) {
      throw StateError(
        'Cannot delete a live connection. Close the lane first: '
        '$normalizedConnectionId',
      );
    }

    await _deleteDormantWorkspaceConnection(this, normalizedConnectionId);
  }

  Future<void> instantiateConnection(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    await initialize();
    _requireKnownConnectionId(normalizedConnectionId);

    if (_state.isConnectionLive(normalizedConnectionId)) {
      selectConnection(normalizedConnectionId);
      return;
    }

    await _instantiateConnection(normalizedConnectionId);
  }

  Future<void> _instantiateConnection(
    String connectionId, {
    bool activatePersistedConversation = false,
  }) async {
    await _instantiateWorkspaceConnection(
      this,
      connectionId,
      activatePersistedConversation: activatePersistedConversation,
    );
  }

  void selectConnection(String connectionId) {
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty ||
        !_state.isConnectionLive(normalizedConnectionId)) {
      return;
    }
    if (_state.selectedConnectionId == normalizedConnectionId &&
        _state.isShowingLiveLane) {
      return;
    }

    _applyState(
      _state.copyWith(
        selectedConnectionId: normalizedConnectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
      ),
    );
  }

  void showDormantRoster() {
    if (_state.isShowingDormantRoster) {
      return;
    }

    _applyState(
      _state.copyWith(viewport: ConnectionWorkspaceViewport.dormantRoster),
    );
  }

  void terminateConnection(String connectionId) {
    final normalizedConnectionId = connectionId.trim();
    final binding = _liveBindingsByConnectionId.remove(normalizedConnectionId);
    if (binding == null) {
      return;
    }

    final currentLiveConnectionIds = _state.liveConnectionIds;
    final removalIndex = currentLiveConnectionIds.indexOf(
      normalizedConnectionId,
    );
    final nextLiveConnectionIds = _orderLiveConnectionIds(
      _liveBindingsByConnectionId.keys,
    );
    final nextSelectedConnectionId = _nextSelectedConnectionIdAfterTermination(
      removedConnectionId: normalizedConnectionId,
      removalIndex: removalIndex,
      nextLiveConnectionIds: nextLiveConnectionIds,
    );
    final nextViewport = _nextViewportAfterTermination(
      removedConnectionId: normalizedConnectionId,
      nextSelectedConnectionId: nextSelectedConnectionId,
    );

    binding.dispose();
    _applyState(
      _state.copyWith(
        isLoading: false,
        liveConnectionIds: nextLiveConnectionIds,
        selectedConnectionId: nextSelectedConnectionId,
        viewport: nextViewport,
        clearSelectedConnectionId: nextSelectedConnectionId == null,
        reconnectRequiredConnectionIds: _sanitizeReconnectRequiredConnectionIds(
          catalog: _state.catalog,
          liveConnectionIds: nextLiveConnectionIds,
          reconnectRequiredConnectionIds: _state.reconnectRequiredConnectionIds,
        ),
      ),
    );
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

  List<String> _orderLiveConnectionIds(Iterable<String> connectionIds) {
    final liveConnectionIdSet = connectionIds.toSet();
    return <String>[
      for (final connectionId in _state.catalog.orderedConnectionIds)
        if (liveConnectionIdSet.contains(connectionId)) connectionId,
    ];
  }

  String? _nextSelectedConnectionIdAfterTermination({
    required String removedConnectionId,
    required int removalIndex,
    required List<String> nextLiveConnectionIds,
  }) {
    if (_state.selectedConnectionId != removedConnectionId) {
      return _state.selectedConnectionId;
    }
    if (nextLiveConnectionIds.isEmpty) {
      return null;
    }

    final nextIndex = removalIndex.clamp(0, nextLiveConnectionIds.length - 1);
    return nextLiveConnectionIds[nextIndex];
  }

  ConnectionWorkspaceViewport _nextViewportAfterTermination({
    required String removedConnectionId,
    required String? nextSelectedConnectionId,
  }) {
    if (_state.selectedConnectionId == removedConnectionId &&
        nextSelectedConnectionId == null) {
      return ConnectionWorkspaceViewport.dormantRoster;
    }

    return _state.viewport;
  }

  void _applyState(ConnectionWorkspaceState nextState) {
    if (_isDisposed || nextState == _state) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  String _normalizeConnectionId(String connectionId) {
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty) {
      throw ArgumentError.value(
        connectionId,
        'connectionId',
        'Connection id must not be empty.',
      );
    }
    return normalizedConnectionId;
  }

  void _requireKnownConnectionId(String connectionId) {
    if (_state.catalog.connectionForId(connectionId) == null) {
      throw StateError('Unknown saved connection: $connectionId');
    }
  }

  Set<String> _sanitizeReconnectRequiredConnectionIds({
    required ConnectionCatalogState catalog,
    required List<String> liveConnectionIds,
    required Set<String> reconnectRequiredConnectionIds,
  }) {
    final liveConnectionIdSet = liveConnectionIds.toSet();
    return <String>{
      for (final connectionId in reconnectRequiredConnectionIds)
        if (catalog.connectionForId(connectionId) != null &&
            liveConnectionIdSet.contains(connectionId))
          connectionId,
    };
  }
}
