import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_connection_conversation_history_store.dart';
import 'codex_connection_repository.dart';
import 'codex_profile_store.dart';

class ConnectionScopedProfileStore implements CodexProfileStore {
  ConnectionScopedProfileStore({
    required String connectionId,
    required CodexConnectionRepository connectionRepository,
  }) : _connectionId = _normalizeConnectionId(connectionId),
       _connectionRepository = connectionRepository;

  final String _connectionId;
  final CodexConnectionRepository _connectionRepository;

  @override
  Future<SavedProfile> load() async {
    final connection = await _connectionRepository.loadConnection(
      _connectionId,
    );
    return SavedProfile(
      profile: connection.profile,
      secrets: connection.secrets,
    );
  }

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    await _connectionRepository.saveConnection(
      SavedConnection(id: _connectionId, profile: profile, secrets: secrets),
    );
  }
}

class ConnectionScopedConversationStateStore
    implements CodexConversationStateStore {
  ConnectionScopedConversationStateStore({
    required String connectionId,
    required CodexConnectionConversationStateStore conversationStateStore,
  }) : _connectionId = _normalizeConnectionId(connectionId),
       _conversationStateStore = conversationStateStore;

  final String _connectionId;
  final CodexConnectionConversationStateStore _conversationStateStore;

  @override
  Future<SavedConnectionConversationState> loadState() {
    return _conversationStateStore.loadState(_connectionId);
  }

  @override
  Future<void> saveState(SavedConnectionConversationState state) {
    return _conversationStateStore.saveState(_connectionId, state);
  }
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
