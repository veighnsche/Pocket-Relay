part of 'chat_session_controller.dart';

extension _ChatSessionControllerPromptFlow on ChatSessionController {
  Future<void> saveObservedHostFingerprint(String blockId) async {
    final block = _findUnpinnedHostKeyBlock(blockId);
    if (block == null) {
      _emitSnackBar('This host fingerprint prompt is no longer available.');
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

      _emitSnackBar(
        'This profile already has a different pinned host fingerprint. Review the connection settings before replacing it.',
      );
      return;
    }

    final nextProfile = _profile.copyWith(hostFingerprint: block.fingerprint);

    try {
      await profileStore.save(nextProfile, _secrets);
    } catch (_) {
      _emitSnackBar('Could not save the host fingerprint to this profile.');
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

    final validationMessage = _validateProfileForSend();
    if (validationMessage != null) {
      _emitSnackBar(validationMessage);
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

  Future<void> stopActiveTurn() async {
    await _stopAppServerTurn();
  }

  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final pendingRequest = _findPendingUserInputRequest(requestId);
    if (pendingRequest == null) {
      _emitSnackBar('This input request is no longer pending.');
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
      _reportAppServerFailure(
        title: 'Input failed',
        message: 'Could not submit the requested user input.',
        error: error,
      );
    }
  }

  String? _validateProfileForSend() {
    if (!_profile.isReady) {
      return switch (_profile.connectionMode) {
        ConnectionMode.remote => 'Fill in the remote connection details first.',
        ConnectionMode.local => 'Fill in the local Codex settings first.',
      };
    }
    if (_profile.connectionMode == ConnectionMode.local) {
      if (!_supportsLocalConnectionMode) {
        return 'Local Codex is only available on desktop.';
      }
      return null;
    }
    if (_profile.authMode == AuthMode.password && !_secrets.hasPassword) {
      return 'This profile needs an SSH password.';
    }
    if (_profile.authMode == AuthMode.privateKey && !_secrets.hasPrivateKey) {
      return 'This profile needs a private key.';
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
    required String title,
    required String message,
    required Object error,
    String? runtimeErrorMessage,
    bool suppressRuntimeError = false,
    bool suppressSnackBar = false,
  }) {
    _reportChatSessionAppServerFailure(
      this,
      title: title,
      message: message,
      error: error,
      runtimeErrorMessage: runtimeErrorMessage,
      suppressRuntimeError: suppressRuntimeError,
      suppressSnackBar: suppressSnackBar,
    );
  }
}
