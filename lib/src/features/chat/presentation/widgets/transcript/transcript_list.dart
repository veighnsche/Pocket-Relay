import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_form_scope.dart';
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
    required this.surface,
    required this.onConfigure,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
  });

  final TranscriptListController controller;
  final ChatTranscriptSurfaceContract surface;
  final VoidCallback onConfigure;
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

  bool get _hasVisibleConversation => !widget.surface.showsEmptyState;

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
    return PendingUserInputFormScope(
      activeRequestIds: _activePendingUserInputRequestIds(),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final emptyState = widget.surface.emptyState;
    if (emptyState != null) {
      return EmptyState(
        isConfigured: emptyState.isConfigured,
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
                final item = widget.surface.mainItems[index];
                return ConversationEntryCard(
                  key: ValueKey<String>('transcript_${item.id}'),
                  item: item,
                  onApproveRequest: widget.onApproveRequest,
                  onDenyRequest: widget.onDenyRequest,
                  onSubmitUserInput: widget.onSubmitUserInput,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: widget.surface.mainItems.length,
            ),
          ),
        ),
        if (widget.surface.pinnedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
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
                          child: ConversationEntryCard(
                            key: ValueKey<String>('pinned_${item.id}'),
                            item: item,
                            onApproveRequest: widget.onApproveRequest,
                            onDenyRequest: widget.onDenyRequest,
                            onSubmitUserInput: widget.onSubmitUserInput,
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

  Set<String> _activePendingUserInputRequestIds() {
    final activeRequestIds = <String>{};

    for (final item in widget.surface.mainItems) {
      if (item case final ChatUserInputRequestItemContract userInputItem
          when !userInputItem.block.isResolved) {
        activeRequestIds.add(userInputItem.block.requestId);
      }
    }

    for (final item in widget.surface.pinnedItems) {
      if (item case final ChatUserInputRequestItemContract userInputItem
          when !userInputItem.block.isResolved) {
        activeRequestIds.add(userInputItem.block.requestId);
      }
    }

    return activeRequestIds;
  }
}
