import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

class ConnectionWorkspaceConversationHistorySheet extends StatelessWidget {
  const ConnectionWorkspaceConversationHistorySheet({
    super.key,
    required this.title,
    required this.future,
    required this.onResumeConversation,
    this.onOpenConnectionSettings,
  });

  final String title;
  final Future<List<CodexWorkspaceConversationSummary>> future;
  final ValueChanged<CodexWorkspaceConversationSummary> onResumeConversation;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return ModalSheetScaffold(
      header: _buildStickyHeader(context, cards),
      bodyIsScrollable: false,
      body: _buildBody(context, cards),
    );
  }

  String _subtitleFor(CodexWorkspaceConversationSummary conversation) {
    final activity = conversation.lastActivityAt?.toLocal();
    final activityLabel = activity == null
        ? 'Unknown activity time'
        : _timestampLabel(activity);
    return '${conversation.promptCount} prompts · $activityLabel\n${conversation.normalizedThreadId}';
  }

  String _timestampLabel(DateTime value) {
    final twoDigitMonth = value.month.toString().padLeft(2, '0');
    final twoDigitDay = value.day.toString().padLeft(2, '0');
    final twoDigitHour = value.hour.toString().padLeft(2, '0');
    final twoDigitMinute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }

  Widget _buildStickyHeader(BuildContext context, TranscriptPalette cards) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(child: SizedBox()),
        const ModalSheetDragHandle(),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close conversation history',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: cards.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TranscriptPalette cards) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pick a saved conversation to resume in this lane.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CodexWorkspaceConversationSummary>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                );
              }

              if (snapshot.hasError) {
                if (snapshot.error
                    is CodexWorkspaceConversationHistoryUnpinnedHostKeyException) {
                  final error =
                      snapshot.error
                          as CodexWorkspaceConversationHistoryUnpinnedHostKeyException;
                  return _ConversationHistoryMessage(
                    title: 'Host key not pinned',
                    body:
                        'Conversation history cannot connect until this host '
                        'fingerprint is saved to the connection profile.\n'
                        'Observed fingerprint: ${error.fingerprint}',
                    actionLabel: onOpenConnectionSettings == null
                        ? null
                        : 'Open connection settings',
                    onAction: onOpenConnectionSettings,
                  );
                }
                if (snapshot.error is CodexRemoteAppServerAttachException) {
                  final error =
                      snapshot.error as CodexRemoteAppServerAttachException;
                  final (title, body) = switch (error.snapshot.status) {
                    CodexRemoteAppServerOwnerStatus.missing ||
                    CodexRemoteAppServerOwnerStatus.stopped => (
                      'Remote server stopped',
                      error.message,
                    ),
                    CodexRemoteAppServerOwnerStatus.unhealthy => (
                      'Remote server unhealthy',
                      error.message,
                    ),
                    CodexRemoteAppServerOwnerStatus.running => (
                      'Remote session unavailable',
                      error.message,
                    ),
                  };
                  return _ConversationHistoryMessage(
                    title: title,
                    body: body,
                    actionLabel: onOpenConnectionSettings == null
                        ? null
                        : 'Open connection settings',
                    onAction: onOpenConnectionSettings,
                  );
                }
                return _ConversationHistoryMessage(
                  title: 'Could not load conversations',
                  body: '${snapshot.error}',
                );
              }

              final conversations = snapshot.data ?? const [];
              if (conversations.isEmpty) {
                return const _ConversationHistoryMessage(
                  title: 'No matching conversations',
                  body: 'No workspace conversations are available yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: cards.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cards.neutralBorder),
                    ),
                    child: ListTile(
                      key: ValueKey<String>(
                        'workspace_conversation_${conversation.normalizedThreadId}',
                      ),
                      onTap: () => onResumeConversation(conversation),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      title: Text(
                        conversation.trimmedPreview.isEmpty
                            ? conversation.normalizedThreadId
                            : conversation.trimmedPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cards.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _subtitleFor(conversation),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cards.textMuted),
                        ),
                      ),
                      trailing: Icon(
                        Icons.play_arrow_rounded,
                        color: cards.textMuted,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationHistoryMessage extends StatelessWidget {
  const _ConversationHistoryMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(
                key: const ValueKey(
                  'conversation_history_open_connection_settings',
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
