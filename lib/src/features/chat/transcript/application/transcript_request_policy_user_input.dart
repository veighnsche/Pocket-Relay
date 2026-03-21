part of 'transcript_request_policy.dart';

CodexSessionState _applyUserInputRequested(
  TranscriptRequestPolicy policy,
  CodexSessionState state,
  CodexRuntimeUserInputRequestedEvent event,
) {
  final requestId = event.requestId;
  if (requestId == null) {
    return state;
  }

  final turnId = event.turnId ?? state.activeTurn?.turnId;
  final threadId = event.threadId ?? state.activeTurn?.threadId;
  final activeTurn = _freezeArtifactsForRequest(
    _ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: event.createdAt,
    ),
    itemId: event.itemId,
  );
  final wasBlocking = activeTurn?.hasBlockingRequests ?? false;
  final pendingRequest = CodexSessionPendingUserInputRequest(
    requestId: requestId,
    requestType: CodexCanonicalRequestType.toolUserInput,
    createdAt: event.createdAt,
    threadId: threadId,
    turnId: turnId,
    itemId: event.itemId,
    questions: event.questions,
    args: event.rawPayload,
  );

  return state.copyWithProjectedTranscript(
    activeTurn: _activeTurnForPendingInput(
      activeTurn,
      requestId: requestId,
      pendingRequest: pendingRequest,
      turnTimer: wasBlocking
          ? activeTurn?.timer
          : policy._support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
    ),
  );
}

CodexSessionState _applyUserInputResolved(
  TranscriptRequestPolicy policy,
  CodexSessionState state,
  CodexRuntimeUserInputResolvedEvent event,
) {
  final requestId = event.requestId;
  if (requestId == null) {
    return state;
  }

  final nextInputRequests = <String, CodexSessionPendingUserInputRequest>{
    ...?state.activeTurn?.pendingUserInputRequests,
  }..remove(requestId);
  final hasBlockingRequestsRemaining =
      state.activeTurn?.pendingApprovalRequests.isNotEmpty == true ||
      nextInputRequests.isNotEmpty;
  final pendingRequest = state.activeTurn?.pendingUserInputRequests[requestId];
  final resolvedBlock = CodexUserInputRequestBlock(
    id: 'request_$requestId',
    createdAt: event.createdAt,
    requestId: requestId,
    requestType: CodexCanonicalRequestType.toolUserInput,
    title: 'Input submitted',
    body: codexAnswersSummaryFromQuestions(
      questions:
          pendingRequest?.questions ?? const <CodexRuntimeUserInputQuestion>[],
      answers: event.answers,
    ),
    isResolved: true,
    questions:
        pendingRequest?.questions ?? const <CodexRuntimeUserInputQuestion>[],
    answers: event.answers,
  );
  final nextState = state.copyWithProjectedTranscript(
    activeTurn: _activeTurnAfterUserInputResolved(
      state.activeTurn,
      requestId: requestId,
      turnTimer: hasBlockingRequestsRemaining
          ? state.activeTurn?.timer
          : policy._support.resumeTurnTimer(
              state.activeTurn?.timer,
              event.createdAt,
            ),
    ),
  );
  return _stateWithResolvedTranscriptBlock(
    nextState,
    resolvedBlock,
    turnId: event.turnId,
    threadId: event.threadId,
  );
}

