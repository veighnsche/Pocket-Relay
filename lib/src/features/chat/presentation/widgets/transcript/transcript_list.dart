import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart';

class TranscriptListController extends ChangeNotifier {
  void requestFollow() {
    notifyListeners();
  }
}

class TranscriptList extends StatefulWidget {
  const TranscriptList({
    super.key,
    required this.controller,
    required this.isConfigured,
    required this.transcriptBlocks,
    required this.turnTimers,
    required this.onConfigure,
    this.pendingApprovalBlock,
    this.pendingUserInputBlock,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
  });

  final TranscriptListController controller;
  final bool isConfigured;
  final List<CodexUiBlock> transcriptBlocks;
  final Map<String, CodexSessionTurnTimer> turnTimers;
  final VoidCallback onConfigure;
  final CodexApprovalRequestBlock? pendingApprovalBlock;
  final CodexUserInputRequestBlock? pendingUserInputBlock;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  static const double _autoScrollResumeDistance = 72;

  final _scrollController = ScrollController();
  bool _shouldFollowTranscript = true;

  bool get _hasVisibleConversation =>
      widget.transcriptBlocks.isNotEmpty ||
      widget.pendingApprovalBlock != null ||
      widget.pendingUserInputBlock != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleFollowRequest);
  }

  @override
  void didUpdateWidget(covariant TranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleFollowRequest);
      widget.controller.addListener(_handleFollowRequest);
    }

    if (_shouldFollowTranscript && _hasVisibleConversation) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleFollowRequest);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasVisibleConversation) {
      return EmptyState(
        isConfigured: widget.isConfigured,
        onConfigure: widget.onConfigure,
      );
    }

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleTranscriptScrollNotification,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              itemBuilder: (context, index) {
                final block = widget.transcriptBlocks[index];
                return ConversationEntryCard(
                  key: ValueKey<String>('transcript_${block.id}'),
                  block: block,
                  turnTimer: _turnTimerForBlock(block),
                  onApproveRequest: widget.onApproveRequest,
                  onDenyRequest: widget.onDenyRequest,
                  onSubmitUserInput: widget.onSubmitUserInput,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: widget.transcriptBlocks.length,
            ),
          ),
        ),
        if (widget.pendingApprovalBlock != null ||
            widget.pendingUserInputBlock != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (widget.pendingApprovalBlock != null)
                      ConversationEntryCard(
                        key: ValueKey<String>(
                          'pending_${widget.pendingApprovalBlock!.id}',
                        ),
                        block: widget.pendingApprovalBlock!,
                        onApproveRequest: widget.onApproveRequest,
                        onDenyRequest: widget.onDenyRequest,
                        onSubmitUserInput: widget.onSubmitUserInput,
                      ),
                    if (widget.pendingApprovalBlock != null &&
                        widget.pendingUserInputBlock != null)
                      const SizedBox(height: 8),
                    if (widget.pendingUserInputBlock != null)
                      ConversationEntryCard(
                        key: ValueKey<String>(
                          'pending_${widget.pendingUserInputBlock!.id}',
                        ),
                        block: widget.pendingUserInputBlock!,
                        onApproveRequest: widget.onApproveRequest,
                        onDenyRequest: widget.onDenyRequest,
                        onSubmitUserInput: widget.onSubmitUserInput,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleFollowRequest() {
    _shouldFollowTranscript = true;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !_shouldFollowTranscript) {
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

    _shouldFollowTranscript = _isNearTranscriptBottom(notification.metrics);
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
        _autoScrollResumeDistance;
  }

  CodexSessionTurnTimer? _turnTimerForBlock(CodexUiBlock block) {
    final turnId = _turnIdFor(block);
    if (turnId == null) {
      return null;
    }
    final turnTimer = widget.turnTimers[turnId];
    if (turnTimer == null) {
      return null;
    }
    final latestBlockId = _latestTimerFooterBlockIdForTurn(turnId);
    return latestBlockId == block.id ? turnTimer : null;
  }

  String? _latestTimerFooterBlockIdForTurn(String turnId) {
    String? latestBlockId;
    for (final block in widget.transcriptBlocks) {
      if (_turnIdFor(block) == turnId && _supportsTurnTimerFooter(block)) {
        latestBlockId = block.id;
      }
    }
    return latestBlockId;
  }
}

bool _supportsTurnTimerFooter(CodexUiBlock block) {
  return switch (block) {
    CodexTextBlock() ||
    CodexProposedPlanBlock() ||
    CodexChangedFilesBlock() ||
    CodexCommandExecutionBlock() ||
    CodexWorkLogEntryBlock() ||
    CodexWorkLogGroupBlock() => true,
    _ => false,
  };
}

String? _turnIdFor(CodexUiBlock block) {
  return switch (block) {
    CodexTextBlock(:final turnId) => turnId,
    CodexProposedPlanBlock(:final turnId) => turnId,
    CodexChangedFilesBlock(:final turnId) => turnId,
    CodexCommandExecutionBlock(:final turnId) => turnId,
    CodexWorkLogEntryBlock(:final turnId) => turnId,
    CodexWorkLogGroupBlock(:final entries) =>
      entries.isEmpty ? null : entries.last.turnId,
    _ => null,
  };
}
