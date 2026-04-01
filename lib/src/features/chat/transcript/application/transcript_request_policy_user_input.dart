part of 'transcript_request_policy.dart';

TranscriptSessionState _applyUserInputRequested(
  TranscriptRequestPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeUserInputRequestedEvent event,
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
  final pendingRequest = TranscriptSessionPendingUserInputRequest(
    requestId: requestId,
    requestType: TranscriptCanonicalRequestType.toolUserInput,
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

TranscriptSessionState _applyUserInputResolved(
  TranscriptRequestPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeUserInputResolvedEvent event,
) {
  final requestId = event.requestId;
  if (requestId == null) {
    return state;
  }

  final nextInputRequests = <String, TranscriptSessionPendingUserInputRequest>{
    ...?state.activeTurn?.pendingUserInputRequests,
  }..remove(requestId);
  final hasBlockingRequestsRemaining =
      state.activeTurn?.pendingApprovalRequests.isNotEmpty == true ||
      nextInputRequests.isNotEmpty;
  final pendingRequest = state.activeTurn?.pendingUserInputRequests[requestId];
  final resolvedBlock = TranscriptUserInputRequestBlock(
    id: 'request_$requestId',
    createdAt: event.createdAt,
    requestId: requestId,
    requestType: TranscriptCanonicalRequestType.toolUserInput,
    title: 'Input submitted',
    body: transcriptAnswersSummaryFromQuestions(
      questions:
          pendingRequest?.questions ??
          const <TranscriptRuntimeUserInputQuestion>[],
      answers: event.answers,
    ),
    isResolved: true,
    questions:
        pendingRequest?.questions ??
        const <TranscriptRuntimeUserInputQuestion>[],
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
