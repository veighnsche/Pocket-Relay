import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart';

class TranscriptList extends StatefulWidget {
  const TranscriptList({
    super.key,
    required this.surface,
    required this.followBehavior,
    required this.platformBehavior,
    required this.onConfigure,
    this.onSelectConnectionMode,
    required this.onAutoFollowEligibilityChanged,
    this.surfaceChangeToken,
    this.onOpenChangedFileDiff,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
    this.onSaveHostFingerprint,
    this.onContinueFromUserMessage,
  });

  final ChatTranscriptSurfaceContract surface;
  final ChatTranscriptFollowContract followBehavior;
  final PocketPlatformBehavior platformBehavior;
  final VoidCallback onConfigure;
  final ValueChanged<ConnectionMode>? onSelectConnectionMode;
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
  final Future<void> Function(String blockId)? onContinueFromUserMessage;

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  final _scrollController = ScrollController();

  bool get _hasVisibleConversation => !widget.surface.showsEmptyState;
  Object get _surfaceChangeToken => widget.surfaceChangeToken ?? widget.surface;

  @override
  void didUpdateWidget(covariant TranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousRequestId = oldWidget.followBehavior.request?.id;
    final nextRequestId = widget.followBehavior.request?.id;
    if (previousRequestId != nextRequestId && nextRequestId != null) {
      _scrollToEnd();
      return;
    }

    final previousSurfaceChangeToken =
        oldWidget.surfaceChangeToken ?? oldWidget.surface;
    if (_surfaceChangeToken != previousSurfaceChangeToken &&
        widget.followBehavior.isAutoFollowEnabled &&
        _hasVisibleConversation) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PendingUserInputFormScope(
      activeRequestIds: widget.surface.activePendingUserInputRequestIds,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final emptyState = widget.surface.emptyState;
    if (emptyState != null) {
      return EmptyState(
        isConfigured: emptyState.isConfigured,
        connectionMode: emptyState.connectionMode,
        platformBehavior: widget.platformBehavior,
        onConfigure: widget.onConfigure,
        onSelectConnectionMode: widget.onSelectConnectionMode,
      );
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleTranscriptScrollNotification,
            child: ListView.separated(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              itemBuilder: (context, index) {
                if (widget.surface.hasHiddenOlderMainItems && index == 0) {
                  return _TranscriptWindowLimitNotice(
                    visibleMainItemCount: widget.surface.visibleMainItemCount,
                    totalMainItemCount: widget.surface.totalMainItemCount,
                  );
                }

                final item = widget
                    .surface
                    .mainItems[index - _transcriptListLeadingItemCount];
                return ConversationEntryRenderer(
                  key: ValueKey<String>('transcript_${item.id}'),
                  item: item,
                  showsDesktopContextMenu:
                      widget.platformBehavior.isDesktopExperience,
                  onConfigure: widget.onConfigure,
                  onApproveRequest: widget.onApproveRequest,
                  onDenyRequest: widget.onDenyRequest,
                  onOpenChangedFileDiff: widget.onOpenChangedFileDiff,
                  onSubmitUserInput: widget.onSubmitUserInput,
                  onSaveHostFingerprint: widget.onSaveHostFingerprint,
                  onContinueFromUserMessage: widget.onContinueFromUserMessage,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount:
                  widget.surface.mainItems.length +
                  _transcriptListLeadingItemCount,
            ),
          ),
        ),
        if (widget.surface.pinnedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: widget.surface.pinnedItems.indexed
                      .map((entry) {
                        final index = entry.$1;
                        final item = entry.$2;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index == widget.surface.pinnedItems.length - 1
                                ? 0
                                : 8,
                          ),
                          child: ConversationEntryRenderer(
                            key: ValueKey<String>('pinned_${item.id}'),
                            item: item,
                            showsDesktopContextMenu:
                                widget.platformBehavior.isDesktopExperience,
                            onConfigure: widget.onConfigure,
                            onApproveRequest: widget.onApproveRequest,
                            onDenyRequest: widget.onDenyRequest,
                            onOpenChangedFileDiff: widget.onOpenChangedFileDiff,
                            onSubmitUserInput: widget.onSubmitUserInput,
                            onSaveHostFingerprint: widget.onSaveHostFingerprint,
                            onContinueFromUserMessage:
                                widget.onContinueFromUserMessage,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int get _transcriptListLeadingItemCount =>
      widget.surface.hasHiddenOlderMainItems ? 1 : 0;

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  bool _handleTranscriptScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }

    final isUserDriven = switch (notification) {
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      ScrollEndNotification() => true,
      UserScrollNotification() => true,
      _ => false,
    };
    if (!isUserDriven) {
      return false;
    }

    widget.onAutoFollowEligibilityChanged(
      _isNearTranscriptBottom(notification.metrics),
    );
    return false;
  }

  bool _isNearTranscriptBottom([ScrollMetrics? metrics]) {
    final activeMetrics =
        metrics ??
        (_scrollController.hasClients ? _scrollController.position : null);
    if (activeMetrics == null) {
      return true;
    }

    return activeMetrics.maxScrollExtent - activeMetrics.pixels <=
        widget.followBehavior.resumeDistance;
  }
}

class _TranscriptWindowLimitNotice extends StatelessWidget {
  const _TranscriptWindowLimitNotice({
    required this.visibleMainItemCount,
    required this.totalMainItemCount,
  });

  final int visibleMainItemCount;
  final int totalMainItemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant;

    return Text(
      'Showing the most recent $visibleMainItemCount of $totalMainItemCount transcript items. Older activity is not shown in this view.',
      style: theme.textTheme.bodySmall?.copyWith(color: textColor),
      textAlign: TextAlign.center,
    );
  }
}
