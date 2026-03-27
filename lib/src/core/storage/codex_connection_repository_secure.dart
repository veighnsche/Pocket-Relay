part of 'codex_connection_repository.dart';

Future<ConnectionCatalogState> _secureLoadCatalog(
  SecureCodexConnectionRepository repository,
) async {
  final workspaceCatalog = await repository.loadWorkspaceCatalog();
  final systemCatalog = await repository.loadSystemCatalog();
  return resolvedConnectionCatalogFromWorkspaces(
    workspaceCatalog: workspaceCatalog,
    systemCatalog: systemCatalog,
  );
}

Future<WorkspaceCatalogState> _secureLoadWorkspaceCatalog(
  SecureCodexConnectionRepository repository,
) async {
  await _ensureSecureCatalogsReady(repository);
  final orderedIds = await _loadOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
    discoveredIds: await _discoverStoredIds(
      repository._preferences,
      prefix: SecureCodexConnectionRepository._workspaceProfileKeyPrefix,
      suffix: SecureCodexConnectionRepository._workspaceProfileKeySuffix,
    ),
  );
  final profiles = await repository._preferences.getAll(
    allowList: orderedIds.map(_workspaceProfileKeyForWorkspace).toSet(),
  );

  final workspacesById = <String, SavedWorkspaceSummary>{};
  final normalizedOrderedIds = <String>[];
  for (final workspaceId in orderedIds) {
    final rawProfile = profiles[_workspaceProfileKeyForWorkspace(workspaceId)];
    if (rawProfile is! String || rawProfile.trim().isEmpty) {
      continue;
    }
    normalizedOrderedIds.add(workspaceId);
    workspacesById[workspaceId] = SavedWorkspaceSummary(
      id: workspaceId,
      profile: WorkspaceProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      ),
    );
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await _persistOrderedIds(
      repository._preferences,
      indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
      schemaVersion:
          SecureCodexConnectionRepository._workspaceCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  return WorkspaceCatalogState(
    orderedWorkspaceIds: normalizedOrderedIds,
    workspacesById: workspacesById,
  );
}

Future<SystemCatalogState> _secureLoadSystemCatalog(
  SecureCodexConnectionRepository repository,
) async {
  await _ensureSecureCatalogsReady(repository);
  final orderedIds = await _loadOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
    discoveredIds: await _discoverStoredIds(
      repository._preferences,
      prefix: SecureCodexConnectionRepository._systemProfileKeyPrefix,
      suffix: SecureCodexConnectionRepository._systemProfileKeySuffix,
    ),
  );
  final profiles = await repository._preferences.getAll(
    allowList: orderedIds.map(_systemProfileKeyForSystem).toSet(),
  );

  final systemsById = <String, SavedSystemSummary>{};
  final normalizedOrderedIds = <String>[];
  for (final systemId in orderedIds) {
    final rawProfile = profiles[_systemProfileKeyForSystem(systemId)];
    if (rawProfile is! String || rawProfile.trim().isEmpty) {
      continue;
    }
    normalizedOrderedIds.add(systemId);
    systemsById[systemId] = SavedSystemSummary(
      id: systemId,
      profile: SystemProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      ),
    );
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await _persistOrderedIds(
      repository._preferences,
      indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
      schemaVersion:
          SecureCodexConnectionRepository._systemCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  return SystemCatalogState(
    orderedSystemIds: normalizedOrderedIds,
    systemsById: systemsById,
  );
}

Future<SavedWorkspace> _secureLoadWorkspace(
  SecureCodexConnectionRepository repository,
  String workspaceId,
) async {
  final normalizedWorkspaceId = _requireConnectionId(workspaceId);
  final catalog = await repository.loadWorkspaceCatalog();
  final summary = catalog.workspaceForId(normalizedWorkspaceId);
  if (summary == null) {
    throw StateError('Unknown saved workspace: $normalizedWorkspaceId');
  }
  return SavedWorkspace(id: summary.id, profile: summary.profile);
}

Future<SavedSystem> _secureLoadSystem(
  SecureCodexConnectionRepository repository,
  String systemId,
) async {
  final normalizedSystemId = _requireSystemId(systemId);
  final catalog = await repository.loadSystemCatalog();
  final summary = catalog.systemForId(normalizedSystemId);
  if (summary == null) {
    throw StateError('Unknown saved system: $normalizedSystemId');
  }
  return SavedSystem(
    id: summary.id,
    profile: summary.profile,
    secrets: await _readSystemSecrets(repository, normalizedSystemId),
  );
}

