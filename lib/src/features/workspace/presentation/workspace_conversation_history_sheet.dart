import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/domain/workspace_conversation_summary.dart';

enum ConnectionWorkspaceConversationHistoryPresentation { mobile, desktop }

class ConnectionWorkspaceConversationHistorySheet extends StatelessWidget {
  const ConnectionWorkspaceConversationHistorySheet({
    super.key,
    required this.title,
    required this.future,
    required this.onResumeConversation,
    this.onOpenConnectionSettings,
    this.presentation =
        ConnectionWorkspaceConversationHistoryPresentation.mobile,
  });

  static const _bodyDescription =
      'Pick a saved conversation to resume in this lane.';

  final String title;
  final Future<List<WorkspaceConversationSummary>> future;
  final ValueChanged<WorkspaceConversationSummary> onResumeConversation;
  final VoidCallback? onOpenConnectionSettings;
  final ConnectionWorkspaceConversationHistoryPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return switch (presentation) {
      ConnectionWorkspaceConversationHistoryPresentation.mobile =>
        ModalSheetScaffold(
          headerPadding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          header: _buildMobileHeader(context),
          bodyIsScrollable: false,
          body: _buildBody(context, cards),
        ),
      ConnectionWorkspaceConversationHistoryPresentation.desktop =>
        _buildDesktopSurface(context, cards),
    };
  }

  String _subtitleFor(WorkspaceConversationSummary conversation) {
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

  Widget _buildMobileHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        const SizedBox(height: 16),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _bodyDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSurface(BuildContext context, TranscriptPalette cards) {
    final palette = context.pocketPalette;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 880,
            maxHeight: MediaQuery.sizeOf(context).height - 48,
          ),
          child: Material(
            key: const ValueKey<String>('desktop_conversation_history_surface'),
            color: palette.sheetBackground,
            elevation: 18,
            shadowColor: palette.shadowColor.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
                  child: _buildDesktopHeader(context, cards),
                ),
                const Divider(height: 1),
                Expanded(child: _buildBody(context, cards)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context, TranscriptPalette cards) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
                _bodyDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Close conversation history',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, color: cards.textMuted),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TranscriptPalette cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FutureBuilder<List<WorkspaceConversationSummary>>(
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
                final error =
                    ConnectionLifecycleErrors.conversationHistoryFailure(
                      snapshot.error!,
                    );
                return _ConversationHistoryMessage(
                  title: error.title,
                  body: error.bodyWithCode,
                  actionLabel: onOpenConnectionSettings == null
                      ? null
                      : 'Open connection settings',
                  onAction: onOpenConnectionSettings,
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
