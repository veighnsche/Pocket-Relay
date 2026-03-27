import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/connection_repository_test_support.dart';

void main() {
  registerConnectionRepositoryStorageLifecycle();

  test(
    'loadCatalog seeds a default saved connection when storage is empty',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
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
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_seed'],
        }),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults(),
            systemId: null,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': const <String>[],
        }),
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
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'codex_pocket.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
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
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults(),
            systemId: null,
          ).toJson(),
        ),
      );
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['codex_pocket.secret.password'], 'secret');
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_seed'],
        }),
      );
    },
  );

  test(
    'loadCatalog migrates the legacy singleton pocket relay profile into the seeded connection',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
        hostFingerprint: 'SHA256:legacyfingerprint',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');
      final systemCatalog = await repository.loadSystemCatalog();
      final systemId = systemCatalog.orderedSystemIds.single;

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: legacyProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            legacyProfile,
            systemId: systemId,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemProfileKey(systemId)),
        jsonEncode(systemProfileFromConnectionProfile(legacyProfile).toJson()),
      );
      expect(secureStorage.data[systemPasswordKey(systemId)], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], isNull);
    },
  );

  test(
    'loadCatalog upgrades a seeded default catalog entry with legacy singleton data',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
        hostFingerprint: 'SHA256:legacyfingerprint',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
        'pocket_relay.connections.index': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
        'pocket_relay.connection.conn_seed.profile': jsonEncode(
          ConnectionProfile.defaults().toJson(),
        ),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');
      final systemCatalog = await repository.loadSystemCatalog();
      final systemId = systemCatalog.orderedSystemIds.single;

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: legacyProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            legacyProfile,
            systemId: systemId,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemProfileKey(systemId)),
        jsonEncode(systemProfileFromConnectionProfile(legacyProfile).toJson()),
      );
      expect(secureStorage.data[systemPasswordKey(systemId)], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], isNull);
    },
  );

  test(
    'loadCatalog ignores orphaned legacy secrets when the legacy profile is missing',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
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
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
    },
  );

  test(
    'loadCatalog ignores malformed legacy singleton data instead of migrating it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': '{not json',
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final connection = await repository.loadConnection('conn_seed');

      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), '{not json');
    },
  );

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
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();

      expect(catalog.orderedConnectionIds, <String>['conn_a', 'conn_b']);
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_a', 'conn_b'],
        }),
      );
    },
  );
}
