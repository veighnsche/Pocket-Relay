part of 'codex_session_state.dart';

class CodexSessionState {
  const CodexSessionState({
    this.connectionStatus = CodexRuntimeSessionState.stopped,
    this.rootThreadId,
    this.selectedThreadId,
    this.timelinesByThreadId = const <String, CodexTimelineState>{},
    this.threadRegistry = const <String, CodexThreadRegistryEntry>{},
    this.requestOwnerById = const <String, String>{},
    this.sessionThreadId,
    this.sessionActiveTurn,
    this.sessionBlocks = const <CodexUiBlock>[],
    this.sessionPendingLocalUserMessageBlockIds = const <String>[],
    this.sessionLocalUserMessageProviderBindings = const <String, String>{},
    this.headerMetadata = const CodexSessionHeaderMetadata(),
  });

  factory CodexSessionState.initial() {
    return const CodexSessionState();
  }

  factory CodexSessionState.transcript({
    required CodexRuntimeSessionState connectionStatus,
    String? threadId,
    CodexActiveTurnState? activeTurn,
    List<CodexUiBlock> blocks = const <CodexUiBlock>[],
    List<String> pendingLocalUserMessageBlockIds = const <String>[],
    Map<String, String> localUserMessageProviderBindings =
        const <String, String>{},
    CodexSessionHeaderMetadata headerMetadata =
        const CodexSessionHeaderMetadata(),
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus,
      sessionThreadId: threadId,
      sessionActiveTurn: activeTurn,
      sessionBlocks: blocks,
      sessionPendingLocalUserMessageBlockIds: pendingLocalUserMessageBlockIds,
      sessionLocalUserMessageProviderBindings: localUserMessageProviderBindings,
      headerMetadata: headerMetadata,
    );
  }

  final CodexRuntimeSessionState connectionStatus;
  final String? rootThreadId;
  final String? selectedThreadId;
  final Map<String, CodexTimelineState> timelinesByThreadId;
  final Map<String, CodexThreadRegistryEntry> threadRegistry;
  final Map<String, String> requestOwnerById;

  final String? sessionThreadId;
  final CodexActiveTurnState? sessionActiveTurn;
  final List<CodexUiBlock> sessionBlocks;
  final List<String> sessionPendingLocalUserMessageBlockIds;
  final Map<String, String> sessionLocalUserMessageProviderBindings;
  final CodexSessionHeaderMetadata headerMetadata;

  String? get currentThreadId =>
      selectedThreadId ?? rootThreadId ?? sessionThreadId;

  CodexTimelineState? get rootTimeline =>
      rootThreadId == null ? null : timelinesByThreadId[rootThreadId!];

  CodexTimelineState? get selectedTimeline {
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

  CodexActiveTurnState? get activeTurn =>
      selectedTimeline?.activeTurn ?? sessionActiveTurn;

  List<CodexUiBlock> get blocks => selectedTimeline?.blocks ?? sessionBlocks;

  List<String> get pendingLocalUserMessageBlockIds =>
      selectedTimeline?.pendingLocalUserMessageBlockIds ??
      sessionPendingLocalUserMessageBlockIds;

  Map<String, String> get localUserMessageProviderBindings =>
      selectedTimeline?.localUserMessageProviderBindings ??
      sessionLocalUserMessageProviderBindings;

  Map<String, CodexSessionPendingRequest> get pendingApprovalRequests =>
      selectedTimeline?.pendingApprovalRequests ??
      sessionActiveTurn?.pendingApprovalRequests ??
      const <String, CodexSessionPendingRequest>{};

  Map<String, CodexSessionPendingUserInputRequest>
  get pendingUserInputRequests =>
      selectedTimeline?.pendingUserInputRequests ??
      sessionActiveTurn?.pendingUserInputRequests ??
      const <String, CodexSessionPendingUserInputRequest>{};

  bool get isBusy => connectionStatus == CodexRuntimeSessionState.running;

  List<CodexUiBlock> get transcriptBlocks =>
      selectedTimeline?.transcriptBlocks ??
      <CodexUiBlock>[
        ...sessionBlocks.where(_shouldAppearInTranscript),
        if (sessionActiveTurn != null)
          ...projectCodexTurnArtifacts(sessionActiveTurn!.artifacts),
      ];

  CodexTimelineState? timelineForThread(String? threadId) {
    if (threadId == null) {
      return null;
    }

    return timelinesByThreadId[threadId];
  }

  CodexSessionState copyWithProjectedTranscript({
    CodexRuntimeSessionState? connectionStatus,
    String? threadId,
    bool clearThreadId = false,
    CodexActiveTurnState? activeTurn,
    bool clearActiveTurn = false,
    List<CodexUiBlock>? blocks,
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

  CodexSessionState copyWith({
    CodexRuntimeSessionState? connectionStatus,
    String? rootThreadId,
    bool clearRootThreadId = false,
    String? selectedThreadId,
    bool clearSelectedThreadId = false,
    Map<String, CodexTimelineState>? timelinesByThreadId,
    bool clearTimelinesByThreadId = false,
    Map<String, CodexThreadRegistryEntry>? threadRegistry,
    bool clearThreadRegistry = false,
    Map<String, String>? requestOwnerById,
    bool clearRequestOwnerById = false,
    String? sessionThreadId,
    bool clearSessionThreadId = false,
    CodexActiveTurnState? sessionActiveTurn,
    bool clearSessionActiveTurn = false,
    List<CodexUiBlock>? sessionBlocks,
    List<String>? sessionPendingLocalUserMessageBlockIds,
    bool clearSessionPendingLocalUserMessageBlockIds = false,
    Map<String, String>? sessionLocalUserMessageProviderBindings,
    bool clearSessionLocalUserMessageProviderBindings = false,
    CodexSessionHeaderMetadata? headerMetadata,
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      rootThreadId: clearRootThreadId
          ? null
          : (rootThreadId ?? this.rootThreadId),
      selectedThreadId: clearSelectedThreadId
          ? null
          : (selectedThreadId ?? this.selectedThreadId),
      timelinesByThreadId: clearTimelinesByThreadId
          ? const <String, CodexTimelineState>{}
          : (timelinesByThreadId ?? this.timelinesByThreadId),
      threadRegistry: clearThreadRegistry
          ? const <String, CodexThreadRegistryEntry>{}
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
