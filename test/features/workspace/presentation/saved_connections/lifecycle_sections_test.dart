import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'connections hub groups attention rows ahead of ordinary saved connections',
    (tester) async {
      final clientsById = <String, FakeCodexAppServerClient>{
        'conn_primary': FakeCodexAppServerClient(),
        'conn_secondary': FakeCodexAppServerClient(),
        'conn_tertiary': FakeCodexAppServerClient(),
      };
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: MemoryCodexConnectionRepository(
          initialConnections: <SavedConnection>[
            SavedConnection(
              id: 'conn_primary',
              profile: workspaceProfile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
            SavedConnection(
              id: 'conn_secondary',
              profile: workspaceProfile(
                'Needs Setup',
                'secondary.local',
              ).copyWith(workspaceDir: ''),
              secrets: const ConnectionSecrets(password: 'secret-2'),
            ),
            SavedConnection(
              id: 'conn_tertiary',
              profile: workspaceProfile('Tertiary Box', 'tertiary.local'),
              secrets: const ConnectionSecrets(password: 'secret-3'),
            ),
          ],
        ),
        remoteAppServerOwnerInspector:
            MapRemoteOwnerInspector(<String, CodexRemoteAppServerOwnerSnapshot>{
              'conn_primary': notRunningOwnerSnapshot('conn_primary'),
              'conn_tertiary': notRunningOwnerSnapshot('conn_tertiary'),
            }),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('connections_section_currentLane')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('connections_section_openLanes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('connections_section_needsAttention')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connections_section_needsAttention')),
          matching: find.byKey(
            const ValueKey('saved_connection_conn_secondary'),
          ),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('saved_connection_conn_tertiary')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connections_section_needsAttention')),
          matching: find.byKey(
            const ValueKey('saved_connection_conn_tertiary'),
          ),
        ),
        findsNothing,
      );

      final attentionTop = tester.getTopLeft(
        find.byKey(const ValueKey('saved_connection_conn_secondary')),
      );
      final savedTop = tester.getTopLeft(
        find.byKey(const ValueKey('saved_connection_conn_tertiary')),
      );
      expect(attentionTop.dy, lessThan(savedTop.dy));
    },
  );

  testWidgets(
    'local rows do not render remote facts or remote detail actions',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: MemoryCodexConnectionRepository(
          initialConnections: <SavedConnection>[
            SavedConnection(
              id: 'conn_primary',
              profile: workspaceProfile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
            SavedConnection(
              id: 'conn_secondary',
              profile: ConnectionProfile.defaults().copyWith(
                connectionMode: ConnectionMode.local,
                label: 'Local Workspace',
                workspaceDir: '/local/workspace',
                codexPath: 'codex',
              ),
              secrets: const ConnectionSecrets(),
            ),
          ],
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      final localRow = find.byKey(
        const ValueKey('saved_connection_conn_secondary'),
      );

      expect(
        find.descendant(of: localRow, matching: find.textContaining('System:')),
        findsNothing,
      );
      expect(
        find.descendant(of: localRow, matching: find.textContaining('Server:')),
        findsNothing,
      );
      expect(
        find.descendant(of: localRow, matching: find.text('Check system')),
        findsNothing,
      );
      expect(
        find.descendant(of: localRow, matching: find.text('Restart server')),
        findsNothing,
      );
      expect(
        find.descendant(of: localRow, matching: find.text('Stop server')),
        findsNothing,
      );
    },
  );
}
