part of 'chat_session_controller.dart';

Future<void> _restoreConversationTranscriptForController(
  ChatSessionController controller,
  String threadId,
) async {
  await _performHistoryRestoringThreadTransitionForController(
    controller,
    operation: () =>
        controller.appServerClient.readThreadWithTurns(threadId: threadId),
    loadingRestoreState: ChatHistoricalConversationRestoreState(
      threadId: threadId,
      phase: ChatHistoricalConversationRestorePhase.loading,
    ),
    emptyHistoryRestoreState: ChatHistoricalConversationRestoreState(
      threadId: threadId,
      phase: ChatHistoricalConversationRestorePhase.unavailable,
    ),
    failureRestoreState: ChatHistoricalConversationRestoreState(
      threadId: threadId,
      phase: ChatHistoricalConversationRestorePhase.failed,
    ),
    failureTitle: 'Conversation load failed',
    failureMessage: 'Could not load the saved conversation transcript.',
  );
}

Future<CodexSessionState?>
_performHistoryRestoringThreadTransitionForController(
  ChatSessionController controller, {
  required Future<CodexAppServerThreadHistory> Function() operation,
  required String failureTitle,
  required String failureMessage,
  ChatHistoricalConversationRestoreState? loadingRestoreState,
  ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
  ChatHistoricalConversationRestoreState? failureRestoreState,
  bool rememberContinuationThread = false,
}) async {
  if (loadingRestoreState != null) {
    controller._setHistoricalConversationRestoreState(loadingRestoreState);
  }

  try {
    await _ensureChatSessionAppServerConnected(controller);
    final thread = await operation();
    if (controller._isDisposed) {
      return null;
    }

    final nextState = _restoredChatSessionStateFromHistory(controller, thread);
    controller._clearConversationRecovery();
    controller._historicalConversationRestoreState =
        nextState.transcriptBlocks.isEmpty ? emptyHistoryRestoreState : null;
    if (rememberContinuationThread) {
      controller._rememberContinuationThread(thread.id);
    }
    controller._applySessionState(nextState);
    return nextState;
  } catch (error) {
    if (failureRestoreState != null) {
      controller._setHistoricalConversationRestoreState(failureRestoreState);
    }
    _reportChatSessionAppServerFailure(
      controller,
      title: failureTitle,
      message: failureMessage,
      error: error,
    );
    return null;
  }
}

CodexSessionState _restoredChatSessionStateFromHistory(
  ChatSessionController controller,
  CodexAppServerThreadHistory thread,
) {
  final historicalConversation = controller._historicalConversationNormalizer
      .normalize(thread);
  return controller._historicalConversationRestorer.restore(
    historicalConversation,
  );
}

Future<bool> _sendPromptWithAppServerForController(
  ChatSessionController controller,
  String prompt,
) async {
  controller._isTrackingSshBootstrapFailures = true;
  controller._sawTrackedSshBootstrapFailure = false;
  try {
    final threadId = await _ensureChatSessionAppServerThread(controller);
    controller._clearConversationRecovery();
    controller._applySessionState(
      controller._sessionState.copyWith(
        connectionStatus: CodexRuntimeSessionState.running,
      ),
    );
    final turn = await controller.appServerClient.sendUserMessage(
      threadId: threadId,
      text: prompt,
      model: controller._selectedModelOverride(),
      effort: controller._profile.reasoningEffort,
    );
    await controller._conversationSelection.recordConversationSelection(
      threadId: turn.threadId,
    );
    controller._rememberContinuationThread(turn.threadId);
    _applyChatSessionRuntimeEvent(
      controller,
      CodexRuntimeTurnStartedEvent(
        createdAt: DateTime.now(),
        threadId: turn.threadId,
        turnId: turn.turnId,
        rawMethod: 'turn/start(response)',
      ),
    );
    return true;
  } catch (error) {
    final recoveryAssessment = controller._conversationRecoveryPolicy
        .assessSendFailure(
          error: error,
          sessionState: controller._sessionState,
          sessionLabel: controller._sessionLabel(),
          preferredAlternateThreadId: controller.appServerClient.threadId,
        );
    if (recoveryAssessment.recoveryState != null) {
      controller._setConversationRecovery(recoveryAssessment.recoveryState!);
    }
    if (controller._sessionState.activeTurn == null &&
        controller._sessionState.pendingLocalUserMessageBlockIds.isNotEmpty) {
      controller._applySessionState(
        controller._sessionReducer.clearLocalUserMessageCorrelationState(
          controller._sessionState,
        ),
      );
    }
    await Future<void>.microtask(() {});
    _reportChatSessionAppServerFailure(
      controller,
      title: recoveryAssessment.presentation.title,
      message: recoveryAssessment.presentation.message,
      error: error,
      runtimeErrorMessage: recoveryAssessment.presentation.runtimeErrorMessage,
      suppressRuntimeError: controller._sawTrackedSshBootstrapFailure,
      suppressSnackBar: recoveryAssessment.suppressSnackBar,
    );
    return false;
  } finally {
    controller._isTrackingSshBootstrapFailures = false;
    controller._sawTrackedSshBootstrapFailure = false;
  }
}

