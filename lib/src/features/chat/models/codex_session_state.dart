import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class CodexSessionTurnTimer {
  const CodexSessionTurnTimer({
    required this.turnId,
    required this.startedAt,
    this.completedAt,
    this.accumulatedElapsed = Duration.zero,
    this.activeSegmentStartedMonotonicAt,
    this.completedElapsed,
    this.isPaused = false,
    DateTime? activeSegmentStartedAt,
  }) : activeSegmentStartedAt =
           activeSegmentStartedAt ?? (isPaused ? null : startedAt);

  final String turnId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration accumulatedElapsed;
  final DateTime? activeSegmentStartedAt;
  final Duration? activeSegmentStartedMonotonicAt;
  final Duration? completedElapsed;
  final bool isPaused;

  bool get isRunning => completedAt == null;

  bool get isTicking => isRunning && !isPaused;

  Duration elapsedNow() {
    return elapsedAt(DateTime.now(), monotonicNow: CodexMonotonicClock.now());
  }

  Duration elapsedAt(DateTime now, {Duration? monotonicNow}) {
    final frozenElapsed = completedElapsed;
    if (frozenElapsed != null) {
      return frozenElapsed;
    }

    final activeStartedAt = activeSegmentStartedAt;
    if (activeStartedAt == null) {
      if (completedAt != null && accumulatedElapsed == Duration.zero) {
        return _safeWallClockDifference(startedAt, completedAt!);
      }
      return accumulatedElapsed;
    }

    return accumulatedElapsed +
        _segmentElapsed(
          activeStartedAt: activeStartedAt,
          activeStartedMonotonicAt: activeSegmentStartedMonotonicAt,
          wallClockEnd: completedAt ?? now,
          monotonicEnd: monotonicNow,
        );
  }

  CodexSessionTurnTimer pause({
    required DateTime pausedAt,
    Duration? monotonicAt,
  }) {
    if (!isRunning || isPaused) {
      return this;
    }

    return copyWith(
      accumulatedElapsed: elapsedAt(pausedAt, monotonicNow: monotonicAt),
      clearActiveSegmentStartedAt: true,
      clearActiveSegmentStartedMonotonicAt: true,
      isPaused: true,
    );
  }

  CodexSessionTurnTimer resume({
    required DateTime resumedAt,
    Duration? monotonicAt,
  }) {
    if (!isRunning || !isPaused) {
      return this;
    }

    return copyWith(
      activeSegmentStartedAt: resumedAt,
      activeSegmentStartedMonotonicAt: monotonicAt,
      isPaused: false,
    );
  }

  CodexSessionTurnTimer complete({
    required DateTime completedAt,
    Duration? monotonicAt,
  }) {
    final frozenElapsed =
        completedElapsed ?? elapsedAt(completedAt, monotonicNow: monotonicAt);
    return copyWith(
      completedAt: this.completedAt ?? completedAt,
      accumulatedElapsed: frozenElapsed,
      completedElapsed: frozenElapsed,
      clearActiveSegmentStartedAt: true,
      clearActiveSegmentStartedMonotonicAt: true,
      isPaused: true,
    );
  }

  CodexSessionTurnTimer copyWith({
    DateTime? completedAt,
    Duration? accumulatedElapsed,
    DateTime? activeSegmentStartedAt,
    bool clearActiveSegmentStartedAt = false,
    Duration? activeSegmentStartedMonotonicAt,
    bool clearActiveSegmentStartedMonotonicAt = false,
    Duration? completedElapsed,
    bool clearCompletedElapsed = false,
    bool? isPaused,
  }) {
    return CodexSessionTurnTimer(
      turnId: turnId,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      accumulatedElapsed: accumulatedElapsed ?? this.accumulatedElapsed,
      activeSegmentStartedAt: clearActiveSegmentStartedAt
          ? null
          : (activeSegmentStartedAt ?? this.activeSegmentStartedAt),
      activeSegmentStartedMonotonicAt: clearActiveSegmentStartedMonotonicAt
          ? null
          : (activeSegmentStartedMonotonicAt ??
                this.activeSegmentStartedMonotonicAt),
      completedElapsed: clearCompletedElapsed
          ? null
          : (completedElapsed ?? this.completedElapsed),
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Duration _segmentElapsed({
    required DateTime activeStartedAt,
    required Duration? activeStartedMonotonicAt,
    required DateTime wallClockEnd,
    required Duration? monotonicEnd,
  }) {
    if (activeStartedMonotonicAt != null && monotonicEnd != null) {
      final monotonicElapsed = monotonicEnd - activeStartedMonotonicAt;
      if (monotonicElapsed.isNegative) {
        return Duration.zero;
      }
      return monotonicElapsed;
    }

    return _safeWallClockDifference(activeStartedAt, wallClockEnd);
  }

  Duration _safeWallClockDifference(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      return Duration.zero;
    }
    return end.difference(start);
  }
}

enum CodexAgentLifecycleState {
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

class CodexThreadRegistryEntry {
  const CodexThreadRegistryEntry({
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

  CodexThreadRegistryEntry copyWith({
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
    return CodexThreadRegistryEntry(
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

class CodexTimelineState {
  const CodexTimelineState({
    required this.threadId,
    this.connectionStatus = CodexRuntimeSessionState.stopped,
    this.lifecycleState = CodexAgentLifecycleState.unknown,
    this.activeTurn,
    this.blocks = const <CodexUiBlock>[],
    this.pendingLocalUserMessageBlockIds = const <String>[],
    this.localUserMessageProviderBindings = const <String, String>{},
    this.hasUnreadActivity = false,
  });

  factory CodexTimelineState.fromLegacySessionState(
    CodexSessionState legacyState, {
    required String threadId,
    CodexAgentLifecycleState lifecycleState = CodexAgentLifecycleState.unknown,
  }) {
    return CodexTimelineState(
      threadId: threadId,
      connectionStatus: legacyState.connectionStatus,
      lifecycleState: lifecycleState,
      activeTurn: legacyState.activeTurn?.copyWith(threadId: threadId),
      blocks: legacyState.blocks,
      pendingLocalUserMessageBlockIds:
          legacyState.pendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings:
          legacyState.localUserMessageProviderBindings,
    );
  }

  final String threadId;
  final CodexRuntimeSessionState connectionStatus;
  final CodexAgentLifecycleState lifecycleState;
  final CodexActiveTurnState? activeTurn;
  final List<CodexUiBlock> blocks;
  final List<String> pendingLocalUserMessageBlockIds;
  final Map<String, String> localUserMessageProviderBindings;
  final bool hasUnreadActivity;

  Map<String, CodexSessionPendingRequest> get pendingApprovalRequests =>
      activeTurn?.pendingApprovalRequests ??
      const <String, CodexSessionPendingRequest>{};

  Map<String, CodexSessionPendingUserInputRequest>
  get pendingUserInputRequests =>
      activeTurn?.pendingUserInputRequests ??
      const <String, CodexSessionPendingUserInputRequest>{};

  bool get hasPendingRequests =>
      pendingApprovalRequests.isNotEmpty || pendingUserInputRequests.isNotEmpty;

  List<CodexUiBlock> get transcriptBlocks => <CodexUiBlock>[
    ...blocks.where(_shouldAppearInTranscript),
    if (activeTurn != null) ...projectCodexTurnArtifacts(activeTurn!.artifacts),
  ];

  CodexTimelineState copyWith({
    CodexRuntimeSessionState? connectionStatus,
    CodexAgentLifecycleState? lifecycleState,
    CodexActiveTurnState? activeTurn,
    bool clearActiveTurn = false,
    List<CodexUiBlock>? blocks,
    List<String>? pendingLocalUserMessageBlockIds,
    bool clearPendingLocalUserMessageBlockIds = false,
    Map<String, String>? localUserMessageProviderBindings,
    bool clearLocalUserMessageProviderBindings = false,
    bool? hasUnreadActivity,
  }) {
    return CodexTimelineState(
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

  CodexSessionState toLegacySessionState() {
    return CodexSessionState(
      connectionStatus: connectionStatus,
      threadId: threadId,
      activeTurn: activeTurn,
      blocks: blocks,
      pendingLocalUserMessageBlockIds: pendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings: localUserMessageProviderBindings,
    );
  }
}

class CodexSessionState {
  const CodexSessionState({
    this.connectionStatus = CodexRuntimeSessionState.stopped,
    String? threadId,
    CodexActiveTurnState? activeTurn,
    List<CodexUiBlock> blocks = const <CodexUiBlock>[],
    List<String> pendingLocalUserMessageBlockIds = const <String>[],
    Map<String, String> localUserMessageProviderBindings =
        const <String, String>{},
    this.rootThreadId,
    this.selectedThreadId,
    this.timelinesByThreadId = const <String, CodexTimelineState>{},
    this.threadRegistry = const <String, CodexThreadRegistryEntry>{},
    this.requestOwnerById = const <String, String>{},
  }) : _legacyThreadId = threadId,
       _legacyActiveTurn = activeTurn,
       _legacyBlocks = blocks,
       _legacyPendingLocalUserMessageBlockIds = pendingLocalUserMessageBlockIds,
       _legacyLocalUserMessageProviderBindings =
           localUserMessageProviderBindings;

  factory CodexSessionState.initial() {
    return const CodexSessionState();
  }

  final CodexRuntimeSessionState connectionStatus;
  final String? rootThreadId;
  final String? selectedThreadId;
  final Map<String, CodexTimelineState> timelinesByThreadId;
  final Map<String, CodexThreadRegistryEntry> threadRegistry;
  final Map<String, String> requestOwnerById;

  final String? _legacyThreadId;
  final CodexActiveTurnState? _legacyActiveTurn;
  final List<CodexUiBlock> _legacyBlocks;
  final List<String> _legacyPendingLocalUserMessageBlockIds;
  final Map<String, String> _legacyLocalUserMessageProviderBindings;

  bool get isWorkspaceMode =>
      rootThreadId != null ||
      selectedThreadId != null ||
      timelinesByThreadId.isNotEmpty ||
      threadRegistry.isNotEmpty ||
      requestOwnerById.isNotEmpty;

  String? get effectiveRootThreadId => rootThreadId ?? _legacyThreadId;

  String? get effectiveSelectedThreadId =>
      selectedThreadId ?? rootThreadId ?? _legacyThreadId;

  Map<String, CodexTimelineState> get effectiveTimelinesByThreadId {
    if (timelinesByThreadId.isNotEmpty) {
      return timelinesByThreadId;
    }
    final legacyThreadId = _legacyThreadId;
    if (legacyThreadId == null) {
      return const <String, CodexTimelineState>{};
    }
    return <String, CodexTimelineState>{
      legacyThreadId: _legacyTimeline(legacyThreadId),
    };
  }

  CodexTimelineState? get rootTimeline =>
      timelineForThread(effectiveRootThreadId);

  CodexTimelineState? get selectedTimeline =>
      timelineForThread(effectiveSelectedThreadId) ?? rootTimeline;

  bool get hasMultipleTimelines => effectiveTimelinesByThreadId.length > 1;

  String? get threadId => isWorkspaceMode
      ? (selectedTimeline?.threadId ?? effectiveSelectedThreadId)
      : _legacyThreadId;

  CodexActiveTurnState? get activeTurn =>
      isWorkspaceMode ? selectedTimeline?.activeTurn : _legacyActiveTurn;

  List<CodexUiBlock> get blocks => isWorkspaceMode
      ? (selectedTimeline?.blocks ?? const <CodexUiBlock>[])
      : _legacyBlocks;

  List<String> get pendingLocalUserMessageBlockIds => isWorkspaceMode
      ? (selectedTimeline?.pendingLocalUserMessageBlockIds ?? const <String>[])
      : _legacyPendingLocalUserMessageBlockIds;

  Map<String, String> get localUserMessageProviderBindings => isWorkspaceMode
      ? (selectedTimeline?.localUserMessageProviderBindings ??
            const <String, String>{})
      : _legacyLocalUserMessageProviderBindings;

  Map<String, CodexSessionPendingRequest> get pendingApprovalRequests =>
      isWorkspaceMode
      ? (selectedTimeline?.pendingApprovalRequests ??
            const <String, CodexSessionPendingRequest>{})
      : _legacyActiveTurn?.pendingApprovalRequests ??
            const <String, CodexSessionPendingRequest>{};

  Map<String, CodexSessionPendingUserInputRequest>
  get pendingUserInputRequests => isWorkspaceMode
      ? (selectedTimeline?.pendingUserInputRequests ??
            const <String, CodexSessionPendingUserInputRequest>{})
      : _legacyActiveTurn?.pendingUserInputRequests ??
            const <String, CodexSessionPendingUserInputRequest>{};

  bool get isBusy => connectionStatus == CodexRuntimeSessionState.running;

  List<CodexUiBlock> get transcriptBlocks => isWorkspaceMode
      ? (selectedTimeline?.transcriptBlocks ?? const <CodexUiBlock>[])
      : <CodexUiBlock>[
          ..._legacyBlocks.where(_shouldAppearInTranscript),
          if (_legacyActiveTurn != null)
            ...projectCodexTurnArtifacts(_legacyActiveTurn.artifacts),
        ];

  CodexTimelineState? timelineForThread(String? threadId) {
    if (threadId == null) {
      return null;
    }

    final timeline = timelinesByThreadId[threadId];
    if (timeline != null) {
      return timeline;
    }

    if (!isWorkspaceMode && _legacyThreadId == threadId) {
      return _legacyTimeline(threadId);
    }

    return null;
  }

  CodexTimelineState _legacyTimeline(String threadId) {
    return CodexTimelineState(
      threadId: threadId,
      connectionStatus: connectionStatus,
      activeTurn: _legacyActiveTurn,
      blocks: _legacyBlocks,
      pendingLocalUserMessageBlockIds: _legacyPendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings: _legacyLocalUserMessageProviderBindings,
    );
  }

  CodexSessionState copyWith({
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
  }) {
    return CodexSessionState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      threadId: clearThreadId ? null : (threadId ?? _legacyThreadId),
      activeTurn: clearActiveTurn ? null : (activeTurn ?? _legacyActiveTurn),
      blocks: blocks ?? _legacyBlocks,
      pendingLocalUserMessageBlockIds: clearPendingLocalUserMessageBlockIds
          ? const <String>[]
          : (pendingLocalUserMessageBlockIds ??
                _legacyPendingLocalUserMessageBlockIds),
      localUserMessageProviderBindings: clearLocalUserMessageProviderBindings
          ? const <String, String>{}
          : (localUserMessageProviderBindings ??
                _legacyLocalUserMessageProviderBindings),
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
    );
  }
}

List<CodexUiBlock> projectCodexTurnArtifacts(
  Iterable<CodexTurnArtifact> artifacts,
) {
  final projected = <CodexUiBlock>[];

  for (final artifact in artifacts) {
    switch (artifact) {
      case CodexTurnTextArtifact():
        projected.add(
          CodexTextBlock(
            id: artifact.id,
            kind: artifact.kind,
            createdAt: artifact.createdAt,
            title: artifact.title,
            body: artifact.body,
            isRunning: artifact.isStreaming,
          ),
        );
      case CodexTurnWorkArtifact():
        projected.add(
          CodexWorkLogGroupBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            entries: artifact.entries,
          ),
        );
      case CodexTurnPlanArtifact():
        projected.add(
          CodexProposedPlanBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            markdown: artifact.markdown,
            isStreaming: artifact.isStreaming,
          ),
        );
      case CodexTurnChangedFilesArtifact():
        projected.add(
          CodexChangedFilesBlock(
            id: artifact.id,
            createdAt: artifact.createdAt,
            title: artifact.title,
            files: artifact.files,
            unifiedDiff: artifact.unifiedDiff,
            isRunning: artifact.isStreaming,
          ),
        );
      case CodexTurnBlockArtifact():
        projected.add(artifact.block);
    }
  }

  return projected;
}

List<CodexTurnArtifact> appendCodexTurnArtifact(
  List<CodexTurnArtifact> artifacts,
  CodexTurnArtifact nextArtifact,
) {
  final nextArtifacts = List<CodexTurnArtifact>.from(artifacts);
  if (nextArtifacts.isNotEmpty) {
    nextArtifacts[nextArtifacts.length - 1] = freezeCodexTurnArtifact(
      nextArtifacts.last,
    );
  }
  nextArtifacts.add(nextArtifact);
  return nextArtifacts;
}

CodexTurnArtifact freezeCodexTurnArtifact(CodexTurnArtifact artifact) {
  return switch (artifact) {
    CodexTurnTextArtifact(:final isStreaming) when isStreaming =>
      CodexTurnTextArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        kind: artifact.kind,
        title: artifact.title,
        body: artifact.body,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    CodexTurnWorkArtifact() => CodexTurnWorkArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      entries: artifact.entries
          .map((entry) => entry.copyWith(isRunning: false))
          .toList(growable: false),
    ),
    CodexTurnPlanArtifact(:final isStreaming) when isStreaming =>
      CodexTurnPlanArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        title: artifact.title,
        markdown: artifact.markdown,
        itemId: artifact.itemId,
        isStreaming: false,
      ),
    CodexTurnChangedFilesArtifact(:final isStreaming) when isStreaming =>
      CodexTurnChangedFilesArtifact(
        id: artifact.id,
        createdAt: artifact.createdAt,
        title: artifact.title,
        itemId: artifact.itemId,
        files: artifact.files,
        unifiedDiff: artifact.unifiedDiff,
        entries: artifact.entries
            .map((entry) => entry.copyWith(isRunning: false))
            .toList(growable: false),
        isStreaming: false,
      ),
    CodexTurnBlockArtifact(:final block) => CodexTurnBlockArtifact(
      block: _freezeCodexUiBlock(block),
    ),
    _ => artifact,
  };
}

CodexUiBlock _freezeCodexUiBlock(CodexUiBlock block) {
  return switch (block) {
    CodexTextBlock(:final isRunning) when isRunning => block.copyWith(
      isRunning: false,
    ),
    CodexProposedPlanBlock(:final isStreaming) when isStreaming =>
      block.copyWith(isStreaming: false),
    CodexChangedFilesBlock(:final isRunning) when isRunning => block.copyWith(
      isRunning: false,
    ),
    _ => block,
  };
}

bool _shouldAppearInTranscript(CodexUiBlock block) {
  return switch (block) {
    CodexApprovalRequestBlock(:final isResolved) => isResolved,
    CodexUserInputRequestBlock(:final isResolved) => isResolved,
    CodexStatusBlock(:final isTranscriptSignal) => isTranscriptSignal,
    _ => true,
  };
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

Iterable<String> codexUiBlockIds(Iterable<CodexUiBlock> blocks) sync* {
  for (final block in blocks) {
    yield block.id;
    if (block case CodexWorkLogGroupBlock(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

Iterable<String> codexTurnArtifactIds(
  Iterable<CodexTurnArtifact> artifacts,
) sync* {
  for (final artifact in artifacts) {
    yield artifact.id;
    if (artifact case CodexTurnWorkArtifact(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

sealed class CodexTurnArtifact {
  const CodexTurnArtifact({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

final class CodexTurnTextArtifact extends CodexTurnArtifact {
  const CodexTurnTextArtifact({
    required super.id,
    required super.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.itemId,
    this.isStreaming = false,
  });

  final CodexUiBlockKind kind;
  final String title;
  final String body;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnWorkArtifact extends CodexTurnArtifact {
  const CodexTurnWorkArtifact({
    required super.id,
    required super.createdAt,
    this.entries = const <CodexWorkLogEntry>[],
  });

  final List<CodexWorkLogEntry> entries;
}

final class CodexTurnPlanArtifact extends CodexTurnArtifact {
  const CodexTurnPlanArtifact({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.itemId,
    this.isStreaming = false,
  });

  final String title;
  final String markdown;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnChangedFilesArtifact extends CodexTurnArtifact {
  const CodexTurnChangedFilesArtifact({
    required super.id,
    required super.createdAt,
    required this.title,
    String? itemId,
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    this.entries = const <CodexChangedFilesEntry>[],
    this.isStreaming = false,
  }) : _itemId = itemId,
       _files = files,
       _unifiedDiff = unifiedDiff;

  final String title;
  final String? _itemId;
  final List<CodexChangedFile>? _files;
  final String? _unifiedDiff;
  final List<CodexChangedFilesEntry> entries;
  final bool isStreaming;

  String? get itemId => _itemId ?? entries.lastOrNull?.itemId;

  List<CodexChangedFile> get files {
    final explicitFiles = _files;
    if (explicitFiles != null) {
      return explicitFiles;
    }

    return _mergedChangedFiles(entries);
  }

  String? get unifiedDiff {
    final explicitUnifiedDiff = _unifiedDiff;
    if (explicitUnifiedDiff != null) {
      return explicitUnifiedDiff;
    }

    return _mergedUnifiedDiff(entries);
  }
}

final class CodexChangedFilesEntry {
  const CodexChangedFilesEntry({
    required this.id,
    required this.itemId,
    required this.createdAt,
    this.files = const <CodexChangedFile>[],
    this.unifiedDiff,
    this.isRunning = false,
  });

  final String id;
  final String itemId;
  final DateTime createdAt;
  final List<CodexChangedFile> files;
  final String? unifiedDiff;
  final bool isRunning;

  CodexChangedFilesEntry copyWith({
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    bool? isRunning,
  }) {
    return CodexChangedFilesEntry(
      id: id,
      itemId: itemId,
      createdAt: createdAt,
      files: files ?? this.files,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

List<CodexChangedFile> _mergedChangedFiles(
  Iterable<CodexChangedFilesEntry> entries,
) {
  final mergedByPath = <String, CodexChangedFile>{};

  for (final entry in entries) {
    for (final file in entry.files) {
      mergedByPath[file.path] = file;
    }
  }

  return mergedByPath.values.toList(growable: false);
}

String? _mergedUnifiedDiff(Iterable<CodexChangedFilesEntry> entries) {
  final parts = entries
      .map((entry) => entry.unifiedDiff?.trim())
      .whereType<String>()
      .where((diff) => diff.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return null;
  }

  return parts.join('\n');
}

final class CodexTurnBlockArtifact extends CodexTurnArtifact {
  CodexTurnBlockArtifact({required this.block})
    : super(id: block.id, createdAt: block.createdAt);

  final CodexUiBlock block;
}

final class CodexTurnDiffSnapshot {
  const CodexTurnDiffSnapshot({
    required this.turnId,
    required this.createdAt,
    required this.unifiedDiff,
  });

  final String turnId;
  final DateTime createdAt;
  final String unifiedDiff;

  CodexTurnDiffSnapshot copyWith({DateTime? createdAt, String? unifiedDiff}) {
    return CodexTurnDiffSnapshot(
      turnId: turnId,
      createdAt: createdAt ?? this.createdAt,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
    );
  }
}

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
