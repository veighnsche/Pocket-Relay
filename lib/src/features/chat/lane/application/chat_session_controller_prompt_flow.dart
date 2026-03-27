part of 'chat_session_controller.dart';

extension _ChatSessionControllerPromptFlow on ChatSessionController {
  Future<void> saveObservedHostFingerprint(String blockId) async {
    final block = _findUnpinnedHostKeyBlock(blockId);
    if (block == null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintPromptUnavailable(),
      );
      return;
    }
    if (block.isSaved) {
      return;
    }

    final currentFingerprint = _profile.hostFingerprint.trim();
    if (currentFingerprint.isNotEmpty) {
      if (normalizeFingerprint(currentFingerprint) ==
          normalizeFingerprint(block.fingerprint)) {
        _applySessionState(
          _sessionReducer.markUnpinnedHostKeySaved(
            _sessionState,
            blockId: blockId,
          ),
        );
        return;
      }

      _emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintConflict(),
      );
      return;
    }

    final nextProfile = _profile.copyWith(hostFingerprint: block.fingerprint);

    try {
      await profileStore.save(nextProfile, _secrets);
    } catch (_) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintSaveFailed(),
      );
      return;
    }
    if (_isDisposed) {
      return;
    }

    _profile = nextProfile;
    _applySessionState(
      _sessionReducer.markUnpinnedHostKeySaved(_sessionState, blockId: blockId),
    );
  }

  Future<bool> sendPrompt(String prompt) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty ||
        _conversationRecoveryState != null ||
        _historicalConversationRestoreState != null) {
      return false;
    }

    final validationError = _validateProfileForSend();
    if (validationError != null) {
      _emitUserFacingError(validationError);
      return false;
    }

    final rootThreadId = _sessionState.rootThreadId;
    if (rootThreadId != null && _sessionState.currentThreadId != rootThreadId) {
      selectTimeline(rootThreadId);
    }

    final recoveryState = _conversationRecoveryPolicy.preflightRecoveryState(
      sessionState: _sessionState,
      activeThreadId: _activeConversationThreadId(),
      trackedThreadId: _trackedThreadReuseCandidate(),
    );
    if (recoveryState != null) {
      _setConversationRecovery(recoveryState);
      return false;
    }

    _applySessionState(
      _sessionReducer.addUserMessage(_sessionState, text: normalizedPrompt),
    );
    return _sendPromptWithAppServer(normalizedPrompt);
  }

  Future<bool> sendDraft(ChatComposerDraft draft) async {
    final normalizedDraft = draft.normalized();
    if (normalizedDraft.isEmpty ||
        _conversationRecoveryState != null ||
        _historicalConversationRestoreState != null) {
      return false;
    }

    final validationError = _validateProfileForSend();
    if (validationError != null) {
      _emitUserFacingError(validationError);
      return false;
    }
    if (!await _ensureImageInputsSupportedForDraft(normalizedDraft)) {
      return false;
    }

    final rootThreadId = _sessionState.rootThreadId;
    if (rootThreadId != null && _sessionState.currentThreadId != rootThreadId) {
      selectTimeline(rootThreadId);
    }

    final recoveryState = _conversationRecoveryPolicy.preflightRecoveryState(
      sessionState: _sessionState,
      activeThreadId: _activeConversationThreadId(),
      trackedThreadId: _trackedThreadReuseCandidate(),
    );
    if (recoveryState != null) {
      _setConversationRecovery(recoveryState);
      return false;
    }

    _applySessionState(
      _sessionReducer.addUserMessage(
        _sessionState,
        text: normalizedDraft.text,
        draft: normalizedDraft,
      ),
    );
    return _sendDraftWithAppServer(normalizedDraft);
  }

  Future<void> stopActiveTurn() async {
    await _stopAppServerTurn();
  }

  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final pendingRequest = _findPendingUserInputRequest(requestId);
    if (pendingRequest == null) {
      _emitUserFacingError(
        ChatSessionGuardrailErrors.userInputRequestUnavailable(),
      );
      return;
    }

    try {
      if (pendingRequest.requestType ==
          CodexCanonicalRequestType.mcpServerElicitation) {
        await appServerClient.respondToElicitation(
          requestId: requestId,
          action: CodexAppServerElicitationAction.accept,
          content: _elicitationContentFromAnswers(answers),
        );
      } else {
        await appServerClient.answerUserInput(
          requestId: requestId,
          answers: answers,
        );
      }
    } catch (error) {
      final userFacingError = ChatSessionErrors.submitUserInputFailed();
      _reportAppServerFailure(
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
      );
    }
  }

  PocketUserFacingError? _validateProfileForSend() {
    if (!_profile.isReady) {
      return switch (_profile.connectionMode) {
        ConnectionMode.remote =>
          ChatSessionGuardrailErrors.remoteConnectionDetailsRequired(),
        ConnectionMode.local =>
          ChatSessionGuardrailErrors.localConfigurationRequired(),
      };
    }
    if (_profile.connectionMode == ConnectionMode.local) {
      if (!_supportsLocalConnectionMode) {
        return ChatSessionGuardrailErrors.localModeUnsupported();
      }
      return null;
    }
    if (_profile.authMode == AuthMode.password && !_secrets.hasPassword) {
      return ChatSessionGuardrailErrors.sshPasswordRequired();
    }
    if (_profile.authMode == AuthMode.privateKey && !_secrets.hasPrivateKey) {
      return ChatSessionGuardrailErrors.privateKeyRequired();
    }
    return null;
  }

  Object? _elicitationContentFromAnswers(Map<String, List<String>> answers) {
    if (answers.length == 1) {
      final entry = answers.entries.single;
      final values = entry.value;
      if (entry.key == 'response' && values.length == 1) {
        return values.single;
      }
      if (values.length == 1) {
        return <String, Object?>{entry.key: values.single};
      }
    }

    return answers.map<String, Object?>((key, values) {
      if (values.isEmpty) {
        return MapEntry<String, Object?>(key, null);
      }
      if (values.length == 1) {
        return MapEntry<String, Object?>(key, values.single);
      }
      return MapEntry<String, Object?>(key, values);
    });
  }

  void _reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    _reportChatSessionAppServerFailure(
      this,
      userFacingError: userFacingError,
      runtimeErrorMessage: runtimeErrorMessage,
      suppressRuntimeError: suppressRuntimeError,
      suppressSnackBar: suppressSnackBar,
    );
  }
}
