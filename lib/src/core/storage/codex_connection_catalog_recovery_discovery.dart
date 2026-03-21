part of 'codex_connection_catalog_recovery.dart';

Future<ConnectionCatalogState> _buildCatalog(
  CodexConnectionCatalogRecovery recovery,
  List<String> candidateConnectionIds,
) async {
  if (candidateConnectionIds.isEmpty) {
    return const ConnectionCatalogState.empty();
  }

  final profileValues = await recovery._preferences.getAll(
    allowList: candidateConnectionIds
        .map((connectionId) => _profileKeyForConnection(recovery, connectionId))
        .toSet(),
  );
  final orderedConnectionIds = <String>[];
  final connectionsById = <String, SavedConnectionSummary>{};

  for (final connectionId in candidateConnectionIds) {
    final rawProfile =
        profileValues[_profileKeyForConnection(recovery, connectionId)];
    if (rawProfile is! String || rawProfile.trim().isEmpty) {
      continue;
    }

    orderedConnectionIds.add(connectionId);
    final profile = ConnectionProfile.fromJson(
      jsonDecode(rawProfile) as Map<String, dynamic>,
    );
    connectionsById[connectionId] = SavedConnectionSummary(
      id: connectionId,
      profile: profile,
    );
  }

  return ConnectionCatalogState(
    orderedConnectionIds: orderedConnectionIds,
    connectionsById: connectionsById,
  );
}

Future<List<String>> _discoverProfileConnectionIds(
  CodexConnectionCatalogRecovery recovery,
) async {
  final keys = await recovery._preferences.getKeys();
  final connectionIds = <String>[];

  for (final key in keys) {
    if (!key.startsWith(recovery.profileKeyPrefix) ||
        !key.endsWith(recovery.profileKeySuffix)) {
      continue;
    }

    final connectionId = key.substring(
      recovery.profileKeyPrefix.length,
      key.length - recovery.profileKeySuffix.length,
    );
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty) {
      continue;
    }
    connectionIds.add(normalizedConnectionId);
  }

  connectionIds.sort();
  return connectionIds;
}

String _profileKeyForConnection(
  CodexConnectionCatalogRecovery recovery,
  String connectionId,
) {
  return '${recovery.profileKeyPrefix}$connectionId${recovery.profileKeySuffix}';
}
