import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
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

  test(
    'loadCatalog seeds a default saved connection when storage is empty',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = SecureCodexConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        catalog.connectionsById['conn_seed'],
        SavedConnectionSummary(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
        ),
      );
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(
        await preferences.getString('pocket_relay.connections.index'),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
      );
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_seed.profile',
        ),
        jsonEncode(ConnectionProfile.defaults().toJson()),
      );
      expect(secureStorage.data, isEmpty);
    },
  );

  test(
    'loadCatalog ignores legacy singleton profile data once the migration window is closed',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'codex_pocket.profile': jsonEncode(
          ConnectionProfile.defaults()
              .copyWith(
                host: 'example.com',
                username: 'vince',
                workspaceDir: '/workspace/app',
              )
              .toJson(),
        ),
      });
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{
        'codex_pocket.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = SecureCodexConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_seed.profile',
        ),
        jsonEncode(ConnectionProfile.defaults().toJson()),
      );
      expect(
        secureStorage.data['pocket_relay.connection.conn_seed.secret.password'],
        isNull,
      );
      expect(secureStorage.data['codex_pocket.secret.password'], 'secret');
      expect(
        await preferences.getString('pocket_relay.connections.index'),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
      );
    },
  );

  test(
    'loadConnection preserves user-entered workspace directories even when they match an old placeholder path',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.connections.index',
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
      );
      await preferences.setString(
        'pocket_relay.connection.conn_seed.profile',
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
      final repository = SecureCodexConnectionRepository(
        secureStorage: _FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final connection = await repository.loadConnection('conn_seed');

      expect(
        connection.profile.workspaceDir,
        '/home/vince/Projects/Pocket-Relay',
      );
      expect(connection.profile.host, 'relay.example.com');
      expect(connection.profile.username, 'vince');
    },
  );

  test(
    'loadConnection clears the old seeded placeholder workspace only for the exact legacy default profile shape',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.connections.index',
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
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
      final repository = SecureCodexConnectionRepository(
        secureStorage: _FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final connection = await repository.loadConnection('conn_seed');

      expect(connection.profile, ConnectionProfile.defaults());
    },
  );

  test(
    'saveConnection appends a new saved connection to the catalog',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = SecureCodexConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      await repository.loadCatalog();
      await repository.saveConnection(
        SavedConnection(
          id: 'conn_second',
          profile: ConnectionProfile.defaults().copyWith(
            label: 'Second Box',
            host: 'second.example.com',
            username: 'vince',
          ),
          secrets: const ConnectionSecrets(
            password: 'second-secret',
            privateKeyPem: 'pem',
          ),
        ),
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_second');

      expect(catalog.orderedConnectionIds, <String>[
        'conn_seed',
        'conn_second',
      ]);
      expect(connection.profile.label, 'Second Box');
      expect(connection.profile.host, 'second.example.com');
      expect(connection.secrets.password, 'second-secret');
      expect(connection.secrets.privateKeyPem, 'pem');
    },
  );

  test('createConnection persists a generated saved connection', () async {
    final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
    final preferences = SharedPreferencesAsync();
    var nextId = 0;
    final repository = SecureCodexConnectionRepository(
      secureStorage: secureStorage,
      preferences: preferences,
      connectionIdGenerator: () =>
          <String>['conn_seed', 'conn_created'][nextId++],
    );

    await repository.loadCatalog();
    final createdConnection = await repository.createConnection(
      profile: ConnectionProfile.defaults().copyWith(
        label: 'Created Box',
        host: 'created.example.com',
        username: 'vince',
      ),
      secrets: const ConnectionSecrets(password: 'created-secret'),
    );

    final catalog = await repository.loadCatalog();
    final persistedConnection = await repository.loadConnection('conn_created');

    expect(createdConnection.id, 'conn_created');
    expect(catalog.orderedConnectionIds, <String>['conn_seed', 'conn_created']);
    expect(persistedConnection.profile.label, 'Created Box');
    expect(persistedConnection.secrets.password, 'created-secret');
  });

  test(
    'loadCatalog rebuilds the index from namespaced profile keys when the index is missing',
    () async {
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
      final repository = SecureCodexConnectionRepository(
        secureStorage: _FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();

      expect(catalog.orderedConnectionIds, <String>['conn_a', 'conn_b']);
      expect(
        await preferences.getString('pocket_relay.connections.index'),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_a', 'conn_b'],
        }),
      );
    },
  );

  test('deleteConnection removes only the targeted connection keys', () async {
    final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
    final preferences = SharedPreferencesAsync();
    final repository = SecureCodexConnectionRepository(
      secureStorage: secureStorage,
      preferences: preferences,
      connectionIdGenerator: () => 'conn_seed',
    );

    await repository.loadCatalog();
    await repository.saveConnection(
      SavedConnection(
        id: 'conn_second',
        profile: ConnectionProfile.defaults().copyWith(
          host: 'second.example.com',
          username: 'vince',
        ),
        secrets: const ConnectionSecrets(password: 'second-secret'),
      ),
    );
    secureStorage
            .data['pocket_relay.connection.conn_second.secret.extra_token'] =
        'cleanup-me';

    await repository.deleteConnection('conn_second');

    final catalog = await repository.loadCatalog();
    final secureKeys = secureStorage.data.keys.toList(growable: false);

    expect(catalog.orderedConnectionIds, <String>['conn_seed']);
    expect(
      await preferences.getString(
        'pocket_relay.connection.conn_second.profile',
      ),
      isNull,
    );
    expect(
      secureKeys.where(
        (key) => key.startsWith('pocket_relay.connection.conn_second.'),
      ),
      isEmpty,
    );
    expect(
      await preferences.getString('pocket_relay.connection.conn_seed.profile'),
      isNotNull,
    );
  });
}

class _FakeFlutterSecureStorage extends FlutterSecureStorage {
  _FakeFlutterSecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map<String, String>.from(data);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
