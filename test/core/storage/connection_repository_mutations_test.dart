import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/connection_repository_test_support.dart';

void main() {
  registerConnectionRepositoryStorageLifecycle();

  test(
    'saveConnection appends a new saved connection to the catalog',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
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

  test(
    'saveConnection propagates an updated fingerprint to sibling connections on the same remote host and port',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
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
            host: '192.168.178.164',
            username: 'vince',
            workspaceDir: '/workspace/b',
          ),
          secrets: const ConnectionSecrets(password: 'second-secret'),
        ),
      );

      await repository.saveConnection(
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults().copyWith(
            host: '192.168.178.164',
            username: 'vince',
            workspaceDir: '/workspace/a',
            hostFingerprint: 'SHA256:updated',
          ),
          secrets: const ConnectionSecrets(),
        ),
      );

      final primaryConnection = await repository.loadConnection('conn_seed');
      final siblingConnection = await repository.loadConnection('conn_second');

      expect(primaryConnection.profile.hostFingerprint, 'SHA256:updated');
      expect(siblingConnection.profile.hostFingerprint, 'SHA256:updated');
    },
  );

  test('createConnection persists a generated saved connection', () async {
    final secureStorage = FakeFlutterSecureStorage(<String, String>{});
    final preferences = SharedPreferencesAsync();
    var nextId = 0;
    final repository = buildSecureConnectionRepository(
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

  test('deleteConnection removes only the targeted connection keys', () async {
    final secureStorage = FakeFlutterSecureStorage(<String, String>{});
    final preferences = SharedPreferencesAsync();
    final repository = buildSecureConnectionRepository(
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