Future<SavedConnection> _secureLoadConnection(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  final workspace = await repository.loadWorkspace(connectionId);
  final system = await _secureLoadSystemForWorkspace(
    repository,
    workspace.profile,
  );
  return resolvedConnectionForWorkspace(
    workspaceId: workspace.id,
    workspace: workspace.profile,
    system: system,
  );
}

Future<SavedWorkspace> _secureCreateWorkspace(
  SecureCodexConnectionRepository repository, {
  required WorkspaceProfile profile,
}) async {
  final catalog = await repository.loadWorkspaceCatalog();
  late SavedWorkspace workspace;
  do {
    workspace = SavedWorkspace(
      id: repository._workspaceIdGenerator(),
      profile: profile,
    );
  } while (catalog.workspaceForId(workspace.id) != null);

  await repository.saveWorkspace(workspace);
  return workspace;
}

Future<SavedSystem> _secureCreateSystem(
  SecureCodexConnectionRepository repository, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final catalog = await repository.loadSystemCatalog();
  late SavedSystem system;
  do {
    system = SavedSystem(
      id: repository._systemIdGenerator(),
      profile: profile,
      secrets: secrets,
    );
  } while (catalog.systemForId(system.id) != null);

  await repository.saveSystem(system);
  return system;
}

Future<SavedConnection> _secureCreateConnection(
  SecureCodexConnectionRepository repository, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final workspace = await repository.createWorkspace(
    profile: workspaceProfileFromConnectionProfile(profile, systemId: null),
  );
  await _securePersistResolvedConnection(
    repository,
    SavedConnection(id: workspace.id, profile: profile, secrets: secrets),
  );
  return repository.loadConnection(workspace.id);
}

Future<void> _secureSaveWorkspace(
  SecureCodexConnectionRepository repository,
  SavedWorkspace workspace,
) async {
  await _ensureSecureCatalogsReady(repository);
  final normalizedWorkspace = _normalizeWorkspace(workspace);
  final catalog = await repository.loadWorkspaceCatalog();
  final exists = catalog.workspaceForId(normalizedWorkspace.id) != null;
  final orderedWorkspaceIds = exists
      ? catalog.orderedWorkspaceIds
      : <String>[...catalog.orderedWorkspaceIds, normalizedWorkspace.id];

  await _persistWorkspaceProfile(
    repository,
    workspaceId: normalizedWorkspace.id,
    profile: normalizedWorkspace.profile,
  );
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
    schemaVersion:
        SecureCodexConnectionRepository._workspaceCatalogSchemaVersion,
    orderedIds: orderedWorkspaceIds,
  );
}

Future<void> _secureSaveSystem(
  SecureCodexConnectionRepository repository,
  SavedSystem system,
) async {
  await _ensureSecureCatalogsReady(repository);
  final normalizedSystem = _normalizeSystem(system);
  final catalog = await repository.loadSystemCatalog();
  final exists = catalog.systemForId(normalizedSystem.id) != null;
  final orderedSystemIds = exists
      ? catalog.orderedSystemIds
      : <String>[...catalog.orderedSystemIds, normalizedSystem.id];

  await _persistSystemProfile(
    repository,
    systemId: normalizedSystem.id,
    profile: normalizedSystem.profile,
  );
  await _persistSystemSecrets(repository, normalizedSystem);
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
    schemaVersion: SecureCodexConnectionRepository._systemCatalogSchemaVersion,
    orderedIds: orderedSystemIds,
  );
}

Future<void> _secureSaveConnection(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  await _securePersistResolvedConnection(repository, connection);
}

