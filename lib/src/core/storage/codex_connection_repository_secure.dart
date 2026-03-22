part of 'codex_connection_repository.dart';

Future<ConnectionCatalogState> _secureLoadCatalog(
  SecureCodexConnectionRepository repository,
) async {
  await repository._catalogRecovery.ensurePreferencesReady();

  final seededCatalog = await repository._catalogRecovery.loadCatalog();
  if (seededCatalog case final existingCatalog? when existingCatalog.isNotEmpty) {
    return existingCatalog;
  }

  if (seededCatalog case final existingCatalog?) {
    return existingCatalog;
  }

  final seededConnection =
      await _loadLegacySingletonConnection(repository) ??
      SavedConnection(
        id: repository._connectionIdGenerator(),
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
  final nextCatalog = ConnectionCatalogState(
    orderedConnectionIds: <String>[seededConnection.id],
    connectionsById: <String, SavedConnectionSummary>{
      seededConnection.id: seededConnection.toSummary(),
    },
  );

  await _persistConnectionProfile(repository, seededConnection);
  await _persistConnectionSecrets(repository, seededConnection);
  await repository._catalogRecovery.persistCatalogIndex(
    nextCatalog.orderedConnectionIds,
  );
  return nextCatalog;
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

  if (rawProfile == null &&
      password.isEmpty &&
      privateKeyPem.isEmpty &&
      privateKeyPassphrase.isEmpty) {
    return null;
  }

  final profile = rawProfile == null
      ? ConnectionProfile.defaults()
      : ConnectionProfile.fromJson(
          jsonDecode(rawProfile) as Map<String, dynamic>,
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
