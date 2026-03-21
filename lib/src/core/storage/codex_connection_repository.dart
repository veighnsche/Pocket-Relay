import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_catalog_recovery.dart';

typedef ConnectionIdGenerator = String Function();

abstract interface class CodexConnectionRepository {
  Future<ConnectionCatalogState> loadCatalog();

  Future<SavedConnection> loadConnection(String connectionId);

  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<void> saveConnection(SavedConnection connection);

  Future<void> deleteConnection(String connectionId);
}

class MemoryCodexConnectionRepository implements CodexConnectionRepository {
  MemoryCodexConnectionRepository({
    Iterable<SavedConnection> initialConnections = const <SavedConnection>[],
    ConnectionIdGenerator? connectionIdGenerator,
  }) : _connectionsById = <String, SavedConnection>{
         for (final connection in initialConnections) connection.id: connection,
       },
       _orderedConnectionIds = <String>[
         for (final connection in initialConnections) connection.id,
       ],
       _connectionIdGenerator =
           connectionIdGenerator ?? _defaultMemoryConnectionIdGenerator();

  factory MemoryCodexConnectionRepository.single({
    required SavedProfile savedProfile,
    String connectionId = 'conn_1',
  }) {
    return MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        SavedConnection(
          id: connectionId,
          profile: savedProfile.profile,
          secrets: savedProfile.secrets,
        ),
      ],
    );
  }

  final Map<String, SavedConnection> _connectionsById;
  final List<String> _orderedConnectionIds;
  final ConnectionIdGenerator _connectionIdGenerator;

  @override
  Future<ConnectionCatalogState> loadCatalog() async {
    return ConnectionCatalogState(
      orderedConnectionIds: List<String>.from(_orderedConnectionIds),
      connectionsById: <String, SavedConnectionSummary>{
        for (final entry in _connectionsById.entries)
          entry.key: entry.value.toSummary(),
      },
    );
  }

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    final connection = _connectionsById[connectionId];
    if (connection == null) {
      throw StateError('Unknown saved connection: $connectionId');
    }
    return connection;
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    late SavedConnection connection;
    do {
      connection = SavedConnection(
        id: _connectionIdGenerator(),
        profile: profile,
        secrets: secrets,
      );
    } while (_connectionsById.containsKey(connection.id));

    await saveConnection(connection);
    return connection;
  }

  @override
  Future<void> saveConnection(SavedConnection connection) async {
    final exists = _connectionsById.containsKey(connection.id);
    _connectionsById[connection.id] = connection;
    if (!exists) {
      _orderedConnectionIds.add(connection.id);
    }
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    _connectionsById.remove(connectionId);
    _orderedConnectionIds.remove(connectionId);
  }
}

class SecureCodexConnectionRepository implements CodexConnectionRepository {
  static const _catalogIndexKey = 'pocket_relay.connections.index';
  static const _catalogSchemaVersion = 1;
  static const _catalogPreferencesMigrationKey =
      'pocket_relay.connections_async_migration_complete';
  static const _profileKeyPrefix = 'pocket_relay.connection.';
  static const _profileKeySuffix = '.profile';
  static const _secretKeyPrefix = 'pocket_relay.connection.';
  static const _passwordKeySuffix = '.secret.password';
  static const _privateKeyKeySuffix = '.secret.private_key';
  static const _privateKeyPassphraseKeySuffix =
      '.secret.private_key_passphrase';

