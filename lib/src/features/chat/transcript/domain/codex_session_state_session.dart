part of 'transcript_session_state.dart';

class TranscriptSessionState {
  const TranscriptSessionState({
    this.connectionStatus = TranscriptRuntimeSessionState.stopped,
    this.rootThreadId,
    this.selectedThreadId,
    this.timelinesByThreadId = const <String, TranscriptTimelineState>{},
    this.threadRegistry = const <String, TranscriptThreadRegistryEntry>{},
    this.requestOwnerById = const <String, String>{},
    this.sessionThreadId,
    this.sessionActiveTurn,
    this.sessionBlocks = const <TranscriptUiBlock>[],
    this.sessionPendingLocalUserMessageBlockIds = const <String>[],
    this.sessionLocalUserMessageProviderBindings = const <String, String>{},
    this.headerMetadata = const TranscriptSessionHeaderMetadata(),
  });

  factory TranscriptSessionState.initial() {
    return const TranscriptSessionState();
  }

  factory TranscriptSessionState.transcript({
    required TranscriptRuntimeSessionState connectionStatus,
    String? threadId,
    TranscriptActiveTurnState? activeTurn,
    List<TranscriptUiBlock> blocks = const <TranscriptUiBlock>[],
    List<String> pendingLocalUserMessageBlockIds = const <String>[],
    Map<String, String> localUserMessageProviderBindings =
        const <String, String>{},
    TranscriptSessionHeaderMetadata headerMetadata =
        const TranscriptSessionHeaderMetadata(),
  }) {
    return TranscriptSessionState(
      connectionStatus: connectionStatus,
      sessionThreadId: threadId,
      sessionActiveTurn: activeTurn,
      sessionBlocks: blocks,
      sessionPendingLocalUserMessageBlockIds: pendingLocalUserMessageBlockIds,
      sessionLocalUserMessageProviderBindings: localUserMessageProviderBindings,
      headerMetadata: headerMetadata,
    );
  }

  final TranscriptRuntimeSessionState connectionStatus;
  final String? rootThreadId;
  final String? selectedThreadId;
  final Map<String, TranscriptTimelineState> timelinesByThreadId;
  final Map<String, TranscriptThreadRegistryEntry> threadRegistry;
  final Map<String, String> requestOwnerById;

  final String? sessionThreadId;
  final TranscriptActiveTurnState? sessionActiveTurn;
  final List<TranscriptUiBlock> sessionBlocks;
  final List<String> sessionPendingLocalUserMessageBlockIds;
  final Map<String, String> sessionLocalUserMessageProviderBindings;
  final TranscriptSessionHeaderMetadata headerMetadata;

  String? get currentThreadId =>
      selectedThreadId ?? rootThreadId ?? sessionThreadId;

  TranscriptTimelineState? get rootTimeline =>
      rootThreadId == null ? null : timelinesByThreadId[rootThreadId!];

  TranscriptTimelineState? get selectedTimeline {
    final selectedId = selectedThreadId;
    if (selectedId != null) {
      final selected = timelinesByThreadId[selectedId];
      if (selected != null) {
        return selected;
      }
    }
    return rootTimeline;
  }

  bool get hasMultipleTimelines => timelinesByThreadId.length > 1;

  String? get threadId => selectedTimeline?.threadId ?? currentThreadId;

  TranscriptActiveTurnState? get activeTurn =>
      selectedTimeline?.activeTurn ?? sessionActiveTurn;

  List<TranscriptUiBlock> get blocks =>
      selectedTimeline?.blocks ?? sessionBlocks;

  List<String> get pendingLocalUserMessageBlockIds =>
      selectedTimeline?.pendingLocalUserMessageBlockIds ??
      sessionPendingLocalUserMessageBlockIds;

  Map<String, String> get localUserMessageProviderBindings =>
      selectedTimeline?.localUserMessageProviderBindings ??
      sessionLocalUserMessageProviderBindings;

  Map<String, TranscriptSessionPendingRequest> get pendingApprovalRequests =>
      selectedTimeline?.pendingApprovalRequests ??
      sessionActiveTurn?.pendingApprovalRequests ??
      const <String, TranscriptSessionPendingRequest>{};

  Map<String, TranscriptSessionPendingUserInputRequest>
  get pendingUserInputRequests =>
      selectedTimeline?.pendingUserInputRequests ??
      sessionActiveTurn?.pendingUserInputRequests ??
      const <String, TranscriptSessionPendingUserInputRequest>{};

  bool get isBusy => connectionStatus == TranscriptRuntimeSessionState.running;

