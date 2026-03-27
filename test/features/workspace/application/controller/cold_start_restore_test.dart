import 'controller_test_support.dart';

void main() {
  test(
    'initialization keeps the first live lane empty until history is explicitly picked',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.selectedLaneBinding;
      expect(binding, isNotNull);

      await binding!.sessionController.initialize();

      expect(clientsById['conn_primary']?.connectCalls, 0);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);
    },
  );

  test(
    'initialization restores the persisted selected lane, draft, and transcript target',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final backgroundedAt = DateTime.utc(2026, 3, 22, 12, 30);
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedAt: backgroundedAt,
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

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        clientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, <String>[
        'thread_saved',
      ]);
      expect(clientsById['conn_secondary']!.connectCalls, 1);
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        isNull,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.liveReattached,
      );
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastBackgroundedAt, backgroundedAt);
      expect(
        diagnostics.lastBackgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      expect(
        diagnostics.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        diagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
    },
  );

  test(
    'initialization keeps booting when local recovery load fails and records a typed warning',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: const ThrowingConnectionWorkspaceRecoveryStore(
          ConnectionWorkspaceRecoveryStoreCorruptedException(
            'Persisted workspace recovery metadata is malformed JSON.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        controller.state.recoveryLoadWarning?.definition,
        PocketErrorCatalog.appBootstrapRecoveryStateLoadFailed,
      );
      expect(
        controller.state.recoveryLoadWarning?.inlineMessage,
        contains('malformed JSON'),
      );
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        isEmpty,
      );
      expect(clientsById['conn_primary']!.connectCalls, 0);
    },
  );

  test(
    'initialization keeps live reattach as the default when cold-start resume replays pending requests',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_restore_1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_saved',
          'turnId': 'turn_restore_1',
          'itemId': 'item_restore_1',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
            },
          ],
        },
      );
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      clientsById['conn_secondary']!
              .resumeThreadReplayEventsByThreadId['thread_saved'] =
          <CodexAppServerEvent>[replayedRequest];
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

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        clientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.sessionState.pendingUserInputRequests
            .containsKey('input_restore_1'),
        isTrue,
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .map((block) => block.body),
        contains('Restored answer'),
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.liveReattached,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_secondary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
    },
  );

  test(
    'initialization marks the restored lane reconnecting while cold-start transport bootstrap is in flight',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      clientsById['conn_secondary']!.connectGate = Completer<void>();
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

      final initialization = controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect(
        controller.selectedLaneBinding?.composerDraftHost.draft.text,
        'Restore my draft',
      );
      final reconnectingDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(reconnectingDiagnostics, isNotNull);
      expect(
        reconnectingDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(reconnectingDiagnostics.lastRecoveryStartedAt, isNotNull);
      expect(reconnectingDiagnostics.lastRecoveryCompletedAt, isNull);
      expect(reconnectingDiagnostics.lastRecoveryOutcome, isNull);

      clientsById['conn_secondary']!.connectGate!.complete();
      await initialization;

      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        isNull,
      );
      expect(
        controller
            .selectedLaneBinding
            ?.sessionController
            .sessionState
            .rootThreadId,
        'thread_saved',
      );
      final restoredDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(restoredDiagnostics, isNotNull);
      expect(
        restoredDiagnostics!.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
      expect(restoredDiagnostics.lastRecoveryCompletedAt, isNotNull);
    },
  );

  test(
    'initialization keeps the restored lane visible and marks remote session unavailable when cold-start transport bootstrap fails',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
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

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Restore my draft',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(controller.state.liveReattachPhaseFor('conn_secondary'), isNull);
      final unavailableDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(unavailableDiagnostics, isNotNull);
      expect(
        unavailableDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        unavailableDiagnostics.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.connectFailed,
      );
      expect(
        unavailableDiagnostics.lastTransportFailureDetail,
        'connect failed',
      );
      expect(
        unavailableDiagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(
        controller
            .selectedLaneBinding!
            .sessionController
            .sessionState
            .rootThreadId,
        isNull,
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, isEmpty);
    },
  );

  test(
    'initialization stores remote stopped runtime when cold-start transport bootstrap cannot attach to the managed owner',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexRemoteAppServerAttachException(
            snapshot: CodexRemoteAppServerOwnerSnapshot(
              ownerId: 'conn_secondary',
              workspaceDir: '/workspace',
              status: CodexRemoteAppServerOwnerStatus.stopped,
              sessionName: 'pocket-relay-conn_secondary',
              detail: 'Managed remote app-server is not running.',
            ),
            message: 'Managed remote app-server is not running.',
          );
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

      final remoteRuntime = controller.state.remoteRuntimeFor('conn_secondary');
      expect(remoteRuntime, isNotNull);
      expect(
        remoteRuntime!.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
      expect(
        remoteRuntime.server.detail,
        'Managed remote app-server is not running.',
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.ownerMissing,
      );
    },
  );

  test(
    'initialization restores the persisted selected lane, draft, and transcript target from secure recovery storage',
    () async {
      final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
        SharedPreferences.setMockInitialValues(<String, Object>{});
      });

      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final recoveryStore = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );
      await recoveryStore.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
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

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        clientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, <String>[
        'thread_saved',
      ]);
      expect(
        await preferences.getString('pocket_relay.workspace.recovery_state'),
        isNot(contains('Restore my draft')),
      );
      expect(
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_secondary'],
        'Restore my draft',
      );
    },
  );
}
