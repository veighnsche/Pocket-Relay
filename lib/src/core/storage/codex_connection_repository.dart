import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_catalog_recovery.dart';

part 'codex_connection_repository_memory.dart';
part 'codex_connection_repository_secure.dart';

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
    return _memoryRepositorySingle(
      savedProfile: savedProfile,
      connectionId: connectionId,
    );
  }

  final Map<String, SavedConnection> _connectionsById;
  final List<String> _orderedConnectionIds;
  final ConnectionIdGenerator _connectionIdGenerator;

  @override
  Future<ConnectionCatalogState> loadCatalog() => _memoryLoadCatalog(this);

  @override
  Future<SavedConnection> loadConnection(String connectionId) =>
      _memoryLoadConnection(this, connectionId);

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => _memoryCreateConnection(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      _memorySaveConnection(this, connection);

  @override
  Future<void> deleteConnection(String connectionId) =>
      _memoryDeleteConnection(this, connectionId);
}

class SecureCodexConnectionRepository implements CodexConnectionRepository {
  static const _catalogIndexKey = 'pocket_relay.connections.index';
  static const _catalogSchemaVersion = 1;
  static const _catalogPreferencesMigrationKey =
      'pocket_relay.connections_async_migration_complete';
  static const _legacySingletonProfileKey = 'pocket_relay.profile';
  static const _legacySingletonPasswordKey = 'pocket_relay.secret.password';
  static const _legacySingletonPrivateKeyKey =
      'pocket_relay.secret.private_key';
  static const _legacySingletonPrivateKeyPassphraseKey =
      'pocket_relay.secret.private_key_passphrase';
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
  Future<ConnectionCatalogState> loadCatalog() => _secureLoadCatalog(this);

  @override
  Future<SavedConnection> loadConnection(String connectionId) =>
      _secureLoadConnection(this, connectionId);

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => _secureCreateConnection(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      _secureSaveConnection(this, connection);

  @override
  Future<void> deleteConnection(String connectionId) =>
      _secureDeleteConnection(this, connectionId);
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
