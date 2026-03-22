import 'dart:convert';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_async_migration.dart';

abstract interface class ConnectionModelCatalogStore {
  Future<ConnectionModelCatalog?> load(String connectionId);

  Future<void> save(ConnectionModelCatalog catalog);

  Future<void> delete(String connectionId);
}

class NoopConnectionModelCatalogStore implements ConnectionModelCatalogStore {
  const NoopConnectionModelCatalogStore();

  @override
  Future<ConnectionModelCatalog?> load(String connectionId) async => null;

  @override
  Future<void> save(ConnectionModelCatalog catalog) async {}

  @override
  Future<void> delete(String connectionId) async {}
}

class MemoryConnectionModelCatalogStore implements ConnectionModelCatalogStore {
  MemoryConnectionModelCatalogStore({
    Iterable<ConnectionModelCatalog> initialCatalogs =
        const <ConnectionModelCatalog>[],
  }) : _catalogsByConnectionId = <String, ConnectionModelCatalog>{
         for (final catalog in initialCatalogs)
           catalog.connectionId.trim(): catalog,
       };

  final Map<String, ConnectionModelCatalog> _catalogsByConnectionId;

  @override
  Future<ConnectionModelCatalog?> load(String connectionId) async {
    return _catalogsByConnectionId[_normalizeCatalogConnectionId(connectionId)];
  }

  @override
  Future<void> save(ConnectionModelCatalog catalog) async {
    final normalized = _normalizeCatalog(catalog);
    _catalogsByConnectionId[normalized.connectionId] = normalized;
  }

  @override
  Future<void> delete(String connectionId) async {
    _catalogsByConnectionId.remove(_normalizeCatalogConnectionId(connectionId));
  }
}

class SecureConnectionModelCatalogStore implements ConnectionModelCatalogStore {
  static const _keyPrefix = 'pocket_relay.connection.';
  static const _keySuffix = '.model_catalog';
  static const _preferencesMigrationKey =
      'pocket_relay.connection_model_catalog_async_migration_complete';

  SecureConnectionModelCatalogStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  Future<void>? _preferencesReady;

  @override
  Future<ConnectionModelCatalog?> load(String connectionId) async {
    await _ensurePreferencesReady();
    final normalizedConnectionId = _normalizeCatalogConnectionId(connectionId);
    final rawCatalog = await _preferences.getString(
      _catalogKey(normalizedConnectionId),
    );
    if (rawCatalog == null || rawCatalog.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawCatalog);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final catalog = ConnectionModelCatalog.fromJson(decoded);
    if (catalog.connectionId != normalizedConnectionId ||
        catalog.connectionId.isEmpty) {
      return null;
    }
    return catalog;
  }

  @override
  Future<void> save(ConnectionModelCatalog catalog) async {
    await _ensurePreferencesReady();
    final normalizedCatalog = _normalizeCatalog(catalog);
    await _preferences.setString(
      _catalogKey(normalizedCatalog.connectionId),
      jsonEncode(normalizedCatalog.toJson()),
    );
  }

  @override
  Future<void> delete(String connectionId) async {
    await _ensurePreferencesReady();
    await _preferences.remove(
      _catalogKey(_normalizeCatalogConnectionId(connectionId)),
    );
  }

  Future<void> _ensurePreferencesReady() {
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }
}

ConnectionModelCatalog _normalizeCatalog(ConnectionModelCatalog catalog) {
  return ConnectionModelCatalog(
    connectionId: _normalizeCatalogConnectionId(catalog.connectionId),
    fetchedAt: catalog.fetchedAt,
    models: catalog.models,
  );
}

String _normalizeCatalogConnectionId(String connectionId) {
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

String _catalogKey(String connectionId) {
  return '${SecureConnectionModelCatalogStore._keyPrefix}'
      '$connectionId'
      '${SecureConnectionModelCatalogStore._keySuffix}';
}
