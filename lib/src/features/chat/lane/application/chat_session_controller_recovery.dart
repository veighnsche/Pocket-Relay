part of 'chat_session_controller.dart';

extension _ChatSessionControllerRecovery on ChatSessionController {
  void startFreshConversation() {
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.freshConversationBlockedByActiveTurn(),
      );
      return;
    }
    _resetConversationState(
      nextState: _sessionReducer.startFreshThread(
        _sessionState,
        message: 'The next prompt will start a fresh Codex thread.',
      ),
    );
  }

  void clearTranscript() {
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.clearTranscriptBlockedByActiveTurn(),
      );
      return;
    }
    _resetConversationState(
      nextState: _sessionReducer.clearTranscript(_sessionState),
    );
  }

  void openConversationRecoveryAlternateSession() {
    final alternateThreadId = _conversationRecoveryState?.alternateThreadId
        ?.trim();
    if (alternateThreadId == null || alternateThreadId.isEmpty) {
      return;
    }

    final timeline = _sessionState.timelineForThread(alternateThreadId);
    if (timeline == null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.alternateSessionUnavailable(),
      );
      return;
    }

    final nextRegistry = <String, CodexThreadRegistryEntry>{
      for (final entry in _sessionState.threadRegistry.entries)
        entry.key: entry.value.copyWith(
          isPrimary: entry.key == alternateThreadId,
        ),
    };

    _invalidateHistoricalConversationRestore();
    _suppressTrackedThreadReuse = false;
    _clearConversationRecovery();
    _clearHistoricalConversationRestoreState();
    _applySessionState(
      _sessionState.copyWith(
        rootThreadId: alternateThreadId,
        selectedThreadId: alternateThreadId,
        threadRegistry: nextRegistry,
      ),
    );
  }

  Future<void> selectConversationForResume(String threadId) async {
    final normalizedThreadId = _normalizedThreadId(threadId);
    if (normalizedThreadId == null) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    _suppressTrackedThreadReuse = false;
    await _restoreConversationTranscript(normalizedThreadId);
  }

  Future<void> reattachConversation(String threadId) async {
    final normalizedThreadId = _normalizedThreadId(threadId);
    if (normalizedThreadId == null) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    _invalidateHistoricalConversationRestore();
    _clearHistoricalConversationRestoreState();
    if (!_hasVisibleConversationState()) {
      await _reattachConversationWithHistoryBaseline(normalizedThreadId);
      return;
    }

    await _resumeConversationThread(normalizedThreadId);
  }

  Future<void> _resumeConversationThread(String threadId) async {
    await _ensureChatSessionAppServerConnected(this);
    final session = await appServerClient.resumeThread(
      threadId: threadId,
      model: _selectedModelOverride(),
      reasoningEffort: _profile.reasoningEffort,
    );
    _clearConversationRecovery();
    _suppressTrackedThreadReuse = false;
    _rememberChatSessionHeaderMetadata(this, session);
    _applyChatSessionRuntimeEvent(
      this,
      CodexRuntimeThreadStartedEvent(
        createdAt: DateTime.now(),
        threadId: session.threadId,
        providerThreadId: session.threadId,
        rawMethod: 'thread/resume(response)',
        threadName: session.thread?.name,
        sourceKind: session.thread?.sourceKind,
        agentNickname: session.thread?.agentNickname,
        agentRole: session.thread?.agentRole,
      ),
    );
  }

  Future<void> _reattachConversationWithHistoryBaseline(String threadId) async {
    Object? historyRestoreError;
    StackTrace? historyRestoreStackTrace;
    CodexSessionState? restoredState;
    CodexSessionHeaderMetadata? resumedHeaderMetadata;

    _startBufferingRuntimeEvents();
    try {
      await _resumeConversationThread(threadId);
      resumedHeaderMetadata = _sessionState.headerMetadata;
      try {
        final thread = await appServerClient.readThreadWithTurns(
          threadId: threadId,
        );
        restoredState = _restoredChatSessionStateFromHistory(this, thread);
      } catch (error, stackTrace) {
        historyRestoreError = error;
        historyRestoreStackTrace = stackTrace;
      }
    } finally {
      final bufferedEvents = _stopBufferingRuntimeEvents();
      if (restoredState != null) {
        _applySessionState(
          restoredState!.copyWith(
            headerMetadata: _mergeHeaderMetadataForHistoryBaseline(
              restoredState!.headerMetadata,
              fallback: resumedHeaderMetadata,
            ),
          ),
        );
      }
      for (final bufferedEvent in bufferedEvents) {
        _applyChatSessionRuntimeEvent(this, bufferedEvent);
      }
    }

    if (restoredState != null || _hasVisibleConversationState()) {
      return;
    }

    if (historyRestoreError != null) {
      Error.throwWithStackTrace(
        historyRestoreError!,
        historyRestoreStackTrace!,
      );
    }
  }

  Future<void> retryHistoricalConversationRestore() async {
    final threadId = _historicalConversationRestoreState?.threadId.trim();
    if (threadId == null || threadId.isEmpty) {
      return;
    }

    await _restoreConversationTranscript(threadId);
  }

  Future<ChatComposerDraft?> continueFromUserMessage(String blockId) async {
    final normalizedBlockId = blockId.trim();
    if (normalizedBlockId.isEmpty) {
      return null;
    }
    if (_historicalConversationRestoreState != null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.continueBlockedByTranscriptRestore(),
      );
      return null;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.continueBlockedByActiveTurn(),
      );
      return null;
    }

    final targetThreadId = _activeConversationThreadId();
    if (targetThreadId == null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.continueTargetUnavailable(),
      );
      return null;
    }

    final timeline = _sessionState.timelineForThread(targetThreadId);
    final transcriptBlocks =
        timeline?.transcriptBlocks ?? _sessionState.transcriptBlocks;
    final userMessages = transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .toList(growable: false);
    final targetIndex = userMessages.indexWhere(
      (block) => block.id == normalizedBlockId,
    );
    if (targetIndex < 0) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.continuePromptUnavailable(),
      );
      return null;
    }

    final targetBlock = userMessages[targetIndex];
    final numTurns = userMessages.length - targetIndex;
    if (numTurns < 1) {
      return null;
    }

    final nextState = await _performHistoryRestoringThreadTransition(
      operation: () => appServerClient.rollbackThread(
        threadId: targetThreadId,
        numTurns: numTurns,
      ),
      userFacingError: ChatSessionErrors.continueFromPromptFailed(),
      loadingRestoreState: ChatHistoricalConversationRestoreState(
        threadId: targetThreadId,
        phase: ChatHistoricalConversationRestorePhase.loading,
      ),
    );
    if (nextState == null) {
      return null;
    }

    return targetBlock.draft;
  }

  Future<bool> branchSelectedConversation() async {
    if (_historicalConversationRestoreState != null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.branchBlockedByTranscriptRestore(),
      );
      return false;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.branchBlockedByActiveTurn(),
      );
      return false;
    }

    final targetThreadId = _selectedConversationThreadId();
    if (targetThreadId == null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.branchTargetUnavailable(),
      );
      return false;
    }

    final nextState = await _performHistoryRestoringThreadTransition(
      operation: () async {
        final forkedSession = await appServerClient.forkThread(
          threadId: targetThreadId,
          persistExtendedHistory: true,
        );
        return appServerClient.readThreadWithTurns(
          threadId: forkedSession.threadId,
        );
      },
      userFacingError: ChatSessionErrors.branchConversationFailed(),
      loadingRestoreState: ChatHistoricalConversationRestoreState(
        threadId: targetThreadId,
        phase: ChatHistoricalConversationRestorePhase.loading,
      ),
    );
    return nextState != null;
  }

  void _setConversationRecovery(ChatConversationRecoveryState nextState) {
    final currentState = _conversationRecoveryState;
    if (currentState?.reason == nextState.reason &&
        currentState?.alternateThreadId == nextState.alternateThreadId &&
        currentState?.expectedThreadId == nextState.expectedThreadId &&
        currentState?.actualThreadId == nextState.actualThreadId) {
      return;
    }

    _conversationRecoveryState = nextState;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _clearConversationRecovery() {
    if (_conversationRecoveryState == null) {
      return;
    }

    _conversationRecoveryState = null;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _setHistoricalConversationRestoreState(
    ChatHistoricalConversationRestoreState nextState,
  ) {
    final currentState = _historicalConversationRestoreState;
    if (currentState?.phase == nextState.phase &&
        currentState?.threadId == nextState.threadId) {
      return;
    }

    _historicalConversationRestoreState = nextState;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _clearHistoricalConversationRestoreState() {
    if (_historicalConversationRestoreState == null) {
      return;
    }

    _historicalConversationRestoreState = null;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _resetConversationState({required CodexSessionState nextState}) {
    _invalidateHistoricalConversationRestore();
    _clearConversationRecovery();
    _clearHistoricalConversationRestoreState();
    _suppressTrackedThreadReuse = true;
    _applySessionState(nextState);
  }

  String? _activeConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(_sessionState.rootThreadId);
  }

  String? _selectedConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(
      _sessionState.currentThreadId ?? _sessionState.rootThreadId,
    );
  }

  String? _trackedThreadReuseCandidate() {
    if (_profile.ephemeralSession ||
        _suppressTrackedThreadReuse ||
        _sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(appServerClient.threadId);
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}

CodexSessionHeaderMetadata _mergeHeaderMetadataForHistoryBaseline(
  CodexSessionHeaderMetadata restored, {
  CodexSessionHeaderMetadata? fallback,
}) {
  if (fallback == null) {
    return restored;
  }

  return restored.copyWith(
    cwd: _nonEmptyMetadataValue(restored.cwd, fallback.cwd),
    model: _nonEmptyMetadataValue(restored.model, fallback.model),
    modelProvider: _nonEmptyMetadataValue(
      restored.modelProvider,
      fallback.modelProvider,
    ),
    reasoningEffort: _nonEmptyMetadataValue(
      restored.reasoningEffort,
      fallback.reasoningEffort,
    ),
  );
}

String? _nonEmptyMetadataValue(String? preferred, String? fallback) {
  final normalizedPreferred = preferred?.trim();
  if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
    return normalizedPreferred;
  }

  final normalizedFallback = fallback?.trim();
  if (normalizedFallback != null && normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }

  return null;
}
