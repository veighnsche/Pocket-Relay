part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  List<ChatChromeMenuAction> _supplementalMenuActionsFor({
    required bool requiresReconnect,
    required bool isLaneBusy,
  }) {
    final hasWorkspaceHistoryScope = widget
        .laneBinding
        .sessionController
        .profile
        .workspaceDir
        .trim()
        .isNotEmpty;
    return buildWorkspaceLiveLaneMenuActions(
      hasWorkspaceHistoryScope: hasWorkspaceHistoryScope,
      requiresReconnect: requiresReconnect,
      isLaneBusy: isLaneBusy,
      isApplyingSavedSettings: _isApplyingSavedSettings,
      onShowConversationHistory: () {
        unawaited(_showConversationHistory());
      },
      onShowDormantRoster: widget.workspaceController.showDormantRoster,
      onReconnect: () {
        unawaited(_applySavedSettings());
      },
      onCloseLane: () => widget.workspaceController.terminateConnection(
        widget.laneBinding.connectionId,
      ),
    );
  }

  Future<void> _showConversationHistory() {
    final repository =
        widget.conversationHistoryRepository ??
        const CodexAppServerConversationHistoryRepository();
    final sessionController = widget.laneBinding.sessionController;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: ConnectionWorkspaceConversationHistorySheet(
            title: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
            future: repository.loadWorkspaceConversations(
              profile: sessionController.profile,
              secrets: sessionController.secrets,
            ),
            onResumeConversation: (conversation) {
              unawaited(_resumeConversation(conversation));
            },
          ),
        );
      },
    );
  }

  Future<void> _resumeConversation(
    CodexWorkspaceConversationSummary conversation,
  ) async {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
    await widget.workspaceController.resumeConversation(
      connectionId: widget.laneBinding.connectionId,
      threadId: conversation.normalizedThreadId,
    );
  }
}
