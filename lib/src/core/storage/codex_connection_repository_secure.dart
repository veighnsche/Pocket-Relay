part of 'codex_connection_repository.dart';

Future<ConnectionCatalogState> _secureLoadCatalog(
  SecureCodexConnectionRepository repository,
) async {
  await repository._catalogRecovery.ensurePreferencesReady();

  final seededCatalog = await repository._catalogRecovery.loadCatalog();
  final legacyConnection = await _loadLegacySingletonConnection(repository);
  if (seededCatalog case final existingCatalog? when existingCatalog.isNotEmpty) {
    final migratedCatalog =
        await _migrateLegacySingletonIntoSeededCatalogIfNeeded(
          repository,
          catalog: existingCatalog,
          legacyConnection: legacyConnection,
        );
    if (migratedCatalog != null) {
      await _deleteLegacySingletonStorage(repository);
      return migratedCatalog;
    }
    return existingCatalog;
  }

  if (seededCatalog case final existingCatalog?) {
    if (legacyConnection != null) {
      final catalog = await _seedCatalogWithConnection(repository, legacyConnection);
      await _deleteLegacySingletonStorage(repository);
      return catalog;
    }
    return existingCatalog;
  }

  final catalog = await _seedCatalogWithConnection(
    repository,
    legacyConnection ??
        SavedConnection(
          id: repository._connectionIdGenerator(),
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
  );
  if (legacyConnection != null) {
    await _deleteLegacySingletonStorage(repository);
  }
  return catalog;
}

Future<SavedConnection> _secureLoadConnection(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  final normalizedConnectionId = _requireConnectionId(connectionId);
  final catalog = await repository.loadCatalog();
  final summary = catalog.connectionForId(normalizedConnectionId);
  if (summary == null) {
    throw StateError('Unknown saved connection: $normalizedConnectionId');
  }

  return SavedConnection(
    id: normalizedConnectionId,
    profile: summary.profile,
    secrets: await _readSecrets(repository, normalizedConnectionId),
  );
}

Future<SavedConnection> _secureCreateConnection(
  SecureCodexConnectionRepository repository, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final catalog = await repository.loadCatalog();

  late SavedConnection connection;
  do {
    connection = SavedConnection(
      id: repository._connectionIdGenerator(),
      profile: profile,
      secrets: secrets,
    );
  } while (catalog.connectionForId(connection.id) != null);

  await repository.saveConnection(connection);
  return connection;
}

Future<void> _secureSaveConnection(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  final normalizedConnection = _normalizeConnection(connection);
  final catalog = await repository.loadCatalog();
  final exists = catalog.connectionForId(normalizedConnection.id) != null;
  final orderedConnectionIds = exists
      ? catalog.orderedConnectionIds
      : <String>[...catalog.orderedConnectionIds, normalizedConnection.id];
  final nextCatalog = ConnectionCatalogState(
    orderedConnectionIds: orderedConnectionIds,
    connectionsById: <String, SavedConnectionSummary>{
      ...catalog.connectionsById,
      normalizedConnection.id: normalizedConnection.toSummary(),
    },
  );

  await _persistConnectionProfile(repository, normalizedConnection);
  await _persistConnectionSecrets(repository, normalizedConnection);
  await repository._catalogRecovery.persistCatalogIndex(
    nextCatalog.orderedConnectionIds,
  );
}

Future<void> _secureDeleteConnection(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  final normalizedConnectionId = _requireConnectionId(connectionId);
  final catalog = await repository.loadCatalog();
  if (catalog.connectionForId(normalizedConnectionId) == null) {
    return;
  }

  final nextCatalog = ConnectionCatalogState(
    orderedConnectionIds: catalog.orderedConnectionIds
        .where((id) => id != normalizedConnectionId)
        .toList(growable: false),
    connectionsById: <String, SavedConnectionSummary>{
      for (final entry in catalog.connectionsById.entries)
        if (entry.key != normalizedConnectionId) entry.key: entry.value,
    },
  );

  await _deleteConnectionPreferences(repository, normalizedConnectionId);
  await _deleteConnectionSecrets(repository, normalizedConnectionId);
  await repository._catalogRecovery.persistCatalogIndex(
    nextCatalog.orderedConnectionIds,
  );
}

Future<void> _persistConnectionProfile(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  await repository._preferences.setString(
    _profileKeyForConnection(connection.id),
    jsonEncode(connection.profile.toJson()),
  );
}

Future<void> _persistConnectionSecrets(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  await _writeSecret(
    repository,
    _passwordKeyForConnection(connection.id),
    connection.secrets.password,
  );
  await _writeSecret(
    repository,
    _privateKeyKeyForConnection(connection.id),
    connection.secrets.privateKeyPem,
  );
  await _writeSecret(
    repository,
    _privateKeyPassphraseKeyForConnection(connection.id),
    connection.secrets.privateKeyPassphrase,
  );
}

Future<ConnectionSecrets> _readSecrets(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  return ConnectionSecrets(
    password: await _readSecret(
      repository,
      _passwordKeyForConnection(connectionId),
    ),
    privateKeyPem: await _readSecret(
      repository,
      _privateKeyKeyForConnection(connectionId),
    ),
    privateKeyPassphrase: await _readSecret(
      repository,
      _privateKeyPassphraseKeyForConnection(connectionId),
    ),
  );
}

Future<void> _writeSecret(
  SecureCodexConnectionRepository repository,
  String key,
  String value,
) async {
  if (value.trim().isEmpty) {
    await repository._secureStorage.delete(key: key);
    return;
  }

  await repository._secureStorage.write(key: key, value: value);
}

Future<String> _readSecret(
  SecureCodexConnectionRepository repository,
  String key,
) async {
  return await repository._secureStorage.read(key: key) ?? '';
}

Future<SavedConnection?> _loadLegacySingletonConnection(
  SecureCodexConnectionRepository repository,
) async {
  final rawProfile = await repository._preferences.getString(
    SecureCodexConnectionRepository._legacySingletonProfileKey,
  );
  if (rawProfile == null) {
    return null;
  }

  final profile = _decodeLegacySingletonProfile(rawProfile);
  if (profile == null) {
    return null;
  }

  final password = await _readSecret(
    repository,
    SecureCodexConnectionRepository._legacySingletonPasswordKey,
  );
  final privateKeyPem = await _readSecret(
    repository,
    SecureCodexConnectionRepository._legacySingletonPrivateKeyKey,
  );
  final privateKeyPassphrase = await _readSecret(
    repository,
    SecureCodexConnectionRepository._legacySingletonPrivateKeyPassphraseKey,
  );

  return SavedConnection(
    id: repository._connectionIdGenerator(),
    profile: profile,
    secrets: ConnectionSecrets(
      password: password,
      privateKeyPem: privateKeyPem,
      privateKeyPassphrase: privateKeyPassphrase,
    ),
  );
}

Future<ConnectionCatalogState> _seedCatalogWithConnection(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  final nextCatalog = ConnectionCatalogState(
    orderedConnectionIds: <String>[connection.id],
    connectionsById: <String, SavedConnectionSummary>{
      connection.id: connection.toSummary(),
    },
  );

  await _persistConnectionProfile(repository, connection);
  await _persistConnectionSecrets(repository, connection);
  await repository._catalogRecovery.persistCatalogIndex(
    nextCatalog.orderedConnectionIds,
  );
  return nextCatalog;
}

Future<ConnectionCatalogState?> _migrateLegacySingletonIntoSeededCatalogIfNeeded(
  SecureCodexConnectionRepository repository, {
  required ConnectionCatalogState catalog,
  required SavedConnection? legacyConnection,
}) async {
  if (legacyConnection == null || !_looksLikeSeededDefaultCatalog(catalog)) {
    return null;
  }

  final seededConnectionId = catalog.orderedConnectionIds.single;
  final seededSummary = catalog.connectionForId(seededConnectionId);
  if (seededSummary == null ||
      seededSummary.profile != ConnectionProfile.defaults()) {
    return null;
  }

  final seededSecrets = await _readSecrets(repository, seededConnectionId);
  if (seededSecrets != const ConnectionSecrets()) {
    return null;
  }

  final migratedConnection = legacyConnection.copyWith(id: seededConnectionId);
  await _persistConnectionProfile(repository, migratedConnection);
  await _persistConnectionSecrets(repository, migratedConnection);
  return ConnectionCatalogState(
    orderedConnectionIds: catalog.orderedConnectionIds,
    connectionsById: <String, SavedConnectionSummary>{
      ...catalog.connectionsById,
      seededConnectionId: migratedConnection.toSummary(),
    },
  );
}

bool _looksLikeSeededDefaultCatalog(ConnectionCatalogState catalog) {
  if (catalog.orderedConnectionIds.length != 1) {
    return false;
  }

  final seededConnectionId = catalog.orderedConnectionIds.single;
  final seededSummary = catalog.connectionForId(seededConnectionId);
  return seededSummary?.profile == ConnectionProfile.defaults();
}

ConnectionProfile? _decodeLegacySingletonProfile(String rawProfile) {
  try {
    return ConnectionProfile.fromJson(
      jsonDecode(rawProfile) as Map<String, dynamic>,
    );
  } catch (_) {
    return null;
  }
}

Future<void> _deleteLegacySingletonStorage(
  SecureCodexConnectionRepository repository,
) async {
  await repository._preferences.remove(
    SecureCodexConnectionRepository._legacySingletonProfileKey,
  );
  await repository._secureStorage.delete(
    key: SecureCodexConnectionRepository._legacySingletonPasswordKey,
  );
  await repository._secureStorage.delete(
    key: SecureCodexConnectionRepository._legacySingletonPrivateKeyKey,
  );
  await repository._secureStorage.delete(
    key: SecureCodexConnectionRepository._legacySingletonPrivateKeyPassphraseKey,
  );
}

Future<void> _deleteConnectionPreferences(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  final keys = await repository._preferences.getKeys();
  final allowedKeys = <String>{
    for (final key in keys)
      if (key.startsWith(
        '${SecureCodexConnectionRepository._profileKeyPrefix}$connectionId.',
      ))
        key,
  };
  if (allowedKeys.isNotEmpty) {
    await repository._preferences.clear(allowList: allowedKeys);
  }
}

Future<void> _deleteConnectionSecrets(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  final prefix =
      '${SecureCodexConnectionRepository._secretKeyPrefix}$connectionId.';
  final secureEntries = await repository._secureStorage.readAll();
  final matchingKeys = <String>[
    for (final key in secureEntries.keys)
      if (key.startsWith(prefix)) key,
  ];

  for (final key in matchingKeys) {
    await repository._secureStorage.delete(key: key);
  }
}

SavedConnection _normalizeConnection(SavedConnection connection) {
  final normalizedConnectionId = _requireConnectionId(connection.id);
  if (normalizedConnectionId == connection.id) {
    return connection;
  }

  return connection.copyWith(id: normalizedConnectionId);
}

String _requireConnectionId(String connectionId) {
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

String _profileKeyForConnection(String connectionId) {
  return '${SecureCodexConnectionRepository._profileKeyPrefix}$connectionId${SecureCodexConnectionRepository._profileKeySuffix}';
}

String _passwordKeyForConnection(String connectionId) {
  return '${SecureCodexConnectionRepository._secretKeyPrefix}$connectionId${SecureCodexConnectionRepository._passwordKeySuffix}';
}

String _privateKeyKeyForConnection(String connectionId) {
  return '${SecureCodexConnectionRepository._secretKeyPrefix}$connectionId${SecureCodexConnectionRepository._privateKeyKeySuffix}';
}

String _privateKeyPassphraseKeyForConnection(String connectionId) {
  return '${SecureCodexConnectionRepository._secretKeyPrefix}$connectionId${SecureCodexConnectionRepository._privateKeyPassphraseKeySuffix}';
}