Future<String> _ensureChatSessionAppServerThread(
  ChatSessionController controller,
) async {
  await _ensureChatSessionAppServerConnected(controller);

  final activeThreadId = controller._activeConversationThreadId();
  final trackedThreadId = controller._normalizedThreadId(
    controller.appServerClient.threadId,
  );
  if (activeThreadId != null && trackedThreadId == activeThreadId) {
    controller._rememberContinuationThread(activeThreadId);
    return activeThreadId;
  }

  final resumeThreadId =
      activeThreadId ??
      controller._conversationSelection.resumeThreadId(
        ephemeralSession: controller._profile.ephemeralSession,
      );
  final session = await controller.appServerClient.startSession(
    model: controller._selectedModelOverride(),
    reasoningEffort: controller._profile.reasoningEffort,
    resumeThreadId: resumeThreadId,
  );
  controller._rememberContinuationThread(session.threadId);
  _rememberChatSessionHeaderMetadata(controller, session);
  _applyChatSessionRuntimeEvent(
    controller,
    CodexRuntimeThreadStartedEvent(
      createdAt: DateTime.now(),
      threadId: session.threadId,
      providerThreadId: session.threadId,
      rawMethod: resumeThreadId == null
          ? 'thread/start(response)'
          : 'thread/resume(response)',
      threadName: session.thread?.name,
      sourceKind: session.thread?.sourceKind,
      agentNickname: session.thread?.agentNickname,
      agentRole: session.thread?.agentRole,
    ),
  );
  return session.threadId;
}

void _rememberChatSessionHeaderMetadata(
  ChatSessionController controller,
  CodexAppServerSession session,
) {
  final nextMetadata = controller._sessionState.headerMetadata.copyWith(
    cwd: session.cwd.trim().isEmpty ? null : session.cwd.trim(),
    model: session.model.trim().isEmpty ? null : session.model.trim(),
    modelProvider: session.modelProvider.trim().isEmpty
        ? null
        : session.modelProvider.trim(),
    reasoningEffort:
        session.reasoningEffort == null ||
            session.reasoningEffort!.trim().isEmpty
        ? null
        : session.reasoningEffort!.trim(),
  );
  controller._applySessionState(
    controller._sessionState.copyWith(headerMetadata: nextMetadata),
  );
}

Future<void> _ensureChatSessionAppServerConnected(
  ChatSessionController controller,
) async {
  if (controller.appServerClient.isConnected) {
    return;
  }

  await controller.appServerClient.connect(
    profile: controller._profile,
    secrets: controller._secrets,
  );
}

Future<void> _stopChatSessionAppServerTurn(
  ChatSessionController controller,
) async {
  try {
    final targetTimeline =
        controller._sessionState.selectedTimeline ??
        controller._sessionState.rootTimeline;
    final turnId = targetTimeline?.activeTurn?.turnId;
    if (targetTimeline == null || turnId == null) {
      return;
    }
    await controller.appServerClient.abortTurn(
      threadId: targetTimeline.threadId,
      turnId: turnId,
    );
  } catch (error) {
    _reportChatSessionAppServerFailure(
      controller,
      title: 'Stop failed',
      message: 'Could not stop the active Codex turn.',
      error: error,
    );
  }
}

Future<void> _resolveChatSessionApproval(
  ChatSessionController controller,
  String requestId, {
  required bool approved,
}) async {
  final pendingRequest = controller._findPendingApprovalRequest(requestId);
  if (pendingRequest == null) {
    controller._emitSnackBar('This approval request is no longer pending.');
    return;
  }

  try {
    await controller.appServerClient.resolveApproval(
      requestId: requestId,
      approved: approved,
    );
  } catch (error) {
    _reportChatSessionAppServerFailure(
      controller,
      title: approved ? 'Approval failed' : 'Denial failed',
      message: 'Could not submit the decision for this request.',
      error: error,
    );
  }
}

void _reportChatSessionAppServerFailure(
  ChatSessionController controller, {
  required String title,
  required String message,
  required Object error,
  String? runtimeErrorMessage,
  bool suppressRuntimeError = false,
  bool suppressSnackBar = false,
}) {
  final now = DateTime.now();
  _applyChatSessionRuntimeEvent(
    controller,
    CodexRuntimeSessionStateChangedEvent(
      createdAt: now,
      state: CodexRuntimeSessionState.ready,
      reason: message,
      rawMethod: 'app-server/failure',
    ),
  );
  if (!suppressRuntimeError) {
    _applyChatSessionRuntimeEvent(
      controller,
      CodexRuntimeErrorEvent(
        createdAt: now,
        message: runtimeErrorMessage ?? '$title: $error',
        errorClass: CodexRuntimeErrorClass.transportError,
        rawMethod: 'app-server/failure',
      ),
    );
  }
  if (!suppressSnackBar) {
    controller._emitSnackBar(message);
  }
}
