import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_catalog_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('rebuilds a missing catalog index from stored profile keys', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'pocket_relay.connection.conn_b.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(
              label: 'Beta',
              host: 'beta.example.com',
              username: 'vince',
            )
            .toJson(),
      ),
    );
    await preferences.setString(
      'pocket_relay.connection.conn_a.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(
              label: 'Alpha',
              host: 'alpha.example.com',
              username: 'vince',
            )
            .toJson(),
      ),
    );
    final recovery = _buildRecovery(preferences);

    await recovery.ensurePreferencesReady();
    final catalog = await recovery.loadCatalog();

    expect(catalog?.orderedConnectionIds, <String>['conn_a', 'conn_b']);
    expect(
      await preferences.getString('pocket_relay.connections.index'),
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'orderedConnectionIds': <String>['conn_a', 'conn_b'],
      }),
    );
  });

  test('keeps indexed order and appends discovered profile ids', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'pocket_relay.connections.index',
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'orderedConnectionIds': <String>['conn_b'],
      }),
    );
    await preferences.setString(
      'pocket_relay.connection.conn_b.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(host: 'beta.example.com', username: 'vince')
            .toJson(),
      ),
    );
    await preferences.setString(
      'pocket_relay.connection.conn_a.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(host: 'alpha.example.com', username: 'vince')
            .toJson(),
      ),
    );
    final recovery = _buildRecovery(preferences);

    await recovery.ensurePreferencesReady();
    final catalog = await recovery.loadCatalog();

    expect(catalog?.orderedConnectionIds, <String>['conn_b', 'conn_a']);
  });

  test('preserves stored profile values exactly as persisted', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(
      'pocket_relay.connections.index',
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'orderedConnectionIds': <String>['conn_seed', 'conn_custom'],
      }),
    );
    await preferences.setString(
      'pocket_relay.connection.conn_seed.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(workspaceDir: '/home/vince/Projects')
            .toJson(),
      ),
    );
    await preferences.setString(
      'pocket_relay.connection.conn_custom.profile',
      jsonEncode(
        ConnectionProfile.defaults()
            .copyWith(
              host: 'relay.example.com',
              username: 'vince',
              workspaceDir: '/home/vince/Projects/Pocket-Relay',
            )
            .toJson(),
      ),
    );
    final recovery = _buildRecovery(preferences);

    await recovery.ensurePreferencesReady();
    final catalog = await recovery.loadCatalog();

    expect(
      catalog?.connectionsById['conn_seed']?.profile.workspaceDir,
      '/home/vince/Projects',
    );
    expect(
      catalog?.connectionsById['conn_custom']?.profile.workspaceDir,
      '/home/vince/Projects/Pocket-Relay',
    );
  });
}

CodexConnectionCatalogRecovery _buildRecovery(
  SharedPreferencesAsync preferences,
) {
  return CodexConnectionCatalogRecovery(
    preferences: preferences,
    catalogIndexKey: 'pocket_relay.connections.index',
    catalogSchemaVersion: 1,
    preferencesMigrationKey:
        'pocket_relay.connections_async_migration_complete',
    profileKeyPrefix: 'pocket_relay.connection.',
    profileKeySuffix: '.profile',
  );
}
