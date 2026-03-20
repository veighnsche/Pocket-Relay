import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class ConnectionWorkspaceConversationHistorySheet extends StatelessWidget {
  const ConnectionWorkspaceConversationHistorySheet({
    super.key,
    required this.title,
    required this.future,
    required this.onResumeConversation,
  });

  final String title;
  final Future<List<SavedConversationThread>> future;
  final ValueChanged<SavedConversationThread> onResumeConversation;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final cards = ConversationCardPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: cards.neutralBorder),
        boxShadow: [
          BoxShadow(
            color: cards.shadow.withValues(alpha: cards.isDark ? 0.34 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.dragHandle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick a saved conversation to resume in this lane.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close conversation history',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cards.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<SavedConversationThread>>(
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
                            conversation.preview.trim().isEmpty
                                ? conversation.normalizedThreadId
                                : conversation.preview.trim(),
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
        ),
      ),
    );
  }

  String _subtitleFor(SavedConversationThread conversation) {
    final activity = conversation.lastActivityAt?.toLocal();
    final activityLabel = activity == null
        ? 'Unknown activity time'
        : _timestampLabel(activity);
    return '${conversation.messageCount} prompts · $activityLabel\n${conversation.normalizedThreadId}';
  }

  String _timestampLabel(DateTime value) {
    final twoDigitMonth = value.month.toString().padLeft(2, '0');
    final twoDigitDay = value.day.toString().padLeft(2, '0');
    final twoDigitHour = value.hour.toString().padLeft(2, '0');
    final twoDigitMinute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }
}

class _ConversationHistoryMessage extends StatelessWidget {
  const _ConversationHistoryMessage({required this.title, required this.body});

  final String title;
  final String body;

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
          ],
        ),
      ),
    );
  }
}
