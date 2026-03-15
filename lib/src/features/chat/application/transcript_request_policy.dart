import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
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

    final wasBlocking = _support.hasBlockingRequest(state);
    if (event.requestType == CodexCanonicalRequestType.mcpServerElicitation) {
      final pendingUserInput = CodexSessionPendingUserInputRequest(
        requestId: requestId,
        requestType: event.requestType,
        createdAt: event.createdAt,
        threadId: event.threadId,
        turnId: event.turnId,
        itemId: event.itemId,
        detail: event.detail,
        args: event.args,
      );
      final nextState = state.copyWith(
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          ...state.pendingUserInputRequests,
          requestId: pendingUserInput,
        },
        turnTimers: wasBlocking
            ? state.turnTimers
            : _support.pauseTurnTimer(
                state.turnTimers,
                event.turnId ?? state.turnId,
                event.createdAt,
              ),
      );
      return _support.upsertBlock(
        nextState,
        CodexUserInputRequestBlock(
          id: 'request_$requestId',
          createdAt: event.createdAt,
          requestId: requestId,
          requestType: event.requestType,
          title: requestTitle(event.requestType),
          body: event.detail ?? 'Codex requested additional user input.',
        ),
      );
    }

    final pendingRequest = CodexSessionPendingRequest(
      requestId: requestId,
      requestType: event.requestType,
      createdAt: event.createdAt,
      threadId: event.threadId,
      turnId: event.turnId,
      itemId: event.itemId,
      detail: event.detail,
      args: event.args,
    );

    final nextState = state.copyWith(
      pendingApprovalRequests: <String, CodexSessionPendingRequest>{
        ...state.pendingApprovalRequests,
        requestId: pendingRequest,
      },
      turnTimers: wasBlocking
          ? state.turnTimers
          : _support.pauseTurnTimer(
              state.turnTimers,
              event.turnId ?? state.turnId,
              event.createdAt,
            ),
    );
    return _support.upsertBlock(
      nextState,
      CodexApprovalRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: event.requestType,
        title: requestTitle(event.requestType),
        body: event.detail ?? 'Codex needs a decision before it can continue.',
      ),
    );
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
      ...state.pendingApprovalRequests,
    }..remove(requestId);
    final nextInputRequests = <String, CodexSessionPendingUserInputRequest>{
      ...state.pendingUserInputRequests,
    }..remove(requestId);

    final nextState = state.copyWith(
      pendingApprovalRequests: nextApprovalRequests,
      pendingUserInputRequests: nextInputRequests,
      turnTimers:
          nextApprovalRequests.isNotEmpty || nextInputRequests.isNotEmpty
          ? state.turnTimers
          : _support.resumeTurnTimer(
              state.turnTimers,
              event.turnId ?? state.turnId,
              event.createdAt,
            ),
    );
    return _support.upsertBlock(
      nextState,
      _resolvedRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: event.requestType,
        title: '${requestTitle(event.requestType)} resolved',
        body: 'Codex received a response for this request.',
      ),
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

    final wasBlocking = _support.hasBlockingRequest(state);
    final pendingRequest = CodexSessionPendingUserInputRequest(
      requestId: requestId,
      requestType: CodexCanonicalRequestType.toolUserInput,
      createdAt: event.createdAt,
      threadId: event.threadId,
      turnId: event.turnId,
      itemId: event.itemId,
      questions: event.questions,
      args: event.rawPayload,
    );

    final nextState = state.copyWith(
      pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
        ...state.pendingUserInputRequests,
        requestId: pendingRequest,
      },
      turnTimers: wasBlocking
          ? state.turnTimers
          : _support.pauseTurnTimer(
              state.turnTimers,
              event.turnId ?? state.turnId,
              event.createdAt,
            ),
    );
    return _support.upsertBlock(
      nextState,
      CodexUserInputRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: questionsSummary(event.questions),
        questions: event.questions,
      ),
    );
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
      ...state.pendingUserInputRequests,
    }..remove(requestId);
    final nextState = state.copyWith(
      pendingUserInputRequests: nextInputRequests,
      turnTimers:
          state.pendingApprovalRequests.isNotEmpty ||
              nextInputRequests.isNotEmpty
          ? state.turnTimers
          : _support.resumeTurnTimer(
              state.turnTimers,
              event.turnId ?? state.turnId,
              event.createdAt,
            ),
    );
    return _support.upsertBlock(
      nextState,
      CodexUserInputRequestBlock(
        id: 'request_$requestId',
        createdAt: event.createdAt,
        requestId: requestId,
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input submitted',
        body: answersSummary(event.answers),
        isResolved: true,
        answers: event.answers,
      ),
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
}
