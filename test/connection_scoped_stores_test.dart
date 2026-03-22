import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';

void main() {
  test(
    'ConnectionScopedProfileStore loads and saves only its connection',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_a',
            profile: ConnectionProfile.defaults().copyWith(
              label: 'A',
              host: 'a.example.com',
              username: 'vince',
            ),
            secrets: const ConnectionSecrets(password: 'secret-a'),
          ),
          SavedConnection(
            id: 'conn_b',
            profile: ConnectionProfile.defaults().copyWith(
              label: 'B',
              host: 'b.example.com',
              username: 'vince',
            ),
            secrets: const ConnectionSecrets(password: 'secret-b'),
          ),
        ],
      );
      final store = ConnectionScopedProfileStore(
        connectionId: 'conn_a',
        connectionRepository: repository,
      );

      final initial = await store.load();
      await store.save(
        initial.profile.copyWith(label: 'A Updated'),
        initial.secrets.copyWith(privateKeyPem: 'pem-a'),
      );

      final connectionA = await repository.loadConnection('conn_a');
      final connectionB = await repository.loadConnection('conn_b');

      expect(initial.profile.label, 'A');
      expect(connectionA.profile.label, 'A Updated');
      expect(connectionA.secrets.privateKeyPem, 'pem-a');
      expect(connectionB.profile.label, 'B');
      expect(connectionB.secrets.privateKeyPem, isEmpty);
    },
  );
}
