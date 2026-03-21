import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_async_migration.dart';

/// Owns compatibility and recovery for the preferences-backed connection
/// catalog so the repository can stay focused on steady-state CRUD.
class CodexConnectionCatalogRecovery {
  CodexConnectionCatalogRecovery({
    required SharedPreferencesAsync preferences,
    required this.catalogIndexKey,
    required this.catalogSchemaVersion,
    required this.preferencesMigrationKey,
    required this.profileKeyPrefix,
    required this.profileKeySuffix,
  }) : _preferences = preferences;

  final SharedPreferencesAsync _preferences;
  final String catalogIndexKey;
  final int catalogSchemaVersion;
  final String preferencesMigrationKey;
  final String profileKeyPrefix;
  final String profileKeySuffix;
  Future<void>? _preferencesReady;

  Future<void> ensurePreferencesReady() {
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: preferencesMigrationKey,
    );
  }

  Future<ConnectionCatalogState?> loadCatalog() async {
    final rawIndex = await _preferences.getString(catalogIndexKey);
    final profileConnectionIds = await _discoverProfileConnectionIds();

    if (rawIndex == null || rawIndex.trim().isEmpty) {
      if (profileConnectionIds.isEmpty) {
        return null;
      }

      final recoveredCatalog = await _buildCatalog(profileConnectionIds);
      await persistCatalogIndex(recoveredCatalog.orderedConnectionIds);
      return recoveredCatalog;
    }

    final orderedConnectionIds = _decodeCatalogIndex(rawIndex);
    final extraConnectionIds =
        profileConnectionIds
            .where((id) => !orderedConnectionIds.contains(id))
            .toList(growable: false)
          ..sort();
    final candidateConnectionIds = <String>[
      ...orderedConnectionIds,
      ...extraConnectionIds,
    ];
    final catalog = await _buildCatalog(candidateConnectionIds);

    if (!listEquals(catalog.orderedConnectionIds, orderedConnectionIds)) {
      await persistCatalogIndex(catalog.orderedConnectionIds);
    }

    return catalog;
  }

  Future<void> persistCatalogIndex(List<String> orderedConnectionIds) async {
    await _preferences.setString(
      catalogIndexKey,
      jsonEncode(<String, Object?>{
        'schemaVersion': catalogSchemaVersion,
        'orderedConnectionIds': orderedConnectionIds,
      }),
    );
  }

  Future<ConnectionCatalogState> _buildCatalog(
    List<String> candidateConnectionIds,
  ) async {
    if (candidateConnectionIds.isEmpty) {
      return const ConnectionCatalogState.empty();
    }

    final profileValues = await _preferences.getAll(
      allowList: candidateConnectionIds.map(_profileKeyForConnection).toSet(),
    );
    final orderedConnectionIds = <String>[];
    final connectionsById = <String, SavedConnectionSummary>{};

    for (final connectionId in candidateConnectionIds) {
      final rawProfile = profileValues[_profileKeyForConnection(connectionId)];
      if (rawProfile is! String || rawProfile.trim().isEmpty) {
        continue;
      }

      orderedConnectionIds.add(connectionId);
      final profile = _normalizeLegacySeededProfile(
        ConnectionProfile.fromJson(
          jsonDecode(rawProfile) as Map<String, dynamic>,
        ),
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

  Future<List<String>> _discoverProfileConnectionIds() async {
    final keys = await _preferences.getKeys();
    final connectionIds = <String>[];

    for (final key in keys) {
      if (!key.startsWith(profileKeyPrefix) ||
          !key.endsWith(profileKeySuffix)) {
        continue;
      }

      final connectionId = key.substring(
        profileKeyPrefix.length,
        key.length - profileKeySuffix.length,
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

  List<String> _decodeCatalogIndex(String rawIndex) {
    final decoded = jsonDecode(rawIndex);
    if (decoded is! Map<String, dynamic>) {
      return const <String>[];
    }

    final rawOrderedConnectionIds = decoded['orderedConnectionIds'];
    if (rawOrderedConnectionIds is! List) {
      return const <String>[];
    }

    final orderedConnectionIds = <String>[];
    for (final value in rawOrderedConnectionIds) {
      if (value is! String) {
        continue;
      }
      final normalizedConnectionId = value.trim();
      if (normalizedConnectionId.isEmpty ||
          orderedConnectionIds.contains(normalizedConnectionId)) {
        continue;
      }
      orderedConnectionIds.add(normalizedConnectionId);
    }
    return orderedConnectionIds;
  }

  ConnectionProfile _normalizeLegacySeededProfile(ConnectionProfile profile) {
    final trimmedWorkspaceDir = profile.workspaceDir.trim();
    if (!ConnectionProfile.legacyWorkspaceDirPlaceholders.contains(
      trimmedWorkspaceDir,
    )) {
      return profile;
    }

    final defaults = ConnectionProfile.defaults();
    final legacySeededProfile = defaults.copyWith(
      workspaceDir: trimmedWorkspaceDir,
    );
    if (profile != legacySeededProfile) {
      return profile;
    }

    return defaults;
  }

  String _profileKeyForConnection(String connectionId) {
    return '$profileKeyPrefix$connectionId$profileKeySuffix';
  }
}
