import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/domain/workspace_conversation_summary.dart';

enum ConnectionWorkspaceConversationHistoryPresentation { mobile, desktop }

enum _ConversationHistorySortMode { latestActivity, newestCreated }

abstract final class _ConversationHistoryCopy {
  static const String bodyDescription =
      'Pick a saved conversation to resume in this lane.';
  static const String closeAction = 'Close conversation history';
  static const String openConnectionSettingsAction = 'Open connection settings';
  static const String emptyTitle = 'No matching conversations';
  static const String emptyBody =
      'No workspace conversations are available yet.';
  static const String updatedLabel = 'Updated';
  static const String createdLabel = 'Created';
  static const String unknownTime = 'time unknown';

  static String promptCountLabel(int promptCount) {
    final promptLabel = promptCount == 1 ? 'prompt' : 'prompts';
    return '$promptCount $promptLabel';
  }

  static String sortTooltip(_ConversationHistorySortMode sortMode) {
    return switch (sortMode) {
      _ConversationHistorySortMode.latestActivity =>
        'Sorting by latest update. Tap to sort by newest conversation.',
      _ConversationHistorySortMode.newestCreated =>
        'Sorting by newest conversation. Tap to sort by latest update.',
    };
  }
}

class ConnectionWorkspaceConversationHistorySheet extends StatefulWidget {
  const ConnectionWorkspaceConversationHistorySheet({
    super.key,
    required this.title,
    required this.future,
    required this.onResumeConversation,
    this.onOpenConnectionSettings,
    this.presentation =
        ConnectionWorkspaceConversationHistoryPresentation.mobile,
  });

  final String title;
  final Future<List<WorkspaceConversationSummary>> future;
  final ValueChanged<WorkspaceConversationSummary> onResumeConversation;
  final VoidCallback? onOpenConnectionSettings;
  final ConnectionWorkspaceConversationHistoryPresentation presentation;

  @override
  State<ConnectionWorkspaceConversationHistorySheet> createState() =>
      _ConnectionWorkspaceConversationHistorySheetState();
}

class _ConnectionWorkspaceConversationHistorySheetState
    extends State<ConnectionWorkspaceConversationHistorySheet> {
  static final _oldestConversationSentinel =
      DateTime.fromMillisecondsSinceEpoch(0);

  var _sortMode = _ConversationHistorySortMode.latestActivity;
  List<WorkspaceConversationSummary>? _lastSortedSource;
  _ConversationHistorySortMode? _lastSortedMode;
  List<WorkspaceConversationSummary>? _lastSortedConversations;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return switch (widget.presentation) {
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
    final labelPrefix = switch (_sortMode) {
      _ConversationHistorySortMode.latestActivity =>
        _ConversationHistoryCopy.updatedLabel,
      _ConversationHistorySortMode.newestCreated =>
        _ConversationHistoryCopy.createdLabel,
    };
    final timestamp = switch (_sortMode) {
      _ConversationHistorySortMode.latestActivity =>
        conversation.lastActivityAt,
      _ConversationHistorySortMode.newestCreated => conversation.firstPromptAt,
    };
    final timestampLabel = timestamp == null
        ? '$labelPrefix ${_ConversationHistoryCopy.unknownTime}'
        : '$labelPrefix ${_timestampLabel(timestamp.toLocal())}';
    return '${_ConversationHistoryCopy.promptCountLabel(conversation.promptCount)} · $timestampLabel';
  }

  String _timestampLabel(DateTime value) {
    final twoDigitMonth = value.month.toString().padLeft(2, '0');
    final twoDigitDay = value.day.toString().padLeft(2, '0');
    final twoDigitHour = value.hour.toString().padLeft(2, '0');
    final twoDigitMinute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }

  void _toggleSortMode() {
    setState(() {
      _lastSortedMode = null;
      _lastSortedSource = null;
      _lastSortedConversations = null;
      _sortMode = switch (_sortMode) {
        _ConversationHistorySortMode.latestActivity =>
          _ConversationHistorySortMode.newestCreated,
        _ConversationHistorySortMode.newestCreated =>
          _ConversationHistorySortMode.latestActivity,
      };
    });
  }

  String get _sortTooltip => _ConversationHistoryCopy.sortTooltip(_sortMode);

  IconData get _sortIcon => switch (_sortMode) {
    _ConversationHistorySortMode.latestActivity => Icons.update_rounded,
    _ConversationHistorySortMode.newestCreated => Icons.schedule_rounded,
  };

  DateTime _sortTimestampFor(WorkspaceConversationSummary conversation) {
    return switch (_sortMode) {
      _ConversationHistorySortMode.latestActivity =>
        conversation.lastActivityAt ?? _oldestConversationSentinel,
      _ConversationHistorySortMode.newestCreated =>
        conversation.firstPromptAt ?? _oldestConversationSentinel,
    };
  }

  List<WorkspaceConversationSummary> _sortedConversations(
    List<WorkspaceConversationSummary> conversations,
  ) {
    if (_lastSortedConversations != null &&
        identical(_lastSortedSource, conversations) &&
        _lastSortedMode == _sortMode) {
      return _lastSortedConversations!;
    }

    final sorted = conversations.toList();
    sorted.sort((left, right) {
      final byTime = _sortTimestampFor(
        right,
      ).compareTo(_sortTimestampFor(left));
      if (byTime != 0) {
        return byTime;
      }
      return left.normalizedThreadId.compareTo(right.normalizedThreadId);
    });

    _lastSortedSource = conversations;
    _lastSortedMode = _sortMode;
    _lastSortedConversations = sorted;

    return sorted;
  }

  Widget _buildSortButton({Color? color}) {
    return IconButton(
      key: const ValueKey<String>('conversation_history_sort_toggle'),
      tooltip: _sortTooltip,
      onPressed: _toggleSortMode,
      icon: Icon(_sortIcon, color: color),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildSortButton(color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _ConversationHistoryCopy.bodyDescription,
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
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _ConversationHistoryCopy.bodyDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildSortButton(color: cards.textMuted),
        IconButton(
          tooltip: _ConversationHistoryCopy.closeAction,
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
            future: widget.future,
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
                  actionLabel: widget.onOpenConnectionSettings == null
                      ? null
                      : _ConversationHistoryCopy.openConnectionSettingsAction,
                  onAction: widget.onOpenConnectionSettings,
                );
              }

              final conversations = _sortedConversations(
                snapshot.data ?? const <WorkspaceConversationSummary>[],
              );
              if (conversations.isEmpty) {
                return const _ConversationHistoryMessage(
                  title: _ConversationHistoryCopy.emptyTitle,
                  body: _ConversationHistoryCopy.emptyBody,
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
                      onTap: () => widget.onResumeConversation(conversation),
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
