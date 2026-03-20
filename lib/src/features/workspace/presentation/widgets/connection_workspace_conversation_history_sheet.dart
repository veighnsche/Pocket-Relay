import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_detail.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';

class ConnectionWorkspaceConversationHistorySheet extends StatefulWidget {
  const ConnectionWorkspaceConversationHistorySheet({
    super.key,
    required this.title,
    required this.future,
    required this.onLoadConversationDetail,
  });

  final String title;
  final Future<List<CodexWorkspaceConversationSummary>> future;
  final Future<CodexWorkspaceConversationDetail?> Function(String sessionId)
  onLoadConversationDetail;

  @override
  State<ConnectionWorkspaceConversationHistorySheet> createState() =>
      _ConnectionWorkspaceConversationHistorySheetState();
}

class _ConnectionWorkspaceConversationHistorySheetState
    extends State<ConnectionWorkspaceConversationHistorySheet> {
  CodexWorkspaceConversationSummary? _selectedConversation;
  Future<CodexWorkspaceConversationDetail?>? _detailFuture;

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
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _selectedConversation == null
                    ? _ConversationHistoryListView(
                        key: const ValueKey<String>(
                          'conversation_history_list',
                        ),
                        title: widget.title,
                        future: widget.future,
                        onClose: () => Navigator.of(context).pop(),
                        onSelectConversation: _handleConversationSelected,
                      )
                    : _ConversationHistoryDetailView(
                        key: ValueKey<String>(
                          'conversation_history_detail_${_selectedConversation!.sessionId}',
                        ),
                        title: widget.title,
                        conversation: _selectedConversation!,
                        future: _detailFuture!,
                        onBack: _clearSelection,
                        onClose: () => Navigator.of(context).pop(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleConversationSelected(
    CodexWorkspaceConversationSummary conversation,
  ) {
    setState(() {
      _selectedConversation = conversation;
      _detailFuture = widget.onLoadConversationDetail(conversation.sessionId);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedConversation = null;
      _detailFuture = null;
    });
  }
}

class _ConversationHistoryListView extends StatelessWidget {
  const _ConversationHistoryListView({
    super.key,
    required this.title,
    required this.future,
    required this.onClose,
    required this.onSelectConversation,
  });

  final String title;
  final Future<List<CodexWorkspaceConversationSummary>> future;
  final VoidCallback onClose;
  final ValueChanged<CodexWorkspaceConversationSummary> onSelectConversation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConversationHistoryHeader(
          title: title,
          subtitle: 'Conversations scoped to this workspace directory.',
          onClose: onClose,
        ),
        const Divider(height: 1),
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
                return _ConversationHistoryMessage(
                  title: 'Could not load conversations',
                  body: '${snapshot.error}',
                );
              }

              final conversations = snapshot.data ?? const [];
              if (conversations.isEmpty) {
                return const _ConversationHistoryMessage(
                  title: 'No matching conversations',
                  body:
                      'Codex history was found, but nothing matched this workspace yet.',
                );
              }

              final cards = ConversationCardPalette.of(context);
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
                        'workspace_conversation_${conversation.sessionId}',
                      ),
                      onTap: () => onSelectConversation(conversation),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      title: Text(
                        conversation.trimmedPreview.isEmpty
                            ? conversation.sessionId
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
                        Icons.chevron_right,
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

class _ConversationHistoryDetailView extends StatelessWidget {
  const _ConversationHistoryDetailView({
    super.key,
    required this.title,
    required this.conversation,
    required this.future,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final CodexWorkspaceConversationSummary conversation;
  final Future<CodexWorkspaceConversationDetail?> future;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConversationHistoryHeader(
          title: conversation.trimmedPreview.isEmpty
              ? conversation.sessionId
              : conversation.trimmedPreview,
          subtitle: title,
          leading: IconButton(
            tooltip: 'Back to conversation history',
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: cards.textMuted),
          ),
          onClose: onClose,
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<CodexWorkspaceConversationDetail?>(
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
                  title: 'Could not load conversation',
                  body: '${snapshot.error}',
                );
              }

              final detail = snapshot.data;
              if (detail == null) {
                return const _ConversationHistoryMessage(
                  title: 'Conversation unavailable',
                  body:
                      'This saved conversation could not be reconstructed from the local Codex session log.',
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                children: [
                  _ConversationHistoryMetaCard(detail: detail),
                  const SizedBox(height: 12),
                  if (detail.entries.isEmpty)
                    const _ConversationHistoryMessage(
                      title: 'No visible events',
                      body:
                          'The session log was found, but it did not contain user-facing events that Pocket Relay can reconstruct yet.',
                    )
                  else
                    for (final entry in detail.entries) ...[
                      _ConversationHistoryEntryCard(entry: entry),
                      const SizedBox(height: 10),
                    ],
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Historical detail is read-only. It does not resume the live lane.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cards.textMuted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConversationHistoryHeader extends StatelessWidget {
  const _ConversationHistoryHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close conversation history',
            onPressed: onClose,
            icon: Icon(Icons.close, color: cards.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ConversationHistoryMetaCard extends StatelessWidget {
  const _ConversationHistoryMetaCard({required this.detail});

  final CodexWorkspaceConversationDetail detail;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cards.neutralBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.summary.sessionId,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cards.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _MetaLine(label: 'Workspace', value: detail.summary.cwd),
            _MetaLine(
              label: 'Started',
              value: detail.startedAt == null
                  ? 'Unknown'
                  : _timestampLabel(detail.startedAt!),
            ),
            _MetaLine(
              label: 'Last activity',
              value: detail.summary.lastActivityAt == null
                  ? 'Unknown'
                  : _timestampLabel(detail.summary.lastActivityAt!),
            ),
            _MetaLine(
              label: 'Stored prompts',
              value: '${detail.summary.messageCount}',
            ),
            _MetaLine(label: 'Source', value: detail.sourcePath),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(color: cards.textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cards.textSecondary,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ConversationHistoryEntryCard extends StatelessWidget {
  const _ConversationHistoryEntryCard({required this.entry});

  final CodexWorkspaceConversationDetailEntry entry;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final presentation = _entryPresentation(entry.kind, cards);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: presentation.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(presentation.icon, size: 18, color: presentation.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      color: cards.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (entry.timestamp != null)
                  Text(
                    _timestampLabel(entry.timestamp!),
                    style: TextStyle(color: cards.textMuted, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              entry.body,
              key: ValueKey<String>(
                'history_detail_${entry.title}_${entry.body}',
              ),
              style: TextStyle(color: cards.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationHistoryEntryPresentation {
  const _ConversationHistoryEntryPresentation({
    required this.icon,
    required this.accent,
    required this.border,
    required this.background,
  });

  final IconData icon;
  final Color accent;
  final Color border;
  final Color background;
}

_ConversationHistoryEntryPresentation _entryPresentation(
  CodexWorkspaceConversationDetailEntryKind kind,
  ConversationCardPalette cards,
) {
  final brightness = cards.brightness;
  return switch (kind) {
    CodexWorkspaceConversationDetailEntryKind.userMessage =>
      _ConversationHistoryEntryPresentation(
        icon: Icons.person_outline,
        accent: tealAccent(brightness),
        border: cards.accentBorder(tealAccent(brightness)),
        background: cards.tintedSurface(tealAccent(brightness)),
      ),
    CodexWorkspaceConversationDetailEntryKind.agentMessage =>
      _ConversationHistoryEntryPresentation(
        icon: Icons.smart_toy_outlined,
        accent: blueAccent(brightness),
        border: cards.accentBorder(blueAccent(brightness)),
        background: cards.tintedSurface(blueAccent(brightness)),
      ),
    CodexWorkspaceConversationDetailEntryKind.toolCall =>
      _ConversationHistoryEntryPresentation(
        icon: Icons.build_outlined,
        accent: amberAccent(brightness),
        border: cards.accentBorder(amberAccent(brightness)),
        background: cards.tintedSurface(amberAccent(brightness)),
      ),
    CodexWorkspaceConversationDetailEntryKind.toolResult =>
      _ConversationHistoryEntryPresentation(
        icon: Icons.terminal,
        accent: neutralAccent(brightness),
        border: cards.accentBorder(neutralAccent(brightness)),
        background: cards.tintedSurface(neutralAccent(brightness)),
      ),
    CodexWorkspaceConversationDetailEntryKind.lifecycle =>
      _ConversationHistoryEntryPresentation(
        icon: Icons.flag_outlined,
        accent: violetAccent(brightness),
        border: cards.accentBorder(violetAccent(brightness)),
        background: cards.tintedSurface(violetAccent(brightness)),
      ),
  };
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

String _subtitleFor(CodexWorkspaceConversationSummary conversation) {
  final activity = conversation.lastActivityAt;
  final activityLabel = activity == null
      ? 'Unknown activity time'
      : _timestampLabel(activity);
  return '${conversation.messageCount} prompts · $activityLabel\n${conversation.cwd}';
}

String _timestampLabel(DateTime value) {
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}