  SecureCodexConnectionRepository({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
    ConnectionIdGenerator? connectionIdGenerator,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _connectionIdGenerator = connectionIdGenerator ?? generateConnectionId;

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  final ConnectionIdGenerator _connectionIdGenerator;
  late final CodexConnectionCatalogRecovery _catalogRecovery =
      CodexConnectionCatalogRecovery(
        preferences: _preferences,
        catalogIndexKey: _catalogIndexKey,
        catalogSchemaVersion: _catalogSchemaVersion,
        preferencesMigrationKey: _catalogPreferencesMigrationKey,
        profileKeyPrefix: _profileKeyPrefix,
        profileKeySuffix: _profileKeySuffix,
      );

  @override
  Future<ConnectionCatalogState> loadCatalog() async {
    await _catalogRecovery.ensurePreferencesReady();

    final seededCatalog = await _catalogRecovery.loadCatalog();
    if (seededCatalog case final existingCatalog?
        when existingCatalog.isNotEmpty) {
      return existingCatalog;
    }

    if (seededCatalog case final existingCatalog?) {
      return existingCatalog;
    }

    final seededConnection = SavedConnection(
      id: _connectionIdGenerator(),
      profile: ConnectionProfile.defaults(),
      secrets: const ConnectionSecrets(),
    );
    final nextCatalog = ConnectionCatalogState(
      orderedConnectionIds: <String>[seededConnection.id],
      connectionsById: <String, SavedConnectionSummary>{
        seededConnection.id: seededConnection.toSummary(),
      },
    );

    await _persistConnectionProfile(seededConnection);
    await _persistConnectionSecrets(seededConnection);
    await _catalogRecovery.persistCatalogIndex(
      nextCatalog.orderedConnectionIds,
    );
    return nextCatalog;
  }

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    final normalizedConnectionId = _requireConnectionId(connectionId);
    final catalog = await loadCatalog();
    final summary = catalog.connectionForId(normalizedConnectionId);
    if (summary == null) {
      throw StateError('Unknown saved connection: $normalizedConnectionId');
    }

    return SavedConnection(
      id: normalizedConnectionId,
      profile: summary.profile,
      secrets: await _readSecrets(normalizedConnectionId),
    );
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final catalog = await loadCatalog();

    late SavedConnection connection;
    do {
      connection = SavedConnection(
        id: _connectionIdGenerator(),
        profile: profile,
        secrets: secrets,
      );
    } while (catalog.connectionForId(connection.id) != null);

    await saveConnection(connection);
    return connection;
  }

  @override
  Future<void> saveConnection(SavedConnection connection) async {
    final normalizedConnection = _normalizeConnection(connection);
    final catalog = await loadCatalog();
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

    await _persistConnectionProfile(normalizedConnection);
    await _persistConnectionSecrets(normalizedConnection);
    await _catalogRecovery.persistCatalogIndex(
      nextCatalog.orderedConnectionIds,
    );
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    final normalizedConnectionId = _requireConnectionId(connectionId);
    final catalog = await loadCatalog();
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

    await _deleteConnectionPreferences(normalizedConnectionId);
    await _deleteConnectionSecrets(normalizedConnectionId);
    await _catalogRecovery.persistCatalogIndex(
      nextCatalog.orderedConnectionIds,
    );
  }

  Future<void> _persistConnectionProfile(SavedConnection connection) async {
    await _preferences.setString(
      _profileKeyForConnection(connection.id),
      jsonEncode(connection.profile.toJson()),
    );
  }

  Future<void> _persistConnectionSecrets(SavedConnection connection) async {
    await _writeSecret(
      _passwordKeyForConnection(connection.id),
      connection.secrets.password,
    );
    await _writeSecret(
      _privateKeyKeyForConnection(connection.id),
      connection.secrets.privateKeyPem,
    );
    await _writeSecret(
      _privateKeyPassphraseKeyForConnection(connection.id),
      connection.secrets.privateKeyPassphrase,
    );
  }

  Future<ConnectionSecrets> _readSecrets(String connectionId) async {
    return ConnectionSecrets(
      password: await _readSecret(_passwordKeyForConnection(connectionId)),
      privateKeyPem: await _readSecret(
        _privateKeyKeyForConnection(connectionId),
      ),
      privateKeyPassphrase: await _readSecret(
        _privateKeyPassphraseKeyForConnection(connectionId),
      ),
    );
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.trim().isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<String> _readSecret(String key) async {
    return await _secureStorage.read(key: key) ?? '';
  }

  Future<void> _deleteConnectionPreferences(String connectionId) async {
    final keys = await _preferences.getKeys();
    final allowedKeys = <String>{
      for (final key in keys)
        if (key.startsWith('$_profileKeyPrefix$connectionId.')) key,
    };
    if (allowedKeys.isNotEmpty) {
      await _preferences.clear(allowList: allowedKeys);
    }
  }

  Future<void> _deleteConnectionSecrets(String connectionId) async {
    final prefix = '$_secretKeyPrefix$connectionId.';
    final secureEntries = await _secureStorage.readAll();
    final matchingKeys = <String>[
      for (final key in secureEntries.keys)
        if (key.startsWith(prefix)) key,
    ];

    for (final key in matchingKeys) {
      await _secureStorage.delete(key: key);
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
    return '$_profileKeyPrefix$connectionId$_profileKeySuffix';
  }

  String _passwordKeyForConnection(String connectionId) {
    return '$_secretKeyPrefix$connectionId$_passwordKeySuffix';
  }

  String _privateKeyKeyForConnection(String connectionId) {
    return '$_secretKeyPrefix$connectionId$_privateKeyKeySuffix';
  }

  String _privateKeyPassphraseKeyForConnection(String connectionId) {
    return '$_secretKeyPrefix$connectionId$_privateKeyPassphraseKeySuffix';
  }
}

String generateConnectionId() {
  final random = Random.secure();
  final buffer = StringBuffer('conn_');
  buffer.write(DateTime.now().microsecondsSinceEpoch.toRadixString(16));
  buffer.write('_');
  for (var index = 0; index < 8; index += 1) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

ConnectionIdGenerator _defaultMemoryConnectionIdGenerator() {
  var nextId = 1;
  return () => 'conn_memory_${nextId++}';
}
