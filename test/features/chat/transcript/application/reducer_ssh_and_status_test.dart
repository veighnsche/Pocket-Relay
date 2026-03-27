import 'reducer_test_support.dart';

void main() {
  var monotonicNow = Duration.zero;

  setUp(() {
    monotonicNow = Duration.zero;
    CodexMonotonicClock.debugSetNowProvider(() => monotonicNow);
  });

  tearDown(() {
    CodexMonotonicClock.debugSetNowProvider(null);
  });

  test('keeps warnings and errors non-fatal to the UI state', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeWarningEvent(
        createdAt: now,
        summary: 'Config warning',
        details: 'Bad config value',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeErrorEvent(
        createdAt: now,
        message: 'Command failed',
        errorClass: CodexRuntimeErrorClass.providerError,
      ),
    );

    expect(state.connectionStatus, CodexRuntimeSessionState.ready);
    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<CodexStatusBlock>());
    expect(state.blocks.last, isA<CodexErrorBlock>());
    expect(
      (state.blocks.first as CodexStatusBlock).statusKind,
      CodexStatusBlockKind.warning,
    );
  });

  test('deduplicates repeated unpinned host key prompts', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);
    final event = CodexRuntimeUnpinnedHostKeyEvent(
      createdAt: now,
      host: '192.168.178.164',
      port: 22,
      keyType: 'ssh-ed25519',
      fingerprint: '7a:9f:d7:dc:2e:f2',
    );

    state = reducer.reduceRuntimeEvent(state, event);
    state = reducer.reduceRuntimeEvent(state, event);

    expect(state.connectionStatus, CodexRuntimeSessionState.ready);
    expect(state.blocks, hasLength(1));
    expect(state.blocks.single, isA<CodexSshUnpinnedHostKeyBlock>());
  });

  test('projects typed SSH failures into dedicated transcript SSH blocks', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshConnectFailedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        message: 'Connection refused',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshHostKeyMismatchEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        host: '192.168.178.164',
        port: 22,
        keyType: 'ssh-ed25519',
        expectedFingerprint: 'aa:bb:cc',
        actualFingerprint: '11:22:33',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshAuthenticationFailedEvent(
        createdAt: now.add(const Duration(milliseconds: 2)),
        host: '192.168.178.164',
        port: 22,
        username: 'vince',
        authMode: AuthMode.privateKey,
        message: 'Permission denied',
      ),
    );

    expect(state.blocks, hasLength(3));
    expect(state.blocks[0], isA<CodexSshConnectFailedBlock>());
    expect(
      (state.blocks[0] as CodexSshConnectFailedBlock).message,
      'Connection refused',
    );
    expect(state.blocks[1], isA<CodexSshHostKeyMismatchBlock>());
    expect(
      (state.blocks[1] as CodexSshHostKeyMismatchBlock).expectedFingerprint,
      'aa:bb:cc',
    );
    expect(state.blocks[2], isA<CodexSshAuthenticationFailedBlock>());
    expect(
      (state.blocks[2] as CodexSshAuthenticationFailedBlock).authMode,
      AuthMode.privateKey,
    );
  });

  test('upserts repeated identical SSH failures instead of appending them', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshConnectFailedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        message: 'Connection refused',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshConnectFailedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        host: '192.168.178.164',
        port: 22,
        message: 'Timed out',
      ),
    );

    expect(state.blocks, hasLength(1));
    expect(state.blocks.single, isA<CodexSshConnectFailedBlock>());
    expect(
      (state.blocks.single as CodexSshConnectFailedBlock).message,
      'Timed out',
    );
  });

  test('keeps SSH authentication milestones non-visible by default', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSshAuthenticatedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        username: 'vince',
        authMode: AuthMode.password,
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);
    expect(state.connectionStatus, CodexRuntimeSessionState.ready);
  });

  test('hides non-signal status events and defers thread token usage', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeStatusEvent(
        createdAt: now,
        rawMethod: 'unknown/method',
        title: 'Unknown Method',
        message: 'Received unknown method.',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeStatusEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        rawMethod: 'thread/tokenUsage/updated',
        title: 'Thread token usage',
        message: 'Last: input 10 | Total: input 20\nContext window: 200000',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);
    expect(state.activeTurn?.pendingThreadTokenUsageBlock, isNotNull);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeStatusEvent(
        createdAt: now.add(const Duration(seconds: 2)),
        threadId: 'thread_123',
        rawMethod: 'thread/tokenUsage/updated',
        title: 'Thread token usage',
        message: 'Last: input 12 | Total: input 24\nContext window: 200000',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(
      state.activeTurn?.pendingThreadTokenUsageBlock?.body,
      contains('input 24'),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: now.add(const Duration(seconds: 3)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        state: CodexRuntimeTurnState.completed,
        usage: const CodexRuntimeTurnUsage(
          inputTokens: 12,
          cachedInputTokens: 3,
          outputTokens: 7,
        ),
      ),
    );

    expect(state.activeTurn, isNull);
    expect(state.blocks, hasLength(1));
    final boundary = state.blocks.single as CodexTurnBoundaryBlock;
    expect(boundary.usage, isNotNull);
    expect(boundary.usage?.title, 'Thread token usage');
    expect(boundary.usage?.body, contains('input 24'));
    expect(state.transcriptBlocks, hasLength(1));
    expect(state.transcriptBlocks.single, isA<CodexTurnBoundaryBlock>());
  });
}
