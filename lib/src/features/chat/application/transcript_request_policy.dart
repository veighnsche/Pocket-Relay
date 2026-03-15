import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptRequestPolicy {
  const TranscriptRequestPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  CodexSessionState applyRequestOpened(
    CodexSessionState state,
    CodexRuntimeRequestOpenedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    final turnId = event.turnId ?? state.activeTurn?.turnId;
    final threadId = event.threadId ?? state.activeTurn?.threadId;
    final activeTurn = _freezeTailArtifact(
      _ensureActiveTurn(
        state.activeTurn,
        turnId: turnId,
        threadId: threadId,
        createdAt: event.createdAt,
      ),
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
      final nextState = state.copyWith(
        activeTurn: _activeTurnForPendingInput(
          activeTurn,
          requestId: requestId,
          pendingRequest: pendingUserInput,
          turnTimer: wasBlocking
              ? activeTurn?.timer
              : _support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
        ),
      );
      return nextState;
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

    final nextState = state.copyWith(
      activeTurn: _activeTurnForPendingApproval(
        activeTurn,
        requestId: requestId,
        pendingRequest: pendingRequest,
        turnTimer: wasBlocking
            ? activeTurn?.timer
            : _support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
      ),
    );
    return nextState;
  }

  CodexSessionState applyRequestResolved(
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

    final resolvedBlock = _resolvedRequestBlock(
      id: 'request_$requestId',
      createdAt: event.createdAt,
      requestId: requestId,
      requestType: event.requestType,
      title: '${requestTitle(event.requestType)} resolved',
      body: 'Codex received a response for this request.',
    );
    final nextState = state.copyWith(
      activeTurn: _activeTurnAfterRequestResolved(
        state.activeTurn,
        requestId: requestId,
        turnTimer: hasBlockingRequestsRemaining
            ? state.activeTurn?.timer
            : _support.resumeTurnTimer(
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

  CodexSessionState applyUserInputRequested(
    CodexSessionState state,
    CodexRuntimeUserInputRequestedEvent event,
  ) {
    final requestId = event.requestId;
    if (requestId == null) {
      return state;
    }

    final turnId = event.turnId ?? state.activeTurn?.turnId;
    final threadId = event.threadId ?? state.activeTurn?.threadId;
    final activeTurn = _freezeTailArtifact(
      _ensureActiveTurn(
        state.activeTurn,
        turnId: turnId,
        threadId: threadId,
        createdAt: event.createdAt,
      ),
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

    final nextState = state.copyWith(
      activeTurn: _activeTurnForPendingInput(
        activeTurn,
        requestId: requestId,
        pendingRequest: pendingRequest,
        turnTimer: wasBlocking
            ? activeTurn?.timer
            : _support.pauseTurnTimer(activeTurn?.timer, event.createdAt),
      ),
    );
    return nextState;
  }

  CodexSessionState applyUserInputResolved(
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
    final resolvedBlock = CodexUserInputRequestBlock(
      id: 'request_$requestId',
      createdAt: event.createdAt,
      requestId: requestId,
      requestType: CodexCanonicalRequestType.toolUserInput,
      title: 'Input submitted',
      body: answersSummary(event.answers),
      isResolved: true,
      answers: event.answers,
    );
    final nextState = state.copyWith(
      activeTurn: _activeTurnAfterUserInputResolved(
        state.activeTurn,
        requestId: requestId,
        turnTimer: hasBlockingRequestsRemaining
            ? state.activeTurn?.timer
            : _support.resumeTurnTimer(
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

  String requestTitle(CodexCanonicalRequestType requestType) {
    return switch (requestType) {
      CodexCanonicalRequestType.commandExecutionApproval => 'Command approval',
      CodexCanonicalRequestType.fileReadApproval => 'File read approval',
      CodexCanonicalRequestType.fileChangeApproval => 'File change approval',
      CodexCanonicalRequestType.applyPatchApproval => 'Patch approval',
      CodexCanonicalRequestType.execCommandApproval => 'Command approval',
      CodexCanonicalRequestType.permissionsRequestApproval =>
        'Permissions request',
      CodexCanonicalRequestType.toolUserInput => 'Input required',
      CodexCanonicalRequestType.mcpServerElicitation => 'MCP input required',
      CodexCanonicalRequestType.dynamicToolCall => 'Tool call',
      CodexCanonicalRequestType.authTokensRefresh => 'Auth refresh',
      CodexCanonicalRequestType.unknown => 'Request',
    };
  }

  String questionsSummary(List<CodexRuntimeUserInputQuestion> questions) {
    return questions
        .map((question) => '${question.header}: ${question.question}')
        .join('\n\n');
  }

  String answersSummary(Map<String, List<String>> answers) {
    if (answers.isEmpty) {
      return 'The requested input was submitted.';
    }

    return answers.entries
        .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
        .join('\n');
  }

  CodexUiBlock _resolvedRequestBlock({
    required String id,
    required DateTime createdAt,
    required String requestId,
    required CodexCanonicalRequestType requestType,
    required String title,
    required String body,
  }) {
    final isUserInput =
        requestType == CodexCanonicalRequestType.toolUserInput ||
        requestType == CodexCanonicalRequestType.mcpServerElicitation;
    if (isUserInput) {
      return CodexUserInputRequestBlock(
        id: id,
        createdAt: createdAt,
        requestId: requestId,
        requestType: requestType,
        title: title,
        body: body,
        isResolved: true,
      );
    }

    return CodexApprovalRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title,
      body: body,
      isResolved: true,
      resolutionLabel: 'resolved',
    );
  }

  CodexActiveTurnState? _activeTurnForPendingApproval(
    CodexActiveTurnState? activeTurn, {
    required String requestId,
    required CodexSessionPendingRequest pendingRequest,
    required CodexSessionTurnTimer? turnTimer,
  }) {
    if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
      return activeTurn;
    }

    return activeTurn.copyWith(
      timer: turnTimer,
      status: CodexActiveTurnStatus.blocked,
      pendingApprovalRequests: <String, CodexSessionPendingRequest>{
        ...activeTurn.pendingApprovalRequests,
        requestId: pendingRequest,
      },
    );
  }

  CodexActiveTurnState? _activeTurnForPendingInput(
    CodexActiveTurnState? activeTurn, {
    required String requestId,
    required CodexSessionPendingUserInputRequest pendingRequest,
    required CodexSessionTurnTimer? turnTimer,
  }) {
    if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
      return activeTurn;
    }

    return activeTurn.copyWith(
      timer: turnTimer,
      status: CodexActiveTurnStatus.blocked,
      pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
        ...activeTurn.pendingUserInputRequests,
        requestId: pendingRequest,
      },
    );
  }

  CodexActiveTurnState? _activeTurnAfterRequestResolved(
    CodexActiveTurnState? activeTurn, {
    required String requestId,
    required CodexSessionTurnTimer? turnTimer,
  }) {
    if (activeTurn == null) {
      return null;
    }

    final nextApprovals = <String, CodexSessionPendingRequest>{
      ...activeTurn.pendingApprovalRequests,
    }..remove(requestId);
    final nextInputs = <String, CodexSessionPendingUserInputRequest>{
      ...activeTurn.pendingUserInputRequests,
    }..remove(requestId);

    return activeTurn.copyWith(
      timer: turnTimer,
      status: nextApprovals.isNotEmpty || nextInputs.isNotEmpty
          ? CodexActiveTurnStatus.blocked
          : CodexActiveTurnStatus.running,
      pendingApprovalRequests: nextApprovals,
      pendingUserInputRequests: nextInputs,
    );
  }

  CodexActiveTurnState? _activeTurnAfterUserInputResolved(
    CodexActiveTurnState? activeTurn, {
    required String requestId,
    required CodexSessionTurnTimer? turnTimer,
  }) {
    if (activeTurn == null) {
      return null;
    }

    final nextInputs = <String, CodexSessionPendingUserInputRequest>{
      ...activeTurn.pendingUserInputRequests,
    }..remove(requestId);

    return activeTurn.copyWith(
      timer: turnTimer,
      status:
          activeTurn.pendingApprovalRequests.isNotEmpty || nextInputs.isNotEmpty
          ? CodexActiveTurnStatus.blocked
          : CodexActiveTurnStatus.running,
      pendingUserInputRequests: nextInputs,
    );
  }

  CodexActiveTurnState? _ensureActiveTurn(
    CodexActiveTurnState? activeTurn, {
    required String? turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    if (activeTurn != null || turnId == null) {
      return activeTurn;
    }

    return CodexActiveTurnState(
      turnId: turnId,
      threadId: threadId,
      timer: CodexSessionTurnTimer(
        turnId: turnId,
        startedAt: createdAt,
        activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
      ),
    );
  }

  CodexSessionState _stateWithResolvedTranscriptBlock(
    CodexSessionState state,
    CodexUiBlock block, {
    required String? turnId,
    required String? threadId,
  }) {
    final activeTurn = _ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: block.createdAt,
    );
    if (activeTurn == null) {
      if (state.blocks.any((existing) => existing.id == block.id)) {
        return state;
      }
      return _support.appendBlock(state, block);
    }

    final existingIndex = activeTurn.artifacts.indexWhere(
      (artifact) => artifact.id == block.id,
    );
    if (existingIndex == -1) {
      return state.copyWith(activeTurn: _appendTurnBlock(activeTurn, block));
    }
    if (existingIndex != activeTurn.artifacts.length - 1) {
      return state;
    }

    final existingArtifact = activeTurn.artifacts[existingIndex];
    final nextBlock = _mergeResolvedRequestBlocks(
      switch (existingArtifact) {
        CodexTurnBlockArtifact(:final block) => block,
        _ => null,
      },
      _resolvedRequestBlockWithCreatedAt(
        block,
        createdAt: existingArtifact.createdAt,
      ),
    );

    return state.copyWith(
      activeTurn: _replaceTailTurnBlock(activeTurn, nextBlock),
    );
  }

  CodexActiveTurnState _appendTurnBlock(
    CodexActiveTurnState activeTurn,
    CodexUiBlock block,
  ) {
    return activeTurn.copyWith(
      artifacts: appendCodexTurnArtifact(
        activeTurn.artifacts,
        CodexTurnBlockArtifact(block: block),
      ),
    );
  }

  CodexActiveTurnState? _freezeTailArtifact(CodexActiveTurnState? activeTurn) {
    if (activeTurn == null || activeTurn.artifacts.isEmpty) {
      return activeTurn;
    }

    final frozenTail = freezeCodexTurnArtifact(activeTurn.artifacts.last);
    if (identical(frozenTail, activeTurn.artifacts.last)) {
      return activeTurn;
    }

    final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
    nextArtifacts[nextArtifacts.length - 1] = frozenTail;
    return activeTurn.copyWith(artifacts: nextArtifacts);
  }

  CodexActiveTurnState _replaceTailTurnBlock(
    CodexActiveTurnState activeTurn,
    CodexUiBlock block,
  ) {
    final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
    nextArtifacts[nextArtifacts.length - 1] = CodexTurnBlockArtifact(
      block: block,
    );
    return activeTurn.copyWith(artifacts: nextArtifacts);
  }

  CodexUiBlock _resolvedRequestBlockWithCreatedAt(
    CodexUiBlock block, {
    required DateTime createdAt,
  }) {
    return switch (block) {
      CodexApprovalRequestBlock() => CodexApprovalRequestBlock(
        id: block.id,
        createdAt: createdAt,
        requestId: block.requestId,
        requestType: block.requestType,
        title: block.title,
        body: block.body,
        isResolved: block.isResolved,
        resolutionLabel: block.resolutionLabel,
      ),
      CodexUserInputRequestBlock() => CodexUserInputRequestBlock(
        id: block.id,
        createdAt: createdAt,
        requestId: block.requestId,
        requestType: block.requestType,
        title: block.title,
        body: block.body,
        isResolved: block.isResolved,
        questions: block.questions,
        answers: block.answers,
      ),
      _ => block,
    };
  }

  CodexUiBlock _mergeResolvedRequestBlocks(
    CodexUiBlock? existingBlock,
    CodexUiBlock incomingBlock,
  ) {
    if (existingBlock == null) {
      return incomingBlock;
    }

    return switch ((existingBlock, incomingBlock)) {
      (
        CodexUserInputRequestBlock existing,
        CodexUserInputRequestBlock incoming,
      ) =>
        _mergeUserInputResolvedBlocks(existing, incoming),
      (
        CodexApprovalRequestBlock existing,
        CodexApprovalRequestBlock incoming,
      ) =>
        _mergeApprovalResolvedBlocks(existing, incoming),
      (
        CodexUserInputRequestBlock existing,
        CodexApprovalRequestBlock incoming,
      ) =>
        incoming.requestType == CodexCanonicalRequestType.unknown
            ? existing
            : incoming,
      (
        CodexApprovalRequestBlock _,
        CodexUserInputRequestBlock incoming,
      ) => incoming,
      _ => incomingBlock,
    };
  }

  CodexUserInputRequestBlock _mergeUserInputResolvedBlocks(
    CodexUserInputRequestBlock existing,
    CodexUserInputRequestBlock incoming,
  ) {
    final incomingIsRich = _isRichUserInputResolution(incoming);
    final existingIsRich = _isRichUserInputResolution(existing);
    if (existingIsRich && !incomingIsRich) {
      return existing;
    }

    return incoming.copyWith(
      questions: incoming.questions.isNotEmpty
          ? incoming.questions
          : existing.questions,
      answers: incoming.answers.isNotEmpty
          ? incoming.answers
          : existing.answers,
      body: incoming.body.isNotEmpty ? incoming.body : existing.body,
    );
  }

  CodexApprovalRequestBlock _mergeApprovalResolvedBlocks(
    CodexApprovalRequestBlock existing,
    CodexApprovalRequestBlock incoming,
  ) {
    final existingIsSpecific =
        existing.requestType != CodexCanonicalRequestType.unknown;
    final incomingIsSpecific =
        incoming.requestType != CodexCanonicalRequestType.unknown;
    if (existingIsSpecific && !incomingIsSpecific) {
      return existing;
    }

    return incoming;
  }

  bool _isRichUserInputResolution(CodexUserInputRequestBlock block) {
    return block.answers.isNotEmpty || block.title == 'Input submitted';
  }
}
