import 'controller_test_support.dart';

void main() {
  test(
    'unexpected transport disconnect stages transport reconnect without replacing the live lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.transportLost,
      );
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.appServerExitError,
      );
      expect(diagnostics.lastTransportLossAt, isNotNull);
      expect(controller.state.reconnectRequiredConnectionIds, <String>{
        'conn_primary',
      });
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test(
    'intentional transport disconnect keeps the live lane but does not stage reconnect recovery',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      await controller.disconnectConnection('conn_primary');
      await Future<void>.delayed(Duration.zero);

      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(clientsById['conn_primary']?.isConnected, isFalse);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
      expect(controller.state.liveReattachPhaseFor('conn_primary'), isNull);
      expect(controller.state.reconnectRequiredConnectionIds, isEmpty);
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')
            ?.lastTransportLossReason,
        isNull,
      );
    },
  );

  test(
    'failed intentional disconnect does not suppress a later unexpected transport loss',
    () async {
      final clientsById = <String, FakeCodexAppServerClient>{
        'conn_primary': StickyDisconnectFakeCodexAppServerClient(),
        'conn_secondary': FakeCodexAppServerClient(),
      };
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      await controller.disconnectConnection('conn_primary');
      await Future<void>.delayed(Duration.zero);

      expect(clientsById['conn_primary']!.isConnected, isTrue);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.transportLost,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')
            ?.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.appServerExitError,
      );
    },
  );

  test(
    'unexpected graceful app-server exit records a distinct transport loss reason',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 0),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
      );
    },
  );

  test(
    'cold-start connect failures keep specific SSH loss reasons instead of downgrading to generic connect failure',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!
        ..connectEventsBeforeThrow.add(
          const CodexAppServerSshConnectFailedEvent(
            host: 'secondary.local',
            port: 22,
            message: 'No route to host',
          ),
        )
        ..connectError = const CodexAppServerException('connect failed');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.sshConnectFailed,
      );
      expect(diagnostics.lastTransportFailureDetail, isNull);
      expect(
        diagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
    },
  );

  test(
    'transport reconnect state clears when the live lane reconnects through the existing binding',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportRestored,
      );
      expect(clientsById['conn_primary']?.connectCalls, 2);
      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
    },
  );
}
