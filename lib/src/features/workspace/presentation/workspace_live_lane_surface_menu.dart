part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  List<ChatChromeMenuAction> _supplementalMenuActionsFor({
    required ConnectionProfile profile,
    required bool isLaneBusy,
  }) {
    final hasWorkspaceHistoryScope = profile.workspaceDir.trim().isNotEmpty;
    return <ChatChromeMenuAction>[
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
        onSelected: widget.workspaceController.showSavedConnections,
      ),
      if (hasWorkspaceHistoryScope)
        ChatChromeMenuAction(
          label: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
          onSelected: () {
            unawaited(_showConversationHistory());
          },
          isEnabled: !isLaneBusy,
        ),
    ];
  }

  Future<void> _showConversationHistory() {
    final repository =
        widget.conversationHistoryRepository ??
        const CodexAppServerConversationHistoryRepository();
    if (widget.platformPolicy.behavior.isDesktopExperience) {
      return showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _ConversationHistorySheetHost(
            title: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
            presentation:
                ConnectionWorkspaceConversationHistoryPresentation.desktop,
            loadConversationHistory: () => _loadConversationHistory(repository),
            onOpenConnectionSettings: () {
              unawaited(
                _openConversationHistoryConnectionSettings(
                  Navigator.of(dialogContext),
                ),
              );
            },
            onResumeConversation: (conversation) {
              unawaited(_resumeConversation(conversation));
            },
          );
        },
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: _ConversationHistorySheetHost(
            title: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
            loadConversationHistory: () => _loadConversationHistory(repository),
            onOpenConnectionSettings: () {
              unawaited(
                _openConversationHistoryConnectionSettings(
                  Navigator.of(sheetContext),
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

class _ConversationHistorySheetHost extends StatefulWidget {
  const _ConversationHistorySheetHost({
    required this.title,
    required this.loadConversationHistory,
    required this.onResumeConversation,
    required this.onOpenConnectionSettings,
    this.presentation =
        ConnectionWorkspaceConversationHistoryPresentation.mobile,
  });

  final String title;
  final ConnectionWorkspaceConversationHistoryPresentation presentation;
  final Future<List<CodexWorkspaceConversationSummary>> Function()
  loadConversationHistory;
  final ValueChanged<CodexWorkspaceConversationSummary> onResumeConversation;
  final VoidCallback? onOpenConnectionSettings;

  @override
  State<_ConversationHistorySheetHost> createState() =>
      _ConversationHistorySheetHostState();
}

class _ConversationHistorySheetHostState
    extends State<_ConversationHistorySheetHost> {
  late final Future<List<CodexWorkspaceConversationSummary>>
  _conversationHistoryFuture;

  @override
  void initState() {
    super.initState();
    _conversationHistoryFuture = widget.loadConversationHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionWorkspaceConversationHistorySheet(
      title: widget.title,
      presentation: widget.presentation,
      future: _conversationHistoryFuture,
      onOpenConnectionSettings: widget.onOpenConnectionSettings,
      onResumeConversation: widget.onResumeConversation,
    );
  }
}