Future<void> _secureDeleteWorkspace(
  SecureCodexConnectionRepository repository,
  String workspaceId,
) async {
  await _ensureSecureCatalogsReady(repository);
  final normalizedWorkspaceId = _requireConnectionId(workspaceId);
  final catalog = await repository.loadWorkspaceCatalog();
  if (catalog.workspaceForId(normalizedWorkspaceId) == null) {
    return;
  }

  final nextOrderedWorkspaceIds = catalog.orderedWorkspaceIds
      .where((id) => id != normalizedWorkspaceId)
      .toList(growable: false);
  await repository._preferences.remove(
    _workspaceProfileKeyForWorkspace(normalizedWorkspaceId),
  );
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
    schemaVersion:
        SecureCodexConnectionRepository._workspaceCatalogSchemaVersion,
    orderedIds: nextOrderedWorkspaceIds,
  );
}

Future<void> _secureDeleteSystem(
  SecureCodexConnectionRepository repository,
  String systemId,
) async {
  await _ensureSecureCatalogsReady(repository);
  final normalizedSystemId = _requireSystemId(systemId);
  final systemCatalog = await repository.loadSystemCatalog();
  if (systemCatalog.systemForId(normalizedSystemId) == null) {
    return;
  }

  final workspaceCatalog = await repository.loadWorkspaceCatalog();
  if (_workspaceCountForSystem(
        workspaceCatalog.orderedWorkspaces.map(
          (summary) => SavedWorkspace(id: summary.id, profile: summary.profile),
        ),
        normalizedSystemId,
      ) >
      0) {
    throw StateError(
      'Cannot delete a system that is still used by a workspace.',
    );
  }

  final nextOrderedSystemIds = systemCatalog.orderedSystemIds
      .where((id) => id != normalizedSystemId)
      .toList(growable: false);
  await repository._preferences.remove(
    _systemProfileKeyForSystem(normalizedSystemId),
  );
  await _deleteSystemSecrets(repository, normalizedSystemId);
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
    schemaVersion: SecureCodexConnectionRepository._systemCatalogSchemaVersion,
    orderedIds: nextOrderedSystemIds,
  );
}

Future<void> _secureDeleteConnection(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  await repository.deleteWorkspace(connectionId);
  await _deleteLegacyConnectionNamespace(repository, connectionId);
}

Future<void> _ensureSecureCatalogsReady(
  SecureCodexConnectionRepository repository,
) {
  return repository._normalizedCatalogsReady ??= _secureMigrateCatalogsIfNeeded(
    repository,
  );
}

Future<void> _secureMigrateCatalogsIfNeeded(
  SecureCodexConnectionRepository repository,
) async {
  await repository._catalogRecovery.ensurePreferencesReady();
  final legacySingletonConnection = await _readLegacySingletonConnection(
    repository,
  );

  final existingWorkspaceIds = await _discoverStoredIds(
    repository._preferences,
    prefix: SecureCodexConnectionRepository._workspaceProfileKeyPrefix,
    suffix: SecureCodexConnectionRepository._workspaceProfileKeySuffix,
  );
  final existingSystemIds = await _discoverStoredIds(
    repository._preferences,
    prefix: SecureCodexConnectionRepository._systemProfileKeyPrefix,
    suffix: SecureCodexConnectionRepository._systemProfileKeySuffix,
  );
  final rawWorkspaceIndex = await repository._preferences.getString(
    SecureCodexConnectionRepository._workspaceCatalogIndexKey,
  );
  final rawSystemIndex = await repository._preferences.getString(
    SecureCodexConnectionRepository._systemCatalogIndexKey,
  );

  if (existingWorkspaceIds.isNotEmpty ||
      existingSystemIds.isNotEmpty ||
      (rawWorkspaceIndex?.trim().isNotEmpty ?? false) ||
      (rawSystemIndex?.trim().isNotEmpty ?? false)) {
    await _persistOrderedIds(
      repository._preferences,
      indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
      schemaVersion:
          SecureCodexConnectionRepository._workspaceCatalogSchemaVersion,
      orderedIds: await _loadOrderedIds(
        repository._preferences,
        indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
        discoveredIds: existingWorkspaceIds,
      ),
    );
    await _persistOrderedIds(
      repository._preferences,
      indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
      schemaVersion:
          SecureCodexConnectionRepository._systemCatalogSchemaVersion,
      orderedIds: await _loadOrderedIds(
        repository._preferences,
        indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
        discoveredIds: existingSystemIds,
      ),
    );
    return;
  }

  final legacyCatalog = await repository._catalogRecovery.loadCatalog();
  if (legacyCatalog == null || legacyCatalog.isEmpty) {
    final seededConnectionId = repository._workspaceIdGenerator();
    final seededConnection =
        legacySingletonConnection ??
        SavedConnection(
          id: seededConnectionId,
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        );
    await _migrateLegacyConnectionsIntoSplitStorage(
      repository,
      legacyConnections: <SavedConnection>[
        seededConnection.copyWith(id: seededConnectionId),
      ],
    );
    if (legacySingletonConnection != null) {
      await _deleteLegacySingletonStorage(repository);
    }
    return;
  }

  final legacyConnections = <SavedConnection>[];
  var pendingSingletonUpgrade = legacySingletonConnection;
  for (final connectionId in legacyCatalog.orderedConnectionIds) {
    final summary = legacyCatalog.connectionForId(connectionId);
    if (summary == null) {
      continue;
    }

    final migratedConnection =
        pendingSingletonUpgrade != null &&
            summary.profile == ConnectionProfile.defaults()
        ? pendingSingletonUpgrade.copyWith(id: connectionId)
        : SavedConnection(
            id: connectionId,
            profile: summary.profile,
            secrets: await _readLegacyConnectionSecrets(
              repository,
              connectionId,
            ),
          );
    if (pendingSingletonUpgrade != null &&
        migratedConnection.id == connectionId &&
        migratedConnection.profile == pendingSingletonUpgrade.profile &&
        connectionSecretsEqual(
          migratedConnection.secrets,
          pendingSingletonUpgrade.secrets,
        )) {
      pendingSingletonUpgrade = null;
    }
    legacyConnections.add(migratedConnection);
  }

  await _migrateLegacyConnectionsIntoSplitStorage(
    repository,
    legacyConnections: legacyConnections,
  );
  await _deleteLegacyConnections(
    repository,
    legacyCatalog.orderedConnectionIds,
  );
  await _deleteLegacySingletonStorage(repository);
}

