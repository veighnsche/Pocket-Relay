import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/connection_repository_test_support.dart';

void main() {
  registerConnectionRepositoryStorageLifecycle();

  test(
    'loadConnection preserves user-entered workspace directories even when they match an old placeholder path',
    () async {
      final preferences = SharedPreferencesAsync();
      await writeConnectionIndex(
        preferences,
        orderedConnectionIds: <String>['conn_seed'],
      );
      await writeStoredConnectionProfile(
        preferences,
        connectionId: 'conn_seed',
        profile: ConnectionProfile.defaults().copyWith(
          host: 'relay.example.com',
          username: 'vince',
          workspaceDir: '/home/vince/Projects/Pocket-Relay',
        ),
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
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
    'loadConnection preserves persisted workspace values exactly as stored',
    () async {
      final preferences = SharedPreferencesAsync();
      await writeConnectionIndex(
        preferences,
        orderedConnectionIds: <String>['conn_seed'],
      );
      await writeStoredConnectionProfile(
        preferences,
        connectionId: 'conn_seed',
        profile: ConnectionProfile.defaults().copyWith(
          workspaceDir: '/home/vince/Projects',
        ),
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final connection = await repository.loadConnection('conn_seed');

      expect(connection.profile.workspaceDir, '/home/vince/Projects');
      expect(connection.profile, isNot(ConnectionProfile.defaults()));
    },
  );

  test(
    'loadCatalog fills an empty fingerprint from a sibling connection on the same remote host and port',
    () async {
      final preferences = SharedPreferencesAsync();
      await writeConnectionIndex(
        preferences,
        orderedConnectionIds: <String>['conn_a', 'conn_b'],
      );
      await writeStoredConnectionProfile(
        preferences,
        connectionId: 'conn_a',
        profile: ConnectionProfile.defaults().copyWith(
          host: '192.168.178.164',
          username: 'vince',
          workspaceDir: '/workspace/a',
          hostFingerprint: 'SHA256:shared',
        ),
      );
      await writeStoredConnectionProfile(
        preferences,
        connectionId: 'conn_b',
        profile: ConnectionProfile.defaults().copyWith(
          host: '192.168.178.164',
          username: 'vince',
          workspaceDir: '/workspace/b',
        ),
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_b');
      final systemCatalog = await repository.loadSystemCatalog();
      final systemId = systemCatalog.orderedSystemIds.single;

      expect(
        catalog.connectionForId('conn_b')?.profile.hostFingerprint,
        'SHA256:shared',
      );
      expect(connection.profile.hostFingerprint, 'SHA256:shared');
      expect(
        await preferences.getString(systemProfileKey(systemId)),
        jsonEncode(
          systemProfileFromConnectionProfile(
            ConnectionProfile.defaults().copyWith(
              host: '192.168.178.164',
              username: 'vince',
              hostFingerprint: 'SHA256:shared',
            ),
          ).toJson(),
        ),
      );
    },
  );
}
