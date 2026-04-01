import 'screen_app_server_test_support.dart';

void main() {
  testWidgets('child agent output stays on its own timeline until selected', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_root'},
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{
            'id': 'thread_child',
            'agentNickname': 'Reviewer',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turn': <String, Object?>{'id': 'turn_child_1', 'status': 'running'},
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turnId': 'turn_child_1',
          'item': <String, Object?>{
            'id': 'item_child_1',
            'type': 'agentMessage',
            'status': 'completed',
            'text': 'Child analysis',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_child',
          'turn': <String, Object?>{
            'id': 'turn_child_1',
            'status': 'completed',
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timeline_thread_child')), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Child analysis'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timeline_thread_child')));
    await tester.pumpAndSettle();

    expect(find.text('Child analysis'), findsOneWidget);
    expect(find.text('New'), findsNothing);
  });

  testWidgets(
    'renders an actionable host fingerprint surface, persists it, and opens workspace settings',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      final repository = MemoryCodexConnectionRepository.single(
        savedProfile: savedProfile(),
        connectionId: 'conn_primary',
      );

      await tester.pumpWidget(
        buildCatalogApp(
          connectionRepository: repository,
          appServerClient: appServerClient,
        ),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerUnpinnedHostKeyEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2:7d:c0:18:29:33:4d:22:2f:ae:4c',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('save_host_fingerprint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('host_fingerprint_value')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('save_host_fingerprint')));
      await tester.pumpAndSettle();

      expect(find.text('saved'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        (await repository.loadConnection(
          'conn_primary',
        )).profile.hostFingerprint,
        '7a:9f:d7:dc:2e:f2:7d:c0:18:29:33:4d:22:2f:ae:4c',
      );

      await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('connection_settings_section_workspace'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('connection_settings_section_codex'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('connection_settings_system_fingerprint'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders SSH host key mismatch as a dedicated settings-oriented surface',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshHostKeyMismatchEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          expectedFingerprint: 'aa:bb:cc:dd',
          actualFingerprint: '11:22:33:44',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH host key mismatch'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('expected_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('observed_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders SSH authentication failure as a dedicated settings-oriented surface',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshAuthenticationFailedEvent(
          host: 'example.com',
          port: 22,
          username: 'vince',
          authMode: AuthMode.privateKey,
          message: 'Permission denied',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH authentication failed'), findsOneWidget);
      expect(find.textContaining('private key'), findsWidgets);
      expect(find.text('Permission denied'), findsOneWidget);
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'reuses the current SSH failure surface when the same connect failure repeats',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerSshConnectFailedEvent(
          host: 'example.com',
          port: 22,
          message: 'Connection refused',
        ),
      );
      appServerClient.emit(
        const CodexAppServerSshConnectFailedEvent(
          host: 'example.com',
          port: 22,
          message: 'Timed out',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SSH connection failed'), findsOneWidget);
      expect(find.text('Connection refused'), findsNothing);
      expect(find.text('Timed out'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ssh_connect_failed_surface')),
        findsOneWidget,
      );
    },
  );

  testWidgets('appends plan update cards instead of replacing them', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'explanation': 'Starting with the initial structure.',
          'plan': <Map<String, Object?>>[
            <String, Object?>{
              'step': 'Inspect transcript ownership',
              'status': 'in_progress',
            },
          ],
        },
      ),
    );

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'explanation': 'Refining after reading the reducer.',
          'plan': <Map<String, Object?>>[
            <String, Object?>{
              'step': 'Inspect transcript ownership',
              'status': 'completed',
            },
            <String, Object?>{
              'step': 'Append visible plan updates',
              'status': 'in_progress',
            },
          ],
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Updated Plan'), findsNWidgets(2));
    expect(find.text('Starting with the initial structure.'), findsOneWidget);
    expect(find.text('Refining after reading the reducer.'), findsOneWidget);
    expect(find.text('Append visible plan updates'), findsOneWidget);
  });
}