Future<void> _migrateLegacyConnectionsIntoSplitStorage(
  SecureCodexConnectionRepository repository, {
  required List<SavedConnection> legacyConnections,
}) async {
  final migratedSystemsById = <String, SavedSystem>{};
  final migratedWorkspacesById = <String, SavedWorkspace>{};
  final orderedSystemIds = <String>[];
  final orderedWorkspaceIds = <String>[];
  for (final legacyConnection in legacyConnections) {
    final normalizedConnection = _normalizeConnection(legacyConnection);
    String? systemId;
    final resolvedSystemProfile = _normalizeSystemFingerprintFromHostIdentity(
      systemProfileFromConnectionProfile(normalizedConnection.profile),
      migratedSystemsById.values,
    );
    if (normalizedConnection.profile.isRemote &&
        _shouldPersistSystem(
          resolvedSystemProfile,
          normalizedConnection.secrets,
        )) {
      final existingSystem = _matchingSystem(
        migratedSystemsById.values,
        profile: resolvedSystemProfile,
        secrets: normalizedConnection.secrets,
      );
      systemId = existingSystem?.id;
      if (existingSystem != null) {
        final mergedProfile = _mergeSystemFingerprint(
          existingSystem.profile,
          resolvedSystemProfile,
        );
        if (mergedProfile != existingSystem.profile) {
          migratedSystemsById[existingSystem.id] = existingSystem.copyWith(
            profile: mergedProfile,
          );
        }
      }
      if (systemId == null) {
        systemId = repository._systemIdGenerator();
        final savedSystem = SavedSystem(
          id: systemId,
          profile: resolvedSystemProfile,
          secrets: normalizedConnection.secrets,
        );
        migratedSystemsById[systemId] = savedSystem;
        orderedSystemIds.add(systemId);
      }
      final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
      if (fingerprintToShare.isNotEmpty) {
        for (final entry in migratedSystemsById.entries.toList()) {
          final savedSystem = entry.value;
          if (!_sameSystemHostIdentity(
                savedSystem.profile,
                resolvedSystemProfile,
              ) ||
              savedSystem.profile.hostFingerprint.trim() ==
                  fingerprintToShare) {
            continue;
          }
          migratedSystemsById[entry.key] = savedSystem.copyWith(
            profile: savedSystem.profile.copyWith(
              hostFingerprint: fingerprintToShare,
            ),
          );
        }
      }
    }

    migratedWorkspacesById[normalizedConnection.id] = SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    );
    orderedWorkspaceIds.add(normalizedConnection.id);
  }

  for (final systemId in orderedSystemIds) {
    final system = migratedSystemsById[systemId];
    if (system == null) {
      continue;
    }
    await _persistSystemProfile(
      repository,
      systemId: systemId,
      profile: system.profile,
    );
    await _persistSystemSecrets(repository, system);
  }
  for (final workspaceId in orderedWorkspaceIds) {
    final workspace = migratedWorkspacesById[workspaceId];
    if (workspace == null) {
      continue;
    }
    await _persistWorkspaceProfile(
      repository,
      workspaceId: workspaceId,
      profile: workspace.profile,
    );
  }
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._workspaceCatalogIndexKey,
    schemaVersion:
        SecureCodexConnectionRepository._workspaceCatalogSchemaVersion,
    orderedIds: orderedWorkspaceIds,
  );
  await _persistOrderedIds(
    repository._preferences,
    indexKey: SecureCodexConnectionRepository._systemCatalogIndexKey,
    schemaVersion: SecureCodexConnectionRepository._systemCatalogSchemaVersion,
    orderedIds: orderedSystemIds,
  );
}

