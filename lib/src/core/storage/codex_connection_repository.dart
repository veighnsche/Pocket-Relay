import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_catalog_recovery.dart';

part 'codex_connection_repository_memory.dart';
part 'codex_connection_repository_secure.dart';

typedef ConnectionIdGenerator = String Function();
typedef SystemIdGenerator = String Function();

abstract interface class CodexConnectionRepository {
  Future<WorkspaceCatalogState> loadWorkspaceCatalog();

  Future<SystemCatalogState> loadSystemCatalog();

  Future<SavedWorkspace> loadWorkspace(String workspaceId);

  Future<SavedSystem> loadSystem(String systemId);

  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile});

  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<void> saveWorkspace(SavedWorkspace workspace);

  Future<void> saveSystem(SavedSystem system);

  Future<void> deleteWorkspace(String workspaceId);

  Future<void> deleteSystem(String systemId);

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
    Iterable<SavedWorkspace> initialWorkspaces = const <SavedWorkspace>[],
    Iterable<SavedSystem> initialSystems = const <SavedSystem>[],
    ConnectionIdGenerator? connectionIdGenerator,
    SystemIdGenerator? systemIdGenerator,
  }) : _workspaceIdGenerator =
           connectionIdGenerator ?? _defaultMemoryConnectionIdGenerator(),
       _systemIdGenerator =
           systemIdGenerator ?? _defaultMemorySystemIdGenerator() {
    _seedMemoryRepository(
      this,
      initialConnections: initialConnections,
      initialWorkspaces: initialWorkspaces,
      initialSystems: initialSystems,
    );
  }

  factory MemoryCodexConnectionRepository.single({
    required SavedProfile savedProfile,
    String connectionId = 'conn_1',
  }) {
    return _memoryRepositorySingle(
      savedProfile: savedProfile,
      connectionId: connectionId,
    );
  }

  late final Map<String, SavedWorkspace> _workspacesById;
  late final List<String> _orderedWorkspaceIds;
  late final Map<String, SavedSystem> _systemsById;
  late final List<String> _orderedSystemIds;
  final ConnectionIdGenerator _workspaceIdGenerator;
  final SystemIdGenerator _systemIdGenerator;

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      _memoryLoadWorkspaceCatalog(this);

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      _memoryLoadSystemCatalog(this);

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) =>
      _memoryLoadWorkspace(this, workspaceId);

  @override
  Future<SavedSystem> loadSystem(String systemId) =>
      _memoryLoadSystem(this, systemId);

  @override
  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile}) =>
      _memoryCreateWorkspace(this, profile: profile);

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) => _memoryCreateSystem(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) =>
      _memorySaveWorkspace(this, workspace);

  @override
  Future<void> saveSystem(SavedSystem system) =>
      _memorySaveSystem(this, system);

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      _memoryDeleteWorkspace(this, workspaceId);

  @override
  Future<void> deleteSystem(String systemId) =>
      _memoryDeleteSystem(this, systemId);

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
  static const _workspaceCatalogIndexKey = 'pocket_relay.workspaces.index';
  static const _workspaceCatalogSchemaVersion = 1;
  static const _workspaceProfileKeyPrefix = 'pocket_relay.workspace.';
  static const _workspaceProfileKeySuffix = '.profile';
  static const _systemCatalogIndexKey = 'pocket_relay.systems.index';
  static const _systemCatalogSchemaVersion = 1;
  static const _systemProfileKeyPrefix = 'pocket_relay.system.';
  static const _systemProfileKeySuffix = '.profile';
  static const _systemSecretKeyPrefix = 'pocket_relay.system.';
  static const _systemPasswordKeySuffix = '.secret.password';
  static const _systemPrivateKeyKeySuffix = '.secret.private_key';
  static const _systemPrivateKeyPassphraseKeySuffix =
      '.secret.private_key_passphrase';

  SecureCodexConnectionRepository({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
    ConnectionIdGenerator? connectionIdGenerator,
    SystemIdGenerator? systemIdGenerator,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _workspaceIdGenerator = connectionIdGenerator ?? generateConnectionId,
       _systemIdGenerator = systemIdGenerator ?? generateSystemId;

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  final ConnectionIdGenerator _workspaceIdGenerator;
  final SystemIdGenerator _systemIdGenerator;
  late final CodexConnectionCatalogRecovery _catalogRecovery =
      CodexConnectionCatalogRecovery(
        preferences: _preferences,
        catalogIndexKey: _catalogIndexKey,
        catalogSchemaVersion: _catalogSchemaVersion,
        preferencesMigrationKey: _catalogPreferencesMigrationKey,
        profileKeyPrefix: _profileKeyPrefix,
        profileKeySuffix: _profileKeySuffix,
      );
  Future<void>? _normalizedCatalogsReady;

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      _secureLoadWorkspaceCatalog(this);

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      _secureLoadSystemCatalog(this);

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) =>
      _secureLoadWorkspace(this, workspaceId);

  @override
  Future<SavedSystem> loadSystem(String systemId) =>
      _secureLoadSystem(this, systemId);

  @override
  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile}) =>
      _secureCreateWorkspace(this, profile: profile);

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) => _secureCreateSystem(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) =>
      _secureSaveWorkspace(this, workspace);

  @override
  Future<void> saveSystem(SavedSystem system) =>
      _secureSaveSystem(this, system);

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      _secureDeleteWorkspace(this, workspaceId);

  @override
  Future<void> deleteSystem(String systemId) =>
      _secureDeleteSystem(this, systemId);

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
  return generateEntityId(prefix: 'conn');
}

