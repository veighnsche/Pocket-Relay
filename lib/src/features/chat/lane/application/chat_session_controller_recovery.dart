part of 'chat_session_controller.dart';

extension _ChatSessionControllerRecovery on ChatSessionController {
  void startFreshConversation() {
    _resetConversationState(
      nextState: _sessionReducer.startFreshThread(
        _sessionState,
        message: 'The next prompt will start a fresh Codex thread.',
      ),
    );
  }

  void clearTranscript() {
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
      _emitSnackBar('That active session is no longer available locally.');
      return;
    }

    final nextRegistry = <String, CodexThreadRegistryEntry>{
      for (final entry in _sessionState.threadRegistry.entries)
        entry.key: entry.value.copyWith(
          isPrimary: entry.key == alternateThreadId,
        ),
    };

    _rememberContinuationThread(alternateThreadId);
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
    await _conversationSelection.selectConversationForResume(
      threadId,
      ephemeralSession: _profile.ephemeralSession,
      activeThreadId: _activeConversationThreadId(),
    );
    await _restoreConversationTranscript(threadId.trim());
  }

  Future<void> activatePersistedConversation() async {
    await _conversationSelection.hydratePersistedSelection();

    final threadId = _resumeConversationThreadId();
    if (threadId == null) {
      return;
    }

    if (_historicalConversationRestoreState == null &&
        _sessionState.rootThreadId == null &&
        _sessionState.transcriptBlocks.isEmpty) {
      await _restoreConversationTranscript(threadId);
    }
    if (_isDisposed || _historicalConversationRestoreState != null) {
      return;
    }

    await prepareSelectedConversationForContinuation();
  }

  Future<void> retryHistoricalConversationRestore() async {
    final threadId = _historicalConversationRestoreState?.threadId.trim();
    if (threadId == null || threadId.isEmpty) {
      return;
    }

    await _restoreConversationTranscript(threadId);
  }

  Future<String?> continueFromUserMessage(String blockId) async {
    final normalizedBlockId = blockId.trim();
    if (normalizedBlockId.isEmpty) {
      return null;
    }
    if (_historicalConversationRestoreState != null) {
      _emitSnackBar('Wait for transcript restore before continuing from here.');
      return null;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitSnackBar('Stop the active turn before continuing from here.');
      return null;
    }

    final targetThreadId = _activeConversationThreadId();
    if (targetThreadId == null) {
      _emitSnackBar('This conversation cannot continue from that prompt yet.');
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
      _emitSnackBar('That prompt is no longer available for continuation.');
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
      rememberContinuationThread: true,
      failureTitle: 'Continue from prompt failed',
      failureMessage:
          'Could not rewind this conversation to the selected prompt.',
    );
    if (nextState == null) {
      return null;
    }

    return targetBlock.text;
  }

  Future<bool> branchSelectedConversation() async {
    if (_historicalConversationRestoreState != null) {
      _emitSnackBar('Wait for transcript restore before branching.');
      return false;
    }
    if (_sessionState.activeTurn != null || _sessionState.isBusy) {
      _emitSnackBar('Stop the active turn before branching this conversation.');
      return false;
    }

    final targetThreadId = _selectedConversationThreadId();
    if (targetThreadId == null) {
      _emitSnackBar('This conversation cannot be branched yet.');
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
      rememberContinuationThread: true,
      failureTitle: 'Branch conversation failed',
      failureMessage: 'Could not branch this conversation from Codex.',
    );
    return nextState != null;
  }

  Future<void> prepareSelectedConversationForContinuation() async {
    if (_historicalConversationRestoreState != null) {
      return;
    }

    final targetThreadId =
        _activeConversationThreadId() ?? _resumeConversationThreadId();
    if (targetThreadId == null) {
      return;
    }

    final trackedThreadId = _normalizedThreadId(appServerClient.threadId);
    if (appServerClient.isConnected && trackedThreadId == targetThreadId) {
      return;
    }

    try {
      await _ensureAppServerThread();
      _clearConversationRecovery();
    } catch (error) {
      final recoveryAssessment = _conversationRecoveryPolicy.assessSendFailure(
        error: error,
        sessionState: _sessionState,
        sessionLabel: _sessionLabel(),
        preferredAlternateThreadId: appServerClient.threadId,
      );
      if (recoveryAssessment.recoveryState != null) {
        _setConversationRecovery(recoveryAssessment.recoveryState!);
      }
    }
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
    _clearConversationRecovery();
    _clearHistoricalConversationRestoreState();
    _clearContinuationThread();
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

  String? _resumeConversationThreadId() {
    return _conversationSelection.resumeThreadId(
      ephemeralSession: _profile.ephemeralSession,
    );
  }

  String? _trackedThreadReuseCandidate() {
    if (_profile.ephemeralSession ||
        _conversationSelection.suppressTrackedThreadReuse ||
        _sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(appServerClient.threadId);
  }

  void _rememberContinuationThread(String? threadId) {
    _conversationSelection.rememberContinuationThread(
      threadId,
      isDisposed: _isDisposed,
      ephemeralSession: _profile.ephemeralSession,
      activeThreadId: _activeConversationThreadId(),
    );
  }

  void _clearContinuationThread() {
    _conversationSelection.clearContinuationThread(
      isDisposed: _isDisposed,
      ephemeralSession: _profile.ephemeralSession,
    );
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}
