part of 'transcript_session_state.dart';

enum TranscriptAgentLifecycleState {
  unknown,
  starting,
  idle,
  running,
  waitingOnChild,
  blockedOnApproval,
  blockedOnInput,
  completed,
  failed,
  aborted,
  closed,
}

class TranscriptThreadRegistryEntry {
  const TranscriptThreadRegistryEntry({
    required this.threadId,
    required this.displayOrder,
    this.parentThreadId,
    this.childThreadIds = const <String>[],
    this.threadName,
    this.agentNickname,
    this.agentRole,
    this.sourceKind,
    this.spawnItemId,
    this.isClosed = false,
    this.isPrimary = false,
  });

  final String threadId;
  final int displayOrder;
  final String? parentThreadId;
  final List<String> childThreadIds;
  final String? threadName;
  final String? agentNickname;
  final String? agentRole;
  final String? sourceKind;
  final String? spawnItemId;
  final bool isClosed;
  final bool isPrimary;

  TranscriptThreadRegistryEntry copyWith({
    int? displayOrder,
    String? parentThreadId,
    bool clearParentThreadId = false,
    List<String>? childThreadIds,
    String? threadName,
    bool clearThreadName = false,
    String? agentNickname,
    bool clearAgentNickname = false,
    String? agentRole,
    bool clearAgentRole = false,
    String? sourceKind,
    bool clearSourceKind = false,
    String? spawnItemId,
    bool clearSpawnItemId = false,
    bool? isClosed,
    bool? isPrimary,
  }) {
    return TranscriptThreadRegistryEntry(
      threadId: threadId,
      displayOrder: displayOrder ?? this.displayOrder,
      parentThreadId: clearParentThreadId
          ? null
          : (parentThreadId ?? this.parentThreadId),
      childThreadIds: childThreadIds ?? this.childThreadIds,
      threadName: clearThreadName ? null : (threadName ?? this.threadName),
      agentNickname: clearAgentNickname
          ? null
          : (agentNickname ?? this.agentNickname),
      agentRole: clearAgentRole ? null : (agentRole ?? this.agentRole),
      sourceKind: clearSourceKind ? null : (sourceKind ?? this.sourceKind),
      spawnItemId: clearSpawnItemId ? null : (spawnItemId ?? this.spawnItemId),
      isClosed: isClosed ?? this.isClosed,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class TranscriptTimelineState {
  const TranscriptTimelineState({
    required this.threadId,
    this.connectionStatus = TranscriptRuntimeSessionState.stopped,
    this.lifecycleState = TranscriptAgentLifecycleState.unknown,
    this.activeTurn,
    this.blocks = const <TranscriptUiBlock>[],
    this.pendingLocalUserMessageBlockIds = const <String>[],
    this.localUserMessageProviderBindings = const <String, String>{},
    this.hasUnreadActivity = false,
  });

  final String threadId;
  final TranscriptRuntimeSessionState connectionStatus;
  final TranscriptAgentLifecycleState lifecycleState;
  final TranscriptActiveTurnState? activeTurn;
  final List<TranscriptUiBlock> blocks;
  final List<String> pendingLocalUserMessageBlockIds;
  final Map<String, String> localUserMessageProviderBindings;
  final bool hasUnreadActivity;

  Map<String, TranscriptSessionPendingRequest> get pendingApprovalRequests =>
      activeTurn?.pendingApprovalRequests ??
      const <String, TranscriptSessionPendingRequest>{};

  Map<String, TranscriptSessionPendingUserInputRequest>
  get pendingUserInputRequests =>
      activeTurn?.pendingUserInputRequests ??
      const <String, TranscriptSessionPendingUserInputRequest>{};

  bool get hasPendingRequests =>
      pendingApprovalRequests.isNotEmpty || pendingUserInputRequests.isNotEmpty;

  List<TranscriptUiBlock> get transcriptBlocks => <TranscriptUiBlock>[
    ...blocks.where(_shouldAppearInTranscript),
    if (activeTurn != null)
      ...projectTranscriptTurnArtifacts(activeTurn!.artifacts),
  ];

  TranscriptTimelineState copyWith({
    TranscriptRuntimeSessionState? connectionStatus,
    TranscriptAgentLifecycleState? lifecycleState,
    TranscriptActiveTurnState? activeTurn,
    bool clearActiveTurn = false,
    List<TranscriptUiBlock>? blocks,
    List<String>? pendingLocalUserMessageBlockIds,
    bool clearPendingLocalUserMessageBlockIds = false,
    Map<String, String>? localUserMessageProviderBindings,
    bool clearLocalUserMessageProviderBindings = false,
    bool? hasUnreadActivity,
  }) {
    return TranscriptTimelineState(
      threadId: threadId,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      activeTurn: clearActiveTurn ? null : (activeTurn ?? this.activeTurn),
      blocks: blocks ?? this.blocks,
      pendingLocalUserMessageBlockIds: clearPendingLocalUserMessageBlockIds
          ? const <String>[]
          : (pendingLocalUserMessageBlockIds ??
                this.pendingLocalUserMessageBlockIds),
      localUserMessageProviderBindings: clearLocalUserMessageProviderBindings
          ? const <String, String>{}
          : (localUserMessageProviderBindings ??
                this.localUserMessageProviderBindings),
      hasUnreadActivity: hasUnreadActivity ?? this.hasUnreadActivity,
    );
  }
}

class TranscriptSessionHeaderMetadata {
  const TranscriptSessionHeaderMetadata({
    this.cwd,
    this.model,
    this.modelProvider,
    this.reasoningEffort,
  });

  final String? cwd;
  final String? model;
  final String? modelProvider;
  final String? reasoningEffort;

  TranscriptSessionHeaderMetadata copyWith({
    String? cwd,
    bool clearCwd = false,
    String? model,
    bool clearModel = false,
    String? modelProvider,
    bool clearModelProvider = false,
    String? reasoningEffort,
    bool clearReasoningEffort = false,
  }) {
    return TranscriptSessionHeaderMetadata(
      cwd: clearCwd ? null : (cwd ?? this.cwd),
      model: clearModel ? null : (model ?? this.model),
      modelProvider: clearModelProvider
          ? null
          : (modelProvider ?? this.modelProvider),
      reasoningEffort: clearReasoningEffort
          ? null
          : (reasoningEffort ?? this.reasoningEffort),
    );
  }
}
