import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live lane shows remote-session-unavailable notice when transport reconnect fails',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pump();

      expect(find.text('Remote session unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionTransportUnavailable.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Underlying error: connect failed'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );

  testWidgets(
    'live lane shows a coded fallback-restore notice when live reattach fails after transport reconnect',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pump();
      await tester.pump();

      expect(find.text('Restoring conversation from history'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionLiveReattachFallbackRestore.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Underlying error: resume failed'),
        findsOneWidget,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );

      controller.dispose();
      await client.dispose();
    },
  );

  testWidgets(
    'live lane shows remote-continuity-unavailable notice when the host lacks required continuity support',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
            detail: 'tmux is not installed on this host.',
          ),
        ),
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectContinuityUnsupported.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('tmux is not installed on this host.'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
    },
  );

  testWidgets(
    'live lane shows remote-continuity-unavailable notice when host capability probing fails',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        remoteAppServerHostProbe: const ThrowingRemoteHostProbe(
          'ssh probe failed',
        ),
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionRuntimeProbeFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('ssh probe failed'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
    },
  );

  testWidgets(
    'live lane shows remote-server-stopped notice when transport reconnect cannot attach to the managed owner',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexRemoteAppServerAttachException(
        snapshot: CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay-conn_primary',
          detail: 'Managed remote app-server is not running.',
        ),
        message: 'Managed remote app-server is not running.',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server stopped'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );

  testWidgets(
    'live lane shows remote-server-unhealthy notice when transport reconnect cannot attach to an unhealthy managed owner',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexRemoteAppServerAttachException(
        snapshot: CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
          detail: 'readyz failed',
        ),
        message: 'readyz failed',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server unhealthy'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectServerUnhealthy.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('readyz failed'), findsWidgets);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );
}

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
