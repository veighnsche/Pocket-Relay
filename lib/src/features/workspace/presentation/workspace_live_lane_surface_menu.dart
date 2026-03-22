part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  List<ChatChromeMenuAction> _supplementalMenuActionsFor({
    required bool requiresReconnect,
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
        isEnabled: hasWorkspaceHistoryScope,
      ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
        onSelected: widget.workspaceController.showDormantRoster,
      ),
      if (requiresReconnect)
        ChatChromeMenuAction(
          label: _isApplyingSavedSettings
              ? ConnectionWorkspaceCopy.reconnectMenuProgress
              : ConnectionWorkspaceCopy.reconnectMenuAction,
          onSelected: () {
            unawaited(_applySavedSettings());
          },
          isEnabled: hasWorkspaceHistoryScope,
        ),
      ChatChromeMenuAction(
        label: ConnectionWorkspaceCopy.closeLaneAction,
        onSelected: () => widget.workspaceController.terminateConnection(
          widget.laneBinding.connectionId,
        ),
        isDestructive: true,
        isEnabled: hasWorkspaceHistoryScope,
      ),
    ];
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

class _SavedSettingsNotice extends StatelessWidget {
  const _SavedSettingsNotice({required this.isApplying, required this.onApply});

  final bool isApplying;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.sync, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ConnectionWorkspaceCopy.reconnectNoticeTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ConnectionWorkspaceCopy.reconnectNoticeBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const ValueKey('apply_saved_settings'),
              onPressed: isApplying
                  ? null
                  : () {
                      unawaited(onApply());
                    },
              child: Text(
                isApplying
                    ? ConnectionWorkspaceCopy.reconnectProgress
                    : ConnectionWorkspaceCopy.reconnectAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