Future<void> _securePersistResolvedConnection(
  SecureCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  final normalizedConnection = _normalizeConnection(connection);
  SavedWorkspace? existingWorkspace;
  try {
    existingWorkspace = await repository.loadWorkspace(normalizedConnection.id);
  } catch (_) {}

  String? systemId;
  final systemCatalog = await repository.loadSystemCatalog();
  final orderedSystems = await _loadOrderedSystems(
    repository,
    systemCatalog.orderedSystemIds,
  );
  final resolvedSystemProfile = _normalizeSystemFingerprintFromHostIdentity(
    systemProfileFromConnectionProfile(normalizedConnection.profile),
    orderedSystems,
  );
  if (normalizedConnection.profile.isRemote &&
      _shouldPersistSystem(
        resolvedSystemProfile,
        normalizedConnection.secrets,
      )) {
    final existingSystem = _matchingSystem(
      orderedSystems,
      profile: resolvedSystemProfile,
      secrets: normalizedConnection.secrets,
    );
    systemId = existingSystem?.id;
    if (existingSystem != null) {
      final mergedProfile = _mergeSystemFingerprint(
        existingSystem.profile,
        resolvedSystemProfile,
      );
      if (mergedProfile != existingSystem.profile) {
        await repository.saveSystem(
          existingSystem.copyWith(profile: mergedProfile),
        );
      }
    }
    if (systemId == null) {
      final currentSystemId = existingWorkspace?.profile.systemId?.trim();
      if (currentSystemId != null && currentSystemId.isNotEmpty) {
        systemId = currentSystemId;
        await repository.saveSystem(
          SavedSystem(
            id: systemId,
            profile: resolvedSystemProfile,
            secrets: normalizedConnection.secrets,
          ),
        );
      } else {
        final system = await repository.createSystem(
          profile: resolvedSystemProfile,
          secrets: normalizedConnection.secrets,
        );
        systemId = system.id;
      }
    }
    final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
    if (fingerprintToShare.isNotEmpty) {
      for (final savedSystem in orderedSystems) {
        if (!_sameSystemHostIdentity(
              savedSystem.profile,
              resolvedSystemProfile,
            ) ||
            savedSystem.profile.hostFingerprint.trim() == fingerprintToShare) {
          continue;
        }
        await repository.saveSystem(
          savedSystem.copyWith(
            profile: savedSystem.profile.copyWith(
              hostFingerprint: fingerprintToShare,
            ),
          ),
        );
      }
    }
  }

  await repository.saveWorkspace(
    SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    ),
  );
}

Future<List<SavedSystem>> _loadOrderedSystems(
  SecureCodexConnectionRepository repository,
  List<String> orderedSystemIds,
) async {
  final systems = <SavedSystem>[];
  for (final systemId in orderedSystemIds) {
    try {
      systems.add(await repository.loadSystem(systemId));
    } catch (_) {}
  }
  return systems;
}

