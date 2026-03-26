part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  List<ChatChromeMenuAction> _supplementalMenuActionsFor({
    required bool isLaneBusy,
  }) {
    final hasWorkspaceHistoryScope = widget
        .laneBinding
        .sessionController
        .profile
        .workspaceDir
        .trim()
        .isNotEmpty;
    return <ChatChromeMenuAction>[
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
        onSelected: () {
          unawaited(_showConversationHistory());
        },
        isEnabled: hasWorkspaceHistoryScope && !isLaneBusy,
      ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
        onSelected: widget.workspaceController.showSavedConnections,
      ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.closeLaneAction,
        onSelected: () => widget.workspaceController.terminateConnection(
          widget.laneBinding.connectionId,
        ),
        isDestructive: true,
        isEnabled: !isLaneBusy,
      ),
    ];
  }

  Future<void> _showConversationHistory() {
    final repository =
        widget.conversationHistoryRepository ??
        const CodexAppServerConversationHistoryRepository();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: ConnectionWorkspaceConversationHistorySheet(
            title: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
            future: _loadConversationHistory(repository),
            onOpenConnectionSettings: () {
              unawaited(
                _openConversationHistoryConnectionSettings(
                  Navigator.of(context),
                ),
              );
            },
            onResumeConversation: (conversation) {
              unawaited(_resumeConversation(conversation));
            },
          ),
        );
      },
    );
  }

  Future<List<CodexWorkspaceConversationSummary>> _loadConversationHistory(
    CodexWorkspaceConversationHistoryRepository repository,
  ) async {
    final connection = await _resolveConversationHistoryConnection();
    return repository.loadWorkspaceConversations(
      profile: connection.profile,
      secrets: connection.secrets,
      ownerId: widget.laneBinding.connectionId,
    );
  }

  Future<void> _openConversationHistoryConnectionSettings(
    NavigatorState navigator,
  ) async {
    navigator.pop();
    final connection = await _resolveConversationHistoryConnection();
    if (!mounted) {
      return;
    }

    await _handleConnectionSettingsRequested(
      ChatConnectionSettingsLaunchContract(
        initialProfile: connection.profile,
        initialSecrets: connection.secrets,
      ),
    );
  }

  Future<SavedConnection> _resolveConversationHistoryConnection() async {
    final connectionId = widget.laneBinding.connectionId;
    final sessionController = widget.laneBinding.sessionController;
    if (!widget.workspaceController.state.requiresReconnect(connectionId)) {
      return SavedConnection(
        id: connectionId,
        profile: sessionController.profile,
        secrets: sessionController.secrets,
      );
    }

    return widget.workspaceController.loadSavedConnection(connectionId);
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
