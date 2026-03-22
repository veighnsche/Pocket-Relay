import 'package:pocket_relay/src/core/models/connection_models.dart';

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