  List<TranscriptUiBlock> get transcriptBlocks =>
      selectedTimeline?.transcriptBlocks ??
      <TranscriptUiBlock>[
        ...sessionBlocks.where(_shouldAppearInTranscript),
        if (sessionActiveTurn != null)
          ...projectTranscriptTurnArtifacts(sessionActiveTurn!.artifacts),
      ];

  TranscriptTimelineState? timelineForThread(String? threadId) {
    if (threadId == null) {
      return null;
    }

    return timelinesByThreadId[threadId];
  }

  TranscriptSessionState copyWithProjectedTranscript({
    TranscriptRuntimeSessionState? connectionStatus,
    String? threadId,
    bool clearThreadId = false,
    TranscriptActiveTurnState? activeTurn,
    bool clearActiveTurn = false,
    List<TranscriptUiBlock>? blocks,
    List<String>? pendingLocalUserMessageBlockIds,
    bool clearPendingLocalUserMessageBlockIds = false,
    Map<String, String>? localUserMessageProviderBindings,
    bool clearLocalUserMessageProviderBindings = false,
  }) {
    return copyWith(
      connectionStatus: connectionStatus,
      sessionThreadId: threadId ?? sessionThreadId,
      clearSessionThreadId: clearThreadId,
      sessionActiveTurn: activeTurn ?? sessionActiveTurn,
      clearSessionActiveTurn: clearActiveTurn,
      sessionBlocks: blocks ?? sessionBlocks,
      sessionPendingLocalUserMessageBlockIds:
          clearPendingLocalUserMessageBlockIds
          ? const <String>[]
          : (pendingLocalUserMessageBlockIds ??
                sessionPendingLocalUserMessageBlockIds),
      sessionLocalUserMessageProviderBindings:
          clearLocalUserMessageProviderBindings
          ? const <String, String>{}
          : (localUserMessageProviderBindings ??
                sessionLocalUserMessageProviderBindings),
    );
  }

  TranscriptSessionState copyWith({
    TranscriptRuntimeSessionState? connectionStatus,
    String? rootThreadId,
    bool clearRootThreadId = false,
    String? selectedThreadId,
    bool clearSelectedThreadId = false,
    Map<String, TranscriptTimelineState>? timelinesByThreadId,
    bool clearTimelinesByThreadId = false,
    Map<String, TranscriptThreadRegistryEntry>? threadRegistry,
    bool clearThreadRegistry = false,
    Map<String, String>? requestOwnerById,
    bool clearRequestOwnerById = false,
    String? sessionThreadId,
    bool clearSessionThreadId = false,
    TranscriptActiveTurnState? sessionActiveTurn,
    bool clearSessionActiveTurn = false,
    List<TranscriptUiBlock>? sessionBlocks,
    List<String>? sessionPendingLocalUserMessageBlockIds,
    bool clearSessionPendingLocalUserMessageBlockIds = false,
    Map<String, String>? sessionLocalUserMessageProviderBindings,
    bool clearSessionLocalUserMessageProviderBindings = false,
    TranscriptSessionHeaderMetadata? headerMetadata,
  }) {
    return TranscriptSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      rootThreadId: clearRootThreadId
          ? null
          : (rootThreadId ?? this.rootThreadId),
      selectedThreadId: clearSelectedThreadId
          ? null
          : (selectedThreadId ?? this.selectedThreadId),
      timelinesByThreadId: clearTimelinesByThreadId
          ? const <String, TranscriptTimelineState>{}
          : (timelinesByThreadId ?? this.timelinesByThreadId),
      threadRegistry: clearThreadRegistry
          ? const <String, TranscriptThreadRegistryEntry>{}
          : (threadRegistry ?? this.threadRegistry),
      requestOwnerById: clearRequestOwnerById
          ? const <String, String>{}
          : (requestOwnerById ?? this.requestOwnerById),
      sessionThreadId: clearSessionThreadId
          ? null
          : (sessionThreadId ?? this.sessionThreadId),
      sessionActiveTurn: clearSessionActiveTurn
          ? null
          : (sessionActiveTurn ?? this.sessionActiveTurn),
      sessionBlocks: sessionBlocks ?? this.sessionBlocks,
      sessionPendingLocalUserMessageBlockIds:
          clearSessionPendingLocalUserMessageBlockIds
          ? const <String>[]
          : (sessionPendingLocalUserMessageBlockIds ??
                this.sessionPendingLocalUserMessageBlockIds),
      sessionLocalUserMessageProviderBindings:
          clearSessionLocalUserMessageProviderBindings
          ? const <String, String>{}
          : (sessionLocalUserMessageProviderBindings ??
                this.sessionLocalUserMessageProviderBindings),
      headerMetadata: headerMetadata ?? this.headerMetadata,
    );
  }
}