String generateSystemId() {
  return generateEntityId(prefix: 'sys');
}

String generateEntityId({required String prefix}) {
  final random = Random.secure();
  final buffer = StringBuffer('${prefix}_');
  buffer.write(DateTime.now().microsecondsSinceEpoch.toRadixString(16));
  buffer.write('_');
  for (var index = 0; index < 8; index += 1) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Map<String, ConnectionProfile> _normalizeProfilesWithSharedHostFingerprints({
  required Iterable<String> orderedConnectionIds,
  required Map<String, ConnectionProfile> profilesByConnectionId,
  String? preferredConnectionId,
  required bool overwriteExistingFingerprints,
}) {
  final sharedFingerprintsByHostIdentity =
      _sharedHostFingerprintsByHostIdentity(
        orderedConnectionIds: orderedConnectionIds,
        profilesByConnectionId: profilesByConnectionId,
      );

  final preferredProfile = preferredConnectionId == null
      ? null
      : profilesByConnectionId[preferredConnectionId];
  final preferredHostIdentityKey = preferredProfile?.remoteHostIdentityKey;
  final preferredFingerprint = preferredProfile?.hostFingerprint.trim() ?? '';
  if (preferredHostIdentityKey != null && preferredFingerprint.isNotEmpty) {
    sharedFingerprintsByHostIdentity[preferredHostIdentityKey] =
        preferredFingerprint;
  }

  return <String, ConnectionProfile>{
    for (final entry in profilesByConnectionId.entries)
      entry.key: _normalizeProfileWithSharedHostFingerprint(
        entry.value,
        sharedFingerprintsByHostIdentity: sharedFingerprintsByHostIdentity,
        overwriteExistingFingerprint: overwriteExistingFingerprints,
      ),
  };
}

Map<String, String> _sharedHostFingerprintsByHostIdentity({
  required Iterable<String> orderedConnectionIds,
  required Map<String, ConnectionProfile> profilesByConnectionId,
}) {
  final sharedFingerprintsByHostIdentity = <String, String>{};
  for (final connectionId in orderedConnectionIds) {
    final profile = profilesByConnectionId[connectionId];
    if (profile == null) {
      continue;
    }

    final hostIdentityKey = profile.remoteHostIdentityKey;
    final hostFingerprint = profile.hostFingerprint.trim();
    if (hostIdentityKey == null || hostFingerprint.isEmpty) {
      continue;
    }

    sharedFingerprintsByHostIdentity.putIfAbsent(
      hostIdentityKey,
      () => hostFingerprint,
    );
  }
  return sharedFingerprintsByHostIdentity;
}

ConnectionProfile _normalizeProfileWithSharedHostFingerprint(
  ConnectionProfile profile, {
  required Map<String, String> sharedFingerprintsByHostIdentity,
  required bool overwriteExistingFingerprint,
}) {
  final hostIdentityKey = profile.remoteHostIdentityKey;
  if (hostIdentityKey == null) {
    return profile;
  }

  final sharedFingerprint = sharedFingerprintsByHostIdentity[hostIdentityKey];
  if (sharedFingerprint == null || sharedFingerprint.isEmpty) {
    return profile;
  }

  final currentFingerprint = profile.hostFingerprint.trim();
  if (currentFingerprint == sharedFingerprint) {
    return profile;
  }
  if (currentFingerprint.isNotEmpty && !overwriteExistingFingerprint) {
    return profile;
  }

  return profile.copyWith(hostFingerprint: sharedFingerprint);
}

SavedWorkspace _normalizeWorkspace(SavedWorkspace workspace) {
  final normalizedWorkspaceId = _requireConnectionId(workspace.id);
  final profile = workspace.profile;
  final normalizedSystemId = profile.systemId?.trim();
  return SavedWorkspace(
    id: normalizedWorkspaceId,
    profile: profile.copyWith(
      label: profile.label.trim().isEmpty ? 'Workspace' : profile.label.trim(),
      systemId: normalizedSystemId == null || normalizedSystemId.isEmpty
          ? null
          : normalizedSystemId,
      workspaceDir: profile.workspaceDir.trim(),
      codexPath: profile.codexPath.trim(),
      model: profile.model.trim(),
    ),
  );
}

SavedConnection _normalizeConnection(SavedConnection connection) {
  final normalizedConnectionId = _requireConnectionId(connection.id);
  final normalizedLabel = connection.profile.label.trim();
  return SavedConnection(
    id: normalizedConnectionId,
    profile: connection.profile.copyWith(
      label: normalizedLabel.isEmpty ? 'Workspace' : normalizedLabel,
      host: connection.profile.host.trim(),
      username: connection.profile.username.trim(),
      workspaceDir: connection.profile.workspaceDir.trim(),
      codexPath: connection.profile.codexPath.trim(),
      hostFingerprint: connection.profile.hostFingerprint.trim(),
      model: connection.profile.model.trim(),
    ),
    secrets: connection.secrets,
  );
}

SavedSystem _normalizeSystem(SavedSystem system) {
  final normalizedSystemId = _requireSystemId(system.id);
  final profile = system.profile;
  return SavedSystem(
    id: normalizedSystemId,
    profile: profile.copyWith(
      host: profile.host.trim(),
      username: profile.username.trim(),
      hostFingerprint: profile.hostFingerprint.trim(),
    ),
    secrets: system.secrets.copyWith(
      password: system.secrets.password,
      privateKeyPem: system.secrets.privateKeyPem,
      privateKeyPassphrase: system.secrets.privateKeyPassphrase,
    ),
  );
}

bool _shouldPersistSystem(SystemProfile profile, ConnectionSecrets secrets) {
  final defaults = SystemProfile.defaults();
  return profile.host.trim().isNotEmpty ||
      profile.username.trim().isNotEmpty ||
      profile.hostFingerprint.trim().isNotEmpty ||
      profile.port != defaults.port ||
      profile.authMode != defaults.authMode ||
      !connectionSecretsEqual(secrets, const ConnectionSecrets());
}

String? _systemHostIdentityKey(SystemProfile profile) {
  final normalizedHost = profile.host.trim().toLowerCase();
  if (normalizedHost.isEmpty) {
    return null;
  }
  return '$normalizedHost:${profile.port}';
}

SavedSystem? _matchingSystem(
  Iterable<SavedSystem> systems, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) {
  for (final system in systems) {
    if (_sameSystemIdentity(system.profile, profile) &&
        connectionSecretsEqual(system.secrets, secrets)) {
      return system;
    }
  }
  return null;
}

bool _sameSystemIdentity(SystemProfile left, SystemProfile right) {
  return left.host.trim().toLowerCase() == right.host.trim().toLowerCase() &&
      left.port == right.port &&
      left.username.trim() == right.username.trim() &&
      left.authMode == right.authMode;
}

bool _sameSystemHostIdentity(SystemProfile left, SystemProfile right) {
  final leftKey = _systemHostIdentityKey(left);
  final rightKey = _systemHostIdentityKey(right);
  return leftKey != null && leftKey == rightKey;
}

String _sharedFingerprintForHost(
  Iterable<SavedSystem> systems,
  SystemProfile profile,
) {
  for (final system in systems) {
    if (!_sameSystemHostIdentity(system.profile, profile)) {
      continue;
    }
    final fingerprint = system.profile.hostFingerprint.trim();
    if (fingerprint.isNotEmpty) {
      return fingerprint;
    }
  }
  return '';
}

SystemProfile _normalizeSystemFingerprintFromHostIdentity(
  SystemProfile profile,
  Iterable<SavedSystem> systems,
) {
  if (profile.hostFingerprint.trim().isNotEmpty) {
    return profile;
  }
  final sharedFingerprint = _sharedFingerprintForHost(systems, profile);
  if (sharedFingerprint.isEmpty) {
    return profile;
  }
  return profile.copyWith(hostFingerprint: sharedFingerprint);
}

SystemProfile _mergeSystemFingerprint(
  SystemProfile existing,
  SystemProfile incoming,
) {
  final incomingFingerprint = incoming.hostFingerprint.trim();
  if (incomingFingerprint.isEmpty ||
      existing.hostFingerprint.trim() == incomingFingerprint) {
    return existing;
  }
  return existing.copyWith(hostFingerprint: incomingFingerprint);
}

int _workspaceCountForSystem(
  Iterable<SavedWorkspace> workspaces,
  String systemId,
) {
  var count = 0;
  for (final workspace in workspaces) {
    if (workspace.profile.systemId == systemId) {
      count += 1;
    }
  }
  return count;
}

String _requireSystemId(String systemId) {
  final normalizedSystemId = systemId.trim();
  if (normalizedSystemId.isEmpty) {
    throw ArgumentError.value(
      systemId,
      'systemId',
      'System id must not be empty.',
    );
  }
  return normalizedSystemId;
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

ConnectionIdGenerator _defaultMemoryConnectionIdGenerator() {
  var nextId = 1;
  return () => 'conn_memory_${nextId++}';
}

SystemIdGenerator _defaultMemorySystemIdGenerator() {
  var nextId = 1;
  return () => 'sys_memory_${nextId++}';
}
