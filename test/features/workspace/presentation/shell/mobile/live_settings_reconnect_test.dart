import 'mobile_shell_test_support.dart';

void main() {
  testWidgets(
    'saving live settings stages reconnect-required state without disconnecting the lane',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: workspaceProfile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lane_connection_status_strip')),
          matching: find.text('Changes pending'),
        ),
        findsNothing,
      );
      expect(find.text('Apply changes'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'transport loss shows reconnect copy instead of saved-settings copy',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await tester.pump();

      await clientsById['conn_primary']!.disconnect();
      await tester.pump();

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(find.text('Changes pending'), findsNothing);
      expect(find.text('Apply changes'), findsNothing);
      expect(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live settings reopen with the staged saved definition while reconnect is pending',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: workspaceProfile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
          null,
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(2));
      expect(
        settingsOverlayDelegate.launchedSettings.last.$1.host,
        'primary.changed',
      );
      expect(
        settingsOverlayDelegate.launchedSettings.last.$2,
        const ConnectionSecrets(password: 'updated-secret'),
      );
    },
  );

  testWidgets(
    'applying saved settings reconnects the lane and clears reconnect-required state',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: workspaceProfile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
      );
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(find.text('Changes pending'), findsNothing);
      expect(find.text('Primary Renamed'), findsOneWidget);
      expect(find.text('primary.changed'), findsOneWidget);
    },
  );
}
