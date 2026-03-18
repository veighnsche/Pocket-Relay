import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';

import '../models/connection_workspace_state.dart';

typedef ConnectionLaneBindingFactory =
    ConnectionLaneBinding Function({
      required String connectionId,
      required SavedConnection connection,
      required SavedConversationHandoff handoff,
    });

class ConnectionWorkspaceController extends ChangeNotifier {
  ConnectionWorkspaceController({
    required CodexConnectionRepository connectionRepository,
    required CodexConnectionHandoffStore connectionHandoffStore,
    required ConnectionLaneBindingFactory laneBindingFactory,
  }) : _connectionRepository = connectionRepository,
       _connectionHandoffStore = connectionHandoffStore,
       _laneBindingFactory = laneBindingFactory;

  final CodexConnectionRepository _connectionRepository;
  final CodexConnectionHandoffStore _connectionHandoffStore;
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

  Future<void> instantiateConnection(String connectionId) async {
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty) {
      throw ArgumentError.value(
        connectionId,
        'connectionId',
        'Connection id must not be empty.',
      );
    }

    await initialize();
    if (_state.catalog.connectionForId(normalizedConnectionId) == null) {
      throw StateError('Unknown saved connection: $normalizedConnectionId');
    }

    if (_state.isConnectionLive(normalizedConnectionId)) {
      selectConnection(normalizedConnectionId);
      return;
    }

    final binding = await _loadLaneBinding(normalizedConnectionId);
    if (_isDisposed) {
      binding.dispose();
      return;
    }

    _liveBindingsByConnectionId[normalizedConnectionId] = binding;
    final nextLiveConnectionIds = _orderLiveConnectionIds(
      _liveBindingsByConnectionId.keys,
    );
    _applyState(
      _state.copyWith(
        isLoading: false,
        liveConnectionIds: nextLiveConnectionIds,
        selectedConnectionId: normalizedConnectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
      ),
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
    final catalog = await _connectionRepository.loadCatalog();
    if (catalog.isEmpty) {
      throw StateError(
        'ConnectionWorkspaceController requires at least one saved connection.',
      );
    }

    final firstConnectionId = catalog.orderedConnectionIds.first;
    final firstBinding = await _loadLaneBinding(firstConnectionId);
    if (_isDisposed) {
      firstBinding.dispose();
      return;
    }

    _liveBindingsByConnectionId[firstConnectionId] = firstBinding;
    _applyState(
      ConnectionWorkspaceState(
        isLoading: false,
        catalog: catalog,
        liveConnectionIds: <String>[firstConnectionId],
        selectedConnectionId: firstConnectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
      ),
    );
  }

  Future<ConnectionLaneBinding> _loadLaneBinding(String connectionId) async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _connectionRepository.loadConnection(connectionId),
      _connectionHandoffStore.load(connectionId),
    ]);

    return _laneBindingFactory(
      connectionId: connectionId,
      connection: results[0] as SavedConnection,
      handoff: results[1] as SavedConversationHandoff,
    );
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
}
