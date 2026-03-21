import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';

class FlutterChatScreenRenderer extends StatelessWidget {
  const FlutterChatScreenRenderer({
    super.key,
    required this.screen,
    required this.appChrome,
    required this.transcriptRegion,
    required this.composerRegion,
    required this.onStopActiveTurn,
  });

  final ChatScreenContract screen;
  final PreferredSizeWidget appChrome;
  final Widget transcriptRegion;
  final Widget composerRegion;
  final Future<void> Function() onStopActiveTurn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appChrome,
      body: ChatScreenGradientBackground(
        child: ChatScreenBody(
          screen: screen,
          transcriptRegion: transcriptRegion,
          composerRegion: composerRegion,
          loadingIndicator: const CircularProgressIndicator(),
          onStopActiveTurn: onStopActiveTurn,
        ),
      ),
    );
  }
}

class FlutterChatAppChrome extends StatelessWidget
    implements PreferredSizeWidget {
  const FlutterChatAppChrome({
    super.key,
    required this.screen,
    required this.onScreenAction,
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final List<ChatChromeMenuAction> supplementalMenuActions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final menuActions = buildChatChromeMenuActions(
      screen: screen,
      onScreenAction: onScreenAction,
      supplementalMenuActions: supplementalMenuActions,
    );

    return AppBar(
      titleSpacing: 18,
      title: ChatAppChromeTitle(header: screen.header),
      actions: [
        ...screen.toolbarActions.map(
          (action) => IconButton(
            tooltip: action.tooltip,
            onPressed: () => onScreenAction(action.id),
            icon: Icon(chatActionIcon(action)),
          ),
        ),
        if (menuActions.isNotEmpty) ...[
          ChatOverflowMenuButton(actions: menuActions),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class FlutterChatTranscriptRegion extends StatelessWidget {
  const FlutterChatTranscriptRegion({
    super.key,
    required this.screen,
    required this.platformBehavior,
    required this.onScreenAction,
    required this.onSelectTimeline,
    required this.onSelectConnectionMode,
    required this.onAutoFollowEligibilityChanged,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
    this.onSaveHostFingerprint,
  });

  final ChatScreenContract screen;
  final PocketPlatformBehavior platformBehavior;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final ValueChanged<String> onSelectTimeline;
  final ValueChanged<ConnectionMode> onSelectConnectionMode;
  final ValueChanged<bool> onAutoFollowEligibilityChanged;
  final Object? surfaceChangeToken;
  final void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;
  final Future<void> Function(String blockId)? onSaveHostFingerprint;

  @override
  Widget build(BuildContext context) {
    final transcriptList = TranscriptList(
      surface: screen.transcriptSurface,
      followBehavior: screen.transcriptFollow,
      platformBehavior: platformBehavior,
      surfaceChangeToken: surfaceChangeToken,
      onConfigure: () {
        onScreenAction(ChatScreenActionId.openSettings);
      },
      onSelectConnectionMode: onSelectConnectionMode,
      onAutoFollowEligibilityChanged: onAutoFollowEligibilityChanged,
      onApproveRequest: onApproveRequest,
      onDenyRequest: onDenyRequest,
      onOpenChangedFileDiff: onOpenChangedFileDiff,
      onSubmitUserInput: onSubmitUserInput,
      onSaveHostFingerprint: onSaveHostFingerprint,
    );
    if (screen.timelineSummaries.length <= 1) {
      return transcriptList;
    }

    return Column(
      children: [
        _TimelineSelector(
          timelines: screen.timelineSummaries,
          onSelectTimeline: onSelectTimeline,
        ),
        Expanded(child: transcriptList),
      ],
    );
  }
}

class _TimelineSelector extends StatelessWidget {
  const _TimelineSelector({
    required this.timelines,
    required this.onSelectTimeline,
  });

  final List<ChatTimelineSummaryContract> timelines;
  final ValueChanged<String> onSelectTimeline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        itemCount: timelines.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final timeline = timelines[index];
          return _TimelineChip(
            summary: timeline,
            onPressed: () => onSelectTimeline(timeline.threadId),
          );
        },
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({required this.summary, required this.onPressed});

  final ChatTimelineSummaryContract summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final statusColor = _timelineStatusColor(summary.status, theme);
    final foregroundColor = summary.isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
    final backgroundColor = summary.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.10)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = summary.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.45)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('timeline_${summary.threadId}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 132),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          summary.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (summary.hasUnreadActivity) ...[
                        const SizedBox(width: 6),
                        _TimelineSignalPill(
                          label: 'New',
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      ],
                      if (summary.hasPendingRequests) ...[
                        const SizedBox(width: 6),
                        _TimelineSignalPill(
                          label: 'Needs action',
                          backgroundColor: theme.colorScheme.tertiary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _timelineStatusLabel(summary),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineSignalPill extends StatelessWidget {
  const _TimelineSignalPill({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: backgroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _timelineStatusLabel(ChatTimelineSummaryContract summary) {
  if (summary.isClosed) {
    return 'Closed';
  }

  return switch (summary.status) {
    CodexAgentLifecycleState.unknown => 'Starting',
    CodexAgentLifecycleState.starting => 'Starting',
    CodexAgentLifecycleState.idle => 'Ready',
    CodexAgentLifecycleState.running => 'Running',
    CodexAgentLifecycleState.waitingOnChild => 'Waiting on child',
    CodexAgentLifecycleState.blockedOnApproval => 'Waiting on approval',
    CodexAgentLifecycleState.blockedOnInput => 'Waiting on input',
    CodexAgentLifecycleState.completed => 'Completed',
    CodexAgentLifecycleState.failed => 'Failed',
    CodexAgentLifecycleState.aborted => 'Aborted',
    CodexAgentLifecycleState.closed => 'Closed',
  };
}

Color _timelineStatusColor(CodexAgentLifecycleState state, ThemeData theme) {
  return switch (state) {
    CodexAgentLifecycleState.unknown ||
    CodexAgentLifecycleState.starting => theme.colorScheme.primary,
    CodexAgentLifecycleState.idle => theme.colorScheme.secondary,
    CodexAgentLifecycleState.running => theme.colorScheme.primary,
    CodexAgentLifecycleState.waitingOnChild => theme.colorScheme.tertiary,
    CodexAgentLifecycleState.blockedOnApproval => const Color(0xFFB45309),
    CodexAgentLifecycleState.blockedOnInput => const Color(0xFF1D4ED8),
    CodexAgentLifecycleState.completed => const Color(0xFF15803D),
    CodexAgentLifecycleState.failed => theme.colorScheme.error,
    CodexAgentLifecycleState.aborted => theme.colorScheme.outline,
    CodexAgentLifecycleState.closed => theme.colorScheme.outline,
  };
}

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
  final ValueChanged<String> onComposerDraftChanged;
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