Future<SavedSystem?> _secureLoadSystemForWorkspace(
  SecureCodexConnectionRepository repository,
  WorkspaceProfile workspace,
) async {
  final systemId = workspace.systemId?.trim();
  if (systemId == null || systemId.isEmpty) {
    return null;
  }
  try {
    return await repository.loadSystem(systemId);
  } catch (_) {
    return null;
  }
}

Future<List<String>> _discoverStoredIds(
  SharedPreferencesAsync preferences, {
  required String prefix,
  required String suffix,
}) async {
  final keys = await preferences.getKeys();
  final ids = <String>[];
  for (final key in keys) {
    if (!key.startsWith(prefix) || !key.endsWith(suffix)) {
      continue;
    }
    final id = key.substring(prefix.length, key.length - suffix.length).trim();
    if (id.isNotEmpty) {
      ids.add(id);
    }
  }
  ids.sort();
  return ids;
}

Future<List<String>> _loadOrderedIds(
  SharedPreferencesAsync preferences, {
  required String indexKey,
  required List<String> discoveredIds,
}) async {
  final rawIndex = await preferences.getString(indexKey);
  if (rawIndex == null || rawIndex.trim().isEmpty) {
    return discoveredIds;
  }

  final decoded = jsonDecode(rawIndex);
  if (decoded is! Map<String, dynamic>) {
    return discoveredIds;
  }
  final rawOrderedIds = decoded['orderedIds'];
  if (rawOrderedIds is! List) {
    return discoveredIds;
  }
  final orderedIds = <String>[
    for (final value in rawOrderedIds)
      if (value is String && value.trim().isNotEmpty) value.trim(),
  ];
  final extraIds =
      discoveredIds.where((id) => !orderedIds.contains(id)).toList()..sort();
  return <String>[...orderedIds, ...extraIds];
}

Future<void> _persistOrderedIds(
  SharedPreferencesAsync preferences, {
  required String indexKey,
  required int schemaVersion,
  required List<String> orderedIds,
}) async {
  await preferences.setString(
    indexKey,
    jsonEncode(<String, Object?>{
      'schemaVersion': schemaVersion,
      'orderedIds': orderedIds,
    }),
  );
}

Future<void> _persistWorkspaceProfile(
  SecureCodexConnectionRepository repository, {
  required String workspaceId,
  required WorkspaceProfile profile,
}) async {
  await repository._preferences.setString(
    _workspaceProfileKeyForWorkspace(workspaceId),
    jsonEncode(profile.toJson()),
  );
}

Future<void> _persistSystemProfile(
  SecureCodexConnectionRepository repository, {
  required String systemId,
  required SystemProfile profile,
}) async {
  await repository._preferences.setString(
    _systemProfileKeyForSystem(systemId),
    jsonEncode(profile.toJson()),
  );
}

Future<void> _persistSystemSecrets(
  SecureCodexConnectionRepository repository,
  SavedSystem system,
) async {
  await _writeSecret(
    repository._secureStorage,
    _systemPasswordKeyForSystem(system.id),
    system.secrets.password,
  );
  await _writeSecret(
    repository._secureStorage,
    _systemPrivateKeyKeyForSystem(system.id),
    system.secrets.privateKeyPem,
  );
  await _writeSecret(
    repository._secureStorage,
    _systemPrivateKeyPassphraseKeyForSystem(system.id),
    system.secrets.privateKeyPassphrase,
  );
}

Future<ConnectionSecrets> _readSystemSecrets(
  SecureCodexConnectionRepository repository,
  String systemId,
) async {
  return ConnectionSecrets(
    password: await _readSecret(
      repository._secureStorage,
      _systemPasswordKeyForSystem(systemId),
    ),
    privateKeyPem: await _readSecret(
      repository._secureStorage,
      _systemPrivateKeyKeyForSystem(systemId),
    ),
    privateKeyPassphrase: await _readSecret(
      repository._secureStorage,
      _systemPrivateKeyPassphraseKeyForSystem(systemId),
    ),
  );
}

Future<void> _deleteSystemSecrets(
  SecureCodexConnectionRepository repository,
  String systemId,
) async {
  await repository._secureStorage.delete(
    key: _systemPasswordKeyForSystem(systemId),
  );
  await repository._secureStorage.delete(
    key: _systemPrivateKeyKeyForSystem(systemId),
  );
  await repository._secureStorage.delete(
    key: _systemPrivateKeyPassphraseKeyForSystem(systemId),
  );
}

