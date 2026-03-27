import 'controller_test_support.dart';

void main() {
  test(
    'saveSavedConnection updates a non-live saved definition immediately',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      await controller.saveSavedConnection(
        connectionId: 'conn_secondary',
        profile: workspaceProfile('Secondary Renamed', 'secondary.changed'),
        secrets: const ConnectionSecrets(password: 'new-secret'),
      );

      final updatedConnection = controller.state.catalog.connectionForId(
        'conn_secondary',
      );
      expect(updatedConnection?.profile.label, 'Secondary Renamed');
      expect(updatedConnection?.profile.host, 'secondary.changed');
      expect(controller.bindingForConnectionId('conn_secondary'), isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test(
    'saveSavedConnection routes live rows through staged reconnect edits',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveSavedConnection(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(controller.bindingForConnectionId('conn_primary'), firstBinding);
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.changed',
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test(
    'saveLiveConnectionEdits stages reconnect-required state without disconnecting the lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(controller.state.reconnectRequiredConnectionIds, <String>{
        'conn_primary',
      });
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.changed',
      );
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test(
    'saveLiveConnectionEdits clears reconnect-required state when the saved definition matches the running lane again',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.reconnectRequiredConnectionIds, isEmpty);
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.local',
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );
}
