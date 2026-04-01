import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/alert_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_decision_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/session_status_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/turn_boundary_marker.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_input_result_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/transcript_list.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';

export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/alert_surface.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_decision_surface.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/session_status_surface.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/turn_boundary_marker.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_input_result_surface.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
export 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/transcript_list.dart';
export 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_form_scope.dart';
export 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
export 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
export 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
export 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';

const itemProjector = ChatTranscriptItemProjector();
const defaultFollowBehavior = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: 72,
);

ChatTranscriptSurfaceContract surfaceContract({
  bool isConfigured = true,
  List<TranscriptUiBlock> mainItems = const <TranscriptUiBlock>[],
  List<TranscriptUiBlock> pinnedItems = const <TranscriptUiBlock>[],
  Set<String>? activePendingUserInputRequestIds,
  int? totalMainItemCount,
  ChatEmptyStateContract? emptyState,
}) {
  return ChatTranscriptSurfaceContract(
    isConfigured: isConfigured,
    mainItems: mainItems.map(itemProjector.project).toList(growable: false),
    pinnedItems: pinnedItems.map(itemProjector.project).toList(growable: false),
    pendingRequestPlacement: ChatPendingRequestPlacementContract(
      visibleApprovalRequest: null,
      visibleUserInputRequest: null,
    ),
    activePendingUserInputRequestIds:
        activePendingUserInputRequestIds ??
        activePendingUserInputRequestIdsForBlocks(
          mainItems: mainItems,
          pinnedItems: pinnedItems,
        ),
    totalMainItemCount: totalMainItemCount,
    emptyState: emptyState,
  );
}

Set<String> activePendingUserInputRequestIdsForBlocks({
  required List<TranscriptUiBlock> mainItems,
  required List<TranscriptUiBlock> pinnedItems,
}) {
  final activeRequestIds = <String>{};

  for (final block in <TranscriptUiBlock>[...mainItems, ...pinnedItems]) {
    if (block case final TranscriptUserInputRequestBlock userInputBlock
        when !userInputBlock.isResolved) {
      activeRequestIds.add(userInputBlock.requestId);
    }
  }

  return activeRequestIds;
}

ChatTranscriptFollowContract followBehavior({
  bool isAutoFollowEnabled = true,
  int? requestId,
  ChatTranscriptFollowRequestSource source =
      ChatTranscriptFollowRequestSource.sendPrompt,
}) {
  return ChatTranscriptFollowContract(
    isAutoFollowEnabled: isAutoFollowEnabled,
    resumeDistance: 72,
    request: requestId == null
        ? null
        : ChatTranscriptFollowRequestContract(id: requestId, source: source),
  );
}

Widget entrySurface({
  Key? key,
  required TranscriptUiBlock block,
  Future<void> Function(String requestId)? onApproveRequest,
  Future<void> Function(String requestId)? onDenyRequest,
  void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
  void Function(ChatWorkLogTerminalContract terminal)? onOpenWorkLogTerminal,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onSubmitUserInput,
  Future<void> Function(String blockId)? onSaveHostFingerprint,
  VoidCallback? onConfigure,
  Future<void> Function(String blockId)? onContinueFromUserMessage,
}) {
  return Builder(
    builder: (context) {
      return ConversationEntryRenderer(
        key: key,
        item: itemProjector.project(block),
        onApproveRequest: onApproveRequest,
        onDenyRequest: onDenyRequest,
        onOpenChangedFileDiff:
            onOpenChangedFileDiff ??
            (diff) {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ChangedFileDiffSheet(diff: diff),
              );
            },
        onOpenWorkLogTerminal: onOpenWorkLogTerminal,
        onSubmitUserInput: onSubmitUserInput,
        onSaveHostFingerprint: onSaveHostFingerprint,
        onConfigure: onConfigure,
        onContinueFromUserMessage: onContinueFromUserMessage,
      );
    },
  );
}

Widget buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Set<String> activeRequestIds = const <String>{},
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: themeMode,
    home: Scaffold(
      body: PendingUserInputFormScope(
        activeRequestIds: activeRequestIds,
        child: child,
      ),
    ),
  );
}

TextStyle? findStyleForText(WidgetTester tester, String text) {
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    if (widget.data == text) {
      return widget.style;
    }

    final span = widget.textSpan;
    if (span == null) {
      continue;
    }
    final style = _styleForInlineText(span, text);
    if (style != null) {
      return style;
    }
  }

  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final style = _styleForInlineText(widget.text, text);
    if (style != null) {
      return style;
    }
  }

  return null;
}

Color? findDecoratedContainerColorForText(WidgetTester tester, String text) {
  final selectableTextFinder = find.byWidgetPredicate(
    (widget) => widget is SelectableText && widget.data == text,
  );
  if (selectableTextFinder.evaluate().isNotEmpty) {
    for (final container in tester.widgetList<Container>(
      find.ancestor(of: selectableTextFinder, matching: find.byType(Container)),
    )) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        return decoration.color;
      }
    }
  }

  for (final ink in tester.widgetList<Ink>(
    find.ancestor(of: find.text(text), matching: find.byType(Ink)),
  )) {
    final decoration = ink.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }

  for (final container in tester.widgetList<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)),
  )) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }

  for (final ink in tester.widgetList<Ink>(
    find.ancestor(of: find.text(text), matching: find.byType(Ink)),
  )) {
    final decoration = ink.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }

  return null;
}

TextStyle? _styleForInlineText(
  InlineSpan span,
  String text, [
  TextStyle? inheritedStyle,
]) {
  if (span is! TextSpan) {
    return null;
  }

  final mergedStyle = inheritedStyle?.merge(span.style) ?? span.style;

  if ((span.text ?? '').contains(text)) {
    return mergedStyle;
  }

  for (final child in span.children ?? const <InlineSpan>[]) {
    final childStyle = _styleForInlineText(child, text, mergedStyle);
    if (childStyle != null) {
      return childStyle;
    }
  }

  return null;
}
