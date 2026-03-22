part of 'flutter_chat_screen_renderer.dart';

class FlutterChatComposerRegion extends StatelessWidget {
  const FlutterChatComposerRegion({
    super.key,
    required this.platformBehavior,
    required this.conversationRecoveryNotice,
    required this.historicalConversationRestoreNotice,
    required this.composer,
    required this.onComposerDraftChanged,
    required this.onSendPrompt,
    required this.onConversationRecoveryAction,
    required this.onHistoricalConversationRestoreAction,
  });

  final PocketPlatformBehavior platformBehavior;
  final ChatConversationRecoveryNoticeContract? conversationRecoveryNotice;
  final ChatHistoricalConversationRestoreNoticeContract?
  historicalConversationRestoreNotice;
  final ChatComposerContract composer;
  final ValueChanged<ChatComposerDraft> onComposerDraftChanged;
  final Future<void> Function() onSendPrompt;
  final ValueChanged<ChatConversationRecoveryActionId>
  onConversationRecoveryAction;
  final ValueChanged<ChatHistoricalConversationRestoreActionId>
  onHistoricalConversationRestoreAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (historicalConversationRestoreNotice case final notice?) ...[
              _HistoricalConversationRestoreNotice(
                notice: notice,
                onAction: onHistoricalConversationRestoreAction,
              ),
              const SizedBox(height: 10),
            ] else if (conversationRecoveryNotice case final notice?) ...[
              _ConversationRecoveryNotice(
                notice: notice,
                onAction: onConversationRecoveryAction,
              ),
              const SizedBox(height: 10),
            ],
            ChatComposer(
              platformBehavior: platformBehavior,
              contract: composer,
              onChanged: onComposerDraftChanged,
              onSend: onSendPrompt,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoricalConversationRestoreNotice extends StatelessWidget {
  const _HistoricalConversationRestoreNotice({
    required this.notice,
    required this.onAction,
  });

  final ChatHistoricalConversationRestoreNoticeContract notice;
  final ValueChanged<ChatHistoricalConversationRestoreActionId> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = theme.colorScheme.onSecondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notice.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: foregroundColor,
                    ),
                  )
                else
                  Icon(
                    Icons.history_toggle_off_rounded,
                    color: foregroundColor,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (notice.actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: notice.actions
                    .map(
                      (action) => action.isPrimary
                          ? FilledButton(
                              onPressed: () => onAction(action.id),
                              child: Text(action.label),
                            )
                          : OutlinedButton(
                              onPressed: () => onAction(action.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: foregroundColor,
                                side: BorderSide(
                                  color: foregroundColor.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: Text(action.label),
                            ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationRecoveryNotice extends StatelessWidget {
  const _ConversationRecoveryNotice({
    required this.notice,
    required this.onAction,
  });

  final ChatConversationRecoveryNoticeContract notice;
  final ValueChanged<ChatConversationRecoveryActionId> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sync_problem_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: notice.actions
                  .map(
                    (action) => action.isPrimary
                        ? FilledButton(
                            key: ValueKey<String>(
                              'conversation_recovery_${action.id.name}',
                            ),
                            onPressed: () => onAction(action.id),
                            child: Text(action.label),
                          )
                        : OutlinedButton(
                            key: ValueKey<String>(
                              'conversation_recovery_${action.id.name}',
                            ),
                            onPressed: () => onAction(action.id),
                            child: Text(action.label),
                          ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
