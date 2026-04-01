part of 'chat_session_controller.dart';

Future<void> _restoreConversationTranscriptForController(
  ChatSessionController controller,
  String threadId,
) async {
  await _performHistoryRestoringThreadTransitionForController(
    controller,
    operation: () =>
        controller.agentAdapterClient.readThreadWithTurns(threadId: threadId),
    userFacingError: ChatSessionErrors.conversationLoadFailed(),
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
  );
}

Future<TranscriptSessionState?>
_performHistoryRestoringThreadTransitionForController(
  ChatSessionController controller, {
  required Future<AgentAdapterThreadHistory> Function() operation,
  required PocketUserFacingError userFacingError,
  ChatHistoricalConversationRestoreState? loadingRestoreState,
  ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
  ChatHistoricalConversationRestoreState? failureRestoreState,
}) async {
  final restoreGeneration = controller._beginHistoricalConversationRestore(
    loadingState: loadingRestoreState,
  );

  try {
    await _ensureChatSessionAppServerConnected(controller);
    final thread = await operation();
    if (controller._isDisposed ||
        !controller._isCurrentHistoricalConversationRestore(
          restoreGeneration,
        )) {
      return null;
    }

    final nextState = _restoredChatSessionStateFromHistory(controller, thread);
    controller._clearConversationRecovery();
    controller._historicalConversationRestoreState =
        nextState.transcriptBlocks.isEmpty ? emptyHistoryRestoreState : null;
    controller._suppressTrackedThreadReuse = false;
    controller._applySessionState(nextState);
    return nextState;
  } catch (error) {
    if (!controller._isCurrentHistoricalConversationRestore(
      restoreGeneration,
    )) {
      return null;
    }
    if (failureRestoreState != null) {
      controller._setHistoricalConversationRestoreState(failureRestoreState);
    } else {
      controller._clearHistoricalConversationRestoreState();
    }
    _reportChatSessionAppServerFailure(
      controller,
      userFacingError: userFacingError,
      runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
        userFacingError,
        error: error,
      ),
    );
    return null;
  }
}

TranscriptSessionState _restoredChatSessionStateFromHistory(
  ChatSessionController controller,
  AgentAdapterThreadHistory thread,
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
  return _sendTurnInputWithAppServerForController(controller, text: prompt);
}

Future<bool> _sendDraftWithAppServerForController(
  ChatSessionController controller,
  ChatComposerDraft draft,
) async {
  return _sendTurnInputWithAppServerForController(
    controller,
    input: AgentAdapterTurnInput(
      text: draft.text,
      textElements: draft.textElements
          .map(
            (element) => AgentAdapterTextElement(
              start: element.start,
              end: element.end,
              placeholder: element.placeholder,
            ),
          )
          .toList(growable: false),
      images: draft.imageAttachments
          .map((attachment) => AgentAdapterImageInput(url: attachment.imageUrl))
          .toList(growable: false),
    ),
  );
}

