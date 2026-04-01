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
    var state = const TranscriptSessionState(
      connectionStatus: TranscriptRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeWarningEvent(
        createdAt: now,
        summary: 'Config warning',
        details: 'Bad config value',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeErrorEvent(
        createdAt: now,
        message: 'Command failed',
        errorClass: TranscriptRuntimeErrorClass.providerError,
      ),
    );

    expect(state.connectionStatus, TranscriptRuntimeSessionState.ready);
    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<TranscriptStatusBlock>());
    expect(state.blocks.last, isA<TranscriptErrorBlock>());
    expect(
      (state.blocks.first as TranscriptStatusBlock).statusKind,
      TranscriptStatusBlockKind.warning,
    );
  });

  test('deduplicates repeated unpinned host key prompts', () {
    final reducer = TranscriptReducer();
    var state = const TranscriptSessionState(
      connectionStatus: TranscriptRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);
    final event = TranscriptRuntimeUnpinnedHostKeyEvent(
      createdAt: now,
      host: '192.168.178.164',
      port: 22,
      keyType: 'ssh-ed25519',
      fingerprint: '7a:9f:d7:dc:2e:f2',
    );

    state = reducer.reduceRuntimeEvent(state, event);
    state = reducer.reduceRuntimeEvent(state, event);

    expect(state.connectionStatus, TranscriptRuntimeSessionState.ready);
    expect(state.blocks, hasLength(1));
    expect(state.blocks.single, isA<TranscriptSshUnpinnedHostKeyBlock>());
  });

  test('projects typed SSH failures into dedicated transcript SSH blocks', () {
    final reducer = TranscriptReducer();
    var state = const TranscriptSessionState(
      connectionStatus: TranscriptRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeSshConnectFailedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        message: 'Connection refused',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeSshHostKeyMismatchEvent(
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
      TranscriptRuntimeSshAuthenticationFailedEvent(
        createdAt: now.add(const Duration(milliseconds: 2)),
        host: '192.168.178.164',
        port: 22,
        username: 'vince',
        authMode: AuthMode.privateKey,
        message: 'Permission denied',
      ),
    );

    expect(state.blocks, hasLength(3));
    expect(state.blocks[0], isA<TranscriptSshConnectFailedBlock>());
    expect(
      (state.blocks[0] as TranscriptSshConnectFailedBlock).message,
      'Connection refused',
    );
    expect(state.blocks[1], isA<TranscriptSshHostKeyMismatchBlock>());
    expect(
      (state.blocks[1] as TranscriptSshHostKeyMismatchBlock)
          .expectedFingerprint,
      'aa:bb:cc',
    );
    expect(state.blocks[2], isA<TranscriptSshAuthenticationFailedBlock>());
    expect(
      (state.blocks[2] as TranscriptSshAuthenticationFailedBlock).authMode,
      AuthMode.privateKey,
    );
  });

  test('upserts repeated identical SSH failures instead of appending them', () {
    final reducer = TranscriptReducer();
    var state = const TranscriptSessionState(
      connectionStatus: TranscriptRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeSshConnectFailedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        message: 'Connection refused',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeSshConnectFailedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        host: '192.168.178.164',
        port: 22,
        message: 'Timed out',
      ),
    );

    expect(state.blocks, hasLength(1));
    expect(state.blocks.single, isA<TranscriptSshConnectFailedBlock>());
    expect(
      (state.blocks.single as TranscriptSshConnectFailedBlock).message,
      'Timed out',
    );
  });

  test('keeps SSH authentication milestones non-visible by default', () {
    final reducer = TranscriptReducer();
    var state = const TranscriptSessionState(
      connectionStatus: TranscriptRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeSshAuthenticatedEvent(
        createdAt: now,
        host: '192.168.178.164',
        port: 22,
        username: 'vince',
        authMode: AuthMode.password,
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);
    expect(state.connectionStatus, TranscriptRuntimeSessionState.ready);
  });

  test('hides non-signal status events and defers thread token usage', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeStatusEvent(
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
      TranscriptRuntimeTurnStartedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeStatusEvent(
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
      TranscriptRuntimeStatusEvent(
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
      TranscriptRuntimeTurnCompletedEvent(
        createdAt: now.add(const Duration(seconds: 3)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        state: TranscriptRuntimeTurnState.completed,
        usage: const TranscriptRuntimeTurnUsage(
          inputTokens: 12,
          cachedInputTokens: 3,
          outputTokens: 7,
        ),
      ),
    );

    expect(state.activeTurn, isNull);
    expect(state.blocks, hasLength(1));
    final boundary = state.blocks.single as TranscriptTurnBoundaryBlock;
    expect(boundary.usage, isNotNull);
    expect(boundary.usage?.title, 'Thread token usage');
    expect(boundary.usage?.body, contains('input 24'));
    expect(state.transcriptBlocks, hasLength(1));
    expect(state.transcriptBlocks.single, isA<TranscriptTurnBoundaryBlock>());
  });
}
