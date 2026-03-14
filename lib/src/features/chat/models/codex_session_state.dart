import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';

class CodexSessionState {
  const CodexSessionState({
    this.connectionStatus = CodexRuntimeSessionState.stopped,
    this.threadId,
    this.turnId,
    this.pendingApprovalRequests = const <String, CodexSessionPendingRequest>{},
    this.pendingUserInputRequests =
        const <String, CodexSessionPendingUserInputRequest>{},
    this.activeItems = const <String, CodexSessionActiveItem>{},
    this.transcript = const <ConversationEntry>[],
    this.latestUsageSummary,
  });

  factory CodexSessionState.initial() {
    return const CodexSessionState();
  }

  final CodexRuntimeSessionState connectionStatus;
  final String? threadId;
  final String? turnId;
  final Map<String, CodexSessionPendingRequest> pendingApprovalRequests;
  final Map<String, CodexSessionPendingUserInputRequest>
  pendingUserInputRequests;
  final Map<String, CodexSessionActiveItem> activeItems;
  final List<ConversationEntry> transcript;
  final String? latestUsageSummary;

  bool get isBusy => connectionStatus == CodexRuntimeSessionState.running;

  CodexSessionState copyWith({
    CodexRuntimeSessionState? connectionStatus,
    String? threadId,
    bool clearThreadId = false,
    String? turnId,
    bool clearTurnId = false,
    Map<String, CodexSessionPendingRequest>? pendingApprovalRequests,
    Map<String, CodexSessionPendingUserInputRequest>? pendingUserInputRequests,
    Map<String, CodexSessionActiveItem>? activeItems,
    List<ConversationEntry>? transcript,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      threadId: clearThreadId ? null : (threadId ?? this.threadId),
      turnId: clearTurnId ? null : (turnId ?? this.turnId),
      pendingApprovalRequests:
          pendingApprovalRequests ?? this.pendingApprovalRequests,
      pendingUserInputRequests:
          pendingUserInputRequests ?? this.pendingUserInputRequests,
      activeItems: activeItems ?? this.activeItems,
      transcript: transcript ?? this.transcript,
      latestUsageSummary: clearLatestUsageSummary
          ? null
          : (latestUsageSummary ?? this.latestUsageSummary),
    );
  }
}

class CodexSessionPendingRequest {
  const CodexSessionPendingRequest({
    required this.requestId,
    required this.requestType,
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.detail,
    this.args,
  });

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final Object? args;
}

class CodexSessionPendingUserInputRequest {
  const CodexSessionPendingUserInputRequest({
    required this.requestId,
    required this.requestType,
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.detail,
    this.questions = const <CodexRuntimeUserInputQuestion>[],
    this.args,
  });

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final List<CodexRuntimeUserInputQuestion> questions;
  final Object? args;
}

class CodexSessionActiveItem {
  const CodexSessionActiveItem({
    required this.itemId,
    required this.threadId,
    required this.turnId,
    required this.itemType,
    required this.entryId,
    required this.kind,
    required this.createdAt,
    this.title,
    this.body = '',
    this.isRunning = false,
    this.exitCode,
  });

  final String itemId;
  final String threadId;
  final String turnId;
  final CodexCanonicalItemType itemType;
  final String entryId;
  final ConversationEntryKind kind;
  final DateTime createdAt;
  final String? title;
  final String body;
  final bool isRunning;
  final int? exitCode;

  CodexSessionActiveItem copyWith({
    String? title,
    String? body,
    bool? isRunning,
    int? exitCode,
  }) {
    return CodexSessionActiveItem(
      itemId: itemId,
      threadId: threadId,
      turnId: turnId,
      itemType: itemType,
      entryId: entryId,
      kind: kind,
      createdAt: createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
    );
  }
}
