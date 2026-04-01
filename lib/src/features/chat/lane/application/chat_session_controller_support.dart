part of 'chat_session_controller.dart';

extension on ChatSessionController {
  TranscriptSessionPendingRequest? _findPendingApprovalRequest(
    String requestId,
  ) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingApprovalRequests[requestId];
    }

    return _sessionState.pendingApprovalRequests[requestId];
  }

  TranscriptSessionPendingUserInputRequest? _findPendingUserInputRequest(
    String requestId,
  ) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingUserInputRequests[requestId];
    }

    return _sessionState.pendingUserInputRequests[requestId];
  }

  TranscriptTimelineState? _ownerTimelineForRequest(String requestId) {
    final ownerThreadId = _sessionState.requestOwnerById[requestId];
    if (ownerThreadId != null && ownerThreadId.isNotEmpty) {
      final ownerTimeline = _sessionState.timelineForThread(ownerThreadId);
      if (ownerTimeline != null) {
        return ownerTimeline;
      }
    }

    for (final timeline in _sessionState.timelinesByThreadId.values) {
      if (timeline.pendingApprovalRequests.containsKey(requestId) ||
          timeline.pendingUserInputRequests.containsKey(requestId)) {
        return timeline;
      }
    }

    return null;
  }

  bool _shouldHydrateThreadMetadata(
    String threadId,
    TranscriptRuntimeThreadStartedEvent event,
  ) {
    if (threadId.isEmpty ||
        event.rawMethod == 'thread/read(response)' ||
        _threadMetadataHydrationAttempts.contains(threadId)) {
      return false;
    }

    final existingEntry = _sessionState.threadRegistry[threadId];
    return !_hasThreadDisplayMetadataValues(
      threadName: existingEntry?.threadName ?? event.threadName,
      agentNickname: existingEntry?.agentNickname ?? event.agentNickname,
      agentRole: existingEntry?.agentRole ?? event.agentRole,
    );
  }

  bool _hasThreadMetadata(AgentAdapterThreadSummary thread) {
    return _hasThreadMetadataValues(
      threadName: thread.name,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
      sourceKind: thread.sourceKind,
    );
  }

  bool _hasThreadMetadataValues({
    String? threadName,
    String? agentNickname,
    String? agentRole,
    String? sourceKind,
  }) {
    return _hasNonEmptyValue(threadName) ||
        _hasNonEmptyValue(agentNickname) ||
        _hasNonEmptyValue(agentRole) ||
        _hasNonEmptyValue(sourceKind);
  }

  bool _hasThreadDisplayMetadataValues({
    String? threadName,
    String? agentNickname,
    String? agentRole,
  }) {
    return _hasNonEmptyValue(threadName) ||
        _hasNonEmptyValue(agentNickname) ||
        _hasNonEmptyValue(agentRole);
  }

  bool _hasNonEmptyValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  bool _isSshBootstrapFailureRuntimeEvent(TranscriptRuntimeEvent event) {
    return switch (event) {
      TranscriptRuntimeSshConnectFailedEvent() ||
      TranscriptRuntimeUnpinnedHostKeyEvent() ||
      TranscriptRuntimeSshHostKeyMismatchEvent() ||
      TranscriptRuntimeSshAuthenticationFailedEvent() => true,
      _ => false,
    };
  }

  bool _hasVisibleConversationState([TranscriptSessionState? state]) {
    final effectiveState = state ?? _sessionState;
    return effectiveState.activeTurn != null ||
        effectiveState.pendingApprovalRequests.isNotEmpty ||
        effectiveState.pendingUserInputRequests.isNotEmpty ||
        effectiveState.transcriptBlocks.isNotEmpty;
  }

  void _startBufferingRuntimeEvents() {
    _bufferedRuntimeEvents.clear();
    _isBufferingRuntimeEvents = true;
  }

  List<TranscriptRuntimeEvent> _stopBufferingRuntimeEvents() {
    _isBufferingRuntimeEvents = false;
    final bufferedEvents = List<TranscriptRuntimeEvent>.from(
      _bufferedRuntimeEvents,
    );
    _bufferedRuntimeEvents.clear();
    return bufferedEvents;
  }

  void _emitSnackBar(String message) {
    if (_isDisposed || _snackBarMessagesController.isClosed) {
      return;
    }
    _snackBarMessagesController.add(message);
  }

  void _emitUserFacingError(PocketUserFacingError error) {
    _emitSnackBar(error.inlineMessage);
  }

  void _emitDiagnosticWarning(
    PocketUserFacingError warning, {
    required String rawMethod,
  }) {
    _applyChatSessionRuntimeEvent(
      this,
      TranscriptRuntimeWarningEvent(
        createdAt: DateTime.now(),
        rawMethod: rawMethod,
        summary: warning.bodyWithCode,
      ),
    );
  }

  String _sessionLabel() {
    final adapterLabel = agentAdapterLabel(_profile.agentAdapter);
    return switch (_profile.connectionMode) {
      ConnectionMode.remote => 'remote $adapterLabel',
      ConnectionMode.local => localConnectionLabelForAgentAdapter(
        _profile.agentAdapter,
      ),
    };
  }
}

Map<String, dynamic>? _chatSessionControllerAsObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _chatSessionControllerAsString(Object? value) {
  return value is String ? value : null;
}
