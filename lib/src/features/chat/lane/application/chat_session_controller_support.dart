part of 'chat_session_controller.dart';

extension on ChatSessionController {
  CodexSessionPendingRequest? _findPendingApprovalRequest(String requestId) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingApprovalRequests[requestId];
    }

    return _sessionState.pendingApprovalRequests[requestId];
  }

  CodexSessionPendingUserInputRequest? _findPendingUserInputRequest(
    String requestId,
  ) {
    final ownerTimeline = _ownerTimelineForRequest(requestId);
    if (ownerTimeline != null) {
      return ownerTimeline.pendingUserInputRequests[requestId];
    }

    return _sessionState.pendingUserInputRequests[requestId];
  }

  CodexTimelineState? _ownerTimelineForRequest(String requestId) {
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
    CodexRuntimeThreadStartedEvent event,
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

  bool _hasThreadMetadata(CodexAppServerThreadSummary thread) {
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

  bool _isSshBootstrapFailureRuntimeEvent(CodexRuntimeEvent event) {
    return switch (event) {
      CodexRuntimeSshConnectFailedEvent() ||
      CodexRuntimeUnpinnedHostKeyEvent() ||
      CodexRuntimeSshHostKeyMismatchEvent() ||
      CodexRuntimeSshAuthenticationFailedEvent() => true,
      _ => false,
    };
  }

  bool _hasVisibleConversationState([CodexSessionState? state]) {
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

  List<CodexRuntimeEvent> _stopBufferingRuntimeEvents() {
    _isBufferingRuntimeEvents = false;
    final bufferedEvents = List<CodexRuntimeEvent>.from(_bufferedRuntimeEvents);
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

  String _sessionLabel() {
    return switch (_profile.connectionMode) {
      ConnectionMode.remote => 'remote Codex',
      ConnectionMode.local => 'local Codex',
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
