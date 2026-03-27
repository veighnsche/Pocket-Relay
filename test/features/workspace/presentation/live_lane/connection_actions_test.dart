import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live empty lane shows a disconnected status and connect action when the remote server is running',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await clientsById['conn_primary']!.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_label')),
        findsNothing,
      );
      expect(find.textContaining('Disconnected.'), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live empty lane connect action keeps the placeholder clean and exposes visible lifecycle controls',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(client.connectCalls, 1);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_disconnect')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_close')),
        findsOneWidget,
      );
      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live connected lane disconnect stays distinct from close lane and preserves the lane',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_disconnect')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_close')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_disconnect')),
      );
      await tester.pumpAndSettle();

      expect(client.disconnectCalls, 1);
      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.isShowingLiveLane, isTrue);
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsOneWidget,
      );

      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live empty lane connect action can start the remote server and attach in one click',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final remoteOwnerRuntime = StatefulRemoteOwnerRuntime(
        statusesByOwnerId: <String, CodexRemoteAppServerOwnerStatus>{
          'conn_primary': CodexRemoteAppServerOwnerStatus.stopped,
        },
      );
      final client = clientsById['conn_primary']!;
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: remoteOwnerRuntime,
        remoteAppServerOwnerControl: remoteOwnerRuntime,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(remoteOwnerRuntime.startCalls, hasLength(1));
      expect(remoteOwnerRuntime.startCalls.single.ownerId, 'conn_primary');
      expect(client.connectCalls, 1);
      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live lane connect action surfaces a coded snackbar when transport attach fails',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      client.connectError = const CodexAppServerException('connect failed');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionTransportUnavailable.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Could not connect lane'), findsOneWidget);
      expect(
        find.textContaining('Underlying error: connect failed'),
        findsOneWidget,
      );
      expect(find.textContaining('Disconnected.'), findsNothing);
    },
  );

  testWidgets(
    'live lane disconnect action surfaces a coded snackbar when transport close fails',
    (tester) async {
      final client = _ThrowingDisconnectFakeCodexAppServerClient(
        const CodexAppServerException('disconnect failed'),
      );
      final controller = buildWorkspaceController(
        clientsById: <String, FakeCodexAppServerClient>{'conn_primary': client},
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          controller.selectedLaneBinding!,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(client.disconnectCalls, 1);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionDisconnectLaneFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Could not disconnect lane'), findsOneWidget);
      expect(
        find.textContaining('Underlying error: disconnect failed'),
        findsOneWidget,
      );
      client.disconnectError = null;
    },
  );
}

class _ThrowingDisconnectFakeCodexAppServerClient
    extends FakeCodexAppServerClient {
  _ThrowingDisconnectFakeCodexAppServerClient(this.error);

  Object? error;

  set disconnectError(Object? value) {
    error = value;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    if (error case final disconnectError?) {
      throw disconnectError;
    }
    return super.disconnect();
  }
}
