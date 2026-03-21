import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_async_migration.dart';

part 'codex_connection_catalog_recovery_discovery.dart';
part 'codex_connection_catalog_recovery_index.dart';

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
    final profileConnectionIds = await _discoverProfileConnectionIds(this);

    if (rawIndex == null || rawIndex.trim().isEmpty) {
      if (profileConnectionIds.isEmpty) {
        return null;
      }

      final recoveredCatalog = await _buildCatalog(
        this,
        profileConnectionIds,
      );
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
    final catalog = await _buildCatalog(this, candidateConnectionIds);

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
}