Future<bool> _sendTurnInputWithAppServerForController(
  ChatSessionController controller, {
  String? text,
  AgentAdapterTurnInput? input,
}) async {
  controller._isTrackingSshBootstrapFailures = true;
  controller._sawTrackedSshBootstrapFailure = false;
  controller._sawTrackedUnpinnedHostKeyFailure = false;
  try {
    final threadId = await _ensureChatSessionAppServerThread(controller);
    controller._clearConversationRecovery();
    controller._applySessionState(
      controller._sessionState.copyWith(
        connectionStatus: TranscriptRuntimeSessionState.running,
      ),
    );
    final turn = await controller.agentAdapterClient.sendUserMessage(
      threadId: threadId,
      text: text,
      input: input,
      model: controller._selectedModelOverride(),
      effort: controller._profile.reasoningEffort,
    );
    controller._suppressTrackedThreadReuse = false;
    _applyChatSessionRuntimeEvent(
      controller,
      TranscriptRuntimeTurnStartedEvent(
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
          preferredAlternateThreadId: controller.agentAdapterClient.threadId,
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
      userFacingError: recoveryAssessment.presentation.userFacingError,
      runtimeErrorMessage: recoveryAssessment.presentation.runtimeErrorMessage,
      suppressRuntimeError: controller._sawTrackedSshBootstrapFailure,
      suppressSnackBar:
          recoveryAssessment.suppressSnackBar ||
          controller._sawTrackedUnpinnedHostKeyFailure,
    );
    return false;
  } finally {
    controller._isTrackingSshBootstrapFailures = false;
    controller._sawTrackedSshBootstrapFailure = false;
    controller._sawTrackedUnpinnedHostKeyFailure = false;
  }
}

Future<String> _ensureChatSessionAppServerThread(
  ChatSessionController controller,
) async {
  await _ensureChatSessionAppServerConnected(controller);

  final activeThreadId = controller._activeConversationThreadId();
  final trackedThreadId = controller._normalizedThreadId(
    controller.agentAdapterClient.threadId,
  );
  if (activeThreadId != null && trackedThreadId == activeThreadId) {
    controller._suppressTrackedThreadReuse = false;
    return activeThreadId;
  }

  final session = await controller.agentAdapterClient.startSession(
    model: controller._selectedModelOverride(),
    reasoningEffort: controller._profile.reasoningEffort,
    resumeThreadId: activeThreadId,
  );
  controller._suppressTrackedThreadReuse = false;
  _rememberChatSessionHeaderMetadata(controller, session);
  _applyChatSessionRuntimeEvent(
    controller,
    TranscriptRuntimeThreadStartedEvent(
      createdAt: DateTime.now(),
      threadId: session.threadId,
      providerThreadId: session.threadId,
      rawMethod: activeThreadId == null
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
  AgentAdapterSession session,
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
  final wasConnected = controller.agentAdapterClient.isConnected;
  if (!wasConnected) {
    await controller.agentAdapterClient.connect(
      profile: controller._profile,
      secrets: controller._secrets,
    );
  }

  try {
    await controller._refreshModelCatalogAfterConnect();
  } catch (error) {
    controller._emitDiagnosticWarning(
      ChatSessionErrors.modelCatalogHydrationFailed(error: error),
      rawMethod: 'local/model-catalog-hydration',
    );
    // Fail open when model metadata is unavailable; send/attach paths will
    // re-check the cached capability state if a later hydration succeeds.
  }
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
    await controller.agentAdapterClient.abortTurn(
      threadId: targetTimeline.threadId,
      turnId: turnId,
    );
  } catch (error) {
    final userFacingError = ChatSessionErrors.stopTurnFailed();
    _reportChatSessionAppServerFailure(
      controller,
      userFacingError: userFacingError,
      runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
        userFacingError,
        error: error,
      ),
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
    controller._emitUserFacingError(
      ChatSessionGuardrailErrors.approvalRequestUnavailable(),
    );
    return;
  }

  try {
    await controller.agentAdapterClient.resolveApproval(
      requestId: requestId,
      approved: approved,
    );
  } catch (error) {
    final userFacingError = approved
        ? ChatSessionErrors.approveRequestFailed()
        : ChatSessionErrors.denyRequestFailed();
    _reportChatSessionAppServerFailure(
      controller,
      userFacingError: userFacingError,
      runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
        userFacingError,
        error: error,
      ),
    );
  }
}

void _reportChatSessionAppServerFailure(
  ChatSessionController controller, {
  required PocketUserFacingError userFacingError,
  String? runtimeErrorMessage,
  bool suppressRuntimeError = false,
  bool suppressSnackBar = false,
}) {
  final now = DateTime.now();
  _applyChatSessionRuntimeEvent(
    controller,
    TranscriptRuntimeSessionStateChangedEvent(
      createdAt: now,
      state: TranscriptRuntimeSessionState.ready,
      reason: userFacingError.message,
      rawMethod: 'app-server/failure',
    ),
  );
  if (!suppressRuntimeError) {
    _applyChatSessionRuntimeEvent(
      controller,
      TranscriptRuntimeErrorEvent(
        createdAt: now,
        message: runtimeErrorMessage ?? userFacingError.inlineMessage,
        errorClass: TranscriptRuntimeErrorClass.transportError,
        rawMethod: 'app-server/failure',
      ),
    );
  }
  if (!suppressSnackBar) {
    controller._emitSnackBar(userFacingError.inlineMessage);
  }
}
