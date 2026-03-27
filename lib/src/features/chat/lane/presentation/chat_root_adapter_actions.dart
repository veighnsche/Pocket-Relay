part of 'chat_root_adapter.dart';

Future<void> _requestChatConnectionSettings(
  _ChatRootAdapterState state,
  ChatConnectionSettingsLaunchContract connectionSettings,
) async {
  await state.widget.onConnectionSettingsRequested(connectionSettings);
}

Future<void> _openChatChangedFileDiff(
  _ChatRootAdapterState state,
  ChatChangedFileDiffContract diff,
) async {
  if (!state.mounted) {
    return;
  }

  await state.widget.overlayDelegate.openChangedFileDiff(
    context: state.context,
    diff: diff,
  );
}

Future<void> _openChatWorkLogTerminal(
  _ChatRootAdapterState state,
  ChatWorkLogTerminalContract terminal,
) async {
  if (!state.mounted) {
    return;
  }

  await state.widget.overlayDelegate.openWorkLogTerminal(
    context: state.context,
    terminal: terminal,
  );
}

void _requestChatChangedFileDiff(
  _ChatRootAdapterState state,
  ChatChangedFileDiffContract diff,
) {
  state._handleScreenEffect(ChatOpenChangedFileDiffEffect(payload: diff));
}

void _requestChatWorkLogTerminal(
  _ChatRootAdapterState state,
  ChatWorkLogTerminalContract terminal,
) {
  state._handleScreenEffect(ChatOpenWorkLogTerminalEffect(payload: terminal));
}

void _handleChatScreenAction(
  _ChatRootAdapterState state,
  ChatScreenActionId action,
  ChatScreenContract screen,
) {
  final effect = state._effectMapper.mapAction(action: action, screen: screen);
  if (effect != null) {
    state._handleScreenEffect(effect);
    return;
  }

  switch (action) {
    case ChatScreenActionId.newThread:
      state._startFreshConversation();
    case ChatScreenActionId.branchConversation:
      unawaited(state._branchConversation());
    case ChatScreenActionId.clearTranscript:
      state._clearTranscript();
    case ChatScreenActionId.openSettings:
      return;
  }
}

Future<void> _sendChatPrompt(_ChatRootAdapterState state) async {
  final laneBinding = state.widget.laneBinding;
  final controller = laneBinding.sessionController;
  final draft = laneBinding.composerDraftHost.draft.normalized();
  final sent = draft.hasStructuredDraft
      ? await controller.sendDraft(draft)
      : await controller.sendPrompt(draft.text);
  if (!state.mounted || laneBinding != state.widget.laneBinding || !sent) {
    return;
  }

  laneBinding.transcriptFollowHost.requestFollow(
    source: ChatTranscriptFollowRequestSource.sendPrompt,
  );
  laneBinding.composerDraftHost.clear();
}

Future<void> _continueChatFromUserMessage(
  _ChatRootAdapterState state,
  String blockId,
) async {
  if (!state.mounted) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Continue From Here'),
        content: const Text(
          'This will discard newer conversation turns in this thread, '
          'reload the selected prompt into the composer, and keep any local '
          'file changes exactly as they are. Local file changes are not '
          'reverted automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !state.mounted) {
    return;
  }

  final laneBinding = state.widget.laneBinding;
  final draft = await laneBinding.sessionController.continueFromUserMessage(
    blockId,
  );
  if (!state.mounted ||
      laneBinding != state.widget.laneBinding ||
      draft == null) {
    return;
  }

  laneBinding.composerDraftHost.updateDraft(draft);
  laneBinding.transcriptFollowHost.requestFollow(
    source: ChatTranscriptFollowRequestSource.clearTranscript,
  );
}

void _startFreshChatConversation(_ChatRootAdapterState state) {
  state.widget.laneBinding.transcriptFollowHost.requestFollow(
    source: ChatTranscriptFollowRequestSource.newThread,
  );
  state.widget.laneBinding.sessionController.startFreshConversation();
}

Future<void> _branchChatConversation(_ChatRootAdapterState state) async {
  final branched = await state.widget.laneBinding.sessionController
      .branchSelectedConversation();
  if (!branched) {
    return;
  }
  state.widget.laneBinding.transcriptFollowHost.reset();
}

void _clearChatTranscript(_ChatRootAdapterState state) {
  state.widget.laneBinding.transcriptFollowHost.requestFollow(
    source: ChatTranscriptFollowRequestSource.clearTranscript,
  );
  state.widget.laneBinding.sessionController.clearTranscript();
}

void _handleChatConversationRecoveryAction(
  _ChatRootAdapterState state,
  ChatConversationRecoveryActionId action,
) {
  switch (action) {
    case ChatConversationRecoveryActionId.startFreshConversation:
      state._startFreshConversation();
    case ChatConversationRecoveryActionId.openAlternateSession:
      state.widget.laneBinding.sessionController
          .openConversationRecoveryAlternateSession();
  }
}

void _handleChatHistoricalConversationRestoreAction(
  _ChatRootAdapterState state,
  ChatHistoricalConversationRestoreActionId action,
) {
  switch (action) {
    case ChatHistoricalConversationRestoreActionId.retryRestore:
      unawaited(
        state.widget.laneBinding.sessionController
            .retryHistoricalConversationRestore(),
      );
    case ChatHistoricalConversationRestoreActionId.startFreshConversation:
      state._startFreshConversation();
  }
}