Future<ConnectionSecrets> _readLegacyConnectionSecrets(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  return ConnectionSecrets(
    password: await _readSecret(
      repository._secureStorage,
      _passwordKeyForConnection(connectionId),
    ),
    privateKeyPem: await _readSecret(
      repository._secureStorage,
      _privateKeyKeyForConnection(connectionId),
    ),
    privateKeyPassphrase: await _readSecret(
      repository._secureStorage,
      _privateKeyPassphraseKeyForConnection(connectionId),
    ),
  );
}

Future<SavedConnection?> _readLegacySingletonConnection(
  SecureCodexConnectionRepository repository,
) async {
  final rawProfile = await repository._preferences.getString(
    SecureCodexConnectionRepository._legacySingletonProfileKey,
  );
  if (rawProfile == null || rawProfile.trim().isEmpty) {
    return null;
  }

  try {
    return SavedConnection(
      id: '',
      profile: ConnectionProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      ),
      secrets: ConnectionSecrets(
        password: await _readSecret(
          repository._secureStorage,
          SecureCodexConnectionRepository._legacySingletonPasswordKey,
        ),
        privateKeyPem: await _readSecret(
          repository._secureStorage,
          SecureCodexConnectionRepository._legacySingletonPrivateKeyKey,
        ),
        privateKeyPassphrase: await _readSecret(
          repository._secureStorage,
          SecureCodexConnectionRepository
              ._legacySingletonPrivateKeyPassphraseKey,
        ),
      ),
    );
  } catch (_) {
    return null;
  }
}

Future<void> _deleteLegacyConnections(
  SecureCodexConnectionRepository repository,
  List<String> connectionIds,
) async {
  for (final connectionId in connectionIds) {
    await _deleteLegacyConnectionNamespace(repository, connectionId);
  }
  await repository._preferences.remove(
    SecureCodexConnectionRepository._catalogIndexKey,
  );
}

Future<void> _deleteLegacyConnectionNamespace(
  SecureCodexConnectionRepository repository,
  String connectionId,
) async {
  await repository._preferences.remove(_profileKeyForConnection(connectionId));
  final legacyKeyPrefix =
      '${SecureCodexConnectionRepository._secretKeyPrefix}$connectionId.';
  final allSecureKeys = await repository._secureStorage.readAll();
  for (final key in allSecureKeys.keys) {
    if (key.startsWith(legacyKeyPrefix)) {
      await repository._secureStorage.delete(key: key);
    }
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
    key:
        SecureCodexConnectionRepository._legacySingletonPrivateKeyPassphraseKey,
  );
}

Future<void> _writeSecret(
  FlutterSecureStorage secureStorage,
  String key,
  String value,
) async {
  if (value.trim().isEmpty) {
    await secureStorage.delete(key: key);
    return;
  }
  await secureStorage.write(key: key, value: value);
}

Future<String> _readSecret(
  FlutterSecureStorage secureStorage,
  String key,
) async {
  return await secureStorage.read(key: key) ?? '';
}

String _workspaceProfileKeyForWorkspace(String workspaceId) {
  return '${SecureCodexConnectionRepository._workspaceProfileKeyPrefix}$workspaceId${SecureCodexConnectionRepository._workspaceProfileKeySuffix}';
}

String _systemProfileKeyForSystem(String systemId) {
  return '${SecureCodexConnectionRepository._systemProfileKeyPrefix}$systemId${SecureCodexConnectionRepository._systemProfileKeySuffix}';
}

String _systemPasswordKeyForSystem(String systemId) {
  return '${SecureCodexConnectionRepository._systemSecretKeyPrefix}$systemId${SecureCodexConnectionRepository._systemPasswordKeySuffix}';
}

String _systemPrivateKeyKeyForSystem(String systemId) {
  return '${SecureCodexConnectionRepository._systemSecretKeyPrefix}$systemId${SecureCodexConnectionRepository._systemPrivateKeyKeySuffix}';
}

String _systemPrivateKeyPassphraseKeyForSystem(String systemId) {
  return '${SecureCodexConnectionRepository._systemSecretKeyPrefix}$systemId${SecureCodexConnectionRepository._systemPrivateKeyPassphraseKeySuffix}';
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
