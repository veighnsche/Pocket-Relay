part of 'transcript_request_policy.dart';

CodexSessionState _applyRequestOpened(
  TranscriptRequestPolicy policy,
  CodexSessionState state,
  CodexRuntimeRequestOpenedEvent event,
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
  if (event.requestType == CodexCanonicalRequestType.mcpServerElicitation) {
    final pendingUserInput = CodexSessionPendingUserInputRequest(
      requestId: requestId,
      requestType: event.requestType,
      createdAt: event.createdAt,
      threadId: threadId,
      turnId: turnId,
      itemId: event.itemId,
      detail: event.detail,
      args: event.args,
    );
    return state.copyWithProjectedTranscript(
      activeTurn: _activeTurnForPendingInput(
        activeTurn,
        requestId: requestId,
        pendingRequest: pendingUserInput,
        turnTimer: wasBlocking
            ? activeTurn?.timer
            : policy._support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
      ),
    );
  }

  final pendingRequest = CodexSessionPendingRequest(
    requestId: requestId,
    requestType: event.requestType,
    createdAt: event.createdAt,
    threadId: threadId,
    turnId: turnId,
    itemId: event.itemId,
    detail: event.detail,
    args: event.args,
  );

  return state.copyWithProjectedTranscript(
    activeTurn: _activeTurnForPendingApproval(
      activeTurn,
      requestId: requestId,
      pendingRequest: pendingRequest,
      turnTimer: wasBlocking
          ? activeTurn?.timer
          : policy._support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
    ),
  );
}

CodexSessionState _applyRequestResolved(
  TranscriptRequestPolicy policy,
  CodexSessionState state,
  CodexRuntimeRequestResolvedEvent event,
) {
  final requestId = event.requestId;
  if (requestId == null) {
    return state;
  }

  final nextApprovalRequests = <String, CodexSessionPendingRequest>{
    ...?state.activeTurn?.pendingApprovalRequests,
  }..remove(requestId);
  final nextInputRequests = <String, CodexSessionPendingUserInputRequest>{
    ...?state.activeTurn?.pendingUserInputRequests,
  }..remove(requestId);
  final hasBlockingRequestsRemaining =
      nextApprovalRequests.isNotEmpty || nextInputRequests.isNotEmpty;
  final pendingApproval = state.activeTurn?.pendingApprovalRequests[requestId];
  final decisionLabel = _resolutionLabel(
    policy._support,
    event.resolution,
    fallback: 'resolved',
  );

  final resolvedBlock = _resolvedRequestBlock(
    id: 'request_$requestId',
    createdAt: event.createdAt,
    requestId: requestId,
    requestType: event.requestType,
    title: '${codexRequestTitle(event.requestType)} $decisionLabel',
    body: _resolvedApprovalBody(
      pendingDetail: pendingApproval?.detail,
      decisionLabel: decisionLabel,
    ),
    resolutionLabel: decisionLabel,
  );
  final nextState = state.copyWithProjectedTranscript(
    activeTurn: _activeTurnAfterRequestResolved(
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

