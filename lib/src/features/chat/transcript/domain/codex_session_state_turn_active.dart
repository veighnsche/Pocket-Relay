part of 'codex_session_state.dart';

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
    required this.blockKind,
    required this.createdAt,
    this.title,
    this.body = '',
    this.aggregatedBody = '',
    this.artifactBaseBody = '',
    this.isRunning = false,
    this.exitCode,
    this.snapshot,
  });

  final String itemId;
  final String threadId;
  final String turnId;
  final CodexCanonicalItemType itemType;
  final String entryId;
  final CodexUiBlockKind blockKind;
  final DateTime createdAt;
  final String? title;
  final String body;
  final String aggregatedBody;
  final String artifactBaseBody;
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  CodexSessionActiveItem copyWith({
    String? entryId,
    DateTime? createdAt,
    String? title,
    String? body,
    String? aggregatedBody,
    String? artifactBaseBody,
    bool? isRunning,
    int? exitCode,
    Map<String, dynamic>? snapshot,
  }) {
    return CodexSessionActiveItem(
      itemId: itemId,
      threadId: threadId,
      turnId: turnId,
      itemType: itemType,
      entryId: entryId ?? this.entryId,
      blockKind: blockKind,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      aggregatedBody: aggregatedBody ?? this.aggregatedBody,
      artifactBaseBody: artifactBaseBody ?? this.artifactBaseBody,
      isRunning: isRunning ?? this.isRunning,
      exitCode: exitCode ?? this.exitCode,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

enum CodexActiveTurnStatus { running, blocked, completing }

class CodexActiveTurnState {
  const CodexActiveTurnState({
    required this.turnId,
    this.threadId,
    required this.timer,
    this.status = CodexActiveTurnStatus.running,
    this.artifacts = const <CodexTurnArtifact>[],
    this.itemsById = const <String, CodexSessionActiveItem>{},
    this.itemArtifactIds = const <String, String>{},
    this.pendingApprovalRequests = const <String, CodexSessionPendingRequest>{},
    this.pendingUserInputRequests =
        const <String, CodexSessionPendingUserInputRequest>{},
    this.turnDiffSnapshot,
    this.pendingThreadTokenUsageBlock,
    this.latestUsageSummary,
    this.hasWork = false,
    this.hasReasoning = false,
  });

  final String turnId;
  final String? threadId;
  final CodexSessionTurnTimer timer;
  final CodexActiveTurnStatus status;
  final List<CodexTurnArtifact> artifacts;
  final Map<String, CodexSessionActiveItem> itemsById;
  final Map<String, String> itemArtifactIds;
  final Map<String, CodexSessionPendingRequest> pendingApprovalRequests;
  final Map<String, CodexSessionPendingUserInputRequest>
  pendingUserInputRequests;
  final CodexTurnDiffSnapshot? turnDiffSnapshot;
  final CodexUsageBlock? pendingThreadTokenUsageBlock;
  final String? latestUsageSummary;
  final bool hasWork;
  final bool hasReasoning;

  bool get hasBlockingRequests =>
      pendingApprovalRequests.isNotEmpty || pendingUserInputRequests.isNotEmpty;

  CodexActiveTurnState copyWith({
    String? turnId,
    String? threadId,
    CodexSessionTurnTimer? timer,
    CodexActiveTurnStatus? status,
    List<CodexTurnArtifact>? artifacts,
    Map<String, CodexSessionActiveItem>? itemsById,
    Map<String, String>? itemArtifactIds,
    Map<String, CodexSessionPendingRequest>? pendingApprovalRequests,
    Map<String, CodexSessionPendingUserInputRequest>? pendingUserInputRequests,
    CodexTurnDiffSnapshot? turnDiffSnapshot,
    bool clearTurnDiffSnapshot = false,
    CodexUsageBlock? pendingThreadTokenUsageBlock,
    bool clearPendingThreadTokenUsageBlock = false,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
    bool? hasWork,
    bool? hasReasoning,
  }) {
    return CodexActiveTurnState(
      turnId: turnId ?? this.turnId,
      threadId: threadId ?? this.threadId,
      timer: timer ?? this.timer,
      status: status ?? this.status,
      artifacts: artifacts ?? this.artifacts,
      itemsById: itemsById ?? this.itemsById,
      itemArtifactIds: itemArtifactIds ?? this.itemArtifactIds,
      pendingApprovalRequests:
          pendingApprovalRequests ?? this.pendingApprovalRequests,
      pendingUserInputRequests:
          pendingUserInputRequests ?? this.pendingUserInputRequests,
      turnDiffSnapshot: clearTurnDiffSnapshot
          ? null
          : (turnDiffSnapshot ?? this.turnDiffSnapshot),
      pendingThreadTokenUsageBlock: clearPendingThreadTokenUsageBlock
          ? null
          : (pendingThreadTokenUsageBlock ?? this.pendingThreadTokenUsageBlock),
      latestUsageSummary: clearLatestUsageSummary
          ? null
          : (latestUsageSummary ?? this.latestUsageSummary),
      hasWork: hasWork ?? this.hasWork,
      hasReasoning: hasReasoning ?? this.hasReasoning,
    );
  }
}
