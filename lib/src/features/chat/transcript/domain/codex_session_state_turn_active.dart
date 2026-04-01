part of 'transcript_session_state.dart';

class TranscriptSessionPendingRequest {
  const TranscriptSessionPendingRequest({
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
  final TranscriptCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final Object? args;
}

class TranscriptSessionPendingUserInputRequest {
  const TranscriptSessionPendingUserInputRequest({
    required this.requestId,
    required this.requestType,
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.detail,
    this.questions = const <TranscriptRuntimeUserInputQuestion>[],
    this.args,
  });

  final String requestId;
  final TranscriptCanonicalRequestType requestType;
  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? detail;
  final List<TranscriptRuntimeUserInputQuestion> questions;
  final Object? args;
}

class TranscriptSessionActiveItem {
  const TranscriptSessionActiveItem({
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
  final TranscriptCanonicalItemType itemType;
  final String entryId;
  final TranscriptUiBlockKind blockKind;
  final DateTime createdAt;
  final String? title;
  final String body;
  final String aggregatedBody;
  final String artifactBaseBody;
  final bool isRunning;
  final int? exitCode;
  final Map<String, dynamic>? snapshot;

  TranscriptSessionActiveItem copyWith({
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
    return TranscriptSessionActiveItem(
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

enum TranscriptActiveTurnStatus { running, blocked, completing }

class TranscriptActiveTurnState {
  const TranscriptActiveTurnState({
    required this.turnId,
    this.threadId,
    required this.timer,
    this.status = TranscriptActiveTurnStatus.running,
    this.artifacts = const <TranscriptTurnArtifact>[],
    this.itemsById = const <String, TranscriptSessionActiveItem>{},
    this.itemArtifactIds = const <String, String>{},
    this.pendingApprovalRequests =
        const <String, TranscriptSessionPendingRequest>{},
    this.pendingUserInputRequests =
        const <String, TranscriptSessionPendingUserInputRequest>{},
    this.turnDiffSnapshot,
    this.pendingThreadTokenUsageBlock,
    this.latestUsageSummary,
    this.hasWork = false,
    this.hasReasoning = false,
  });

  final String turnId;
  final String? threadId;
  final TranscriptSessionTurnTimer timer;
  final TranscriptActiveTurnStatus status;
  final List<TranscriptTurnArtifact> artifacts;
  final Map<String, TranscriptSessionActiveItem> itemsById;
  final Map<String, String> itemArtifactIds;
  final Map<String, TranscriptSessionPendingRequest> pendingApprovalRequests;
  final Map<String, TranscriptSessionPendingUserInputRequest>
  pendingUserInputRequests;
  final TranscriptTurnDiffSnapshot? turnDiffSnapshot;
  final TranscriptUsageBlock? pendingThreadTokenUsageBlock;
  final String? latestUsageSummary;
  final bool hasWork;
  final bool hasReasoning;

  bool get hasBlockingRequests =>
      pendingApprovalRequests.isNotEmpty || pendingUserInputRequests.isNotEmpty;

  TranscriptActiveTurnState copyWith({
    String? turnId,
    String? threadId,
    TranscriptSessionTurnTimer? timer,
    TranscriptActiveTurnStatus? status,
    List<TranscriptTurnArtifact>? artifacts,
    Map<String, TranscriptSessionActiveItem>? itemsById,
    Map<String, String>? itemArtifactIds,
    Map<String, TranscriptSessionPendingRequest>? pendingApprovalRequests,
    Map<String, TranscriptSessionPendingUserInputRequest>?
    pendingUserInputRequests,
    TranscriptTurnDiffSnapshot? turnDiffSnapshot,
    bool clearTurnDiffSnapshot = false,
    TranscriptUsageBlock? pendingThreadTokenUsageBlock,
    bool clearPendingThreadTokenUsageBlock = false,
    String? latestUsageSummary,
    bool clearLatestUsageSummary = false,
    bool? hasWork,
    bool? hasReasoning,
  }) {
    return TranscriptActiveTurnState(
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
